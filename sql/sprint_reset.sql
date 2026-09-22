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

-- ---------- en wie het niet vraagt ----------
-- Hierboven staat een NETTE reset: de pagina vraagt hem, de server voert hem uit. Alleen
-- is "de pagina vraagt hem" geen afspraak waar de server iets aan heeft. Het saldo gaat
-- gewoon als kolom mee in een PATCH op /rest/v1/profiles, dus wie sprint_reset() nooit
-- aanroept -- een aangepaste pagina, of een curl met zijn eigen token -- houdt zijn stapel
-- van vorige sprint en schrijft die elke keer opnieuw weg. De reset was een verzoek.
--
-- Hij hoort op het SCHRIJFPAD te staan, niet in een functie die je mag overslaan. Elke
-- update van een profielrij komt hier eerst langs, en staat die rij nog op een sprint die
-- voorbij is, dan wordt hij hier afgerekend -- wat de schrijver ook meestuurde. Je kunt de
-- reset niet ontlopen door hem niet te vragen: je eerstvolgende schrijfactie IS de reset.
--
-- En reset_sprint zelf is niet te verzetten. De nieuwe waarde wordt hier altijd uit de
-- OUDE rij afgeleid, nooit uit wat er binnenkwam; anders zet een aanvaller die kolom
-- vooruit en is hij voorgoed "bij".
create or replace function public.sprint_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now bigint := public.sprint_now();
  v_had bigint := coalesce(old.reset_sprint, public.sprint_now());
begin
  -- Niet vanuit onszelf. poker.void_all schrijft óók naar profiles -- het betaalt de inzet
  -- terug van wie tijdens de hand was opgestaan -- en die schrijfactie komt hier weer
  -- langs. Omdat dit een BEFORE-trigger is, is reset_sprint van de buitenste rij nog niet
  -- bijgewerkt als de binnenste langskomt, dus die ziet nog steeds "achterstallig", roept
  -- void_all opnieuw aan, en zo door tot Postgres afkapt met "stack depth limit exceeded".
  --
  -- Een geneste schrijfactie hoort hier dus niets te doen. De kolom wordt wel gepind, want
  -- die mag ook via een omweg niet vooruit te zetten zijn.
  if pg_trigger_depth() > 1 then
    new.reset_sprint := v_had;
    return new;
  end if;

  if v_had >= v_now then
    -- Bij. De kolom toch terugzetten op wat er stond: niemand schuift hem vooruit.
    new.reset_sprint := v_had;
    return new;
  end if;

  -- Achterstallig. Eerst de fiches die op een pokertafel liggen -- die zitten niet in
  -- balance, dus zonder deze stap begint iemand de nieuwe sprint met een stapel van de
  -- vorige. void_all raakt profiles niet aan, dus dit roept zichzelf niet terug.
  if (select count(*) from pg_proc pr join pg_namespace n on n.oid = pr.pronamespace
       where n.nspname = 'poker' and pr.proname = 'void_all') > 0 then
    execute 'select poker.void_all($1)' using new.id;
  end if;

  new.balance := 1000;
  new.reset_sprint := v_now;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists sprint_guard on public.profiles;
create trigger sprint_guard
  before update on public.profiles
  for each row execute function public.sprint_guard();

revoke all on function public.sprint_guard() from public, anon, authenticated;

-- ---------- geld uit een vorige sprint ----------
-- Een uitbetaling voor een ronde die vóór jouw reset begon, mag niet bovenop de verse 1000
-- landen: dan zou de omslag een bonus zijn voor wie toevallig een hand open had staan. De
-- inzet zelf is geen probleem -- die was al van het saldo af, en dat saldo bestaat niet
-- meer. Alleen de uitbetaling moet tegengehouden worden.
--
-- Hier stond "deze functie is wat elke afrekening aanroept". Dat was niet waar, en zo'n
-- zin is erger dan geen zin: hij laat je vertrouwen op een grendel die nergens dicht zit.
--
-- Waar hij WEL gebruikt wordt: pk_settle roept hem aan voor de enige uitbetaling die bij
-- poker rechtstreeks op een saldo landt -- die van een speler die tijdens de hand is
-- opgestaan. Al het andere bij poker gaat naar de stapel op tafel en niet naar het saldo,
-- en die stapels worden bij de sprintgrens toch afgebroken door poker.void_all.
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
