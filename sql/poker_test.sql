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
create or replace function pg_temp.beurt_uid_of_iemand() returns uuid language sql as $$
  select user_id from public.pk_players order by seat_no limit 1; $$;
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

-- Aan tafel 1 zitten, zoals lobby_join dat doet. De echte my_lobby laat je alleen je
-- tafel zien als je in lobby_members staat -- en pk_sit leest precies daaruit. En tafel 1
-- moet er zijn: de echte lobby-functies ruimen een lege lobby op.
insert into public.lobbies (id, code) values (1, 'TEST') on conflict (id) do nothing;
delete from public.lobby_members;
insert into public.lobby_members (lobby_id, player, username)
     select 1, id, username from public.profiles;

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

-- ---------- opstaan midden in een hand ----------
-- Hier zat een gat waar geld uit kwam. `pk_players.stack` wordt alleen bij het delen en
-- bij het afrekenen bijgewerkt; tijdens een hand staat daar nog de stand van VOOR je
-- inzetten. Wie daarmee uitbetaalde, kreeg alles terug wat al in de pot lag -- en kon dat
-- herhalen zo vaak hij wilde.
truncate public.pk_players, public.pk_rounds, public.pk_seats cascade;
delete from poker.hole; delete from poker.deck; delete from public.pk_ledger;
truncate public.profiles;
insert into public.profiles (id, username, balance, reset_sprint) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'ann', 1000, public.sprint_now()),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1000, public.sprint_now()),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'cas', 1000, public.sprint_now());

-- Aan tafel 1 zitten, zoals lobby_join dat doet. De echte my_lobby laat je alleen je
-- tafel zien als je in lobby_members staat -- en pk_sit leest precies daaruit. En tafel 1
-- moet er zijn: de echte lobby-functies ruimen een lege lobby op.
insert into public.lobbies (id, code) values (1, 'TEST') on conflict (id) do nothing;
delete from public.lobby_members;
insert into public.lobby_members (lobby_id, player, username)
     select 1, id, username from public.profiles;

select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000003', 'select public.pk_sit(200)');
select public.pk_tick(1);

-- Wie aan de beurt is verhoogt flink, en staat dan op.
do $$
declare v_uid uuid;
begin
  select pg_temp.beurt_uid() into v_uid;
  perform set_config('test.uid', v_uid::text, true);
  perform public.pk_act(pg_temp.ronde(), pg_temp.seq(), 'raise', 150);
  perform public.pk_leave();
end $$;

select pg_temp.zegt('opstaan midden in een hand maakt geen fiches', '3000', pg_temp.totaal()::text);

-- En nog een keer opstaan verandert niets meer.
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_leave()');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_leave()');
select pg_temp.zegt('twee keer opstaan ook niet', '3000', pg_temp.totaal()::text);

-- De hand uitspelen en dan nog eens tellen.
do $$
declare i int; v_uid uuid; v_hoog int; v_bet int;
begin
  for i in 1..40 loop
    exit when (select settled_at is not null from public.pk_rounds order by id desc limit 1);
    select pg_temp.beurt_uid() into v_uid;
    exit when v_uid is null;
    perform set_config('test.uid', v_uid::text, true);
    select r.high_bet, s.bet into v_hoog, v_bet
      from public.pk_rounds r join public.pk_seats s
        on s.round_id = r.id and s.seat_no = r.to_act_seat
     where r.id = pg_temp.ronde();
    if v_bet < v_hoog then perform public.pk_act(pg_temp.ronde(), pg_temp.seq(), 'call');
    else perform public.pk_act(pg_temp.ronde(), pg_temp.seq(), 'check'); end if;
  end loop;
end $$;
select pg_temp.zegt('en na het afrekenen nog steeds niet', '3000', pg_temp.totaal()::text);

-- ---------- de knop schuift echt door ----------
-- Met een max() over alle handen bleef hij hangen zodra hij één keer op de laatste stoel
-- had gestaan, en postte dezelfde speler elke hand de blind.
truncate public.pk_players, public.pk_rounds, public.pk_seats cascade;
delete from poker.hole; delete from poker.deck;
update public.profiles set balance = 1000;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
do $$
declare i int;
begin
  for i in 1..4 loop
    perform public.pk_tick(1);
    update public.pk_rounds set settled_at = now(), street = 5
     where lobby_id = 1 and settled_at is null;
  end loop;
