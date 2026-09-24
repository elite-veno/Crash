-- Toetst sql/sprint_reset.sql op een Postgres die verder leeg is. Draai eerst
-- sql/test_stub.sql (het kleinste stukje Supabase dat nodig is), dan sprint_reset.sql,
-- dan dit.
--
--   psql -f sql/test_stub.sql -f sql/sprint_reset.sql -f sql/sprint_reset_test.sql
--
-- Elke regel die begint met FOUT is een test die niet klopt; komt er geen enkele, dan is
-- alles in orde.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

create or replace function pg_temp.zegt(wat text, verwacht text, gekregen text)
returns text language sql as $$
  select case when verwacht = gekregen then 'ok    ' || wat
              else 'FOUT  ' || wat || ' -- verwacht ' || verwacht || ', kreeg ' || gekregen end;
$$;

truncate public.profiles;
insert into public.profiles (id, username, balance, reset_sprint) values
  ('11111111-1111-1111-1111-111111111111', 'winnaar',   8421.55, public.sprint_now() - 1),
  ('22222222-2222-2222-2222-222222222222', 'verliezer',    3.20, public.sprint_now() - 1),
  ('33333333-3333-3333-3333-333333333333', 'nieuw',      1000.00, public.sprint_now());

set test.uid = '11111111-1111-1111-1111-111111111111';
select pg_temp.zegt('wie geld had gaat terug naar 1000',
  'true|1000|8421.55',
  (select (d->>'reset') || '|' || (d->>'balance') || '|' || (d->>'before')
     from (select public.sprint_reset() as d) x));

select pg_temp.zegt('nog een keer vragen doet niets',
  'false|1000',
  (select (d->>'reset') || '|' || (d->>'balance') from (select public.sprint_reset() as d) x));

set test.uid = '22222222-2222-2222-2222-222222222222';
select pg_temp.zegt('wie alles kwijt was krijgt ook 1000',
  'true|1000|3.20',
  (select (d->>'reset') || '|' || (d->>'balance') || '|' || (d->>'before')
     from (select public.sprint_reset() as d) x));

set test.uid = '33333333-3333-3333-3333-333333333333';
select pg_temp.zegt('wie deze sprint al was teruggezet blijft met rust',
  'false',
  (select d->>'reset' from (select public.sprint_reset() as d) x));

-- Drie sprints weg geweest: een keer terug naar 1000, niet drie keer iets.
--
-- De trigger laat reset_sprint niet terugzetten -- dat is precies waar hij voor is, en
-- een paar regels verderop wordt dat ook getoetst. Om een speler NEER te kunnen zetten
-- alsof er sprints voorbij zijn (in het echt doet de klok dat, niet een schrijver) gaat
-- hij hier even uit. Alles wat daarna getoetst wordt loopt weer over de gewone weg.
alter table public.profiles disable trigger sprint_guard;
update public.profiles set balance = 50000, reset_sprint = public.sprint_now() - 3
 where username = 'winnaar';
alter table public.profiles enable trigger sprint_guard;
set test.uid = '11111111-1111-1111-1111-111111111111';
select public.sprint_reset();
select pg_temp.zegt('drie sprints weg is ook maar een keer', '1000',
  (select balance::text from public.profiles where username = 'winnaar'));

-- Geld uit een vorige sprint landt niet op de verse 1000.
select pg_temp.zegt('een ronde van voor de reset betaalt niet uit', 'false',
  public.sprint_may_pay('11111111-1111-1111-1111-111111111111', now() - interval '4 days')::text);
select pg_temp.zegt('een ronde van deze sprint betaalt wel uit', 'true',
  public.sprint_may_pay('11111111-1111-1111-1111-111111111111', now())::text);
select pg_temp.zegt('een onbekend account betaalt niet uit', 'false',
  public.sprint_may_pay('99999999-9999-9999-9999-999999999999', now())::text);

-- Niemand ingelogd: geweigerd. De fout wordt opgevangen, want een uitzondering zou het
-- script hier afbreken en dan zou je niet zien of hij de goede fout gaf.
set test.uid = '';
create or replace function pg_temp.zonder_account() returns text language plpgsql as $$
begin
  perform public.sprint_reset();
  return 'geen fout';
exception when others then
  return sqlerrm;
