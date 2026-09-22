-- ============================================================================
--  DEEL 2 VAN 14
-- ============================================================================
--
--  Plak dit pas NA deel 1. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker.sql
-- ============================================================================

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