end $$;
select pg_temp.zegt('de knop staat op vier handen op twee verschillende stoelen', '2',
  (select count(distinct button_seat)::text from public.pk_rounds where lobby_id = 1));

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
-- En het zaadje: dat komt helemaal niet meer naar buiten, ook niet na afloop. Wie het
-- heeft rekent met poker.shuffle de hele schudbeurt na, dus ook de kaarten van wie heeft
-- gepast en ze nooit heeft laten zien. Eerst gaf pk_live het vrij zodra settled_at stond.
select pg_temp.zegt('het zaadje staat niet meer in de openbare view', '0',
  (select count(*)::text from information_schema.columns
    where table_schema = 'public' and table_name = 'pk_live'
      and column_name in ('deck_seed', 'seed')));
select pg_temp.zegt('en de tafel met de zaadjes is voor niemand te lezen', 'false',
  has_table_privilege('authenticated', 'poker.deck', 'select')::text);
select pg_temp.zegt('ook de schudfunctie zelf is niet aan te roepen', 'false',
  has_function_privilege('authenticated', 'poker.shuffle(text)', 'execute')::text);
select pg_temp.zegt('en de hash-functie evenmin', 'false',
  has_function_privilege('authenticated', 'poker.sha256(text)', 'execute')::text);
select pg_temp.zegt('en het verse deck ook niet', 'false',
  has_function_privilege('authenticated', 'poker.fresh_deck()', 'execute')::text);
-- Wat WEL kan: je eigen hand narekenen tegen de hash die voor het delen al openbaar stond.
select pg_temp.zegt('je eigen kaarten kloppen met de hash van voor het delen', 'true',
  (select (s.card_commit = encode(poker.sha256(h.salt || ':' || h.cards[1] || h.cards[2]), 'hex'))::text
     from public.pk_my_hole h
     join public.pk_seats s on s.round_id = h.round_id and s.seat_no = h.seat_no));

-- ---------- het grootboek ----------
-- Poker is het enige spel hier waar geld tussen accounts beweegt. Wat dat met je saldo
-- doet wordt bijgehouden, zodat de sprintranglijst niet te sturen is door fiches naar een
-- vriend te schuiven.
do $$ begin
  if to_regclass('public.pk_ledger') is null then
    raise notice 'het grootboek staat er niet in, deze test wordt overgeslagen';
  end if;
end $$;

truncate public.pk_players, public.pk_rounds, public.pk_seats cascade;
delete from poker.hole; delete from poker.deck;
delete from public.pk_ledger;
update public.profiles set balance = 1000, poker_net = 0, poker_net_sprint = null;

-- ann koopt in voor 200 en staat meteen weer op: netto nul.
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.zegt('inkopen staat als min in het grootboek', '-200',
  (select amount::text from public.pk_ledger order by id desc limit 1));
select pg_temp.zegt('en de stand van deze sprint ook', '-200',
  (select poker_net::text from public.profiles where username = 'ann'));
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_leave()');
select pg_temp.zegt('opstaan zet hem weer op nul', '0',
  (select poker_net::text from public.profiles where username = 'ann'));

-- bob koopt in voor 200 en staat op met 350: netto honderdvijftig erbij. Dat is precies
-- wat er van de ranglijst af moet, want het kwam van een andere speler.
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
update public.pk_players set stack = 350 where username = 'bob';
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_leave()');
select pg_temp.zegt('wat je van tafel meeneemt telt mee', '150',
  (select poker_net::text from public.profiles where username = 'bob'));
select pg_temp.zegt('en staat als twee regels in het grootboek', '2',
  (select count(*)::text from public.pk_ledger where username = 'bob'));
select pg_temp.zegt('een speler ziet alleen zijn eigen regels', 'false',
  has_table_privilege('authenticated', 'public.pk_ledger', 'select')::text);

-- ---------- blut, en toch verder kunnen ----------
-- Wie zijn stapel kwijt is hield een rij met nul fiches: pk_tick deelt hem niets meer en
-- pk_sit gaf 'already seated'. Vastgelopen, terwijl er gewoon geld op zijn saldo stond.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds;
  update public.profiles set balance = 1000;
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.zegt('nog een keer aanschuiven met fiches op tafel mag niet', 'already seated',
  pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)'));
