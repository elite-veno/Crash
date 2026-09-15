# Accounts en live leaderboard aanzetten

Het spel is één HTML-bestand op GitHub Pages en heeft dus zelf geen server. Voor echte
accounts en een live leaderboard tegen andere spelers hangt het aan een gratis
[Supabase](https://supabase.com)-project. Reken op ongeveer tien minuten.

Zonder deze stappen blijft het spel werken in offline modus: je kiest een naam, je voortgang
staat alleen in je eigen browser en de leaderboard zegt dat ook. Er worden nooit nepspelers
of bots getoond.

---

## Stap 1 · Project aanmaken

1. Ga naar [supabase.com/dashboard](https://supabase.com/dashboard) en log in met GitHub.
2. Klik **New project**.
3. Vul in:
   - **Name**: `neon-casino` (vrij te kiezen).
   - **Database Password**: klik **Generate a password** en bewaar hem in je wachtwoord­manager. Je hebt hem voor dit spel niet nodig, maar je kunt hem later niet meer opvragen.
   - **Region**: kies de regio die het dichtst bij je spelers ligt, bijvoorbeeld *West EU (Ireland)* of *Central EU (Frankfurt)*.
   - **Pricing Plan**: **Free**.
4. Klik **Create new project** en wacht tot de status bovenin van *Setting up* naar actief springt. Dit duurt ongeveer twee minuten.

---

## Stap 2 · De twee waarden ophalen die het spel nodig heeft

Ga in de linkerbalk naar het tandwiel **Project Settings**.

**a. Project URL**

Open **Project Settings → Data API** (in oudere dashboards heet dit **API**). Bovenaan staat
**Project URL**:

```
https://abcdefghijklmnop.supabase.co
```

Kopieer die hele regel, zonder schuine streep aan het eind en zonder pad erachter.

Staat er op deze pagina dat de Data API is uitgeschakeld, zet hem dan aan. Het spel praat
via die API met de database.

**b. Publieke sleutel**

Open **Project Settings → API Keys**. Je ziet twee soorten sleutels; je hebt de publieke
nodig, niet de geheime.

- Heet er één **anon** / **public** en begint hij met `eyJ...` → dat is hem.
- Zie je in plaats daarvan **Publishable key** met `sb_publishable_...` → dat is hem.

Beide werken. Kopieer hem met de kopieerknop.

> **Niet gebruiken:** de sleutel met het label **service_role** of **secret**
> (`sb_secret_...`). Die geeft volledige toegang tot je database en hoort nooit in een
> publieke repository. Zet die dus nergens in `crash.html`.
>
> De publieke sleutel hóórt in de pagina te staan. Hij zegt alleen tegen welk project je
> praat; wat iemand ermee mag doen, bepalen de regels die je in stap 4 aanzet.

---

## Stap 3 · Inloggen op gebruikersnaam mogelijk maken

Spelers loggen in met een gebruikersnaam, niet met een echt e-mailadres. Het spel maakt er
intern `naam@neoncasino.example` van. Supabase mag daar dus geen bevestigingsmail naartoe
willen sturen.

Ga naar **Authentication** (het sleutel-icoon) **→ Sign In / Providers → Email** en zet:

| Instelling | Stand | Waarom |
| --- | --- | --- |
| **Enable email provider** | **aan** | anders kan niemand registreren |
| **Confirm email** | **uit** | het adres bestaat niet, dus een bevestigingsmail komt nooit aan |
| **Allow new users to sign up** | **aan** | staat onder **Authentication → Sign In / Providers**, bovenaan de pagina |
| **Minimum password length** | 6 of lager | het spel eist zelf minstens 6 tekens |

Klik onderaan op **Save**. De overige instellingen (Secure email change, password strength,
URL Configuration) laat je staan; die doen hier niets omdat er geen mail wordt verstuurd.

> Heb je al een account aangemaakt terwijl *Confirm email* nog aan stond? Verwijder dat
> account via **Authentication → Users**, anders blijft het onbevestigd hangen.

---

## Stap 4 · Database en beveiliging opzetten

Ga naar **SQL Editor → New query**, plak onderstaande blok in zijn geheel en klik **Run**.
Je mag het later nog eens draaien: alles is herhaalbaar geschreven.

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
drop policy if exists "eigen profiel lezen"    on public.profiles;
drop policy if exists "eigen profiel aanmaken" on public.profiles;
drop policy if exists "eigen profiel wijzigen" on public.profiles;
create policy "eigen profiel lezen"    on public.profiles for select using (auth.uid() = id);
create policy "eigen profiel aanmaken" on public.profiles for insert with check (auth.uid() = id);
create policy "eigen profiel wijzigen" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- De server bepaalt de startwaarden en de naam; de client kan ze niet kiezen.
-- Bij een nieuwe rij worden saldo en statistieken vastgezet op de beginstand en wordt de
-- gebruikersnaam overgenomen uit het account zelf, zodat niemand een naam van een ander
-- kan claimen. Bij een wijziging liggen id en naam vast en wordt een absurde saldosprong
-- geweigerd.
create or replace function public.guard_profile_write() returns trigger
language plpgsql security definer set search_path = public as $$
declare claimed text;
begin
  if tg_op = 'INSERT' then
    select u.raw_user_meta_data->>'username' into claimed from auth.users u where u.id = new.id;
    new.username := coalesce(claimed, new.username);
    new.balance := 1000;
    new.rounds := 0;
    new.won := 0;
    new.lost := 0;
    new.profit := 0;
    new.stats := '{}'::jsonb;
    new.updated_at := now();
    return new;
  end if;
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
drop function if exists public.guard_profile_update();
create trigger profiles_guard before insert or update on public.profiles
  for each row execute function public.guard_profile_write();

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

drop policy if exists "winsten lezen" on public.wins;
drop policy if exists "eigen winst plaatsen" on public.wins;
create policy "winsten lezen" on public.wins for select using (true);
create policy "eigen winst plaatsen" on public.wins for insert
  with check (auth.uid() = player and username = (select p.username from public.profiles p where p.id = auth.uid()));

create index if not exists wins_recent_idx on public.wins (created_at desc);
```

Onder de query verschijnt **Success. No rows returned**. Dat is goed.

Controleer daarna in **Table Editor** dat `profiles` en `wins` bestaan en dat er achter
allebei een groen **RLS enabled** staat. Zonder dat label kan iedereen bij elkaars gegevens.

---

## Stap 5 · De sleutels in het spel zetten

Open `crash.html`, zoek bovenin het script naar `const BACKEND = {` en vul je twee waarden
in:

```js
const BACKEND = {
  url: 'https://abcdefghijklmnop.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  emailDomain: 'neoncasino.example',
};
```

Let op: geen schuine streep aan het eind van de URL, en de sleutel als één regel zonder
spaties of regeleinden.

Commit en push naar `main`. GitHub Pages deployt automatisch en binnen een minuut staat het
inlogscherm live op https://elite-veno.github.io/Crash/.

---

## Stap 6 · Controleren of het werkt

1. Open de site. Het inlogscherm moet **geen** waarschuwing meer tonen en de knop
   **ACCOUNT AANMAKEN** moet klikbaar zijn.
2. Registreer een account en speel één ronde.
3. Ga terug naar de lobby: bij **LIVE LEADERBOARD** staat je naam, en onderaan staat hoeveel
   spelers er geregistreerd zijn.
4. Kijk in Supabase bij **Table Editor → profiles**: er staat één rij met jouw naam, saldo en
   statistieken.
5. Open de site in een privévenster, maak een tweede account en speel. Beide accounts zien
   elkaar nu in de ranglijst en in de winstenfeed.

---

## Als er iets misgaat

| Melding in het spel of de console | Oorzaak | Oplossing |
| --- | --- | --- |
| *Online accounts zijn nog niet geconfigureerd* | `BACKEND.url` of `anonKey` is leeg of de URL begint niet met `https://` | stap 5 opnieuw, let op de hele URL |
| *het project vraagt om e-mailbevestiging* | **Confirm email** staat nog aan | stap 3, en verwijder het zojuist aangemaakte account bij **Authentication → Users** |
| *Signups not allowed for this instance* | **Allow new users to sign up** staat uit | stap 3 |
| *Invalid API key* | verkeerde of afgekapte sleutel | kopieer de publieke sleutel opnieuw met de kopieerknop |
| *relation "public.public_leaderboard" does not exist* | de SQL is niet gedraaid | stap 4 |
| *permission denied for table profiles* | policies ontbreken | stap 4 opnieuw draaien |
| CORS- of netwerkfout in de console | verkeerde project-URL, of de Data API staat uit | stap 2a |
| Registreren lukt maar de leaderboard blijft leeg | de view of de grant ontbreekt | stap 4 opnieuw draaien |

---

## Wat er waar wordt bewaard

| Gegeven | Waar | Beveiliging |
| --- | --- | --- |
| Wachtwoord | Supabase Auth | bcrypt-hash, verlaat je apparaat nooit leesbaar, staat niet in de browseropslag |
| Saldo, statistieken per spel, winst | `profiles`, jouw eigen rij | row level security: alleen jij leest en schrijft die rij; een trigger zet de beginstand vast |
| Naam, saldo, W/L voor de ranglijst | `public_leaderboard` | alleen deze vier kolommen zijn publiek leesbaar |
| Winstenfeed | `wins` | iedereen leest, je kunt alleen onder je eigen naam schrijven |
| Sessietoken | browseropslag | kortlevend, wordt automatisch ververst, verdwijnt bij uitloggen |

Het spel rekent de rondes in de browser uit, dus het saldo dat wordt opgeslagen komt van de
client. De databaseregels zorgen dat niemand een ander account kan lezen of wijzigen, dat een
nieuw account altijd op $1000 begint, dat een gebruikersnaam alleen door de eigenaar gebruikt
kan worden en dat het eigen saldo niet in één sprong onrealistisch omhoog kan. Voor een spel met fictief geld
is dat het passende niveau; wil je het onvervalsbaar maken, dan moeten de rondes op een
server worden uitgerekend.
