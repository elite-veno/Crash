-- ============================================================================
--  DEEL 7 VAN 14
-- ============================================================================
--
--  Plak dit pas NA deel 6. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


-- ---------- een zet doen ----------
-- Dit is de grendel. De browser stuurt één getal in het hele spel: het totaal waar je deze
-- straat naartoe verhoogt. Dat getal zit aan twee kanten vast in de stand op de server, en
-- alles eromheen -- of je aan de beurt bent, of je al gezet hebt, wat je nog hebt -- komt
-- uit de tabellen en niet uit wat de browser beweert.
--
-- `p_seq` is het volgnummer van de zet die de speler dénkt te doen. Stuurt een tweede tab
-- dezelfde zet nog een keer, dan klopt dat nummer niet meer en gebeurt er niets.
create or replace function public.pk_act(p_round bigint, p_seq integer, p_move text, p_to integer default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  r public.pk_rounds%rowtype;
  s public.pk_seats%rowtype;
  v_tegaan integer;
  v_doel integer;
  v_bij integer;
  v_vol boolean;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  select * into r from public.pk_rounds where id = p_round for update;
  if r.id is null then raise exception 'no such hand'; end if;
  if r.settled_at is not null then raise exception 'hand is over'; end if;
  if r.act_seq <> p_seq then raise exception 'too late'; end if;

  select * into s from public.pk_seats
   where round_id = p_round and user_id = v_uid for update;
  if s.round_id is null then raise exception 'not in this hand'; end if;
  if r.to_act_seat is distinct from s.seat_no then raise exception 'not your turn'; end if;
  if s.folded or s.allin then raise exception 'you are out of this hand'; end if;

  v_tegaan := greatest(0, r.high_bet - s.bet);

  if p_move = 'fold' then
    update public.pk_seats set folded = true, acted = true
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'check' then
    if v_tegaan > 0 then raise exception 'cannot check'; end if;
    update public.pk_seats set acted = true
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'call' then
    if v_tegaan <= 0 then raise exception 'nothing to call'; end if;
    v_bij := least(v_tegaan, s.stack);
    update public.pk_seats
       set stack = stack - v_bij, bet = bet + v_bij, total_bet = total_bet + v_bij,
           acted = true, allin = (stack - v_bij) = 0
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'raise' then
    if not s.may_raise then raise exception 'cannot raise again'; end if;
    v_doel := coalesce(p_to, 0);
    if v_doel > s.bet + s.stack then raise exception 'more than you have'; end if;
    if v_doel <= r.high_bet then raise exception 'raise too small'; end if;
    -- Onder het minimum mag alleen als het alles is wat je hebt.
    if v_doel < r.high_bet + r.min_raise and v_doel <> s.bet + s.stack then
      raise exception 'raise too small';
    end if;
    v_bij := v_doel - s.bet;
    v_vol := (v_doel - r.high_bet) >= r.min_raise;

    update public.pk_seats
       set stack = stack - v_bij, bet = v_doel, total_bet = total_bet + v_bij,
           acted = true, allin = (stack - v_bij) = 0
     where round_id = p_round and seat_no = s.seat_no;

    if v_vol then
      -- Een volle verhoging heropent de ronde: iedereen mag weer reageren en weer verhogen.
      update public.pk_rounds set min_raise = v_doel - r.high_bet, high_bet = v_doel
       where id = p_round;
      update public.pk_seats set acted = false, may_raise = true
       where round_id = p_round and seat_no <> s.seat_no and not folded and not allin;
    else
      -- Een korte all-in verhoogt de inzet wel, maar wie al gezet had mag alleen nog het
      -- verschil bijleggen -- niet opnieuw verhogen op een minimum dat hierop gebouwd is.
      --
      -- In ÉÉN opdracht, en dat is geen stijlkeuze. Er stonden hier twee updates: eerst
      -- `acted = false` voor iedereen, daarna `may_raise = false where ... and acted`.
      -- Maar `acted` was op dat moment net op false gezet, dus die tweede raakte niemand
      -- en heropende de korte all-in het bieden alsnog -- precies wat hij moest voorkomen.
      update public.pk_rounds set high_bet = v_doel where id = p_round;
      update public.pk_seats
         set may_raise = not acted,   -- wie nog niet gezet had mag straks gewoon verhogen
             acted = false
       where round_id = p_round and seat_no <> s.seat_no and not folded and not allin;
    end if;

  else
    raise exception 'unknown move';
  end if;

  update public.pk_rounds set act_seq = act_seq + 1 where id = p_round;
  perform public.pk_advance(p_round);
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.pk_act(bigint, integer, text, integer) from public, anon;
grant execute on function public.pk_act(bigint, integer, text, integer) to authenticated;

-- ---------- de hand vooruit ----------
-- Wie is er hierna? De eerste die nog kan en nog moet: niet gepast, niet all-in, en of nog
-- niet gezet of nog niet op de hoogste inzet.
create or replace function public.pk_next_seat(p_round bigint, p_vanaf smallint)
returns smallint language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  d int; i smallint; s public.pk_seats%rowtype;
  n int;
begin
  select * into r from public.pk_rounds where id = p_round;
  select count(*) into n from public.pk_seats where round_id = p_round;
  for d in 1..n loop
    i := ((p_vanaf + d) % n)::smallint;
    select * into s from public.pk_seats where round_id = p_round and seat_no = i;
    if s.seat_no is null or s.folded or s.allin or s.stack <= 0 then continue; end if;
    if not s.acted or s.bet <> r.high_bet then return i; end if;
  end loop;
  return null;
end;
$$;