update public.pk_players set stack = 0 where username = 'ann';
select pg_temp.zegt('maar wie blut is mag bijkopen', 'geen fout',
  pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(150)'));
select pg_temp.zegt('en zit weer met fiches', '150',
  (select stack::text from public.pk_players where username = 'ann'));
select pg_temp.zegt('op dezelfde stoel als daarvoor', '1',
  (select count(distinct seat_no)::text from public.pk_players where username = 'ann'));
select pg_temp.zegt('het saldo is twee keer afgeschreven', '650',
  (select balance::text from public.profiles where username = 'ann'));
select pg_temp.zegt('en het bijkopen staat apart in het grootboek', 'rebuy',
  coalesce((select kind from public.pk_ledger order by id desc limit 1), 'geen grootboek'));

-- Bijkopen midden in een hand waar je nog in zit: nee. Dat is je stapel vergroten terwijl
-- er om gespeeld wordt.
do $$ begin
  insert into public.pk_rounds (id, lobby_id, deck_commit) values (7771, 1, 'x');
  insert into public.pk_seats (round_id, seat_no, user_id, username, stack)
       values (7771, 0, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0);
  update public.pk_players set stack = 0 where username = 'ann';
end $$;
select pg_temp.zegt('bijkopen terwijl je hand nog loopt mag niet', 'wait for the hand to finish',
  pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(150)'));

-- ---------- een dichtgeslagen tab laat geen fiches achter ----------
-- Wie de lobby verlaat zonder op te staan (of wiens tab dichtgaat) hield een rij aan een
-- tafel waar hij niet meer bij hoort, met zijn stapel erop. pk_tick ruimt dat tussen de
-- handen door op en zet de fiches terug op het saldo.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  update public.profiles set balance = 1000;
  insert into public.lobby_members (lobby_id, player, username) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob') on conflict do nothing;
  delete from public.lobby_members where player = 'aaaaaaaa-0000-0000-0000-000000000001';
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 175),
    (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1, 200);
end $$;
select public.pk_tick(1);
select pg_temp.zegt('wie de lobby uit is zit niet meer aan tafel', '0',
  (select count(*)::text from public.pk_players where username = 'ann'));
select pg_temp.zegt('en zijn stapel staat terug op zijn saldo', '1175',
  (select balance::text from public.profiles where username = 'ann'));
select pg_temp.zegt('wie er nog wel bij hoort blijft zitten', '200',
  coalesce((select stack::text from public.pk_players where username = 'bob'), 'weg'));

-- ---------- de sprintgrens mag geen gratis fiches geven ----------
-- Op profiles staat een trigger die een achterstallig account terugzet naar 1000. Raakte
-- pk_sit dat saldo aan zonder die grens eerst af te handelen, dan gooide de trigger de
-- aftrek weg -- en stonden de fiches er toch. Alleen te toetsen met sprint_reset.sql erbij.
do $$ begin
  if to_regprocedure('public.sprint_now()') is null then
    raise notice 'sprint_reset staat er niet in, deze test wordt overgeslagen';
    return;
  end if;
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  -- Ann moet aan tafel zitten om te kunnen inkopen; de toets hierboven had haar er juist
  -- uitgehaald om het opruimen te laten zien.
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles on conflict do nothing;
  alter table public.profiles disable trigger sprint_guard;
  update public.profiles set balance = 8000, reset_sprint = public.sprint_now() - 1
   where username = 'ann';
  alter table public.profiles enable trigger sprint_guard;
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.zegt('inkopen over een sprintgrens heen kost gewoon geld', '800',
  coalesce((select balance::text from public.profiles where username = 'ann'), 'geen sprint'));
select pg_temp.zegt('en er staan niet meer fiches op tafel dan betaald', '200',
  coalesce((select stack::text from public.pk_players where username = 'ann'), 'geen sprint'));
select pg_temp.zegt('saldo plus stapel is precies de verse duizend', '1000',
  coalesce((select (p.balance + pl.stack)::text from public.profiles p
              join public.pk_players pl on pl.user_id = p.id where p.username = 'ann'), 'geen sprint'));

-- ---------- aanschuiven terwijl er al gedeeld is ----------
-- Wie tijdens een lopende hand aanschuift staat wel in pk_players en niet in pk_seats: hij
-- wacht op de volgende hand. pk_leave ging toch de stoelen-tak in, vond daar niets, en
-- telde null bij het saldo op -- zijn hele inkoop verdween zonder een woord.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
  -- De toets hierboven haalde er een lid uit om het opruimen te laten zien; hier hoort
  -- iedereen er weer bij, anders veegt pk_tick ze meteen van tafel.
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles on conflict do nothing;
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select public.pk_tick(1);
select pg_temp.zegt('er loopt een hand met twee stoelen', '2',
  (select count(*)::text from public.pk_seats));
select pg_temp.zegt('en cas schuift aan terwijl die loopt', 'geen fout',
  pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000003', 'select public.pk_sit(500)'));
select pg_temp.zegt('hij zit aan tafel maar niet in de hand', '0',
  (select count(*)::text from public.pk_seats s
    where s.user_id = 'aaaaaaaa-0000-0000-0000-000000000003'));
select pg_temp.zegt('opstaan lukt gewoon', 'geen fout',
  pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000003', 'select public.pk_leave()'));
select pg_temp.zegt('en zijn inkoop staat helemaal terug', '1000',
  (select balance::text from public.profiles where username = 'cas'));
select pg_temp.zegt('de hand van de anderen loopt nog steeds', '1',
  (select count(*)::text from public.pk_rounds where settled_at is null));

-- ---------- opstaan terwijl je nog geld tegoed hebt ----------
-- De uitbetaling van een hand landde op pk_players. Wie tijdens die hand opstond had daar
-- geen rij meer, dus de join vond niets en het geld was uit het spel weg -- terwijl zijn
-- stoel wel degelijk iets kreeg: een inzet die niemand callde komt terug, en wie all-in
-- ging kan de hand gewoon winnen.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck;
  -- Allebei ingekocht voor 100, dus 900 op het saldo en 100 op tafel. Dat moet kloppen,
  -- anders toetst de som aan het eind niets.
  update public.profiles set balance = 900, reset_sprint = public.sprint_now()
   where username in ('ann', 'bob');
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles on conflict do nothing;
  -- Een hand waarin ann all-in staat en bob gepast heeft: ann hoort alles te krijgen.
  -- Allebei hebben hun hele stapel van 100 ingezet, dus voor de stoelen ligt er niets meer.
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 0),
    (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1, 0);
  insert into public.pk_rounds (id, lobby_id, deck_commit, street, high_bet)
       values (8881, 1, 'x', 3, 100);
  insert into public.pk_seats (round_id, seat_no, user_id, username, stack, total_bet, allin, acted, hole) values
    (8881, 0, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 100, true,  true, '{As,Ks}'),
    (8881, 1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 0, 100, false, true, '{2c,7d}');
  update public.pk_seats set folded = true where round_id = 8881 and seat_no = 1;
end $$;

set test.uid = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.pk_leave();
select pg_temp.zegt('wie all-in staat wordt niet weggepast bij het opstaan', 'false',
  (select folded::text from public.pk_seats where round_id = 8881 and seat_no = 0));
select pg_temp.zegt('maar hij staat wel als vertrokken gemerkt', 'true',
  (select left_table::text from public.pk_seats where round_id = 8881 and seat_no = 0));
select public.pk_settle(8881);
select pg_temp.zegt('zijn stoel wint de pot', '200',
  (select payout::text from public.pk_seats where round_id = 8881 and seat_no = 0));
select pg_temp.zegt('en dat geld komt op zijn saldo terecht', '1100',
  (select balance::text from public.profiles where username = 'ann'));
select pg_temp.zegt('bob houdt zijn saldo maar is zijn inzet kwijt', '900',
  (select balance::text from public.profiles where username = 'bob'));
select pg_temp.zegt('en zit met een lege stapel aan tafel', '0',
  (select stack::text from public.pk_players where username = 'bob'));

-- Alles bij elkaar is nog steeds tweeduizend: 1000 + 1000 aan het begin.
select pg_temp.zegt('er zijn geen fiches bij gekomen of af gegaan', '2000',
  (select (coalesce((select sum(balance) from public.profiles
                      where username in ('ann', 'bob')), 0)
         + coalesce((select sum(stack) from public.pk_players
                      where username in ('ann', 'bob')), 0))::text));

-- En opstaan-en-meteen-opnieuw-inkopen mag de verse inkoop niet overschrijven met de
-- stapel van de stoel die je net verlaten hebt.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  update public.profiles set balance = 1000;
  insert into public.pk_rounds (id, lobby_id, deck_commit, street, high_bet)
       values (8882, 1, 'x', 3, 50);
  insert into public.pk_seats (round_id, seat_no, user_id, username, stack, total_bet, folded, acted, left_table) values
    (8882, 0, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 50, true, true, true),
    (8882, 1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 150, 50, false, true, '{}' is null);
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 300),
    (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1, 150);
end $$;
select public.pk_settle(8882);
select pg_temp.zegt('een verse inkoop blijft staan na het afrekenen', '300',
  (select stack::text from public.pk_players where username = 'ann'));

-- ---------- de knop draait echt rond ----------
-- De knop hing aan het nummer BINNEN de hand, en dat nummer wordt elke hand opnieuw
-- uitgedeeld op volgorde van de tafelstoelen van wie er fiches heeft. Schuift er iemand
-- aan op een lagere tafelstoel, dan schuift iedereen daarachter een plek op en wijst
-- hetzelfde rondenummer een andere speler aan: dezelfde twee posten twee handen achter
-- elkaar de blinds en de nieuwkomer krijgt de knop cadeau.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles on conflict do nothing;
  -- bob en cas zitten op tafelstoel 1 en 2; stoel 0 is nog vrij.
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1, 200),
    (1, 'aaaaaaaa-0000-0000-0000-000000000003', 'cas', 2, 200);