end;
$$;
select pg_temp.zegt('zonder account wordt de reset geweigerd', 'not signed in',
  pg_temp.zonder_account());

-- ---------- fiches op een pokertafel overleven de reset niet ----------
-- Dit is het gat dat een reset per sprint anders openlaat: geld op een tafel zit niet in
-- profiles.balance, dus zou het de omslag overleven. Alleen te toetsen als sql/poker.sql
-- er ook in zit.
do $$
begin
  if to_regclass('public.pk_players') is null then
    raise notice 'poker staat er niet in, deze test wordt overgeslagen';
    return;
  end if;

  delete from public.pk_players;
  delete from public.pk_rounds;
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack)
       values (1, '11111111-1111-1111-1111-111111111111', 'winnaar', 0, 50000);
  insert into public.pk_rounds (id, lobby_id, deck_commit)
       values (999, 1, 'x') on conflict do nothing;
  insert into public.pk_seats (round_id, seat_no, user_id, username, stack, total_bet)
       values (999, 0, '11111111-1111-1111-1111-111111111111', 'winnaar', 0, 300);

  alter table public.profiles disable trigger sprint_guard;
  update public.profiles set balance = 12, reset_sprint = public.sprint_now() - 1
   where id = '11111111-1111-1111-1111-111111111111';
  alter table public.profiles enable trigger sprint_guard;
end $$;

set test.uid = '11111111-1111-1111-1111-111111111111';
select public.sprint_reset();
select pg_temp.zegt('de stapel op de tafel is weg', '0',
  coalesce((select count(*)::text from public.pk_players
             where user_id = '11111111-1111-1111-1111-111111111111'), 'geen poker'));
select pg_temp.zegt('de lopende hand is afgesloten', 'true',
  coalesce((select (settled_at is not null)::text from public.pk_rounds where id = 999), 'geen poker'));
select pg_temp.zegt('en het saldo staat gewoon op 1000', '1000',
  (select balance::text from public.profiles where id = '11111111-1111-1111-1111-111111111111'));

-- ---------- de reset van een speler mag de pot van de anderen niet slopen ----------
-- Er zat een gat: de lopende hand werd doodverklaard zonder uit te betalen, dus de inzet
-- van de tafelgenoten -- die niets met die sprintgrens te maken hebben -- verdween.
do $$
begin
  if to_regclass('public.pk_players') is null then return; end if;
  delete from public.pk_players; delete from public.pk_rounds;
  truncate public.profiles;
  insert into public.profiles (id, username, balance, reset_sprint) values
    ('11111111-1111-1111-1111-111111111111', 'weg',   1000, public.sprint_now() - 1),
    ('22222222-2222-2222-2222-222222222222', 'blijft',1000, public.sprint_now());
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack) values
    (1, '11111111-1111-1111-1111-111111111111', 'weg',    0, 100),
    (1, '22222222-2222-2222-2222-222222222222', 'blijft', 1, 100);
  insert into public.pk_rounds (id, lobby_id, deck_commit) values (5551, 1, 'x');
  insert into public.pk_seats (round_id, seat_no, user_id, username, stack, total_bet) values
    (5551, 0, '11111111-1111-1111-1111-111111111111', 'weg',    50, 50),
    (5551, 1, '22222222-2222-2222-2222-222222222222', 'blijft', 50, 50);
end $$;

set test.uid = '11111111-1111-1111-1111-111111111111';
select public.sprint_reset();
select pg_temp.zegt('wie blijft zitten houdt zijn hele stapel', '100',
  coalesce((select stack::text from public.pk_players where username = 'blijft'), 'geen poker'));
select pg_temp.zegt('en de hand is afgebroken, niet uitbetaald', '0',
  coalesce((select sum(payout)::text from public.pk_seats where round_id = 5551), 'geen poker'));
select pg_temp.zegt('er staat niets meer in de pot', '0',
  coalesce((select sum(total_bet)::text from public.pk_seats where round_id = 5551), 'geen poker'));
select pg_temp.zegt('en wie wegging staat gewoon op 1000', '1000',
  (select balance::text from public.profiles where username = 'weg'));

