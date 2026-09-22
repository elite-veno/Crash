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
  insert into public.lobby_members (lobby_id, user_id) values
    (1, 'aaaaaaaa-0000-0000-0000-000000000002') on conflict do nothing;
  delete from public.lobby_members where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
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