end $$;
select public.pk_tick(1);
select pg_temp.zegt('de eerste knop ligt op de laagste bezette tafelstoel', '1',
  (select button_lobby_seat::text from public.pk_rounds order by id desc limit 1));

-- Hand afbreken en ann laten aanschuiven op tafelstoel 0 -- voor de anderen dus.
do $$ begin
  update public.pk_rounds set settled_at = now() where settled_at is null;
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack)
       values (1, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 200);
end $$;
select public.pk_tick(1);
select pg_temp.zegt('de knop schuift naar de volgende tafelstoel, niet terug', '2',
  (select button_lobby_seat::text from public.pk_rounds order by id desc limit 1));
select pg_temp.zegt('en de nieuwkomer krijgt hem niet cadeau', 'cas',
  (select s.username from public.pk_seats s
     join public.pk_rounds r on r.id = s.round_id
    where r.id = (select max(id) from public.pk_rounds) and s.seat_no = r.button_seat));

-- Nog een hand: nu moet hij ronddraaien naar de laagste, dus naar ann op tafelstoel 0.
do $$ begin
  update public.pk_rounds set settled_at = now() where settled_at is null;
  update public.pk_players set stack = 200;
end $$;
select public.pk_tick(1);
select pg_temp.zegt('daarna draait hij rond naar de laagste tafelstoel', '0',
  (select button_lobby_seat::text from public.pk_rounds order by id desc limit 1));
