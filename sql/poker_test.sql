-- Een hand poker van begin tot eind, op een lege Postgres. Waar het hier vooral om gaat is
-- één ding: fiches worden niet gemaakt en gaan niet weg. Bij elke stap wordt geteld dat
-- saldo plus stapels plus pot nog steeds is wat het was.
--
--   psql -f sql/test_stub.sql -f sql/sprint_reset.sql -f sql/poker.sql \
--        -f sql/poker_rpc.sql -f sql/poker_test.sql
--
-- Elke regel die met FOUT begint is een test die niet klopt.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

create or replace function pg_temp.zegt(wat text, verwacht text, gekregen text)
returns text language sql as $$
  select case when verwacht = gekregen then 'ok    ' || wat
              else 'FOUT  ' || wat || ' -- verwacht ' || verwacht || ', kreeg ' || gekregen end;
$$;
-- Alle fiches in het spel: op zak, op tafel, en in de pot van een lopende hand.
create or replace function pg_temp.totaal() returns int language sql as $$
  select (select coalesce(sum(balance), 0) from public.profiles)::int
       + (select coalesce(sum(stack), 0) from public.pk_players)
       + (select coalesce(sum(s.total_bet), 0) from public.pk_seats s
            join public.pk_rounds r on r.id = s.round_id where r.settled_at is null);
$$;
create or replace function pg_temp.ronde() returns bigint language sql as $$
  select id from public.pk_rounds order by id desc limit 1; $$;
create or replace function pg_temp.seq() returns int language sql as $$
  select act_seq from public.pk_rounds order by id desc limit 1; $$;
create or replace function pg_temp.beurt_uid() returns uuid language sql as $$
  select s.user_id from public.pk_seats s join public.pk_rounds r on r.id = s.round_id
   where r.id = pg_temp.ronde() and s.seat_no = r.to_act_seat; $$;

truncate public.pk_players, public.pk_rounds, public.pk_seats cascade;
delete from poker.hole; delete from poker.deck;
truncate public.profiles;
insert into public.profiles (id, username, balance, reset_sprint) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'ann', 1000, public.sprint_now()),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1000, public.sprint_now()),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'cas', 1000, public.sprint_now());

select pg_temp.zegt('drieduizend om mee te beginnen', '3000', pg_temp.totaal()::text);

-- ---------- aanschuiven ----------
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000001'; select public.pk_sit(200);
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000002'; select public.pk_sit(200);
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000003'; select public.pk_sit(200);
select pg_temp.zegt('aanschuiven maakt geen fiches', '3000', pg_temp.totaal()::text);
select pg_temp.zegt('en haalt ze van het saldo', '2400',
  (select sum(balance)::text from public.profiles));

-- Meer inkopen dan je hebt, of twee keer aanschuiven: allebei geweigerd.
-- Voert iets uit namens een speler en geeft de foutmelding terug in plaats van te
-- klappen. De uid wordt hier gezet, niet in een do-blok erbuiten: `set local` geldt alleen
-- binnen zijn eigen blok, en dan zou de zet namens de vorige speler gaan.
create or replace function pg_temp.mislukt(p_uid uuid, sql text) returns text
language plpgsql as $$
begin
  perform set_config('test.uid', p_uid::text, true);
  execute sql;
  return 'geen fout';
