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
  deck_commit  text not null,
  deck_seed    text,
  deck         text[] not null,
  button_seat  smallint not null default 0,
  sb           integer not null default 50,     -- in centen
  bb           integer not null default 100,
  high_bet     integer not null default 0,      -- hoogste inzet van deze straat, in centen
  min_raise    integer not null default 100,
  to_act_seat  smallint,
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
  stack      integer not null default 0,        -- in centen, wat er voor je ligt
  bet        integer not null default 0,        -- deze straat
  total_bet  integer not null default 0,        -- deze hele hand
  folded     boolean not null default false,
  allin      boolean not null default false,
  acted      boolean not null default false,
  hole       text[] not null default '{}',
  shown      boolean not null default false,    -- open gegooid bij de showdown
  payout     integer not null default 0,
  primary key (round_id, seat_no)
);
create index if not exists pk_seats_user on public.pk_seats (user_id);

-- ---------- wie er aan tafel zit tussen de handen door ----------
-- Je stapel hoort bij de tafel, niet bij de hand: je blijft zitten als een hand voorbij is.
create table if not exists public.pk_players (
  lobby_id  bigint not null,
  user_id   uuid not null,
  username  text not null,
  seat_no   smallint not null,
  stack     integer not null default 0,         -- in centen
  sat_at    timestamptz not null default now(),
  beat_at   timestamptz not null default now(),
  primary key (lobby_id, user_id)
);
create unique index if not exists pk_players_seat on public.pk_players (lobby_id, seat_no);

-- ---------- de kaarten van een ander zijn niet van jou ----------
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
create or replace view public.pk_seats_public
with (security_invoker = false) as
  select s.round_id, s.seat_no, s.username, s.user_id, s.stack, s.bet, s.total_bet,
         s.folded, s.allin, s.acted, s.payout, s.shown,
         case when s.shown or s.user_id = auth.uid() then s.hole else '{}'::text[] end as hole,
         array_length(s.hole, 1) as cards
    from public.pk_seats s;

grant select on public.pk_seats_public to anon, authenticated;

-- En de ronde zelf, zonder het zaadje zolang de hand loopt.
create or replace view public.pk_live
with (security_invoker = false) as
  select r.id, r.lobby_id, r.started_at, r.street, r.board, r.deck_commit,
         case when r.settled_at is null then null else r.deck_seed end as deck_seed,
         r.button_seat, r.sb, r.bb, r.high_bet, r.min_raise, r.to_act_seat,
         r.act_deadline, r.settled_at, now() as server_now
    from public.pk_rounds r;

grant select on public.pk_live to anon, authenticated;

-- Wie er aan tafel zit, met zijn stapel. Geen geheimen.
create or replace view public.pk_table
with (security_invoker = false) as
  select p.lobby_id, p.user_id, p.username, p.seat_no, p.stack, p.beat_at
    from public.pk_players p;

grant select on public.pk_table to anon, authenticated;