select pg_temp.zegt('en dat is ann', 'ann',
  (select s.username from public.pk_seats s
     join public.pk_rounds r on r.id = s.round_id
    where r.id = (select max(id) from public.pk_rounds) and s.seat_no = r.button_seat));

-- En wie van tafel gaat mag de knop niet laten terugspringen.
do $$ begin
  update public.pk_rounds set settled_at = now() where settled_at is null;
  delete from public.pk_players where username = 'cas';
  update public.pk_players set stack = 200;
end $$;
select public.pk_tick(1);
select pg_temp.zegt('na een vertrek schuift hij gewoon door', '1',
  (select button_lobby_seat::text from public.pk_rounds order by id desc limit 1));

-- ---------- het bord ligt vast voordat het valt ----------
-- Sinds het zaadje niet meer naar buiten komt, hield niets de vijf gemeenschappelijke
-- kaarten nog vast: deck_commit stond wel op het scherm maar ging nooit meer open. Een
-- oneerlijke server kon dus de flop neerleggen die hem uitkwam. Nu staat er bij het delen
-- een hash van het hele bord, en komt het zout bij het afrekenen vrij.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles on conflict do nothing;
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select public.pk_tick(1);
select pg_temp.zegt('er staat een hash van het bord zodra er gedeeld is', 'true',
  (select (board_commit is not null)::text from public.pk_rounds order by id desc limit 1));
