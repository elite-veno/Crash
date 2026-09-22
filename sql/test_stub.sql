-- Het kleinste stukje Supabase dat nodig is om de SQL hiernaast te kunnen toetsen op een
-- lege Postgres: een profielentabel en een auth.uid() die te sturen is. Dit hoort NIET in
-- een echte database -- daar levert Supabase deze dingen zelf.
create schema if not exists auth;
create table if not exists public.profiles (
  id uuid primary key,
  username text,
  balance numeric not null default 1000,
  reset_season bigint
);
do $$ begin
  create role authenticated;
exception when duplicate_object then null; end $$;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid;
$$;
