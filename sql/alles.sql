-- ============================================================================
--  CRASH CASINO -- alles wat er in Supabase moet, in een bestand
-- ============================================================================
--
--  Plak dit hele bestand in de SQL-editor van Supabase en druk op RUN. Het is
--  veilig om twee keer te draaien: alles staat als `create or replace`, of met
--  `if not exists`.
--
--  Dit bestand is samengesteld uit de vier losse bestanden in sql/, in de
--  volgorde waarin ze moeten draaien. Wil je ze apart houden, gebruik dan die.
--  De losse bestanden blijven de bron; dit is een afdruk ervan.
--
--    1. poker.sql         de tabellen en views van poker
--    2. poker_rpc.sql     de functies: delen, inzetten, afrekenen, de klok
--    3. sprint_reset.sql  iedereen na elke sprint terug op $1000
--    4. poker_ledger.sql  wat poker met een saldo doet, zodat de ranglijst klopt
--
--  ER STAAT HIER GEEN ENKELE SLEUTEL IN, en die hoort er ook niet in. De pagina
--  gebruikt alleen de publieke (anon/publishable) sleutel. De service_role-sleutel
--  hoort nergens anders dan in het dashboard van Supabase -- niet in dit bestand,
--  niet in crash.html, nergens.
--
--  NA HET DRAAIEN, EEN DING OM TE CONTROLEEREN:
--  Ga naar Settings -> API -> Exposed schemas en zorg dat daar ALLEEN `public`
--  staat. Het schema `poker` mag daar NOOIT bij. Daar liggen de holekaarten en de
--  zaadjes van de schudbeurt; komt dat schema in die lijst, dan kan iedereen met
--  de publieke sleutel de kaarten van zijn tegenstanders opvragen.
--
--  pgcrypto is nodig (voor sha256). Op Supabase staat die standaard aan, in het
--  schema `extensions`; het stuk hieronder zoekt hem zelf op. Zegt de editor toch
--  dat pgcrypto ontbreekt, draai dan eerst:
--      create extension if not exists pgcrypto with schema extensions;
--
-- ============================================================================



-- ============================================================================
--  1 van 4 -- DE TABELLEN EN VIEWS   (sql/poker.sql)
-- ============================================================================

-- Multiplayer poker: Texas Hold'em aan de tafel waar je met je vrienden al zit.
--
-- Draai dit in de SQL-editor van Supabase, ná sql/sprint_reset.sql. Het is veilig om twee
-- keer te draaien. Er staat geen enkele sleutel in.
--
-- Hoe het in elkaar zit, in één alinea: een LOBBY is de tafel (die bestond al, met
-- lobby_quick / lobby_join / lobby_invite), en daar hangt nu een pokerronde aan. De server
-- deelt, houdt de beurt bij en rekent af; de browser stuurt hooguit "raise" met een bedrag
-- en laat de rest zien. Elke browser mag pk_tick() porren -- wie als eerste merkt dat er
-- gedeeld of afgerekend moet worden, vraagt het aan, en de server doet het één keer.
--
-- Het moeilijkste stuk staat bij pk_hole: bij poker heeft iedereen twee kaarten die tot de
-- showdown van hem alleen zijn, en de pagina is openbaar. Daar is row-level security voor,
-- en die staat hieronder aan.

-- ---------- het schema dat de REST-laag niet bedient ----------
-- Dit is het fundament onder alles wat geheim moet blijven. PostgREST bedient alleen de
-- schema's die in de API-instellingen staan (public, graphql_public). Staat `poker` daar
-- niet bij -- en dat hoort zo -- dan is er simpelweg geen URL die hier binnenkomt, wat
-- iemand ook probeert.
--
-- LET OP bij het installeren: zet `poker` NOOIT in "Exposed schemas" in de API-instellingen
-- van Supabase. Alles wat de browser van poker mag weten staat in public.
create schema if not exists poker;
revoke all on schema poker from public;

-- ---------- de ronde ----------
create table if not exists public.pk_rounds (
  id           bigserial primary key,
  lobby_id     bigint not null,
  started_at   timestamptz not null default now(),
  -- 0 = preflop, 1 = flop, 2 = turn, 3 = river, 4 = showdown, 5 = afgerekend
  street       smallint not null default 0,
  board        text[] not null default '{}',
  -- Het pak ligt vast voordat er gedeeld wordt: de hash gaat vooraf naar de spelers, het
  -- zaadje pas na de showdown. Zo is achteraf na te rekenen dat er niet geschud is
  -- onderweg -- dezelfde afspraak als bij crash en blackjack.
  -- De hash van het zaadje gaat vooraf naar de spelers; het zaadje zelf staat in het
  -- schema hiernaast en komt pas vrij als de hand is afgerekend.
  deck_commit  text not null,
  -- Het bord, vastgelegd bij het delen. Sinds het zaadje niet meer naar buiten komt, was
  -- er niets meer dat de vijf gemeenschappelijke kaarten vasthield: deck_commit stond nog
  -- wel op het scherm maar ging nooit meer open, dus een oneerlijke server kon de flop,
  -- turn en river neerleggen die hem uitkwamen.
  --
  -- Per kaart een eigen hash, niet een over het hele bord. Een hand hoeft niet uit te
  -- komen: past iedereen voor de flop, dan valt er geen kaart, en eindigt hij op de turn
  -- dan liggen er vier. Met een hash over vijf kaarten viel er in die gevallen niets na te
  -- rekenen. Nu komt bij het afrekenen het zout vrij van precies de kaarten die ook echt
  -- gevallen zijn; de rest blijft dicht, en de holekaarten zitten er sowieso niet in.
  board_commit text[],
  board_salt   text[],
  button_seat  smallint not null default 0,   -- de plek BINNEN deze hand (0..n-1)
  -- En de stoel AAN TAFEL waar de knop lag. De hand hernummert elke keer opnieuw, dus
  -- alleen op het rondenummer draaien laat de knop verspringen zodra er iemand aanschuift
  -- of weggaat. Dit is wat de volgende hand oppakt.
  button_lobby_seat smallint,
  -- Fiches zijn hele dollars. Centen blijven in profiles.balance en komen de tafel niet
  -- op: dan valt er bij het verdelen van een pot niets weg in de afronding.
  sb           integer not null default 5,
  bb           integer not null default 10,
  high_bet     integer not null default 0,      -- hoogste inzet van deze straat
  min_raise    integer not null default 10,
  to_act_seat  smallint,
  -- Het volgnummer van de volgende zet. De browser stuurt mee welke zet hij dénkt te doen;
  -- klopt dat nummer niet meer -- omdat een tweede tab net voor was -- dan gebeurt er
  -- niets in plaats van twee keer hetzelfde.
  act_seq      integer not null default 0,
  act_deadline timestamptz,
  settled_at   timestamptz
);
create index if not exists pk_rounds_lobby on public.pk_rounds (lobby_id, id desc);

-- ---------- de stoelen ----------
create table if not exists public.pk_seats (
  round_id   bigint not null references public.pk_rounds(id) on delete cascade,
  seat_no    smallint not null,
  user_id    uuid not null,
  username   text not null,
  stack      integer not null default 0,        -- hele dollars, wat er voor je ligt
  bet        integer not null default 0,        -- deze straat
  total_bet  integer not null default 0,        -- deze hele hand
  folded     boolean not null default false,
  allin      boolean not null default false,
  acted      boolean not null default false,
  -- Na een korte all-in -- een all-in die kleiner is dan een volle verhoging -- mag wie al
  -- gezet had het verschil nog bijleggen, maar niet opnieuw verhogen. Dat is een aparte
  -- vlag, want `acted` gaat bij een volle verhoging juist weer uit.
  may_raise  boolean not null default true,
  -- De kaarten liggen NIET hier maar in poker.hole. Wat hier staat is de gezouten hash
  -- ervan, zodat elke speler zijn eigen kaarten meteen kan narekenen zonder dat iemand
  -- anders iets te zien krijgt.
  card_commit text,
  -- Opgestaan terwijl de hand nog liep. Dan is er geen rij meer in pk_players om de
  -- uitbetaling op te zetten, en zonder deze vlag verdween die uitbetaling: het geld was
  -- uit het spel weg. Ook nodig om een verse inkoop niet te overschrijven met de stapel
  -- van de stoel die hij net verlaten heeft.
  left_table boolean not null default false,
  shown      boolean not null default false,    -- open gegooid bij de showdown
  hole       text[] not null default '{}',      -- pas gevuld bij de showdown
  payout     integer not null default 0,
  primary key (round_id, seat_no)
);

