-- ============================================================================
--  DEEL 8 VAN 14
-- ============================================================================
--
--  Plak dit pas NA deel 7. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


-- De hand een stap verder: volgende speler, volgende straat, of afrekenen.
create or replace function public.pk_advance(p_round bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_levend int;
  v_kunnen int;
  v_volgende smallint;
  v_kaarten text[];
  v_gedeeld int;
begin
  select * into r from public.pk_rounds where id = p_round for update;
  if r.settled_at is not null then return; end if;

  select count(*) into v_levend from public.pk_seats where round_id = p_round and not folded;
  -- Iedereen op één na gepast: die krijgt de pot, zonder te hoeven laten zien.
  if v_levend <= 1 then
    perform public.pk_settle(p_round);
    return;
  end if;

  v_volgende := public.pk_next_seat(p_round, coalesce(r.to_act_seat, r.button_seat));
  if v_volgende is not null then
    update public.pk_rounds
       set to_act_seat = v_volgende, act_deadline = now() + interval '25 seconds'
     where id = p_round;
    return;
  end if;

  -- De straat is dicht. Inzetten van deze straat gaan in de pot (total_bet houdt ze bij),
  -- en dan de volgende kaarten.
  update public.pk_seats set bet = 0, acted = false, may_raise = true
   where round_id = p_round;
  update public.pk_rounds set high_bet = 0, min_raise = bb where id = p_round;

  if r.street >= 3 then
    perform public.pk_settle(p_round);
    return;
  end if;

  select d.cards into v_kaarten from poker.deck d where d.round_id = p_round;
  -- De eerste kaarten van de stok zijn voor de spelers: twee per stoel.
  select count(*) * 2 into v_gedeeld from public.pk_seats where round_id = p_round;

  update public.pk_rounds
     set street = r.street + 1,
         board = case r.street
                   when 0 then v_kaarten[v_gedeeld + 1 : v_gedeeld + 3]
                   when 1 then r.board || v_kaarten[v_gedeeld + 4]
                   else r.board || v_kaarten[v_gedeeld + 5]
                 end
   where id = p_round;

  -- Is er hooguit één speler die nog fiches heeft om mee te zetten, dan valt er niets meer
  -- te bieden: het bord loopt uit en de hand gaat naar de showdown. pk_settle legt de rest
  -- van de kaarten zelf neer.
  --
  -- Deze controle stond eerst ONDER het bepalen van de volgende speler, en dan wacht de
  -- tafel op iemand die niets meer kan doen.
  select count(*) into v_kunnen from public.pk_seats
   where round_id = p_round and not folded and not allin and stack > 0;
  if v_kunnen <= 1 then
    perform public.pk_settle(p_round);
    return;
  end if;

  update public.pk_rounds
     set to_act_seat = public.pk_next_seat(p_round, r.button_seat),
         act_deadline = now() + interval '25 seconds'
   where id = p_round;
end;
$$;
