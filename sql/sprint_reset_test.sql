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
update public.profiles set balance = 50000, reset_sprint = public.sprint_now() - 3
 where username = 'winnaar';
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