-- De kaarten zelf, en de stok. Hier komt geen enkele browser bij.
create table if not exists poker.hole (
  round_id bigint   not null references public.pk_rounds(id) on delete cascade,
  seat_no  smallint not null,
  player   uuid     not null,
  cards    text[]   not null,
  salt     text     not null,   -- waarmee de speler zijn eigen commit narekent
  primary key (round_id, seat_no)
);

create table if not exists poker.deck (
  round_id bigint primary key references public.pk_rounds(id) on delete cascade,
  seed     text   not null,
  cards    text[] not null
);
create index if not exists pk_seats_user on public.pk_seats (user_id);

-- Ook op de tabellen in het schema hiernaast, al komt daar al niets bij: drie sloten op de
-- kaarten en de stok is niet te veel voor het enige dat bij poker echt geheim moet blijven.
alter table poker.hole enable row level security;
alter table poker.deck enable row level security;
revoke all on all tables in schema poker from public, anon, authenticated;
revoke all on all functions in schema poker from public, anon, authenticated;

-- ---------- wie er aan tafel zit tussen de handen door ----------
-- Je stapel hoort bij de tafel, niet bij de hand: je blijft zitten als een hand voorbij is.
create table if not exists public.pk_players (
  lobby_id  bigint not null,
  user_id   uuid not null,
  username  text not null,
  seat_no   smallint not null,
  stack     integer not null default 0,         -- hele dollars
  sat_at    timestamptz not null default now(),
  beat_at   timestamptz not null default now(),
  primary key (lobby_id, user_id)
);
create unique index if not exists pk_players_seat on public.pk_players (lobby_id, seat_no);

-- ---------- de kaarten van een ander zijn niet van jou ----------
-- ---------- kolommen die er later bij kwamen ----------
-- `create table if not exists` slaat een bestaande tabel over, ook als er kolommen bij
-- zijn gekomen. Zonder deze regels krijgt wie het bestand eerder al draaide de nieuwe
-- kolommen niet, en dat valt pas op als een functie erover struikelt. Staan ze er al, dan
-- doet dit niets.
alter table public.pk_rounds add column if not exists act_seq     integer not null default 0;
alter table public.pk_rounds add column if not exists button_lobby_seat smallint;
alter table public.pk_rounds add column if not exists board_commit text[];
alter table public.pk_rounds add column if not exists board_salt   text[];
alter table public.pk_seats  add column if not exists may_raise   boolean not null default true;
alter table public.pk_seats  add column if not exists card_commit text;
alter table public.pk_seats  add column if not exists left_table  boolean not null default false;

-- Dit is de kern. De pagina is openbaar en iedereen kan met de publieke sleutel
-- rechtstreeks de REST-laag bevragen, dus een view die alle kaarten teruggeeft is meteen
-- vals spel. Row-level security laat alleen je eigen rij door -- of elke rij die bij de
-- showdown open is gegooid.
-- Twee sloten op elkaar, want één is te makkelijk per ongeluk open te zetten.
--
-- Het eerste: niemand komt rechtstreeks bij de tabellen. Geen select, geen insert, geen
-- update. Alles loopt via de functies en de views hieronder.
revoke all on public.pk_rounds  from anon, authenticated;
revoke all on public.pk_seats   from anon, authenticated;
revoke all on public.pk_players from anon, authenticated;

-- Het tweede: row-level security aan, zonder ook maar één policy. Dat betekent voor
-- iedereen behalve de eigenaar: niets. Raakt het eerste slot ooit los -- een `grant` die
-- iemand er later bijzet -- dan houdt dit het nog steeds dicht.
alter table public.pk_rounds  enable row level security;
alter table public.pk_seats   enable row level security;
alter table public.pk_players enable row level security;


-- En dit is de enige deur: een view die draait als zijn eigenaar (security_invoker = false,
-- de standaard) en zelf beslist wat hij laat zien. `auth.uid()` leest de claim uit het
-- token van de AANROEPER, niet van de eigenaar, dus de regel hieronder klopt ook al draait
-- de view met andermans rechten.
--
-- Wat iedereen mag zien: alles behalve de kaarten van een ander die nog dicht liggen.
-- Een drop hoort erbij: `create or replace view` mag er geen kolom TUSSEN zetten, en
-- may_raise hoort naast de andere standen van de stoel te staan. De grant eronder zet het
-- recht meteen terug.
drop view if exists public.pk_seats_public;
create view public.pk_seats_public
with (security_invoker = false) as
  select s.round_id, s.seat_no, s.username, s.user_id, s.stack, s.bet, s.total_bet,
         s.folded, s.allin, s.acted, s.payout, s.shown,
         -- Of deze stoel nog mag verhogen. Na een korte all-in mag wie al had gehandeld
         -- alleen nog callen of passen; zonder deze kolom weet het scherm dat niet en zet
         -- het een RAISE-knop neer die de server vervolgens weigert.
         s.may_raise,
         s.card_commit,
         -- Alleen wat open ligt. Je eigen kaarten haal je bij pk_my_hole; die komen uit
         -- het andere schema en gaan nooit door deze view heen.
         case when s.shown then s.hole else '{}'::text[] end as hole
    from public.pk_seats s;

grant select on public.pk_seats_public to anon, authenticated;

-- En de ronde zelf, zonder het zaadje zolang de hand loopt.
-- Hier stond het zaadje in, vrijgegeven zodra de hand was afgerekend -- zoals bij crash
-- en roulette, waar het achteraf tonen van het zaadje juist het bewijs IS.
--
-- Bij poker kan dat niet. Het zaadje stuurt de hele schudbeurt, dus wie het heeft rekent
-- ELKE hand van die ronde na: ook de twee kaarten van wie gepast heeft en ze nooit heeft
-- laten zien. Gemuckte kaarten horen nooit bekend te worden -- niet aan tafel, en niet een
-- uur later. En het stond hier voor iedereen, ook voor wie niet is ingelogd.
--
-- Het bewijs loopt daarom per stoel in plaats van per deck: voor het delen staat er van
-- elke hand een gezouten hash in pk_seats_public.card_commit, en na het delen kan elke
-- speler met zijn eigen zout uit pk_my_hole narekenen dat die hash bij zijn kaarten hoort.
-- Je controleert zo je eigen hand net zo hard als vroeger, zonder iets over die van een
-- ander te leren. Het zaadje blijft in poker.deck, in het schema dat PostgREST niet serveert.
drop view if exists public.pk_live;
create view public.pk_live
with (security_invoker = false) as
  select r.id, r.lobby_id, r.started_at, r.street, r.board, r.deck_commit,
         r.board_commit,
         -- De zouten van het bord pas als de hand om is, en dan alleen van de kaarten die
         -- ook echt gevallen zijn. Eerder, of verder, zou het kaarten verraden die nog
         -- dicht horen te liggen.
         case when r.settled_at is null then null
              else r.board_salt[1:coalesce(array_length(r.board, 1), 0)] end as board_salt,
         r.button_seat, r.sb, r.bb, r.high_bet, r.min_raise, r.to_act_seat,
         r.act_seq, r.act_deadline, r.settled_at, now() as server_now
    from public.pk_rounds r;

grant select on public.pk_live to anon, authenticated;

-- Je eigen kaarten, en niets anders. Het filter staat IN de view, niet in de vraag die de
-- browser stelt: `where player = auth.uid()` is hier niet weg te laten of te omzeilen met
-- een andere query. Dit is de enige deur naar het schema hiernaast.
create or replace view public.pk_my_hole
with (security_invoker = false, security_barrier = true) as
  select h.round_id, h.seat_no, h.cards, h.salt
    from poker.hole h
   where h.player = auth.uid();

grant select on public.pk_my_hole to authenticated;

-- Wie er aan tafel zit, met zijn stapel. Geen geheimen.
create or replace view public.pk_table
with (security_invoker = false) as
  select p.lobby_id, p.user_id, p.username, p.seat_no, p.stack, p.beat_at
    from public.pk_players p;

grant select on public.pk_table to anon, authenticated;