exception when others then return sqlerrm;
end; $$;
select pg_temp.zegt('twee keer aanschuiven kan niet', 'already seated',
  pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000003', 'select public.pk_sit(200)'));

-- ---------- een hand spelen ----------
select public.pk_tick(1);
select pg_temp.zegt('er is gedeeld', '3', (select count(*)::text from public.pk_seats));
select pg_temp.zegt('iedereen heeft twee kaarten', '3',
  (select count(*)::text from poker.hole where array_length(cards, 1) = 2));
select pg_temp.zegt('de blinds staan', '15',
  (select sum(total_bet)::text from public.pk_seats));
select pg_temp.zegt('delen maakt geen fiches', '3000', pg_temp.totaal()::text);

-- Buiten je beurt mag niets.
-- Wie NIET aan de beurt is, mag niets. (De stoel na degene die aan de beurt is.)
select pg_temp.zegt('buiten je beurt wordt geweigerd', 'not your turn',
  pg_temp.mislukt(
    (select s.user_id from public.pk_seats s join public.pk_rounds r on r.id = s.round_id
      where r.id = pg_temp.ronde() and s.seat_no <> r.to_act_seat limit 1),
    'select public.pk_act(pg_temp.ronde(), pg_temp.seq(), ''fold'')'));

-- En wie wel aan de beurt is, mag nog steeds geen onzin.
select pg_temp.zegt('een te kleine verhoging wordt geweigerd', 'raise too small',
  pg_temp.mislukt(pg_temp.beurt_uid(),
    'select public.pk_act(pg_temp.ronde(), pg_temp.seq(), ''raise'', 12)'));
select pg_temp.zegt('meer dan je hebt wordt geweigerd', 'more than you have',
  pg_temp.mislukt(pg_temp.beurt_uid(),
    'select public.pk_act(pg_temp.ronde(), pg_temp.seq(), ''raise'', 99999)'));
select pg_temp.zegt('checken terwijl er een inzet staat kan niet', 'cannot check',
  pg_temp.mislukt(pg_temp.beurt_uid(),
    'select public.pk_act(pg_temp.ronde(), pg_temp.seq(), ''check'')'));
select pg_temp.zegt('een onbekende zet wordt geweigerd', 'unknown move',
  pg_temp.mislukt(pg_temp.beurt_uid(),
    'select public.pk_act(pg_temp.ronde(), pg_temp.seq(), ''dansen'')'));
select pg_temp.zegt('een oud volgnummer wordt geweigerd', 'too late',
  pg_temp.mislukt(pg_temp.beurt_uid(),
    'select public.pk_act(pg_temp.ronde(), pg_temp.seq() - 1, ''fold'')'));
select pg_temp.zegt('en na al die pogingen is er niets veranderd', '15',
  (select sum(total_bet)::text from public.pk_seats));

-- En dan gewoon uitspelen: iedereen callt of checkt tot de showdown.
do $$
declare i int; v_uid uuid; v_hoog int; v_bet int;
begin
  for i in 1..40 loop
    exit when (select settled_at is not null from public.pk_rounds order by id desc limit 1);
    select pg_temp.beurt_uid() into v_uid;
    exit when v_uid is null;
    execute format('set local test.uid = %L', v_uid);
    select r.high_bet, s.bet into v_hoog, v_bet
      from public.pk_rounds r join public.pk_seats s
        on s.round_id = r.id and s.seat_no = r.to_act_seat
     where r.id = pg_temp.ronde();
    if v_bet < v_hoog then
      perform public.pk_act(pg_temp.ronde(), pg_temp.seq(), 'call');
    else
      perform public.pk_act(pg_temp.ronde(), pg_temp.seq(), 'check');
    end if;
  end loop;
end $$;

select pg_temp.zegt('de hand is afgerekend', 'true',
  (select (settled_at is not null)::text from public.pk_rounds order by id desc limit 1));
select pg_temp.zegt('er liggen vijf kaarten op het bord', '5',
  (select array_length(board, 1)::text from public.pk_rounds order by id desc limit 1));
select pg_temp.zegt('de pot is helemaal uitbetaald', '30',
  (select sum(payout)::text from public.pk_seats));
select pg_temp.zegt('afrekenen maakt geen fiches', '3000', pg_temp.totaal()::text);
select pg_temp.zegt('de fiches op tafel kloppen', '600',
  (select sum(stack)::text from public.pk_players));

-- De winnaar is degene met de hoogste hand, niet iemand anders.
select pg_temp.zegt('het geld ging naar de beste hand', 'true',
  (select (s.payout > 0)::text
     from public.pk_seats s
     join poker.hole h on h.round_id = s.round_id and h.seat_no = s.seat_no
     join public.pk_rounds r on r.id = s.round_id
    where not s.folded
    order by public.pk_score(h.cards || r.board) desc limit 1));

-- ---------- opstaan ----------
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000001'; select public.pk_leave();
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000002'; select public.pk_leave();
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000003'; select public.pk_leave();
select pg_temp.zegt('opstaan maakt geen fiches', '3000', pg_temp.totaal()::text);
select pg_temp.zegt('alles staat weer op het saldo', '3000',
  (select sum(balance)::text from public.profiles));
select pg_temp.zegt('en de tafel is leeg', '0',
  (select count(*)::text from public.pk_players));

-- ---------- de kaarten van een ander ----------
-- Dit is waar het bij poker op staat. De pagina is openbaar en iedereen kan met de
-- publieke sleutel rechtstreeks de REST-laag bevragen, dus hier wordt nagegaan dat de rol
-- `authenticated` -- dat is wat een ingelogde speler is -- nergens bij de kaarten komt.
select pg_temp.zegt('een speler mag niet bij de kaartentabel', 'false',
  has_table_privilege('authenticated', 'poker.hole', 'select')::text);
select pg_temp.zegt('en niet bij de stok', 'false',
  has_table_privilege('authenticated', 'poker.deck', 'select')::text);
select pg_temp.zegt('en niet bij het schema waar ze in staan', 'false',
  has_schema_privilege('authenticated', 'poker', 'usage')::text);
select pg_temp.zegt('ook niet bij de stoelentabel zelf', 'false',
  has_table_privilege('authenticated', 'public.pk_seats', 'select')::text);
select pg_temp.zegt('en niet bij de rondetabel', 'false',
  has_table_privilege('authenticated', 'public.pk_rounds', 'select')::text);
select pg_temp.zegt('schrijven al helemaal niet', 'false',
  has_table_privilege('authenticated', 'public.pk_seats', 'update')::text);

-- Wat hij wel mag: de views. En die geven de kaarten van een ander niet.
select pg_temp.zegt('de openbare stoelenview mag wel', 'true',
  has_table_privilege('authenticated', 'public.pk_seats_public', 'select')::text);
select pg_temp.zegt('en de eigen kaarten ook', 'true',
  has_table_privilege('authenticated', 'public.pk_my_hole', 'select')::text);

-- Row-level security staat aan als tweede slot, voor het geval het eerste ooit losraakt.
select pg_temp.zegt('row-level security staat aan op de kaarten', 'true',
  (select relrowsecurity::text from pg_class where oid = 'poker.hole'::regclass));
select pg_temp.zegt('en er is geen enkele policy die iets doorlaat', '0',
  (select count(*)::text from pg_policies where schemaname = 'poker'));

-- En het bewijs in de praktijk: deel een hand, en kijk wat de view van een speler
-- teruggeeft over de kaarten van de anderen.
truncate public.pk_players, public.pk_rounds, public.pk_seats cascade;
delete from poker.hole; delete from poker.deck;
update public.profiles set balance = 1000;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select public.pk_tick(1);

set test.uid = 'aaaaaaaa-0000-0000-0000-000000000001';
select pg_temp.zegt('je ziet je eigen twee kaarten', '1',
  (select count(*)::text from public.pk_my_hole));
select pg_temp.zegt('en die van de ander niet', '1',
  (select count(distinct seat_no)::text from public.pk_my_hole));
select pg_temp.zegt('de openbare view laat tijdens de hand geen enkele kaart zien', '0',
  (select coalesce(sum(coalesce(array_length(hole, 1), 0)), 0)::text
     from public.pk_seats_public));
select pg_temp.zegt('maar wel dat er gedeeld is, via de hash per stoel', '2',
  (select count(*)::text from public.pk_seats_public where card_commit is not null));
select pg_temp.zegt('het zaadje blijft dicht zolang de hand loopt', '0',
  (select count(*)::text from public.pk_live where deck_seed is not null));
