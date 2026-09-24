-- ============================================================================
--  DEEL 11 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 10. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 11 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


-- ---------- de klok ----------
-- Elke browser mag dit porren: wie als eerste merkt dat er gedeeld of afgerekend moet
-- worden, vraagt het aan, en de server doet het één keer. Er zit geen controle op of de
-- aanroeper aan tafel zit, met opzet -- anders kan een vastgelopen tafel door niemand meer
-- losgemaakt worden. Er valt ook niets mee te winnen: alles wat hier gebeurt hangt aan
-- now() en aan de stand, niet aan wie het vraagt.
create or replace function public.pk_tick(p_lobby bigint)
returns json language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_spelers int;
  v_zaad text;
  v_commit text;
  v_kaarten text[];
  v_ronde bigint;
  v_knop smallint;
  v_i int := 0;
  p record;
  v_sb smallint; v_bb smallint;
  v_zout text;
  w record;
  v_stoelen smallint[];
  v_knop_tafel int;
  v_terug integer;
begin
  -- Eén tafel tegelijk. Twee browsers die op hetzelfde moment porren zagen allebei geen
  -- lopende hand en deelden er allebei een; op de tijdklok sloegen ze samen een beurt over.
  -- Dit slot geldt tot het einde van de transactie, dus alle porren voor één tafel staan
  -- netjes in de rij.
  perform pg_advisory_xact_lock(p_lobby);

  select * into r from public.pk_rounds
   where lobby_id = p_lobby and settled_at is null order by id desc limit 1 for update;

  -- Loopt er een hand? Dan alleen kijken of iemand te lang nadenkt.
  if r.id is not null then
    if r.act_deadline is not null and now() > r.act_deadline and r.to_act_seat is not null then
      -- Wie zijn tijd laat verlopen checkt als dat gratis is, en past anders. Zo blijft een
      -- tafel niet staan omdat iemand zijn tab dichtgooit, en verliest niemand zijn inzet
      -- door een haperende verbinding als er niets te betalen viel.
      if (select s.bet from public.pk_seats s
           where s.round_id = r.id and s.seat_no = r.to_act_seat) = r.high_bet then
        update public.pk_seats set acted = true
         where round_id = r.id and seat_no = r.to_act_seat;
      else
        update public.pk_seats set folded = true, acted = true
         where round_id = r.id and seat_no = r.to_act_seat;
      end if;
      update public.pk_rounds set act_seq = act_seq + 1 where id = r.id;
      perform public.pk_advance(r.id);
    end if;
    return json_build_object('ok', true, 'round', r.id);
  end if;

  -- Geen hand. Eerst opruimen: wie de lobby heeft verlaten zonder op te staan, laat een
  -- rij achter aan een tafel waar hij niet meer bij hoort, met zijn fiches erop. De pagina
  -- staat nu eerst op voordat ze weggaat, maar een dichtgeslagen tab doet dat niet.
  --
  -- Dit staat met opzet tussen de handen door: midden in een hand iemand van tafel halen
  -- zou de pot scheef trekken. En het hele blok is afgeschermd -- vindt het de ledentabel
  -- niet, of ziet die er anders uit dan hier verwacht, dan slaat het over. Een tafel die
  -- vastloopt omdat het opruimen struikelt is erger dan een rij die blijft staan.
  begin
    -- De speler heet in lobby_members `player`, niet `user_id`. Hier stond eerst
    -- user_id, en de controle hieronder vond die kolom dus nooit: het opruimen werd
    -- stilletjes overgeslagen. Er ging niets kapot, maar het deed ook nooit iets.
    if (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'lobby_members'
           and column_name in ('lobby_id', 'player')) = 2 then
      for w in
        -- lobby_prune haalt wie een minuut niets van zich liet horen uit de lobby; wie
        -- daarna nog aan deze tafel zit, hoort er niet meer bij. Dezelfde regel als voor
        -- blackjack, dus een tafel voelt overal hetzelfde aan.
        execute 'select pl.user_id, pl.stack from public.pk_players pl'
             || ' where pl.lobby_id = $1'
             || '   and not exists ('
             || '   select 1 from public.lobby_members m'
             || '    where m.lobby_id = pl.lobby_id and m.player = pl.user_id)'
        using p_lobby
      loop
        -- Eerst weghalen, dan pas uitbetalen, en alleen wat de delete echt heeft
        -- weggehaald. Andersom betaalde het opruimen ook uit als iemand anders die rij
        -- net had opgeruimd -- fiches uit het niets. Nu levert een tweede poging niets op.
        delete from public.pk_players pl
         where pl.lobby_id = p_lobby and pl.user_id = w.user_id
        returning pl.stack into v_terug;
        if v_terug is not null then
          update public.profiles set balance = balance + v_terug where id = w.user_id;
          v_terug := null;
        end if;
      end loop;
    end if;
  -- Alleen opvangen waar dit blok voor bedoeld is: een ledentabel die er niet is of er
  -- anders uitziet. `when others` ving ook een deadlock op, en dan meldde pk_tick gewoon
  -- succes terwijl er niets was opgeruimd en er nergens iets over stond.
  exception when undefined_table or undefined_column then null;
  end;

  -- Kan er een hand beginnen? Wie geen fiches meer heeft doet niet mee.
  select count(*) into v_spelers from public.pk_players
   where lobby_id = p_lobby and stack > 0;
  if v_spelers < 2 then return json_build_object('ok', true, 'round', null); end if;

  -- De knop schuift een stoel op ten opzichte van de VORIGE hand -- niet ten opzichte van
  -- de hoogste die er ooit was. Met een max blijft hij hangen zodra hij één keer op de
  -- laatste stoel heeft gestaan, en dan post dezelfde speler elke hand de blind.
  --
  -- En hij hangt aan de stoel AAN TAFEL, niet aan het nummer binnen de hand. Die twee zijn
  -- niet hetzelfde: de hand hernummert elke keer opnieuw van nul af, op volgorde van de
  -- tafelstoelen van wie er fiches heeft. Schuift er iemand aan op een lagere tafelstoel,
  -- dan schuift iedereen daarachter een plek op en wijst hetzelfde rondenummer opeens een
  -- andere speler aan -- dezelfde twee posten twee handen achter elkaar de blinds, en de
  -- nieuwkomer krijgt de knop zonder ooit betaald te hebben. Van tafel gaan deed hetzelfde
  -- in de andere richting.
  --
  -- Dus: pak de tafelstoelen van wie meedoet, op volgorde, en zoek de eerste die ECHT na
  -- de vorige knop komt. Is er geen, dan ronddraaien naar de laagste.
  select array_agg(pl.seat_no order by pl.seat_no) into v_stoelen
    from public.pk_players pl where pl.lobby_id = p_lobby and pl.stack > 0;

  select coalesce((select r2.button_lobby_seat from public.pk_rounds r2
                    where r2.lobby_id = p_lobby and r2.button_lobby_seat is not null
                    order by r2.id desc limit 1), -1)
    into v_knop_tafel;

  v_knop := 0;
  for v_i in 1 .. array_length(v_stoelen, 1) loop
    if v_stoelen[v_i] > v_knop_tafel then v_knop := v_i - 1; exit; end if;
  end loop;
  v_knop_tafel := v_stoelen[v_knop + 1];
  v_i := 0;

  v_zaad := encode(poker.sha256(gen_random_uuid()::text || clock_timestamp()::text), 'hex');
  v_commit := encode(poker.sha256('commit:' || v_zaad), 'hex');
  v_kaarten := poker.shuffle(v_zaad);

  select coalesce(max(sb), 5), coalesce(max(bb), 10) into v_sb, v_bb
    from public.pk_rounds where lobby_id = p_lobby;

  insert into public.pk_rounds (lobby_id, deck_commit, button_seat, button_lobby_seat,
                                sb, bb, min_raise, street)
       values (p_lobby, v_commit, v_knop::smallint, v_knop_tafel::smallint,
               v_sb, v_bb, v_bb, 0)
    returning id into v_ronde;

  insert into poker.deck (round_id, seed, cards) values (v_ronde, v_zaad, v_kaarten);

  -- De stoelen, op volgorde, met hun kaarten. De kaarten gaan naar het andere schema; wat
  -- hier blijft staan is een gezouten hash, zodat elke speler zijn eigen hand meteen kan
  -- narekenen zonder dat iemand anders iets te zien krijgt.
  for p in select * from public.pk_players
            where lobby_id = p_lobby and stack > 0 order by seat_no loop
    v_zout := encode(poker.sha256(v_zaad || ':zout:' || v_i::text), 'hex');
    insert into public.pk_seats (round_id, seat_no, user_id, username, stack, card_commit)
         values (v_ronde, v_i::smallint, p.user_id, p.username, p.stack,
                 encode(poker.sha256(v_zout || ':' ||
                        v_kaarten[v_i * 2 + 1] || v_kaarten[v_i * 2 + 2]), 'hex'));
    insert into poker.hole (round_id, seat_no, player, cards, salt)
         values (v_ronde, v_i::smallint, p.user_id,
                 array[v_kaarten[v_i * 2 + 1], v_kaarten[v_i * 2 + 2]], v_zout);
    v_i := v_i + 1;
  end loop;

  -- Het bord vastleggen. De vijf gemeenschappelijke kaarten liggen op vaste plekken in de
  -- stok -- meteen na de holekaarten -- dus ze zijn hier al bekend, lang voordat ze vallen.
  -- Publiceer er nu een hash van; het zout komt pas vrij bij het afrekenen. Daarmee is
  -- achteraf na te rekenen dat de flop, turn en river zijn wat ze bij het delen al waren,
  -- zonder dat er iets over iemands holekaarten uit lekt.
  declare
    v_zouten text[] := '{}';
    v_commits text[] := '{}';
    v_k int;
    v_z text;
  begin
    for v_k in 1 .. 5 loop
      v_z := encode(poker.sha256(v_zaad || ':bord:' || v_k::text), 'hex');
      v_zouten := v_zouten || v_z;
      v_commits := v_commits ||
        encode(poker.sha256(v_z || ':' || v_kaarten[v_i * 2 + v_k]), 'hex');
    end loop;
    update public.pk_rounds
       set board_salt = v_zouten, board_commit = v_commits
     where id = v_ronde;
  end;

  -- De blinds. Heads-up post de knop de kleine blind; met meer spelers de stoel erna.
  declare
    v_n int := v_i;
    v_knop2 smallint;
    v_sbs smallint; v_bbs smallint;
  begin
    select button_seat into v_knop2 from public.pk_rounds where id = v_ronde;
    if v_n = 2 then
      v_sbs := v_knop2;
      v_bbs := ((v_knop2 + 1) % v_n)::smallint;
    else
      v_sbs := ((v_knop2 + 1) % v_n)::smallint;
      v_bbs := ((v_knop2 + 2) % v_n)::smallint;
    end if;

    update public.pk_seats
       set bet = least(v_sb, stack), total_bet = least(v_sb, stack),
           stack = stack - least(v_sb, stack), allin = stack <= v_sb
     where round_id = v_ronde and seat_no = v_sbs;
    update public.pk_seats
       set bet = least(v_bb, stack), total_bet = least(v_bb, stack),
           stack = stack - least(v_bb, stack), allin = stack <= v_bb
     where round_id = v_ronde and seat_no = v_bbs;

    update public.pk_rounds
       set high_bet = v_bb,
           to_act_seat = ((v_bbs + 1) % v_n)::smallint,
           act_deadline = now() + interval '25 seconds'
     where id = v_ronde;
  end;

  -- De stapels aan tafel volgen die in de hand.
  update public.pk_players pl set stack = s.stack
    from public.pk_seats s
   where s.round_id = v_ronde and s.user_id = pl.user_id
     and pl.lobby_id = p_lobby;

  return json_build_object('ok', true, 'round', v_ronde, 'dealt', true);
end;
$$;

-- Zie je hieronder "DEEL 11 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Maak de editor leeg en ga door met deel 12.
select 'DEEL 11 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
