-- ============================================================================
--  DEEL 13 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 12. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 13 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/sprint_reset.sql, sql/poker_ledger.sql
-- ============================================================================


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
-- Poker is het eerste spel hier waar geld tussen ACCOUNTS beweegt. Alle andere spellen
-- gaan tegen het huis: wat je wint komt uit de kas en wat je verliest gaat erheen. Aan een
-- pokertafel komt het van de speler naast je.
--
-- Dat botst met de sprintranglijst. Die rekent je winst als saldo-nu min saldo-aan-het-
-- begin, en beloont de nummer één met een VIP-pas. Twee vrienden die aan een privétafel
-- gaan zitten en de fiches van de een naar de ander schuiven, zetten die ander zo bovenaan
-- zonder dat er ook maar iets gewonnen is. Netto over het tweetal is het nul; voor de
-- ranglijst is het een pas.
--
-- Vandaar deze twee dingen:
--
--  1. Per speler wordt bijgehouden wat poker deze sprint met zijn saldo heeft gedaan:
--     alles wat van tafel terugkwam min alles wat erop ging. Daarmee is de ranglijst te
--     corrigeren -- zie de view onderaan.
--  2. Elke verplaatsing komt in een grootboek. Dat lost afspraken tussen spelers niet op
--     (geen enkele pokersite kan dat), maar maakt het wel zichtbaar: een vraag naar grote
--     eenzijdige stromen tussen twee vaste namen is één regel.
--
-- Draai dit ná sql/poker_rpc.sql.

alter table public.profiles
  add column if not exists poker_net numeric not null default 0,
  add column if not exists poker_net_sprint bigint;

create table if not exists public.pk_ledger (
  id        bigserial primary key,
  at        timestamptz not null default now(),
  sprint    bigint not null,
  lobby_id  bigint,
  user_id   uuid not null,
  username  text not null,
  -- 'sit' is negatief (van het saldo af), 'leave' positief (er weer op).
  kind      text not null,
  amount    integer not null
);
create index if not exists pk_ledger_sprint on public.pk_ledger (sprint, user_id);

revoke all on public.pk_ledger from anon, authenticated;
alter table public.pk_ledger enable row level security;

-- Het grootboek is niet geheim, maar ook niet iets om rond te strooien: alleen je eigen
-- regels, zodat je kunt narekenen wat poker met je saldo heeft gedaan.
create or replace view public.pk_my_ledger
with (security_invoker = false, security_barrier = true) as
  select l.at, l.sprint, l.kind, l.amount
    from public.pk_ledger l
   where l.user_id = auth.uid();

grant select on public.pk_my_ledger to authenticated;

-- Zie je hieronder "DEEL 13 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Maak de editor leeg en ga door met deel 14.
select 'DEEL 13 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
