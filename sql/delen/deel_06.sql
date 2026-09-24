-- ============================================================================
--  DEEL 6 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 5. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 6 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


-- ---------- opstaan ----------
create or replace function public.pk_leave()
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_lobby bigint;
  v_stack integer;
  v_stoelstack integer;
  v_ronde bigint;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  -- Eerst kijken AAN WELKE TAFEL je zit, zonder iets vast te houden.
  select p.lobby_id into v_lobby from public.pk_players p where p.user_id = v_uid;
  if v_lobby is null then return json_build_object('ok', true, 'stack', 0); end if;

  -- Dan het tafelslot, en pas daarna het rijslot. Die volgorde is niet vrijblijvend:
  -- pk_tick en pk_sit nemen ze ook zo, en wie ze andersom pakt loopt vast zodra allebei
  -- tegelijk beginnen -- de een houdt de rij en wacht op de tafel, de ander houdt de tafel
  -- en wacht op de rij. Postgres schiet er dan een dood met een deadlock.
  --
  -- Het slot zelf is hier nodig omdat opstaan anders tegelijk kon lopen met het opruimen
  -- in pk_tick: allebei lazen ze dezelfde stapel en allebei schreven ze hem op het saldo.
  -- Je inkoop kwam dan dubbel terug, en dat was te herhalen zo vaak je wilde.
  perform pg_advisory_xact_lock(v_lobby);

  -- En nu pas vastpakken. Tussen de twee regels kan iemand je van tafel hebben gehaald,
  -- dus de lobby wordt hier opnieuw gelezen in plaats van aangenomen.
  select p.lobby_id, p.stack into v_lobby, v_stack
    from public.pk_players p where p.user_id = v_uid for update;
  if v_lobby is null then return json_build_object('ok', true, 'stack', 0); end if;

  -- Zit je midden in een hand, dan pas je eerst. Je inzet blijft in de pot staan -- dat is
  -- geld dat je al hebt ingelegd, en weglopen mag dat niet ongedaan maken.
  select r.id into v_ronde from public.pk_rounds r
    where r.lobby_id = v_lobby and r.settled_at is null order by r.id desc limit 1;
  if v_ronde is not null then
    -- LEZEN VOOR SCHRIJVEN. Hieronder wordt left_table gezet, en daar filtert deze regel
    -- op -- andersom vindt hij zijn eigen stoel niet meer terug, valt de uitbetaling terug
    -- op pk_players.stack (de stand van vóór je inzetten) en maakt dat fiches.
    --
    -- Het filter zelf is nodig omdat je al eerder deze hand opgestaan kunt zijn en daarna
    -- opnieuw aangeschoven. Die oude stoel staat er dan nog, met nul fiches op. Die als
    -- waarheid nemen liet je verse inkoop verdwijnen: opstaan gaf $0 terug.
    --
    -- Geeft dit null, dan heb je geen stoel in deze hand -- je schoof aan terwijl er al
    -- gedeeld was en wacht op de volgende. Dan is pk_players.stack juist wél de goede
    -- stand, want je hebt nog niets ingezet.
    select s.stack into v_stoelstack from public.pk_seats s
      where s.round_id = v_ronde and s.user_id = v_uid and not s.left_table;

    -- Passen, maar NIET als je all-in staat. Wie al zijn fiches in de pot heeft, heeft
    -- niets meer te beslissen: die hand speelt zichzelf uit en hij hoort mee te doen aan
    -- de showdown. Hem laten passen omdat hij opstaat gaf zijn pot aan de anderen.
    --
    -- `left_table` erbij zodat de afrekening weet dat er geen stoel aan tafel meer is om
    -- de uitbetaling op te zetten, en de stapel op nul: die fiches gaan naar het saldo.
    update public.pk_seats s
       set folded = (case when s.allin then s.folded else true end),
           acted = true,
           left_table = true,
           stack = 0
     where s.round_id = v_ronde and s.user_id = v_uid and not s.left_table;

    if v_stoelstack is not null then v_stack := v_stoelstack; end if;

    -- En dan de hand laten doorlopen, net als na een gewone fold. Hier stond eerst niets:
    -- de stoel werd gepast, maar de hand bleef staan. Stond de ander daarna ook op, dan
    -- had iedereen gepast en won niemand -- en omdat een lege lobby wordt opgeruimd, kwam
    -- er ook nooit meer iemand die de tafel porde. De inzetten bleven voor altijd in een
    -- pot waar niemand meer bij kon.
    --
    -- Niet blind pk_advance aanroepen: dat geeft de beurt door vanaf wie er aan de beurt
    -- IS, en was dat iemand anders, dan sloeg je diens beurt over. Dus alleen als de
    -- vertrekker zelf aan de beurt was, of als er nog maar één speler over is -- die wint
    -- dan meteen, zoals aan elke tafel.
    if v_stoelstack is not null then
      declare
        v_r public.pk_rounds%rowtype;
        v_mijn smallint;
        v_levend int;
      begin
        select * into v_r from public.pk_rounds where id = v_ronde for update;
        select s.seat_no into v_mijn from public.pk_seats s
         where s.round_id = v_ronde and s.user_id = v_uid and s.left_table
         order by s.seat_no limit 1;
        select count(*) into v_levend from public.pk_seats
         where round_id = v_ronde and not folded;
        if v_r.settled_at is null
           and (v_levend <= 1 or v_r.to_act_seat is not distinct from v_mijn) then
          update public.pk_rounds set act_seq = act_seq + 1 where id = v_ronde;
          perform public.pk_advance(v_ronde);
        end if;
      end;
    end if;
  end if;

  -- En wat er ook misgaat, hier staat nooit null. Het grootboek weigert dat terecht, en
  -- dan kwam je met een rauwe databasefout niet meer van tafel.
  v_stack := coalesce(v_stack, 0);

  -- Alleen de stoel aan DEZE tafel. Zonder dat filter haalt opstaan je overal weg terwijl
  -- er maar één stapel wordt uitbetaald.
  delete from public.pk_players where user_id = v_uid and lobby_id = v_lobby;
  update public.profiles set balance = balance + coalesce(v_stack, 0) where id = v_uid;

  if to_regprocedure('poker.note(uuid, text, bigint, text, integer)') is not null then
    execute 'select poker.note($1, $2, $3, $4, $5)' using
      v_uid, (select username from public.profiles where id = v_uid), v_lobby, 'leave', v_stack;
  end if;

  return json_build_object('ok', true, 'stack', v_stack);
end;
$$;

revoke all on function public.pk_leave() from public, anon;
grant execute on function public.pk_leave() to authenticated;

-- Zie je hieronder "DEEL 6 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Maak de editor leeg en ga door met deel 7.
select 'DEEL 6 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
