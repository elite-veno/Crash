-- ============================================================================
--  DEEL 9 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 8. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 9 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


-- ---------- afrekenen ----------
-- De pot verdelen, met zijpotten. Dezelfde rekensom als ODDS.pokerPots in crash.html:
-- iedereen speelt alleen om het geld dat hij zelf heeft kunnen matchen.
create or replace function public.pk_settle(p_round bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_niveau int;
  v_vorig int := 0;
  v_pot int;
  v_beste bigint;
  v_winnaars smallint[];
  v_ieder int;
  v_rest int;
  v_board text[];
  v_kaarten text[];
  w smallint;
  v_eerste smallint;
  v_n int;
begin
  select * into r from public.pk_rounds where id = p_round for update;
  if r.settled_at is not null then return; end if;

  select count(*) into v_n from public.pk_seats where round_id = p_round;
  v_board := r.board;

  -- De rest van het bord moet er liggen voordat er vergeleken wordt: als iedereen all-in
  -- ging op de flop, komen turn en river er alsnog.
  select d.cards into v_kaarten from poker.deck d where d.round_id = p_round;
  if (select count(*) from public.pk_seats where round_id = p_round and not folded) > 1 then
    while array_length(v_board, 1) is null or array_length(v_board, 1) < 5 loop
      v_board := coalesce(v_board, '{}'::text[]) ||
                 v_kaarten[v_n * 2 + coalesce(array_length(v_board, 1), 0) + 1];
    end loop;
  end if;

  -- De kaarten van wie nog meedoet gaan open, en krijgen hun score.
  update public.pk_seats s
     set shown = true,
         hole = (select h.cards from poker.hole h
                  where h.round_id = p_round and h.seat_no = s.seat_no)
   where s.round_id = p_round and not s.folded
     and (select count(*) from public.pk_seats q where q.round_id = p_round and not q.folded) > 1;

  -- Elk verschillend inzetbedrag is een laag.
  v_eerste := ((r.button_seat + 1) % v_n)::smallint;
  for v_niveau in
    select distinct total_bet from public.pk_seats
     where round_id = p_round and total_bet > 0 order by 1
  loop
    select sum(least(total_bet, v_niveau) - least(total_bet, v_vorig)) into v_pot
      from public.pk_seats where round_id = p_round;

    if v_pot > 0 then
      select max(public.pk_score(
               (select h.cards from poker.hole h
                 where h.round_id = p_round and h.seat_no = s.seat_no) || v_board))
        into v_beste
        from public.pk_seats s
       where s.round_id = p_round and not s.folded and s.total_bet >= v_niveau;

      if v_beste is null then
        -- Iedereen die om deze laag speelde is gepast. Dan gaat hij terug naar wie hem
        -- volstortte, NAAR RATO -- niet in zijn geheel naar de grootste inlegger. Dat
        -- laatste stond er, en dan kreeg één speler geld terug dat van een ander was.
        update public.pk_seats s
           set payout = s.payout
                      + (least(s.total_bet, v_niveau) - least(s.total_bet, v_vorig))
         where s.round_id = p_round;
      else
        select array_agg(s.seat_no order by ((s.seat_no - v_eerste + v_n) % v_n))
          into v_winnaars
          from public.pk_seats s
         where s.round_id = p_round and not s.folded and s.total_bet >= v_niveau
           and public.pk_score(
                 (select h.cards from poker.hole h
                   where h.round_id = p_round and h.seat_no = s.seat_no) || v_board) = v_beste;

        v_ieder := v_pot / array_length(v_winnaars, 1);
        v_rest := v_pot - v_ieder * array_length(v_winnaars, 1);
        -- De oneven fiches gaan naar links van de knop, zoals aan een echte tafel.
        foreach w in array v_winnaars loop
          update public.pk_seats
             set payout = payout + v_ieder + (case when v_rest > 0 then 1 else 0 end)
           where round_id = p_round and seat_no = w;
          if v_rest > 0 then v_rest := v_rest - 1; end if;
        end loop;
      end if;
    end if;
    v_vorig := v_niveau;
  end loop;

  -- De uitbetaling gaat naar de stapel, niet naar het saldo: je blijft aan tafel zitten.
  --
  -- Let op wat hier de waarheid is. `pk_seats.stack` is wat er ná deze hand nog voor je
  -- ligt: daar zijn de blinds, de calls en de verhogingen al van af. `pk_players.stack`
  -- stond nog op de stand van vóór de hand. Er stond hier eerst `pk_players.stack + payout`
  -- en dat maakte fiches: alles wat je tijdens de hand had ingelegd kwam er zo weer bij.
  update public.pk_players pl
     set stack = s.stack + s.payout
    from public.pk_seats s
   where s.round_id = p_round and s.user_id = pl.user_id
     and pl.lobby_id = r.lobby_id
     and not s.left_table;

  -- En wie tijdens de hand is opgestaan, heeft geen stapel aan tafel meer. Zijn stoel kan
  -- nog steeds geld krijgen: een inzet die niemand heeft gecalld komt terug, en wie all-in
  -- ging en daarna opstond kan de hand gewoon winnen. Zonder deze regel landde dat nergens
  -- -- de join hierboven vond geen rij, en het geld was uit het spel weg.
  --
  -- Het gaat naar het saldo, want aan tafel zit hij niet meer. sprint_may_pay houdt tegen
  -- dat een hand van vóór zijn sprintgrens alsnog op de verse duizend landt; bestaat die
  -- functie niet, dan wordt er gewoon uitbetaald.
  --
  -- De twee takken zijn bijna gelijk, en dat is met opzet: PL/pgSQL leest een opdracht pas
  -- in als hij hem voor het eerst uitvoert, dus de tak met sprint_may_pay erin struikelt
  -- niet over een functie die er niet is zolang die tak niet gedraaid wordt. Eén opdracht
  -- met `to_regprocedure(...) is null or public.sprint_may_pay(...)` erin zou dat wel doen.
  if to_regprocedure('public.sprint_may_pay(uuid, timestamptz)') is not null then
    update public.profiles p
       set balance = p.balance + s.payout
      from public.pk_seats s
     where s.round_id = p_round and s.left_table and s.payout > 0
       and p.id = s.user_id
       and public.sprint_may_pay(s.user_id, r.started_at);
  else
    update public.profiles p
       set balance = p.balance + s.payout
      from public.pk_seats s
     where s.round_id = p_round and s.left_table and s.payout > 0
       and p.id = s.user_id;
  end if;

  -- En de zouten afkappen op wat er echt ligt. pk_live geeft ze toch al niet verder vrij,
  -- maar wat er niet staat kan ook niet alsnog uitlekken -- en de hash van de kaarten die
  -- NIET gevallen zijn, staat wel voor altijd openbaar in board_commit.
  update public.pk_rounds
     set settled_at = now(), street = 5, to_act_seat = null, act_deadline = null,
         board = v_board,
         board_salt = board_salt[1:coalesce(array_length(v_board, 1), 0)]
   where id = p_round;

  -- En het zaadje weg. De hand is uitgespeeld: wat open moest gaan staat in pk_seats.hole,
  -- het bord in pk_rounds.board met zijn eigen zout ernaast. Wat er nog zou blijven staan
  -- is de hele geschudde stok van deze hand, inclusief de kaarten van wie heeft gepast --
  -- voor altijd, in elke back-up en elke supportvraag. Daar was het juist om begonnen.
  delete from poker.deck d where d.round_id = p_round;
end;
$$;

-- Zie je hieronder "DEEL 9 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Maak de editor leeg en ga door met deel 10.
select 'DEEL 9 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