select pg_temp.zegt('maar het zout nog niet', '0',
  (select count(*)::text from public.pk_live where board_salt is not null));

-- De hand uitspelen: een speler past, dan rekent de server af.
do $$
declare v_r bigint; v_beurt smallint; v_seq integer;
begin
  select id, to_act_seat, act_seq into v_r, v_beurt, v_seq
    from public.pk_rounds order by id desc limit 1;
  perform set_config('test.uid',
    (select user_id::text from public.pk_seats where round_id = v_r and seat_no = v_beurt), true);
  perform public.pk_act(v_r, v_seq, 'fold');
end $$;
-- Iedereen past voor de flop, dus er valt geen kaart: dan is er ook geen zout vrij te
-- geven, en valt er niets na te rekenen. Dat is goed -- er is niets getoond.
select pg_temp.zegt('zonder bord komt er geen zout vrij', '0',
  (select coalesce(array_length(board_salt, 1), 0)::text from public.pk_live
    order by id desc limit 1));

-- En nu een hand die WEL uitkomt: twee keer checken tot de river.
do $$
declare v_r bigint; v_beurt smallint; v_seq integer; v_uid uuid; v_n int := 0;
begin
  perform public.pk_tick(1);
  select id into v_r from public.pk_rounds order by id desc limit 1;
  while v_n < 40 loop
    select to_act_seat, act_seq into v_beurt, v_seq from public.pk_rounds where id = v_r;
    exit when v_beurt is null;
    select user_id into v_uid from public.pk_seats where round_id = v_r and seat_no = v_beurt;
    perform set_config('test.uid', v_uid::text, true);
    -- Callen als er wat te betalen valt, anders checken: zo komt de hand tot de river.
    begin perform public.pk_act(v_r, v_seq, 'check');
    exception when others then perform public.pk_act(v_r, v_seq, 'call'); end;
    v_n := v_n + 1;
  end loop;
end $$;
select pg_temp.zegt('een hand die uitkomt heeft vijf bordkaarten', '5',
  (select array_length(board, 1)::text from public.pk_rounds order by id desc limit 1));
select pg_temp.zegt('en evenveel zouten komen vrij', '5',
  (select array_length(board_salt, 1)::text from public.pk_live order by id desc limit 1));
select pg_temp.zegt('elke bordkaart klopt met zijn hash van voor de flop', '5',
  (select count(*)::text from public.pk_rounds r,
          generate_series(1, array_length(r.board, 1)) k
    where r.id = (select max(id) from public.pk_rounds)
      and r.board_commit[k] = encode(poker.sha256(r.board_salt[k] || ':' || r.board[k]), 'hex')));
select pg_temp.zegt('het zaadje is opgeruimd zodra de hand om is', '0',
  (select count(*)::text from poker.deck));

-- ---------- opstaan en opruimen tegelijk geeft geen dubbele fiches ----------
-- Het opruimen betaalde uit en verwijderde daarna; wie tegelijk zelf opstond kreeg zijn
-- inkoop twee keer terug. Nu haalt het opruimen eerst weg en betaalt alleen uit wat het
-- echt heeft weggehaald, dus een tweede poging levert niets meer op.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  update public.profiles set balance = 500 where username = 'ann';
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 500),
    (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1, 200);
  delete from public.lobby_members where player = 'aaaaaaaa-0000-0000-0000-000000000001';
end $$;
select public.pk_tick(1);
select pg_temp.zegt('het opruimen betaalt een keer uit', '1000',
  (select balance::text from public.profiles where username = 'ann'));
select public.pk_tick(1);
select pg_temp.zegt('en een tweede keer porren doet er niets bij', '1000',
  (select balance::text from public.profiles where username = 'ann'));

-- ---------- opstaan, weer aanschuiven, en nog eens opstaan ----------
-- Binnen dezelfde hand. De oude stoel blijft staan met nul fiches erop; werd die als
-- waarheid genomen, dan gaf het tweede opstaan $0 terug en was de verse inkoop weg.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles on conflict do nothing;
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select public.pk_tick(1);
select pg_temp.zegt('ann en bob zitten in de hand', '2',
  (select count(*)::text from public.pk_seats));
