-- Na elke sprint begint iedereen weer op $1000.
--
-- Tot nu toe gebeurde dat één keer per SEIZOEN (twaalf dagen) en hield je $1000 plus een
-- tiende van alles daarboven. Dat is nu per SPRINT (drie dagen), en plat: iedereen op
-- 1000, niemand neemt iets mee. Een sprint is waar de ranglijst en de titels al op lopen,
-- dus nu loopt het saldo mee met dezelfde klok.
--
-- Draai dit in de SQL-editor van Supabase. Het is veilig om twee keer te draaien.
--
-- Er staat hier geen enkele sleutel in. De pagina gebruikt alleen de publieke sleutel; de
-- service_role-sleutel hoort nergens anders dan in het dashboard van Supabase.

-- ---------- de klok ----------
-- Dezelfde blokken als de pagina: sprintId() = floor(unix / 259200).
create or replace function public.sprint_now()
returns bigint
language sql
stable
as $$
  select floor(extract(epoch from now()) / 259200)::bigint;
$$;

-- ---------- de kolom ----------
-- Voor welke sprint dit account al is teruggezet. Null betekent: nog nooit, en dan telt de
-- lopende sprint als afgehandeld -- anders zou een nieuw account meteen "achterstallig"
-- zijn en bij zijn eerste stap al gereset worden.
alter table public.profiles
  add column if not exists reset_sprint bigint;

update public.profiles
   set reset_sprint = public.sprint_now()
 where reset_sprint is null;

-- ---------- de reset zelf ----------
-- Eén keer per speler per sprint, hoeveel tabs er ook tegelijk vragen: het `where` op
-- reset_sprint doet het werk, en de rij wordt door de update vergrendeld. Vraagt een
-- tweede tab het een tel later, dan vindt die geen rij meer om bij te werken en krijgt hij
-- reset = false met het saldo dat er nu staat.
--
-- Wie drie sprints weg is geweest, wordt één keer teruggezet en niet drie keer -- er valt
-- ook niets te stapelen, want het is plat.
create or replace function public.sprint_reset()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_now bigint := public.sprint_now();
  v_before numeric;
  v_after numeric;
  v_done boolean := false;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  -- Eerst van de pokertafels af, dan pas het saldo. Fiches op een tafel zitten niet in
  -- profiles.balance, dus een reset die alleen dat saldo aanraakt laat ze staan -- en dan
  -- begint iemand de nieuwe sprint met een stapel van de vorige. De functie staat in het
  -- schema `poker` en bestaat alleen als sql/poker.sql gedraaid is; zonder poker slaat dit
  -- stil over.
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'poker' and p.proname = 'void_all') > 0
     and exists (select 1 from public.profiles pr
                  where pr.id = v_uid
                    and (pr.reset_sprint is null or pr.reset_sprint < v_now))
  then
    execute 'select poker.void_all($1)' using v_uid;
  end if;

  -- Het saldo van VOOR de reset wordt in dezelfde stap meegenomen: de `from` ziet de rij
  -- nog zoals hij was. Zonder dat trucje leest een `select` erna het nieuwe saldo, en dan
  -- meldt de pagina "$1000 -> $1000" in plaats van wat er stond.
  update public.profiles p
     set balance = 1000,
         reset_sprint = v_now
    from public.profiles oud
   where p.id = v_uid
     and oud.id = p.id
     and (p.reset_sprint is null or p.reset_sprint < v_now)
  returning oud.balance into v_before;

  if found then
    v_done := true;
    v_after := 1000;
  else
    -- Niets te doen: een andere tab was net eerder, of deze sprint is al afgehandeld.
    select balance into v_before from public.profiles where id = v_uid;
    v_after := v_before;
  end if;

  return json_build_object(
    'reset',  v_done,
    'sprint', v_now,
    'balance', v_after,
    'before', v_before
  );
end;
$$;

revoke all on function public.sprint_reset() from public;
grant execute on function public.sprint_reset() to authenticated;

-- ---------- geld uit een vorige sprint ----------
-- Een uitbetaling voor een ronde die vóór jouw reset begon, mag niet bovenop de verse 1000
-- landen: dan zou de omslag een bonus zijn voor wie toevallig een hand open had staan. De
-- inzet zelf is geen probleem -- die was al van het saldo af, en dat saldo bestaat niet
-- meer. Alleen de uitbetaling moet tegengehouden worden.
--
-- Deze functie is wat elke afrekening aanroept voordat hij geld bijschrijft.
create or replace function public.sprint_may_pay(p_uid uuid, p_round_started timestamptz)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select floor(extract(epoch from p_round_started) / 259200)::bigint >= coalesce(p.reset_sprint, 0)
       from public.profiles p where p.id = p_uid),
    false);
$$;

revoke all on function public.sprint_may_pay(uuid, timestamptz) from public;
grant execute on function public.sprint_may_pay(uuid, timestamptz) to authenticated;