-- ---------- de sprintreset raakt ook de tafels ----------
-- Fiches die op een pokertafel liggen zitten niet in profiles.balance, dus een reset die
-- alleen dat saldo op 1000 zet, slaat ze over. Wie $50.000 op een tafel parkeert over de
-- sprintgrens heen, begint de nieuwe sprint met $50.000 in plaats van met $1000 -- precies
-- wat de reset moet voorkomen.
--
-- Daarom: bij het omslaan vervalt de lopende hand en gaat elke stapel van tafel. Het geld
-- dat terugkomt doet er niet toe, want het saldo gaat er meteen daarna toch op 1000; wat
-- ertoe doet is dat er geen fiches ACHTERBLIJVEN die de reset overleven.
create or replace function poker.void_all(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ronde bigint;
begin
  -- De lopende hand waar deze speler in zit, wordt AFGEBROKEN -- niet doodverklaard.
  --
  -- Er stond hier eerst alleen `settled_at = now()`. Dat leek genoeg, want het saldo van
  -- deze speler gaat zo meteen toch op 1000. Maar aan die tafel zitten anderen, en die
  -- hebben hun inzet al in de pot staan. Die pot werd dan nooit uitbetaald: de sprintgrens
  -- van één speler maakte het geld van zijn tafelgenoten zoek, en zij hebben niets met die
  -- omslag te maken.
  --
  -- Dus: iedereen krijgt eerst terug wat hij deze hand heeft ingelegd, en dan pas gaat de
  -- ronde dicht. Het is geen hand die is uitgespeeld, dus niemand wint hem.
  for v_ronde in
    select r.id from public.pk_rounds r
     where r.settled_at is null
       and exists (select 1 from public.pk_seats s
                    where s.round_id = r.id and s.user_id = p_uid)
  loop
    update public.pk_seats s
       set stack = s.stack + s.total_bet, total_bet = 0, bet = 0
     where s.round_id = v_ronde;

    -- Op de lobby van DEZE ronde, niet op elke tafel waar deze speler toevallig zit.
    -- Zonder die grens overschreef een reset aan de ene tafel zijn stapel aan de andere.
    --
    -- En niet op een stoel die al verlaten is. Wie tijdens de hand is opgestaan heeft geen
    -- stapel aan tafel meer -- of een verse, als hij opnieuw is aangeschoven. Die
    -- overschrijven met wat er op de oude stoel lag, maakte zijn inkoop stuk.
    update public.pk_players pl set stack = s.stack
      from public.pk_seats s, public.pk_rounds rd
     where rd.id = v_ronde and s.round_id = v_ronde
       and s.user_id = pl.user_id and pl.lobby_id = rd.lobby_id
       and not s.left_table;

    -- Wie is opgestaan krijgt zijn inzet op zijn saldo. Hij zit niet meer aan tafel, dus
    -- de regel hierboven ziet hem niet -- en zonder dit was zijn inzet weg. Dezelfde tak
    -- als in pk_settle, en om dezelfde reden.
    --
    -- Behalve voor DEGENE om wie deze reset draait. Zijn saldo gaat zo meteen toch op
    -- 1000: bijschrijven heeft geen zin, en het kan niet eens -- deze functie draait dan
    -- binnen de trigger op precies die rij, en Postgres weigert een rij twee keer in
    -- dezelfde opdracht bij te werken. Zijn fiches zijn met de sprintgrens weg, en dat is
    -- ook de bedoeling: niemand neemt iets mee naar de nieuwe sprint.
    update public.profiles p
       set balance = p.balance + s.stack
      from public.pk_seats s
     where s.round_id = v_ronde and s.left_table and s.stack > 0
       and p.id = s.user_id and s.user_id <> p_uid;

    update public.pk_seats s set stack = 0
     where s.round_id = v_ronde and s.left_table;

    update public.pk_rounds
       set settled_at = now(), street = 5, to_act_seat = null, act_deadline = null
     where id = v_ronde;

    -- En het zaadje weg. Een afgebroken hand is nooit uitgespeeld, dus er valt niets na te
    -- rekenen -- maar de kaarten van iedereen aan die tafel zitten er wel in. Zolang de rij
    -- bestaat is er iets te lekken; verwijderd is er niets meer te lekken.
    delete from poker.deck d where d.round_id = v_ronde;
  end loop;

  -- En dan alleen deze speler van tafel. De rest blijft zitten met zijn fiches.
  delete from public.pk_players p where p.user_id = p_uid;
end;
$$;

revoke all on function poker.void_all(uuid) from public, anon, authenticated;


-- ============================================================================
--  2 van 4 -- DE FUNCTIES   (sql/poker_rpc.sql)
-- ============================================================================

-- De functies van poker. Alles wat een speler kan doen loopt hier langs, en niets anders
-- raakt de tabellen aan. Draai dit ná sql/poker.sql.
--
-- Alle bedragen in centen, zodat er niets wegvalt in de afronding.

-- ---------- de handbeoordelaar ----------
-- Dezelfde regels als ODDS.pokerScore in crash.html, en getoetst met dezelfde gevallen:
-- zeven kaarten naar één getal waarmee twee handen tegen elkaar te leggen zijn. Een kaart
-- is 'As', 'Th', '2c' -- rang plus kleur, tien als T.
create or replace function public.pk_rank(c text)
returns int language sql immutable as $$
  select case left(c, 1)
    when 'A' then 14 when 'K' then 13 when 'Q' then 12 when 'J' then 11 when 'T' then 10
    else left(c, 1)::int end;
$$;

-- De hoogste straat in een rij rangen, of 0. Het aas telt aan beide kanten: als hoogste in
-- 10-J-Q-K-A en als laagste in A-2-3-4-5, en dan is de straat vijf-hoog.
create or replace function public.pk_straight(rangen int[])
returns int language plpgsql immutable as $$
declare
  heeft boolean[] := array_fill(false, array[15]);
  r int; hoog int; i int; alle boolean;
begin
  foreach r in array rangen loop
    heeft[r] := true;
    if r = 14 then heeft[1] := true; end if;
  end loop;
  for hoog in reverse 14..5 loop
    alle := true;
    for i in 0..4 loop
      if not heeft[hoog - i] then alle := false; exit; end if;
    end loop;
    if alle then return hoog; end if;
  end loop;
  return 0;
end;
$$;

-- Zeven kaarten naar één getal. Categorie maal 15^5, dan de tiebreakers.
create or replace function public.pk_score(kaarten text[])
returns bigint language plpgsql immutable as $$
declare
  rangen int[] := '{}';
  per_rang int[] := array_fill(0, array[15]);
  kleuren text[] := '{}';
  kleur_rangen int[] := '{}';
  k text; r int; i int; c int;
  groepen int[][];
  vier int := 0; drie int := 0; drie2 int := 0; paar1 int := 0; paar2 int := 0;
  sleutels int[] := '{0,0,0,0,0}';
  cat int := 0;
  sf int; st int;
  kickers int[] := '{}';
  waarde bigint := 0;
begin
  foreach k in array kaarten loop
    r := public.pk_rank(k);
    rangen := rangen || r;
    per_rang[r] := per_rang[r] + 1;
  end loop;

  -- Kleur: vijf of meer van één soort.
  foreach k in array kaarten loop
    if (select count(*) from unnest(kaarten) x where right(x, 1) = right(k, 1)) >= 5 then
      select array_agg(public.pk_rank(x) order by public.pk_rank(x) desc)
        into kleur_rangen from unnest(kaarten) x where right(x, 1) = right(k, 1);
      exit;
    end if;
  end loop;

  if array_length(kleur_rangen, 1) is not null then
    sf := public.pk_straight(kleur_rangen);
    if sf > 0 then
      cat := 8; sleutels := array[sf, 0, 0, 0, 0];
      waarde := cat;
      foreach i in array sleutels loop waarde := waarde * 15 + i; end loop;
      return waarde;
    end if;
  end if;

  -- De rangen op aantal, hoog eerst.
  for r in reverse 14..2 loop
    c := per_rang[r];
    if c = 4 then vier := r;
    elsif c = 3 then
      if drie = 0 then drie := r; else drie2 := r; end if;
    elsif c = 2 then
      if paar1 = 0 then paar1 := r; elsif paar2 = 0 then paar2 := r; end if;
    end if;
  end loop;

  if vier > 0 then
    select coalesce(max(x), 0) into i from unnest(rangen) x where x <> vier;
    cat := 7; sleutels := array[vier, i, 0, 0, 0];
  elsif drie > 0 and (drie2 > 0 or paar1 > 0) then
    cat := 6; sleutels := array[drie, greatest(drie2, paar1), 0, 0, 0];
  elsif array_length(kleur_rangen, 1) is not null then
    cat := 5;
    sleutels := array[kleur_rangen[1], kleur_rangen[2], kleur_rangen[3],
                      kleur_rangen[4], kleur_rangen[5]];
  else
    st := public.pk_straight(rangen);
    if st > 0 then
      cat := 4; sleutels := array[st, 0, 0, 0, 0];
    elsif drie > 0 then
      select array_agg(x order by x desc) into kickers
        from (select distinct unnest(rangen) x) q where x <> drie;
      cat := 3; sleutels := array[drie, coalesce(kickers[1], 0), coalesce(kickers[2], 0), 0, 0];
    elsif paar1 > 0 and paar2 > 0 then
      -- Drie paren kan met zeven kaarten: de twee hoogste tellen, en de hoogste kaart van
      -- de rest -- ook als dat de kaart van het derde paar is -- wordt de kicker.
      select coalesce(max(x), 0) into i from unnest(rangen) x where x <> paar1 and x <> paar2;
      cat := 2; sleutels := array[paar1, paar2, i, 0, 0];
    elsif paar1 > 0 then
      select array_agg(x order by x desc) into kickers
        from (select distinct unnest(rangen) x) q where x <> paar1;
      cat := 1; sleutels := array[paar1, coalesce(kickers[1], 0), coalesce(kickers[2], 0),
                                 coalesce(kickers[3], 0), 0];
    else
      select array_agg(x order by x desc) into kickers from (select distinct unnest(rangen) x) q;
      cat := 0; sleutels := array[kickers[1], kickers[2], kickers[3], kickers[4], kickers[5]];
    end if;
  end if;

  waarde := cat;
  foreach i in array sleutels loop waarde := waarde * 15 + coalesce(i, 0); end loop;
  return waarde;
end;
$$;

-- ---------- eerlijk delen ----------
-- De stok ligt vast voordat er gedeeld wordt. De hash gaat vooraf naar de spelers, het
-- zaadje pas als de hand is afgerekend -- dan kan iedereen naspelen dat er onderweg niet
-- is geschud. Dezelfde afspraak als bij crash en blackjack.
create or replace function poker.fresh_deck()
returns text[] language sql immutable set search_path = '' as $$
  select array_agg(r.v || s.v order by s.i, r.i)
    from unnest(array['s','h','d','c']) with ordinality as s(v, i),
         unnest(array['2','3','4','5','6','7','8','9','T','J','Q','K','A']) with ordinality as r(v, i);
$$;

-- pgcrypto staat op Supabase in het schema `extensions` en op een kale Postgres meestal in
-- `public`. De functies hieronder draaien met `search_path = ''` -- dat hoort zo, want een
-- definer-functie met een te kapen zoekpad voert iets anders uit dan je denkt -- en dan
-- moet elke naam volledig gekwalificeerd zijn. Dus wordt hier één keer opgezocht waar
-- `digest` staat, en daar wijst poker.sha256 naar.
do $$
declare v_schema text;
begin
  select n.nspname into v_schema
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where p.proname = 'digest' and pg_get_function_identity_arguments(p.oid) = 'text, text'
   limit 1;
  if v_schema is null then
    raise exception 'pgcrypto is niet geinstalleerd: create extension pgcrypto;';
  end if;
  execute format($f$
    create or replace function poker.sha256(p text)
    returns bytea language sql immutable set search_path = '' as
    $b$ select %I.digest(p, 'sha256') $b$;
  $f$, v_schema);
end $$;

-- Fisher-Yates, gestuurd door het zaadje. Zelfde zaadje, zelfde stok.
create or replace function poker.shuffle(p_seed text)
returns text[] language plpgsql immutable set search_path = '' as $$
declare
  kaarten text[] := poker.fresh_deck();
  n int := array_length(kaarten, 1);
  i int; j int; tmp text; h bytea;
begin
  for i in reverse n..2 loop
    -- Voor elke stap een eigen hash van zaadje plus positie: zo hangt elke trekking aan
    -- het zaadje en is de hele stok uit dat ene getal na te rekenen.
    h := poker.sha256(p_seed || ':' || i::text);
    j := 1 + (('x' || encode(substring(h from 1 for 4), 'hex'))::bit(32)::bigint
              & 2147483647) % i;
    tmp := kaarten[i]; kaarten[i] := kaarten[j]; kaarten[j] := tmp;
  end loop;
  return kaarten;
end;
$$;

-- ---------- aan tafel gaan ----------
-- Fiches komen uit je saldo en gaan er weer heen. Ze worden nergens gemaakt.
create or replace function public.pk_sit(p_buyin integer)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_lobby bigint;
  v_naam text;
  v_saldo numeric;
  v_koop integer;
  v_stoel smallint;
  v_zat integer;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  select l.lobby_id into v_lobby from public.my_lobby l limit 1;
  if v_lobby is null then raise exception 'join a table first'; end if;

  -- Eén tafel tegelijk, net als in pk_tick en pk_leave: aanschuiven raakt dezelfde rijen
  -- als het opruimen en het delen.
  perform pg_advisory_xact_lock(v_lobby);

  -- Eerst de sprintgrens, dan pas geld aanraken.
  --
  -- Op profiles zit een trigger die een achterstallig account terugzet naar 1000 zodra er
  -- iets naar die rij geschreven wordt. Deed je dat hier niet expliciet, dan gebeurde het
  -- alsnog -- maar midden in `balance = balance - inkoop`, en dan gooit de trigger die
  -- aftrek weg en zet er 1000 neer. De fiches werden daarna toch op tafel gezet: gratis
  -- inkopen, elke sprintgrens opnieuw. Een lege update laat de trigger zijn werk doen
  -- voordat er iets te rekenen valt; is er niets achterstallig, dan verandert er niets.
  update public.profiles set balance = balance where id = v_uid;

  -- Zit je er al? Dan mag je alleen bijkopen als je blut bent. Anders stond je vast: een
  -- speler die zijn stapel kwijt is heeft een rij met nul fiches, pk_tick deelt hem geen
  -- kaarten meer, en opstaan-en-weer-zitten was de enige uitweg. Bijkopen met fiches nog
  -- op tafel mag niet -- dat is midden in het spel je stapel vergroten.
  select pl.stack into v_zat from public.pk_players pl
   where pl.lobby_id = v_lobby and pl.user_id = v_uid for update;
  if v_zat is not null and v_zat > 0 then
    raise exception 'already seated';
  end if;
  if v_zat is not null and exists (
       select 1 from public.pk_rounds r
        join public.pk_seats st on st.round_id = r.id
       where r.lobby_id = v_lobby and r.settled_at is null and st.user_id = v_uid) then
    raise exception 'wait for the hand to finish';
  end if;

  -- De inkoop ligt tussen honderd en vijfhonderd: met een startsaldo van 1000 kan niemand
  -- zijn hele hebben en houden op één tafel zetten, en een tafel loopt niet leeg omdat er
  -- iemand met tien dollar aanschuift.
  v_koop := greatest(100, least(500, coalesce(p_buyin, 200)));

  select p.balance, p.username into v_saldo, v_naam
    from public.profiles p where p.id = v_uid for update;
  if v_saldo is null then raise exception 'no profile'; end if;
  if v_saldo < v_koop then raise exception 'not enough money'; end if;

  if v_zat is not null then
    -- Bijkopen: dezelfde stoel, alleen fiches erbij. Zo verschuift niemand aan tafel en
    -- houdt de knop zijn plek.
    update public.profiles set balance = balance - v_koop where id = v_uid;
    update public.pk_players set stack = v_koop
     where lobby_id = v_lobby and user_id = v_uid
    returning seat_no into v_stoel;
  else
    -- De laagste vrije stoel.
    -- Geen coalesce: min() over niets is null, en dat is precies hoe je weet dat de tafel
    -- vol zit. Met een coalesce naar nul werd de zevende speler op stoel nul gezet.
    select min(x) into v_stoel
      from generate_series(0, 5) x
     where not exists (select 1 from public.pk_players q
                        where q.lobby_id = v_lobby and q.seat_no = x);
    if v_stoel is null then raise exception 'table is full'; end if;

    update public.profiles set balance = balance - v_koop where id = v_uid;
    insert into public.pk_players (lobby_id, user_id, username, seat_no, stack)
         values (v_lobby, v_uid, v_naam, v_stoel, v_koop);
  end if;

  -- In het grootboek, zodat na te rekenen is wat poker met je saldo heeft gedaan. Zie
  -- sql/poker_ledger.sql; zonder dat bestand slaat dit stil over.
  if to_regprocedure('poker.note(uuid, text, bigint, text, integer)') is not null then
    execute 'select poker.note($1, $2, $3, $4, $5)' using
      v_uid, v_naam, v_lobby, case when v_zat is null then 'sit' else 'rebuy' end, -v_koop;
  end if;

  return json_build_object('ok', true, 'seat', v_stoel, 'stack', v_koop,
                           'balance', v_saldo - v_koop);
end;
$$;

revoke all on function public.pk_sit(integer) from public, anon;
grant execute on function public.pk_sit(integer) to authenticated;

-- ---------- opstaan ----------
create or replace function public.pk_leave()
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_lobby bigint;
  v_stack integer;
  v_stoelstack integer;
  v_ronde bigint;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  -- Eerst kijken AAN WELKE TAFEL je zit, zonder iets vast te houden.
  select p.lobby_id into v_lobby from public.pk_players p where p.user_id = v_uid;
  if v_lobby is null then return json_build_object('ok', true, 'stack', 0); end if;

  -- Dan het tafelslot, en pas daarna het rijslot. Die volgorde is niet vrijblijvend:
  -- pk_tick en pk_sit nemen ze ook zo, en wie ze andersom pakt loopt vast zodra allebei
  -- tegelijk beginnen -- de een houdt de rij en wacht op de tafel, de ander houdt de tafel
  -- en wacht op de rij. Postgres schiet er dan een dood met een deadlock.
  --
  -- Het slot zelf is hier nodig omdat opstaan anders tegelijk kon lopen met het opruimen
  -- in pk_tick: allebei lazen ze dezelfde stapel en allebei schreven ze hem op het saldo.
  -- Je inkoop kwam dan dubbel terug, en dat was te herhalen zo vaak je wilde.
  perform pg_advisory_xact_lock(v_lobby);

  -- En nu pas vastpakken. Tussen de twee regels kan iemand je van tafel hebben gehaald,
  -- dus de lobby wordt hier opnieuw gelezen in plaats van aangenomen.
  select p.lobby_id, p.stack into v_lobby, v_stack
    from public.pk_players p where p.user_id = v_uid for update;
  if v_lobby is null then return json_build_object('ok', true, 'stack', 0); end if;

  -- Zit je midden in een hand, dan pas je eerst. Je inzet blijft in de pot staan -- dat is
  -- geld dat je al hebt ingelegd, en weglopen mag dat niet ongedaan maken.
  select r.id into v_ronde from public.pk_rounds r
    where r.lobby_id = v_lobby and r.settled_at is null order by r.id desc limit 1;
  if v_ronde is not null then
    -- LEZEN VOOR SCHRIJVEN. Hieronder wordt left_table gezet, en daar filtert deze regel
    -- op -- andersom vindt hij zijn eigen stoel niet meer terug, valt de uitbetaling terug
    -- op pk_players.stack (de stand van vóór je inzetten) en maakt dat fiches.
    --
    -- Het filter zelf is nodig omdat je al eerder deze hand opgestaan kunt zijn en daarna
    -- opnieuw aangeschoven. Die oude stoel staat er dan nog, met nul fiches op. Die als
    -- waarheid nemen liet je verse inkoop verdwijnen: opstaan gaf $0 terug.
    --
    -- Geeft dit null, dan heb je geen stoel in deze hand -- je schoof aan terwijl er al
    -- gedeeld was en wacht op de volgende. Dan is pk_players.stack juist wél de goede
    -- stand, want je hebt nog niets ingezet.
    select s.stack into v_stoelstack from public.pk_seats s
      where s.round_id = v_ronde and s.user_id = v_uid and not s.left_table;

    -- Passen, maar NIET als je all-in staat. Wie al zijn fiches in de pot heeft, heeft
    -- niets meer te beslissen: die hand speelt zichzelf uit en hij hoort mee te doen aan
    -- de showdown. Hem laten passen omdat hij opstaat gaf zijn pot aan de anderen.
    --
    -- `left_table` erbij zodat de afrekening weet dat er geen stoel aan tafel meer is om
    -- de uitbetaling op te zetten, en de stapel op nul: die fiches gaan naar het saldo.
    update public.pk_seats s
       set folded = (case when s.allin then s.folded else true end),
           acted = true,
           left_table = true,
           stack = 0
     where s.round_id = v_ronde and s.user_id = v_uid and not s.left_table;

    if v_stoelstack is not null then v_stack := v_stoelstack; end if;
  end if;

  -- En wat er ook misgaat, hier staat nooit null. Het grootboek weigert dat terecht, en
  -- dan kwam je met een rauwe databasefout niet meer van tafel.
  v_stack := coalesce(v_stack, 0);

  -- Alleen de stoel aan DEZE tafel. Zonder dat filter haalt opstaan je overal weg terwijl
  -- er maar één stapel wordt uitbetaald.
  delete from public.pk_players where user_id = v_uid and lobby_id = v_lobby;
  update public.profiles set balance = balance + coalesce(v_stack, 0) where id = v_uid;

  if to_regprocedure('poker.note(uuid, text, bigint, text, integer)') is not null then
    execute 'select poker.note($1, $2, $3, $4, $5)' using
      v_uid, (select username from public.profiles where id = v_uid), v_lobby, 'leave', v_stack;
  end if;

  return json_build_object('ok', true, 'stack', v_stack);
end;
$$;

revoke all on function public.pk_leave() from public, anon;
grant execute on function public.pk_leave() to authenticated;

-- ---------- een zet doen ----------
-- Dit is de grendel. De browser stuurt één getal in het hele spel: het totaal waar je deze
-- straat naartoe verhoogt. Dat getal zit aan twee kanten vast in de stand op de server, en
-- alles eromheen -- of je aan de beurt bent, of je al gezet hebt, wat je nog hebt -- komt
-- uit de tabellen en niet uit wat de browser beweert.
--
-- `p_seq` is het volgnummer van de zet die de speler dénkt te doen. Stuurt een tweede tab
-- dezelfde zet nog een keer, dan klopt dat nummer niet meer en gebeurt er niets.
create or replace function public.pk_act(p_round bigint, p_seq integer, p_move text, p_to integer default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  r public.pk_rounds%rowtype;
  s public.pk_seats%rowtype;
  v_tegaan integer;
  v_doel integer;
  v_bij integer;
  v_vol boolean;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  select * into r from public.pk_rounds where id = p_round for update;
  if r.id is null then raise exception 'no such hand'; end if;
  if r.settled_at is not null then raise exception 'hand is over'; end if;
  if r.act_seq <> p_seq then raise exception 'too late'; end if;

  select * into s from public.pk_seats
   where round_id = p_round and user_id = v_uid for update;
  if s.round_id is null then raise exception 'not in this hand'; end if;
  if r.to_act_seat is distinct from s.seat_no then raise exception 'not your turn'; end if;
  if s.folded or s.allin then raise exception 'you are out of this hand'; end if;

  v_tegaan := greatest(0, r.high_bet - s.bet);

  if p_move = 'fold' then
    update public.pk_seats set folded = true, acted = true
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'check' then
    if v_tegaan > 0 then raise exception 'cannot check'; end if;
    update public.pk_seats set acted = true
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'call' then
    if v_tegaan <= 0 then raise exception 'nothing to call'; end if;
    v_bij := least(v_tegaan, s.stack);
    update public.pk_seats
       set stack = stack - v_bij, bet = bet + v_bij, total_bet = total_bet + v_bij,
           acted = true, allin = (stack - v_bij) = 0
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'raise' then
    if not s.may_raise then raise exception 'cannot raise again'; end if;
    v_doel := coalesce(p_to, 0);
    if v_doel > s.bet + s.stack then raise exception 'more than you have'; end if;
    if v_doel <= r.high_bet then raise exception 'raise too small'; end if;
    -- Onder het minimum mag alleen als het alles is wat je hebt.
    if v_doel < r.high_bet + r.min_raise and v_doel <> s.bet + s.stack then
      raise exception 'raise too small';
    end if;
    v_bij := v_doel - s.bet;
    v_vol := (v_doel - r.high_bet) >= r.min_raise;

    update public.pk_seats
       set stack = stack - v_bij, bet = v_doel, total_bet = total_bet + v_bij,
           acted = true, allin = (stack - v_bij) = 0
     where round_id = p_round and seat_no = s.seat_no;

    if v_vol then
      -- Een volle verhoging heropent de ronde: iedereen mag weer reageren en weer verhogen.
      update public.pk_rounds set min_raise = v_doel - r.high_bet, high_bet = v_doel
       where id = p_round;
      update public.pk_seats set acted = false, may_raise = true
       where round_id = p_round and seat_no <> s.seat_no and not folded and not allin;
    else
      -- Een korte all-in verhoogt de inzet wel, maar wie al gezet had mag alleen nog het
      -- verschil bijleggen -- niet opnieuw verhogen op een minimum dat hierop gebouwd is.
      --
      -- In ÉÉN opdracht, en dat is geen stijlkeuze. Er stonden hier twee updates: eerst
      -- `acted = false` voor iedereen, daarna `may_raise = false where ... and acted`.
      -- Maar `acted` was op dat moment net op false gezet, dus die tweede raakte niemand
      -- en heropende de korte all-in het bieden alsnog -- precies wat hij moest voorkomen.
      update public.pk_rounds set high_bet = v_doel where id = p_round;
      update public.pk_seats
         set may_raise = not acted,   -- wie nog niet gezet had mag straks gewoon verhogen
             acted = false
       where round_id = p_round and seat_no <> s.seat_no and not folded and not allin;
    end if;

  else
    raise exception 'unknown move';
  end if;

  update public.pk_rounds set act_seq = act_seq + 1 where id = p_round;
  perform public.pk_advance(p_round);
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.pk_act(bigint, integer, text, integer) from public, anon;
grant execute on function public.pk_act(bigint, integer, text, integer) to authenticated;

-- ---------- de hand vooruit ----------
-- Wie is er hierna? De eerste die nog kan en nog moet: niet gepast, niet all-in, en of nog
-- niet gezet of nog niet op de hoogste inzet.
create or replace function public.pk_next_seat(p_round bigint, p_vanaf smallint)
returns smallint language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  d int; i smallint; s public.pk_seats%rowtype;
  n int;
begin
  select * into r from public.pk_rounds where id = p_round;
  select count(*) into n from public.pk_seats where round_id = p_round;
  for d in 1..n loop
    i := ((p_vanaf + d) % n)::smallint;
    select * into s from public.pk_seats where round_id = p_round and seat_no = i;
    if s.seat_no is null or s.folded or s.allin or s.stack <= 0 then continue; end if;
    if not s.acted or s.bet <> r.high_bet then return i; end if;
  end loop;
  return null;
end;
$$;

-- De hand een stap verder: volgende speler, volgende straat, of afrekenen.
create or replace function public.pk_advance(p_round bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_levend int;
  v_kunnen int;
  v_volgende smallint;
  v_kaarten text[];
  v_gedeeld int;
begin
  select * into r from public.pk_rounds where id = p_round for update;
  if r.settled_at is not null then return; end if;

  select count(*) into v_levend from public.pk_seats where round_id = p_round and not folded;
  -- Iedereen op één na gepast: die krijgt de pot, zonder te hoeven laten zien.
  if v_levend <= 1 then
    perform public.pk_settle(p_round);
    return;
  end if;

  v_volgende := public.pk_next_seat(p_round, coalesce(r.to_act_seat, r.button_seat));
  if v_volgende is not null then
    update public.pk_rounds
       set to_act_seat = v_volgende, act_deadline = now() + interval '25 seconds'
     where id = p_round;
    return;
  end if;

  -- De straat is dicht. Inzetten van deze straat gaan in de pot (total_bet houdt ze bij),
  -- en dan de volgende kaarten.
  update public.pk_seats set bet = 0, acted = false, may_raise = true
   where round_id = p_round;
  update public.pk_rounds set high_bet = 0, min_raise = bb where id = p_round;

  if r.street >= 3 then
    perform public.pk_settle(p_round);
    return;
  end if;

  select d.cards into v_kaarten from poker.deck d where d.round_id = p_round;
  -- De eerste kaarten van de stok zijn voor de spelers: twee per stoel.
  select count(*) * 2 into v_gedeeld from public.pk_seats where round_id = p_round;

  update public.pk_rounds
     set street = r.street + 1,
         board = case r.street
                   when 0 then v_kaarten[v_gedeeld + 1 : v_gedeeld + 3]
                   when 1 then r.board || v_kaarten[v_gedeeld + 4]
                   else r.board || v_kaarten[v_gedeeld + 5]
                 end
   where id = p_round;

  -- Is er hooguit één speler die nog fiches heeft om mee te zetten, dan valt er niets meer
  -- te bieden: het bord loopt uit en de hand gaat naar de showdown. pk_settle legt de rest
  -- van de kaarten zelf neer.
  --
  -- Deze controle stond eerst ONDER het bepalen van de volgende speler, en dan wacht de
  -- tafel op iemand die niets meer kan doen.
  select count(*) into v_kunnen from public.pk_seats
   where round_id = p_round and not folded and not allin and stack > 0;
  if v_kunnen <= 1 then
    perform public.pk_settle(p_round);
    return;
  end if;

  update public.pk_rounds
     set to_act_seat = public.pk_next_seat(p_round, r.button_seat),
         act_deadline = now() + interval '25 seconds'
   where id = p_round;
end;
$$;

-- ---------- afrekenen ----------
-- De pot verdelen, met zijpotten. Dezelfde rekensom als ODDS.pokerPots in crash.html:
-- iedereen speelt alleen om het geld dat hij zelf heeft kunnen matchen.
create or replace function public.pk_settle(p_round bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_niveau int;
  v_vorig int := 0;
  v_pot int;
  v_beste bigint;
  v_winnaars smallint[];
  v_ieder int;
  v_rest int;
  v_board text[];
  v_kaarten text[];
  w smallint;
  v_eerste smallint;
  v_n int;
begin
  select * into r from public.pk_rounds where id = p_round for update;
  if r.settled_at is not null then return; end if;

  select count(*) into v_n from public.pk_seats where round_id = p_round;
  v_board := r.board;

  -- De rest van het bord moet er liggen voordat er vergeleken wordt: als iedereen all-in
  -- ging op de flop, komen turn en river er alsnog.
  select d.cards into v_kaarten from poker.deck d where d.round_id = p_round;
  if (select count(*) from public.pk_seats where round_id = p_round and not folded) > 1 then
    while array_length(v_board, 1) is null or array_length(v_board, 1) < 5 loop
      v_board := coalesce(v_board, '{}'::text[]) ||
                 v_kaarten[v_n * 2 + coalesce(array_length(v_board, 1), 0) + 1];
    end loop;
  end if;

  -- De kaarten van wie nog meedoet gaan open, en krijgen hun score.
  update public.pk_seats s
     set shown = true,
         hole = (select h.cards from poker.hole h
                  where h.round_id = p_round and h.seat_no = s.seat_no)
   where s.round_id = p_round and not s.folded
     and (select count(*) from public.pk_seats q where q.round_id = p_round and not q.folded) > 1;

  -- Elk verschillend inzetbedrag is een laag.
  v_eerste := ((r.button_seat + 1) % v_n)::smallint;
  for v_niveau in
    select distinct total_bet from public.pk_seats
     where round_id = p_round and total_bet > 0 order by 1
  loop
    select sum(least(total_bet, v_niveau) - least(total_bet, v_vorig)) into v_pot
      from public.pk_seats where round_id = p_round;

    if v_pot > 0 then
      select max(public.pk_score(
               (select h.cards from poker.hole h
                 where h.round_id = p_round and h.seat_no = s.seat_no) || v_board))
        into v_beste
        from public.pk_seats s
       where s.round_id = p_round and not s.folded and s.total_bet >= v_niveau;

      if v_beste is null then
        -- Iedereen die om deze laag speelde is gepast. Dan gaat hij terug naar wie hem
        -- volstortte, NAAR RATO -- niet in zijn geheel naar de grootste inlegger. Dat
        -- laatste stond er, en dan kreeg één speler geld terug dat van een ander was.
        update public.pk_seats s
           set payout = s.payout
                      + (least(s.total_bet, v_niveau) - least(s.total_bet, v_vorig))
         where s.round_id = p_round;
      else
        select array_agg(s.seat_no order by ((s.seat_no - v_eerste + v_n) % v_n))
          into v_winnaars
          from public.pk_seats s
         where s.round_id = p_round and not s.folded and s.total_bet >= v_niveau
           and public.pk_score(
                 (select h.cards from poker.hole h
                   where h.round_id = p_round and h.seat_no = s.seat_no) || v_board) = v_beste;

        v_ieder := v_pot / array_length(v_winnaars, 1);
        v_rest := v_pot - v_ieder * array_length(v_winnaars, 1);
        -- De oneven fiches gaan naar links van de knop, zoals aan een echte tafel.
        foreach w in array v_winnaars loop
          update public.pk_seats
             set payout = payout + v_ieder + (case when v_rest > 0 then 1 else 0 end)
           where round_id = p_round and seat_no = w;
          if v_rest > 0 then v_rest := v_rest - 1; end if;
        end loop;
      end if;
    end if;
    v_vorig := v_niveau;
  end loop;

  -- De uitbetaling gaat naar de stapel, niet naar het saldo: je blijft aan tafel zitten.
  --
  -- Let op wat hier de waarheid is. `pk_seats.stack` is wat er ná deze hand nog voor je
  -- ligt: daar zijn de blinds, de calls en de verhogingen al van af. `pk_players.stack`
  -- stond nog op de stand van vóór de hand. Er stond hier eerst `pk_players.stack + payout`
  -- en dat maakte fiches: alles wat je tijdens de hand had ingelegd kwam er zo weer bij.
  update public.pk_players pl
     set stack = s.stack + s.payout
    from public.pk_seats s
   where s.round_id = p_round and s.user_id = pl.user_id
     and pl.lobby_id = r.lobby_id
     and not s.left_table;

  -- En wie tijdens de hand is opgestaan, heeft geen stapel aan tafel meer. Zijn stoel kan
  -- nog steeds geld krijgen: een inzet die niemand heeft gecalld komt terug, en wie all-in
  -- ging en daarna opstond kan de hand gewoon winnen. Zonder deze regel landde dat nergens
  -- -- de join hierboven vond geen rij, en het geld was uit het spel weg.
  --
  -- Het gaat naar het saldo, want aan tafel zit hij niet meer. sprint_may_pay houdt tegen
  -- dat een hand van vóór zijn sprintgrens alsnog op de verse duizend landt; bestaat die
  -- functie niet, dan wordt er gewoon uitbetaald.
  --
  -- De twee takken zijn bijna gelijk, en dat is met opzet: PL/pgSQL leest een opdracht pas
  -- in als hij hem voor het eerst uitvoert, dus de tak met sprint_may_pay erin struikelt
  -- niet over een functie die er niet is zolang die tak niet gedraaid wordt. Eén opdracht
  -- met `to_regprocedure(...) is null or public.sprint_may_pay(...)` erin zou dat wel doen.
  if to_regprocedure('public.sprint_may_pay(uuid, timestamptz)') is not null then
    update public.profiles p
       set balance = p.balance + s.payout
      from public.pk_seats s
     where s.round_id = p_round and s.left_table and s.payout > 0
       and p.id = s.user_id
       and public.sprint_may_pay(s.user_id, r.started_at);
  else
    update public.profiles p
       set balance = p.balance + s.payout
      from public.pk_seats s
     where s.round_id = p_round and s.left_table and s.payout > 0
       and p.id = s.user_id;
  end if;

  -- En de zouten afkappen op wat er echt ligt. pk_live geeft ze toch al niet verder vrij,
  -- maar wat er niet staat kan ook niet alsnog uitlekken -- en de hash van de kaarten die
  -- NIET gevallen zijn, staat wel voor altijd openbaar in board_commit.
  update public.pk_rounds
     set settled_at = now(), street = 5, to_act_seat = null, act_deadline = null,
         board = v_board,
         board_salt = board_salt[1:coalesce(array_length(v_board, 1), 0)]
   where id = p_round;

  -- En het zaadje weg. De hand is uitgespeeld: wat open moest gaan staat in pk_seats.hole,
  -- het bord in pk_rounds.board met zijn eigen zout ernaast. Wat er nog zou blijven staan
  -- is de hele geschudde stok van deze hand, inclusief de kaarten van wie heeft gepast --
  -- voor altijd, in elke back-up en elke supportvraag. Daar was het juist om begonnen.
  delete from poker.deck d where d.round_id = p_round;
end;
$$;

revoke all on function public.pk_advance(bigint) from public, anon, authenticated;
revoke all on function public.pk_settle(bigint) from public, anon, authenticated;
revoke all on function public.pk_next_seat(bigint, smallint) from public, anon, authenticated;

-- ---------- de klok ----------
-- Elke browser mag dit porren: wie als eerste merkt dat er gedeeld of afgerekend moet
-- worden, vraagt het aan, en de server doet het één keer. Er zit geen controle op of de
-- aanroeper aan tafel zit, met opzet -- anders kan een vastgelopen tafel door niemand meer
-- losgemaakt worden. Er valt ook niets mee te winnen: alles wat hier gebeurt hangt aan
-- now() en aan de stand, niet aan wie het vraagt.
create or replace function public.pk_tick(p_lobby bigint)
returns json language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_spelers int;
  v_zaad text;
  v_commit text;
  v_kaarten text[];
  v_ronde bigint;
  v_knop smallint;
  v_i int := 0;
  p record;
  v_sb smallint; v_bb smallint;
  v_zout text;
  w record;
  v_stoelen smallint[];
  v_knop_tafel int;
  v_terug integer;
begin
  -- Eén tafel tegelijk. Twee browsers die op hetzelfde moment porren zagen allebei geen
  -- lopende hand en deelden er allebei een; op de tijdklok sloegen ze samen een beurt over.
  -- Dit slot geldt tot het einde van de transactie, dus alle porren voor één tafel staan
  -- netjes in de rij.
  perform pg_advisory_xact_lock(p_lobby);

  select * into r from public.pk_rounds
   where lobby_id = p_lobby and settled_at is null order by id desc limit 1 for update;

  -- Loopt er een hand? Dan alleen kijken of iemand te lang nadenkt.
  if r.id is not null then
    if r.act_deadline is not null and now() > r.act_deadline and r.to_act_seat is not null then
      -- Wie zijn tijd laat verlopen checkt als dat gratis is, en past anders. Zo blijft een
      -- tafel niet staan omdat iemand zijn tab dichtgooit, en verliest niemand zijn inzet
      -- door een haperende verbinding als er niets te betalen viel.
      if (select s.bet from public.pk_seats s
           where s.round_id = r.id and s.seat_no = r.to_act_seat) = r.high_bet then
        update public.pk_seats set acted = true
         where round_id = r.id and seat_no = r.to_act_seat;
      else
        update public.pk_seats set folded = true, acted = true
         where round_id = r.id and seat_no = r.to_act_seat;
      end if;
      update public.pk_rounds set act_seq = act_seq + 1 where id = r.id;
      perform public.pk_advance(r.id);
    end if;
    return json_build_object('ok', true, 'round', r.id);
  end if;

  -- Geen hand. Eerst opruimen: wie de lobby heeft verlaten zonder op te staan, laat een
  -- rij achter aan een tafel waar hij niet meer bij hoort, met zijn fiches erop. De pagina
  -- staat nu eerst op voordat ze weggaat, maar een dichtgeslagen tab doet dat niet.
  --
  -- Dit staat met opzet tussen de handen door: midden in een hand iemand van tafel halen
  -- zou de pot scheef trekken. En het hele blok is afgeschermd -- vindt het de ledentabel
  -- niet, of ziet die er anders uit dan hier verwacht, dan slaat het over. Een tafel die
  -- vastloopt omdat het opruimen struikelt is erger dan een rij die blijft staan.
  begin
    if (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'lobby_members'
           and column_name in ('lobby_id', 'user_id')) = 2 then
      for w in
        -- En één grendel erbij: alleen opruimen als er voor DEZE lobby uberhaupt leden
        -- in die tabel staan. Staat hij leeg, dan wordt het lidmaatschap ergens anders
        -- bijgehouden en betekent "staat er niet in" niet "hoort er niet bij" -- dan zou
        -- dit de hele tafel leegvegen in plaats van één achterblijver.
        execute 'select pl.user_id, pl.stack from public.pk_players pl'
             || ' where pl.lobby_id = $1'
             || '   and exists (select 1 from public.lobby_members m2'
             || '                where m2.lobby_id = pl.lobby_id)'
             || '   and not exists ('
             || '   select 1 from public.lobby_members m'
             || '    where m.lobby_id = pl.lobby_id and m.user_id = pl.user_id)'
        using p_lobby
      loop
        -- Eerst weghalen, dan pas uitbetalen, en alleen wat de delete echt heeft
        -- weggehaald. Andersom betaalde het opruimen ook uit als iemand anders die rij
        -- net had opgeruimd -- fiches uit het niets. Nu levert een tweede poging niets op.
        delete from public.pk_players pl
         where pl.lobby_id = p_lobby and pl.user_id = w.user_id
        returning pl.stack into v_terug;
        if v_terug is not null then
          update public.profiles set balance = balance + v_terug where id = w.user_id;
          v_terug := null;
        end if;
      end loop;
    end if;
  -- Alleen opvangen waar dit blok voor bedoeld is: een ledentabel die er niet is of er
  -- anders uitziet. `when others` ving ook een deadlock op, en dan meldde pk_tick gewoon
  -- succes terwijl er niets was opgeruimd en er nergens iets over stond.
  exception when undefined_table or undefined_column then null;
  end;

  -- Kan er een hand beginnen? Wie geen fiches meer heeft doet niet mee.
  select count(*) into v_spelers from public.pk_players
   where lobby_id = p_lobby and stack > 0;
  if v_spelers < 2 then return json_build_object('ok', true, 'round', null); end if;

  -- De knop schuift een stoel op ten opzichte van de VORIGE hand -- niet ten opzichte van
  -- de hoogste die er ooit was. Met een max blijft hij hangen zodra hij één keer op de
  -- laatste stoel heeft gestaan, en dan post dezelfde speler elke hand de blind.
  --
  -- En hij hangt aan de stoel AAN TAFEL, niet aan het nummer binnen de hand. Die twee zijn
  -- niet hetzelfde: de hand hernummert elke keer opnieuw van nul af, op volgorde van de
  -- tafelstoelen van wie er fiches heeft. Schuift er iemand aan op een lagere tafelstoel,
  -- dan schuift iedereen daarachter een plek op en wijst hetzelfde rondenummer opeens een
  -- andere speler aan -- dezelfde twee posten twee handen achter elkaar de blinds, en de
  -- nieuwkomer krijgt de knop zonder ooit betaald te hebben. Van tafel gaan deed hetzelfde
  -- in de andere richting.
  --
  -- Dus: pak de tafelstoelen van wie meedoet, op volgorde, en zoek de eerste die ECHT na
  -- de vorige knop komt. Is er geen, dan ronddraaien naar de laagste.
  select array_agg(pl.seat_no order by pl.seat_no) into v_stoelen
    from public.pk_players pl where pl.lobby_id = p_lobby and pl.stack > 0;

  select coalesce((select r2.button_lobby_seat from public.pk_rounds r2
                    where r2.lobby_id = p_lobby and r2.button_lobby_seat is not null
                    order by r2.id desc limit 1), -1)
    into v_knop_tafel;

  v_knop := 0;
  for v_i in 1 .. array_length(v_stoelen, 1) loop
    if v_stoelen[v_i] > v_knop_tafel then v_knop := v_i - 1; exit; end if;
  end loop;
  v_knop_tafel := v_stoelen[v_knop + 1];
  v_i := 0;

  v_zaad := encode(poker.sha256(gen_random_uuid()::text || clock_timestamp()::text), 'hex');
  v_commit := encode(poker.sha256('commit:' || v_zaad), 'hex');
  v_kaarten := poker.shuffle(v_zaad);

  select coalesce(max(sb), 5), coalesce(max(bb), 10) into v_sb, v_bb
    from public.pk_rounds where lobby_id = p_lobby;

  insert into public.pk_rounds (lobby_id, deck_commit, button_seat, button_lobby_seat,
                                sb, bb, min_raise, street)
       values (p_lobby, v_commit, v_knop::smallint, v_knop_tafel::smallint,
               v_sb, v_bb, v_bb, 0)
    returning id into v_ronde;

  insert into poker.deck (round_id, seed, cards) values (v_ronde, v_zaad, v_kaarten);

  -- De stoelen, op volgorde, met hun kaarten. De kaarten gaan naar het andere schema; wat
  -- hier blijft staan is een gezouten hash, zodat elke speler zijn eigen hand meteen kan
  -- narekenen zonder dat iemand anders iets te zien krijgt.
  for p in select * from public.pk_players
            where lobby_id = p_lobby and stack > 0 order by seat_no loop
    v_zout := encode(poker.sha256(v_zaad || ':zout:' || v_i::text), 'hex');
    insert into public.pk_seats (round_id, seat_no, user_id, username, stack, card_commit)
         values (v_ronde, v_i::smallint, p.user_id, p.username, p.stack,
                 encode(poker.sha256(v_zout || ':' ||
                        v_kaarten[v_i * 2 + 1] || v_kaarten[v_i * 2 + 2]), 'hex'));
    insert into poker.hole (round_id, seat_no, player, cards, salt)
         values (v_ronde, v_i::smallint, p.user_id,
                 array[v_kaarten[v_i * 2 + 1], v_kaarten[v_i * 2 + 2]], v_zout);
    v_i := v_i + 1;
  end loop;

  -- Het bord vastleggen. De vijf gemeenschappelijke kaarten liggen op vaste plekken in de
  -- stok -- meteen na de holekaarten -- dus ze zijn hier al bekend, lang voordat ze vallen.
  -- Publiceer er nu een hash van; het zout komt pas vrij bij het afrekenen. Daarmee is
  -- achteraf na te rekenen dat de flop, turn en river zijn wat ze bij het delen al waren,
  -- zonder dat er iets over iemands holekaarten uit lekt.
  declare
    v_zouten text[] := '{}';
    v_commits text[] := '{}';
    v_k int;
    v_z text;
  begin
    for v_k in 1 .. 5 loop
      v_z := encode(poker.sha256(v_zaad || ':bord:' || v_k::text), 'hex');
      v_zouten := v_zouten || v_z;
      v_commits := v_commits ||
        encode(poker.sha256(v_z || ':' || v_kaarten[v_i * 2 + v_k]), 'hex');
    end loop;
    update public.pk_rounds
       set board_salt = v_zouten, board_commit = v_commits
     where id = v_ronde;
  end;

  -- De blinds. Heads-up post de knop de kleine blind; met meer spelers de stoel erna.
  declare
    v_n int := v_i;
    v_knop2 smallint;
    v_sbs smallint; v_bbs smallint;
  begin
    select button_seat into v_knop2 from public.pk_rounds where id = v_ronde;
    if v_n = 2 then
      v_sbs := v_knop2;
      v_bbs := ((v_knop2 + 1) % v_n)::smallint;
    else
      v_sbs := ((v_knop2 + 1) % v_n)::smallint;
      v_bbs := ((v_knop2 + 2) % v_n)::smallint;
    end if;

    update public.pk_seats
       set bet = least(v_sb, stack), total_bet = least(v_sb, stack),
           stack = stack - least(v_sb, stack), allin = stack <= v_sb
     where round_id = v_ronde and seat_no = v_sbs;
    update public.pk_seats
       set bet = least(v_bb, stack), total_bet = least(v_bb, stack),
           stack = stack - least(v_bb, stack), allin = stack <= v_bb
     where round_id = v_ronde and seat_no = v_bbs;

    update public.pk_rounds
       set high_bet = v_bb,
           to_act_seat = ((v_bbs + 1) % v_n)::smallint,
           act_deadline = now() + interval '25 seconds'
     where id = v_ronde;
  end;

  -- De stapels aan tafel volgen die in de hand.
  update public.pk_players pl set stack = s.stack
    from public.pk_seats s
   where s.round_id = v_ronde and s.user_id = pl.user_id
     and pl.lobby_id = p_lobby;

  return json_build_object('ok', true, 'round', v_ronde, 'dealt', true);
end;
$$;

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


-- ============================================================================
--  3 van 4 -- DE SPRINTRESET   (sql/sprint_reset.sql)
-- ============================================================================

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


-- ============================================================================
--  4 van 4 -- HET GROOTBOEK   (sql/poker_ledger.sql)
-- ============================================================================

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

-- Bijschrijven, en meteen de stand van deze sprint bijwerken. Begint er een nieuwe sprint,
-- dan begint de teller opnieuw -- net als het saldo zelf.
create or replace function poker.note(p_uid uuid, p_naam text, p_lobby bigint,
                                      p_kind text, p_bedrag integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_sprint bigint := public.sprint_now();
begin
  insert into public.pk_ledger (sprint, lobby_id, user_id, username, kind, amount)
       values (v_sprint, p_lobby, p_uid, p_naam, p_kind, p_bedrag);

  update public.profiles
     set poker_net = case when poker_net_sprint is distinct from v_sprint
                          then p_bedrag else poker_net + p_bedrag end,
         poker_net_sprint = v_sprint
   where id = p_uid;
end;
$$;

revoke all on function poker.note(uuid, text, bigint, text, integer) from public, anon, authenticated;

-- De ranglijst zonder poker erin. `season_scores` bestond al en rekent met het kale saldo;
-- deze legt de pokerstroom ernaast, zodat wat je aan de tafels hebt verplaatst niet meetelt
-- voor de titel en de pas.
--
-- Let op: dit is een view OVER season_scores. Bestaat die niet, dan doet deze het ook niet.
do $$
begin
  if to_regclass('public.season_scores') is null then
    raise notice 'season_scores bestaat hier niet; sprint_scores wordt overgeslagen';
    return;
  end if;
  execute $v$
    create or replace view public.sprint_scores as
      select s.*,
             coalesce(p.poker_net, 0) as poker_net,
             (s.end_balance - s.start_balance)
               - case when p.poker_net_sprint = s.season then coalesce(p.poker_net, 0) else 0 end
               as gain_no_poker
        from public.season_scores s
        left join public.profiles p on p.username = s.username;
  $v$;
  execute 'grant select on public.sprint_scores to anon, authenticated';
end $$;
