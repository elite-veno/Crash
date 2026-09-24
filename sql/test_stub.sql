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

-- De lobby is de tafel, en die komt uit de sociale kant van het spel. Poker leest eruit:
-- pk_sit uit my_lobby, het opruimen in pk_tick uit lobby_members.
--
-- Wat hieronder staat is NIET zelf verzonnen maar overgenomen uit de echte Supabase:
-- dezelfde kolomnamen, dezelfde view, dezelfde functies. Dat is met opzet. Hier stond
-- eerst een eigen nabouw -- `my_lobby` met een kolom `lobby_id`, `lobby_members` met
-- `user_id` -- en de SQL werd daartegen geschreven en getoetst. Alles groen. Maar in de
-- echte my_lobby heet die kolom `id`, en in lobby_members heet de speler `player`, dus in
-- productie klapte elke poging om aan de pokertafel te gaan zitten. Een testopstelling
-- die de werkelijkheid niet volgt, toetst alleen zichzelf.
--
-- lobby_code() en lobby_invites staan hier in de kleinste vorm die werkt; de echte
-- versies doen er voor poker niet toe.
create table if not exists public.lobbies (
  id         bigserial primary key,
  code       text unique,
  is_private boolean not null default false,
  host       uuid
);
insert into public.lobbies (id, code) values (1, 'TEST')
  on conflict (id) do nothing;
select setval(pg_get_serial_sequence('public.lobbies', 'id'),
              greatest(1, (select max(id) from public.lobbies)));

create table if not exists public.lobby_members (
  lobby_id  bigint not null references public.lobbies on delete cascade,
  player    uuid not null,
  username  text not null,
  joined_at timestamptz not null default now(),
  seen_at   timestamptz not null default now(),
  primary key (lobby_id, player)
);

create table if not exists public.lobby_invites (
  lobby_id bigint not null,
  invited  uuid not null
);

create or replace function public.lobby_code() returns text language sql as $$
  select upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
$$;

drop view if exists public.my_lobby;
create view public.my_lobby as
  select l.id,
         l.code,
         l.is_private,
         (l.host = auth.uid()) as is_host,
         (select count(*) from public.lobby_members m2 where m2.lobby_id = l.id) as players,
         (select coalesce(jsonb_agg(jsonb_build_object('username', m3.username,
                                                       'host', m3.player = l.host)
                                    order by m3.joined_at), '[]'::jsonb)
            from public.lobby_members m3 where m3.lobby_id = l.id) as members
    from public.lobbies l
    join public.lobby_members m on m.lobby_id = l.id
   where auth.uid() is not null and m.player = auth.uid();

create or replace function public.lobby_prune(p_lobby bigint) returns void
language sql security definer set search_path = public as $$
  delete from public.lobby_members
   where lobby_id = p_lobby and seen_at < now() - interval '60 seconds'
$$;

create or replace function public.lobby_quick() returns jsonb
language plpgsql security definer set search_path = public as $$
declare me public.profiles; l record;
begin
  if auth.uid() is null then raise exception 'niet ingelogd'; end if;
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then raise exception 'geen profiel'; end if;

  -- Eerst de spoken opruimen, anders lijkt elke tafel vol.
  delete from public.lobby_members where seen_at < now() - interval '60 seconds';
  delete from public.lobbies lo where not exists (select 1 from public.lobby_members m where m.lobby_id = lo.id);

  select lo.id, lo.code, count(m.player) as n
    into l
    from public.lobbies lo
    left join public.lobby_members m on m.lobby_id = lo.id
   where not lo.is_private
   group by lo.id, lo.code
  having count(m.player) < 24
   order by count(m.player) desc, lo.id asc
   limit 1;

  if l.id is null then return public.lobby_create(false); end if;
  return public.lobby_join(l.code);
end $$;

create or replace function public.lobby_create(p_private boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me public.profiles; c text; lid bigint; tries int := 0;
begin
  if auth.uid() is null then raise exception 'niet ingelogd'; end if;
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then raise exception 'geen profiel'; end if;

  perform public.lobby_leave();

  loop
    c := public.lobby_code();
    exit when not exists (select 1 from public.lobbies where code = c);
    tries := tries + 1;
    if tries > 20 then raise exception 'geen vrije code'; end if;
  end loop;

  insert into public.lobbies (code, host, is_private) values (c, me.id, coalesce(p_private, true))
  returning id into lid;
  insert into public.lobby_members (lobby_id, player, username) values (lid, me.id, me.username);
  return jsonb_build_object('lobby', lid, 'code', c, 'private', coalesce(p_private, true), 'host', true);
end $$;

create or replace function public.lobby_join(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me public.profiles; l public.lobbies; n int;
begin
  if auth.uid() is null then raise exception 'niet ingelogd'; end if;
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then raise exception 'geen profiel'; end if;

  select * into l from public.lobbies where code = upper(trim(coalesce(p_code, ''))) for update;
  if l.id is null then raise exception 'die lobby bestaat niet'; end if;

  perform public.lobby_prune(l.id);
  select count(*) into n from public.lobby_members where lobby_id = l.id;
  if n >= 24 and not exists (select 1 from public.lobby_members where lobby_id = l.id and player = me.id) then
    raise exception 'die lobby zit vol';
  end if;

  perform public.lobby_leave();
  insert into public.lobby_members (lobby_id, player, username) values (l.id, me.id, me.username)
  on conflict (lobby_id, player) do update set seen_at = now();
  delete from public.lobby_invites where lobby_id = l.id and invited = me.id;
  return jsonb_build_object('lobby', l.id, 'code', l.code, 'private', l.is_private, 'host', l.host = me.id);
end $$;

create or replace function public.lobby_leave() returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); lid bigint; n int;
begin
  if me is null then raise exception 'niet ingelogd'; end if;
  select lobby_id into lid from public.lobby_members where player = me limit 1;
  if lid is null then return jsonb_build_object('left', false); end if;
  delete from public.lobby_members where lobby_id = lid and player = me;
  select count(*) into n from public.lobby_members where lobby_id = lid;
  if n = 0 then delete from public.lobbies where id = lid; end if;
  return jsonb_build_object('left', true, 'lobby', lid);
end $$;

create or replace function public.lobby_heartbeat() returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); lid bigint;
begin
  if me is null then raise exception 'niet ingelogd'; end if;
  update public.lobby_members set seen_at = now() where player = me returning lobby_id into lid;
  if lid is null then return jsonb_build_object('lobby', null); end if;
  perform public.lobby_prune(lid);
  return jsonb_build_object('lobby', lid);
end $$;

do $$ begin
  create role anon;
exception when duplicate_object then null; end $$;
