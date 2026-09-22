-- ============================================================================
--  DEEL 1 VAN 14
-- ============================================================================
--
--  Begin hier. Plak dit deel in de SQL-editor van Supabase en druk op RUN.
--  Pas als dat gelukt is (groen, "Success"), ga je door met deel 2.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker.sql
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
