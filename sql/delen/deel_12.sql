-- ============================================================================
--  DEEL 12 VAN 14
-- ============================================================================
--
--  Plak dit pas NA deel 11. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql, sql/sprint_reset.sql
-- ============================================================================


revoke all on function public.pk_tick(bigint) from public, anon;
grant execute on function public.pk_tick(bigint) to authenticated;

-- ---------- en nog eens de sloten ----------
-- poker.sql doet `revoke all on all functions in schema poker`, maar dat draait VOORDAT
-- dit bestand poker.sha256, poker.fresh_deck en poker.shuffle aanmaakt. Die drie hielden
-- dus de standaard PUBLIC EXECUTE die Postgres aan elke nieuwe functie geeft.
--
-- Vandaag is er niets mee te doen: zonder USAGE op het schema `poker` komt een aanroep er
-- niet eens langs. Maar het is één `grant usage` van iemand die het schema ooit open zet
-- verwijderd van poker.shuffle(zaadje) -- en dat geeft het hele deck terug. Een slot dat
-- alleen houdt zolang een ander slot houdt, is geen slot. Dus hier nog een keer, nu de
-- functies bestaan.
revoke all on all functions in schema poker from public, anon, authenticated;
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

-- De pagina schrijft deze kolom al mee bij elke opslag, maar de reset gebeurt op de
-- server en moet hem ook kunnen zetten -- anders wint de oudere momentopname van de
-- browser. Staat hij er al, dan doet deze regel niets.
alter table public.profiles
  add column if not exists updated_at timestamptz default now();

-- En voor wat er hierna bij komt. Zonder deze default staat er bij een vers account null,
-- en dan hing het van de plek in de code af of dat "nog nooit" of "bij" betekende.
alter table public.profiles
  alter column reset_sprint set default public.sprint_now();

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
                    and coalesce(pr.reset_sprint, v_now) < v_now)
  then
    execute 'select poker.void_all($1)' using v_uid;
  end if;

  -- Het saldo van VOOR de reset wordt in dezelfde stap meegenomen: de `from` ziet de rij
  -- nog zoals hij was. Zonder dat trucje leest een `select` erna het nieuwe saldo, en dan
  -- meldt de pagina "$1000 -> $1000" in plaats van wat er stond.
  -- `updated_at` moet mee. De pagina vergelijkt bij het ophalen de tijd op de server met
  -- die van haar eigen laatste opslag en houdt de nieuwste; laat je die tijd staan, dan is
  -- de lokale momentopname jonger dan de reset, wint hij, en schrijft de browser het oude
  -- saldo meteen weer terug. De reset was dan wel gebeurd en toch niet.
  update public.profiles p
     set balance = 1000,
         reset_sprint = v_now,
         updated_at = now()
    from public.profiles oud
   where p.id = v_uid
     and oud.id = p.id
     and coalesce(p.reset_sprint, v_now) < v_now
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
