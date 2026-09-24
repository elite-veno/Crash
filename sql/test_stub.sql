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

-- De lobby is de tafel, en die komt uit de sociale kant van het spel (lobby_quick,
-- lobby_join, lobby_invite). Poker leest er alleen uit, dus hier staat het kleinste dat
-- werkt: iedereen zit aan tafel 1. Zonder dit liep het commando in sql/README.md vast op
-- "relation public.my_lobby does not exist".
create table if not exists public.lobbies (
  id         bigserial primary key,
  code       text,
  is_private boolean not null default false
);
insert into public.lobbies (id, code) values (1, 'TEST')
  on conflict (id) do nothing;

create table if not exists public.lobby_members (
  lobby_id bigint not null,
  user_id  uuid   not null,
  primary key (lobby_id, user_id)
);

create or replace view public.my_lobby as
  select 1::bigint as lobby_id, 'TEST'::text as code, false as is_private;

do $$ begin
  create role anon;
exception when duplicate_object then null; end $$;