-- ---------- de reset overslaan kan niet ----------
-- sprint_reset() is een verzoek: de pagina moet het vragen. Een aangepaste pagina, of een
-- curl met je eigen token, vraagt het niet en schrijft gewoon zijn oude saldo weg. Daarom
-- staat de afrekening nu op het schrijfpad. Deze toetsen doen precies wat zo'n schrijver
-- doet -- een kale UPDATE op profiles, zonder ooit sprint_reset() aan te roepen.
do $$
begin
  delete from public.pk_players; delete from public.pk_rounds;
  truncate public.profiles;
  insert into public.profiles (id, username, balance, reset_sprint) values
    ('11111111-1111-1111-1111-111111111111', 'sluw',  9999, public.sprint_now() - 1),
    ('22222222-2222-2222-2222-222222222222', 'braaf',  742, public.sprint_now());
end $$;

update public.profiles set balance = 9999 where username = 'sluw';
select pg_temp.zegt('wie de reset niet vraagt krijgt hem alsnog', '1000',
  (select balance::text from public.profiles where username = 'sluw'));
select pg_temp.zegt('en staat daarna op de lopende sprint', '0',
  (select (reset_sprint - public.sprint_now())::text from public.profiles where username = 'sluw'));

-- En de kolom zelf vooruitzetten werkt ook niet: dan was je met een enkele PATCH voorgoed
-- "bij" en raakte je nooit meer teruggezet.
do $$
begin
  alter table public.profiles disable trigger sprint_guard;
  update public.profiles set balance = 9999, reset_sprint = public.sprint_now() - 2
   where username = 'sluw';
  alter table public.profiles enable trigger sprint_guard;
end $$;
update public.profiles set balance = 9999, reset_sprint = public.sprint_now() + 50
 where username = 'sluw';
select pg_temp.zegt('reset_sprint is niet vooruit te zetten', '0',
  (select (reset_sprint - public.sprint_now())::text from public.profiles where username = 'sluw'));
select pg_temp.zegt('en het saldo ging toch terug naar 1000', '1000',
  (select balance::text from public.profiles where username = 'sluw'));

-- Wie bij is speelt gewoon door: de trigger mag een normale opslag niet in de weg zitten.
update public.profiles set balance = 1337 where username = 'braaf';
select pg_temp.zegt('een gewone opslag blijft gewoon staan', '1337',
  (select balance::text from public.profiles where username = 'braaf'));
update public.profiles set balance = 1338, reset_sprint = public.sprint_now() + 9
 where username = 'braaf';
select pg_temp.zegt('ook wie bij is schuift de kolom niet op', '0',
  (select (reset_sprint - public.sprint_now())::text from public.profiles where username = 'braaf'));

-- En de fiches op tafel gaan op het schrijfpad net zo goed mee als via de RPC.
do $$
begin
  if to_regclass('public.pk_players') is null then return; end if;
  delete from public.pk_players; delete from public.pk_rounds;
  insert into public.pk_players (lobby_id, user_id, username, seat_no, stack)
       values (1, '11111111-1111-1111-1111-111111111111', 'sluw', 0, 7500);
  alter table public.profiles disable trigger sprint_guard;
  update public.profiles set reset_sprint = public.sprint_now() - 1 where username = 'sluw';
  alter table public.profiles enable trigger sprint_guard;
end $$;
update public.profiles set balance = 9999 where username = 'sluw';
select pg_temp.zegt('en de stapel op tafel ging mee', '0',
  coalesce((select count(*)::text from public.pk_players where username = 'sluw'), 'geen poker'));

-- ---------- de pagina mag de reset niet terugdraaien ----------
-- profilePull() houdt de nieuwste van server en browser. Bleef updated_at op de oude tijd
-- staan, dan was de lokale momentopname jonger, won hij, en schreef de browser het saldo
-- van vorige sprint meteen weer terug.
do $$
begin
  alter table public.profiles disable trigger sprint_guard;
  update public.profiles
     set balance = 4200, reset_sprint = public.sprint_now() - 1, updated_at = now() - interval '9 days'
   where username = 'sluw';
  alter table public.profiles enable trigger sprint_guard;
end $$;
set test.uid = '11111111-1111-1111-1111-111111111111';
select public.sprint_reset();
select pg_temp.zegt('de reset zet ook de tijd bij', 'true',
  (select (updated_at > now() - interval '1 minute')::text
     from public.profiles where username = 'sluw'));