-- ann staat op midden in de hand, schuift meteen weer aan, en staat dan nog eens op.
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_leave()');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(300)');
select pg_temp.zegt('ze zit weer met een verse inkoop', '300',
  (select stack::text from public.pk_players where username = 'ann'));
-- De blind die ze bij het delen postte blijft in de pot -- dat geld was al ingelegd. Wat
-- terug moet komen is de verse inkoop van 300, en niet nul.
select pg_temp.zegt('het tweede opstaan geeft de verse inkoop terug', '300',
  (select (public.pk_leave()->>'stack')));
select pg_temp.zegt('er staat geen stoel meer voor haar aan tafel', '0',
  (select count(*)::text from public.pk_players where username = 'ann'));

-- ---------- de sprintgrens vernietigt de inzet van wie is opgestaan niet ----------
-- void_all geeft elke stoel zijn inzet terug in pk_seats.stack en zet dat door naar
-- pk_players. Wie is opgestaan heeft daar geen rij meer, dus zijn inzet verdween.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  update public.profiles set balance = 900, reset_sprint = public.sprint_now()
   where username in ('ann', 'bob');
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack)
       values (1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 1, 50);
  insert into public.pk_rounds (id, lobby_id, deck_commit, street, high_bet)
       values (9991, 1, 'x', 1, 50);
  -- ann is opgestaan met 50 nog in de pot; bob zit er nog.
  insert into public.pk_seats (round_id, seat_no, user_id, username, stack, total_bet, folded, acted, left_table) values
    (9991, 0, 'aaaaaaaa-0000-0000-0000-000000000001', 'ann', 0, 50, true, true, true),
    (9991, 1, 'aaaaaaaa-0000-0000-0000-000000000002', 'bob', 50, 50, false, true, false);
  alter table public.profiles disable trigger sprint_guard;
  update public.profiles set reset_sprint = public.sprint_now() - 1 where username = 'ann';
  alter table public.profiles enable trigger sprint_guard;
end $$;
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000001';
select public.sprint_reset();
select pg_temp.zegt('wie opstond en dan de sprintgrens raakt, staat op 1000', '1000',
  (select balance::text from public.profiles where username = 'ann'));
select pg_temp.zegt('en bob houdt zijn inzet plus zijn stapel', '100',
  coalesce((select stack::text from public.pk_players where username = 'bob'), 'weg'));
select pg_temp.zegt('er blijft niets op de verlaten stoel staan', '0',
  (select stack::text from public.pk_seats where round_id = 9991 and seat_no = 0));

-- ---------- aan tafel via de echte lobby ----------
-- De fout die in productie elke poging om te gaan zitten liet klappen: pk_sit las
-- my_lobby.lobby_id, maar in de echte view heet die kolom `id`. Alle toetsen hierboven
-- zetten de spelers zelf in lobby_members; deze gaat door de lobby-functies zelf naar
-- binnen, precies zoals de knop QUICK PLAY en een uitnodigingscode dat doen.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from public.lobby_members;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
end $$;
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000001';
select pg_temp.zegt('quick play zet ann aan een tafel', 'true',
  (select (public.lobby_quick() ? 'lobby')::text));
select pg_temp.zegt('en ze kan meteen gaan zitten', 'true',
  (select (public.pk_sit(200)->>'ok')));
select pg_temp.zegt('ze zit aan de pokertafel van haar eigen lobby', '1',
  (select count(*)::text from public.pk_players pl join public.my_lobby l on l.id = pl.lobby_id
    where pl.username = 'ann'));

-- Een vriend komt erbij met de code van de tafel.
select set_config('pk.code', (select code from public.my_lobby), false);
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000002';
select pg_temp.zegt('bob komt binnen met de code', 'true',
  (select (public.lobby_join(current_setting('pk.code')) ? 'lobby')::text));
select pg_temp.zegt('en gaat ook zitten', 'true', (select (public.pk_sit(200)->>'ok')));
select pg_temp.zegt('ze zitten samen aan dezelfde tafel', '2',
  (select count(*)::text from public.pk_players
    where lobby_id = (select id from public.my_lobby)));
select pg_temp.zegt('en er wordt gedeeld', 'true',
  (select (public.pk_tick((select id from public.my_lobby))->>'dealt')));

