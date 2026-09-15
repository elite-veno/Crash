# Accounts en live leaderboard aanzetten

Het spel is één HTML-bestand op GitHub Pages en heeft dus zelf geen server. Voor echte
accounts en een live leaderboard tegen andere spelers hangt het aan een gratis
[Supabase](https://supabase.com)-project. Dat kost ongeveer drie minuten.

Zonder deze stappen blijft het spel werken in offline modus: je kiest een naam, je
voortgang staat alleen in je eigen browser en de leaderboard laat dat ook zien. Er worden
nooit nepspelers of bots getoond.

## 1. Project aanmaken

1. Maak een gratis account op supabase.com en klik op **New project**.
2. Ga naar **Project Settings → API** en noteer:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **anon public** key

De anon key hoort publiek te zijn. Hij geeft alleen toegang tot wat de regels hieronder
toestaan; de `service_role` key zet je nooit in de code.

## 2. Registratie zonder e-mailbevestiging

Spelers loggen in met een gebruikersnaam, niet met een echt e-mailadres. Zet daarom
**Authentication → Sign In / Providers → Email → Confirm email** uit. Laat
**Enable email provider** aan staan.

## 3. Database opzetten

Plak dit in **SQL Editor → New query** en voer het uit.

```sql
-- Alle voortgang van een account staat in één rij.
create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  username   text not null unique check (username ~ '^[A-Za-z0-9_]{3,16}$'),
  balance    numeric(14,2) not null default 1000 check (balance >= 0),
  rounds     integer not null default 0 check (rounds >= 0),
  won        integer not null default 0 check (won >= 0),
  lost       integer not null default 0 check (lost >= 0),
  profit     numeric(14,2) not null default 0,
  stats      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Een speler mag uitsluitend zijn eigen rij zien en schrijven.
create policy "eigen profiel lezen"    on public.profiles for select using (auth.uid() = id);
create policy "eigen profiel aanmaken" on public.profiles for insert with check (auth.uid() = id);
create policy "eigen profiel wijzigen" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- Naam ligt vast na registratie en het saldo kan niet in één klap absurd stijgen.
create or replace function public.guard_profile_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id <> old.id or new.username <> old.username then
    raise exception 'id en gebruikersnaam liggen vast';
  end if;
  if new.balance > old.balance + 100000 then
    raise exception 'ongeldige saldosprong';
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_update();

-- De leaderboard leest alleen deze kolommen; de rest van het profiel blijft privé.
create or replace view public.public_leaderboard as
  select username, balance, won, lost, updated_at from public.profiles;
alter view public.public_leaderboard set (security_invoker = false);
grant select on public.public_leaderboard to anon, authenticated;

-- Live winstenfeed.
create table if not exists public.wins (
  id         bigint generated always as identity primary key,
  player     uuid not null references auth.users on delete cascade,
  username   text not null,
  game       text not null check (game in ('crash','roulette','tower','mines','plinko','blackjack','horse')),
  amount     numeric(14,2) not null check (amount >= 0),
  mult       numeric(12,2) not null check (mult >= 0),
  created_at timestamptz not null default now()
);

alter table public.wins enable row level security;

create policy "winsten lezen" on public.wins for select using (true);
create policy "eigen winst plaatsen" on public.wins for insert
  with check (auth.uid() = player and username = (select p.username from public.profiles p where p.id = auth.uid()));

create index if not exists wins_recent_idx on public.wins (created_at desc);
```

## 4. Sleutels in het spel zetten

Open `crash.html`, zoek `const BACKEND = {` bovenin het script en vul in:

```js
const BACKEND = {
  url: 'https://xxxx.supabase.co',
  anonKey: 'eyJhbGciOi...',
  emailDomain: 'neoncasino.example',
};
```

Commit en push naar `main`. GitHub Pages deployt automatisch en het inlogscherm staat live.

## Wat er waar wordt bewaard

| Gegeven | Waar | Beveiliging |
| --- | --- | --- |
| Wachtwoord | Supabase Auth | bcrypt-hash, verlaat je apparaat nooit leesbaar, staat niet in de browseropslag |
| Saldo, statistieken per spel, winst | `profiles`, jouw eigen rij | row level security: alleen jij leest en schrijft die rij |
| Naam, saldo, W/L voor de ranglijst | `public_leaderboard` | alleen deze vier kolommen zijn publiek leesbaar |
| Winstenfeed | `wins` | iedereen leest, je kunt alleen onder je eigen naam schrijven |
| Sessietoken | browseropslag | kortlevend, wordt automatisch ververst, verwijderd bij uitloggen |

Het spel rekent de rondes in de browser uit, dus het saldo dat wordt opgeslagen komt van de
client. De databaseregels zorgen dat niemand een ander account kan lezen of wijzigen en dat
het eigen saldo niet in één sprong onrealistisch omhoog kan; dat is het passende niveau voor
een spel met fictief geld.
