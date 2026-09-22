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
    update public.pk_players pl set stack = s.stack
      from public.pk_seats s, public.pk_rounds rd
     where rd.id = v_ronde and s.round_id = v_ronde
       and s.user_id = pl.user_id and pl.lobby_id = rd.lobby_id;

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