-- ---------- iedereen staat op midden in een hand ----------
-- In de browser-toets gevonden. Ann stond op, daarna bob, en de hand bleef open staan met
-- beider blinds in de pot. Omdat een lege lobby wordt opgeruimd, kwam er nooit meer iemand
-- die de tafel porde: die fiches waren weg. Wie als laatste overblijft hoort de pot te
-- winnen, meteen, zoals aan elke tafel.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck; delete from public.lobby_members;
  -- lobby_quick hierboven ruimt lege lobby's op, net als in het echt; tafel 1 weer neerzetten.
  insert into public.lobbies (id, code) values (1, 'TEST') on conflict (id) do nothing;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles where username in ('ann', 'bob');
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select public.pk_tick(1);
select pg_temp.zegt('er loopt een hand met twee blinds in de pot', '15',
  (select sum(total_bet)::text from public.pk_seats where round_id = pg_temp.ronde()));

-- Wie is NIET aan de beurt? Die staat op: de ander mag zijn beurt niet kwijtraken.
select set_config('pk.wacht', (select s.user_id::text from public.pk_seats s
  join public.pk_rounds r on r.id = s.round_id
 where r.id = pg_temp.ronde() and s.seat_no <> r.to_act_seat), false);
select pg_temp.mislukt(current_setting('pk.wacht')::uuid, 'select public.pk_leave()');
select pg_temp.zegt('wie als laatste overblijft wint meteen', 'true',
  (select (settled_at is not null)::text from public.pk_rounds where id = pg_temp.ronde()));
-- De small blind (5) wint, want de big blind (10) stond op. Het deel van de big blind dat
-- niemand callde gaat terug naar hem: dat is gewone poker. De winnaar krijgt zijn eigen 5
-- plus de 5 die gecalld waren; de vertrekker krijgt zijn ongecallde 5 op zijn saldo.
select pg_temp.zegt('en krijgt wat er om gespeeld werd', '10',
  (select payout::text from public.pk_seats
    where round_id = pg_temp.ronde() and not folded));
select pg_temp.zegt('en de vertrekker krijgt zijn ongecallde deel terug', '5',
  (select payout::text from public.pk_seats
    where round_id = pg_temp.ronde() and left_table));
select pg_temp.mislukt(pg_temp.beurt_uid_of_iemand(), 'select public.pk_leave()');
select pg_temp.zegt('als ook de ander opstaat, staat er niets meer open', '0',
  (select count(*)::text from public.pk_rounds where settled_at is null));
select pg_temp.zegt('en elke fiche staat weer op een saldo', '2000',
  (select sum(balance)::int::text from public.profiles where username in ('ann', 'bob')));

-- En met drie spelers: wie opstaat terwijl een ander aan de beurt is, neemt die ander zijn
-- beurt niet af.
do $$ begin
  delete from public.pk_players; delete from public.pk_rounds; delete from public.pk_seats;
  delete from poker.hole; delete from poker.deck; delete from public.lobby_members;
  -- lobby_quick hierboven ruimt lege lobby's op, net als in het echt; tafel 1 weer neerzetten.
  insert into public.lobbies (id, code) values (1, 'TEST') on conflict (id) do nothing;
  update public.profiles set balance = 1000, reset_sprint = public.sprint_now();
  insert into public.lobby_members (lobby_id, player, username)
       select 1, id, username from public.profiles;
end $$;
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000001', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000002', 'select public.pk_sit(200)');
select pg_temp.mislukt('aaaaaaaa-0000-0000-0000-000000000003', 'select public.pk_sit(200)');
select public.pk_tick(1);
select set_config('pk.beurt', (select to_act_seat::text from public.pk_rounds where id = pg_temp.ronde()), false);
select set_config('pk.ander', (select s.user_id::text from public.pk_seats s
  join public.pk_rounds r on r.id = s.round_id
 where r.id = pg_temp.ronde() and s.seat_no <> r.to_act_seat order by s.seat_no limit 1), false);
select pg_temp.mislukt(current_setting('pk.ander')::uuid, 'select public.pk_leave()');
select pg_temp.zegt('wie aan de beurt was, is dat nog steeds', current_setting('pk.beurt'),
  (select to_act_seat::text from public.pk_rounds where id = pg_temp.ronde()));
select pg_temp.zegt('en de hand loopt gewoon door', 'false',
  (select (settled_at is not null)::text from public.pk_rounds where id = pg_temp.ronde()));
