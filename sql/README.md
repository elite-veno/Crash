# De SQL achter het casino

De pagina praat met Supabase (Postgres + PostgREST). Wat hier staat is wat daarin moet.
Draai het in de SQL-editor van Supabase, in deze volgorde. Alles is veilig om twee keer te
draaien.

| bestand | wat het doet |
|---|---|
| `sprint_reset.sql` | iedereen na elke sprint terug op $1000 |
| `poker.sql` | de tabellen en views van poker |
| `poker_rpc.sql` | de functies van poker: delen, inzetten, afrekenen |
| `poker_ledger.sql` | houdt bij wat poker met een saldo doet, zodat de sprintranglijst klopt |

Of, als je liever één keer plakt: **`alles.sql`** is precies die vier bestanden achter
elkaar, in deze volgorde, met een kop erboven. Eén keer plakken in de SQL-editor en RUN.
De losse bestanden blijven de bron -- `alles.sql` wordt daaruit samengesteld, dus pas nooit
alleen `alles.sql` aan.

**Kijk na het draaien één ding na:** Settings -> API -> Exposed schemas moet ALLEEN `public`
bevatten. Het schema `poker` mag daar nooit bij staan -- daar liggen de holekaarten en de
zaadjes van de schudbeurt.

`poker.sql` en `poker_rpc.sql` vervangen twee views (`pk_live` en `pk_seats_public`) met
een `drop` ervoor, omdat er kolommen bij en af gaan. Draai ze dus niet terwijl er een hand
loopt; tussen twee handen kost het niets.

**Er staat hier geen enkele sleutel in, en die hoort er ook niet in.** De pagina gebruikt
alleen de publieke sleutel; de `service_role`-sleutel hoort nergens anders dan in het
dashboard van Supabase.

## Zelf naspelen zonder Supabase

De functies zijn gewone Postgres, dus ze zijn na te spelen op een lege database. `test_stub.sql`
zet het kleinste stukje Supabase neer dat ervoor nodig is -- een profielentabel en een
`auth.uid()` die te sturen is -- zodat de tests hiernaast kunnen draaien.

```sh
# een Postgres in /tmp, als de gebruiker postgres want initdb wil niet als root
D=/tmp/pgpoker; PG=/usr/lib/postgresql/16/bin
rm -rf $D && mkdir -p $D/data $D/sock && chown -R postgres:postgres $D
su postgres -c "$PG/initdb -D $D/data -U postgres --auth=trust"
su postgres -c "$PG/pg_ctl -D $D/data -o '-k $D/sock -h \"\"' -l $D/log start"

# en dan alles erin
su postgres -c "psql -h $D/sock -U postgres -q \
  -f sql/test_stub.sql -f sql/sprint_reset.sql -f sql/poker.sql -f sql/poker_rpc.sql \
  -f sql/poker_ledger.sql"

# de tests
su postgres -c "psql -h $D/sock -U postgres -q -f sql/sprint_reset_test.sql"
su postgres -c "psql -h $D/sock -U postgres -q -f sql/poker_test.sql"
node tools/poker_sql_test.js 2000
```

Er staan ook twee toetsen die de PAGINA draaien in plaats van de database:

```sh
npm install playwright           # chromium staat al klaar in deze omgeving
node tools/pok_scherm_test.js    # tekent de tafel in elke fase van een hand
node tools/pok_eerlijk_test.js   # rekent het eerlijkheidsbewijs na, ook met een vervalst bord
```

Die twee zijn de enige die zouden merken dat het scherm klapt zodra er echt een hand op
staat -- de rest gaat over regels en over de database. De eerste vond meteen dat de
fasebalk "SIT DOWN TO PLAY" zei terwijl je zat te spelen.

`tools/poker_sql_test.js` is de belangrijkste van de twee: die legt de handbeoordelaar in
SQL naast die in `crash.html` en controleert dat ze op elke hand hetzelfde zeggen. Zeggen
ze iets anders, dan ziet een speler zichzelf winnen terwijl het geld naar een ander gaat.

## Poker en de ranglijst

Poker is het enige spel hier waar geld tussen ACCOUNTS beweegt; alle andere gaan tegen het
huis. Dat botst met de sprintranglijst, die winst rekent als saldo-nu min saldo-aan-het-
begin en de nummer één een VIP-pas geeft: twee vrienden aan een privétafel kunnen de fiches
van de een naar de ander schuiven en die ander zo bovenaan zetten zonder dat er iets
gewonnen is.

`poker_ledger.sql` houdt daarom per speler bij wat poker deze sprint met zijn saldo heeft
gedaan, en legt een view `sprint_scores` naast de bestaande `season_scores` met een kolom
`gain_no_poker`. **Die view wordt alleen aangemaakt als `season_scores` al bestaat.**

De ranglijst op de pagina leest die view nu ook: `seasonScoresPull()` vraagt eerst
`sprint_scores` en gebruikt `gain_no_poker`; komt daar een 404 op, dan valt hij één keer
terug op `season_scores` met de oude berekening en onthoudt dat. Zolang
`poker_ledger.sql` niet gedraaid is werkt de ranglijst dus gewoon -- alleen telt poker dan
mee, en is de sprintstand met een privétafel te sturen.

## Twee dingen die niet op hun woord te geloven zijn

**De reset is geen verzoek.** `sprint_reset()` is netjes, maar de pagina hoeft hem niet aan
te roepen: het saldo gaat gewoon als kolom mee in een `PATCH` op `/rest/v1/profiles`, dus
een aangepaste pagina houdt zijn stapel van vorige sprint en schrijft die elke keer opnieuw
weg. Daarom staat de afrekening nu op het SCHRIJFPAD: de trigger `sprint_guard` op
`profiles` zet een achterstallig account terug naar 1000 zodra er iets naar die rij
geschreven wordt, wat de schrijver ook meestuurde -- en `reset_sprint` leidt hij altijd af
uit de oude rij, zodat die kolom niet vooruit te zetten is. Je eerstvolgende schrijfactie
*is* de reset.

Wie daardoor iets aanraakt dat geld beweegt, moet die grens eerst afhandelen: `pk_sit`
begint met een lege update op zijn eigen profielrij. Zonder dat gooide de trigger midden in
`balance = inkoop` de aftrek weg, stonden de fiches er toch, en kocht je elke sprintgrens
gratis in. `sql/poker_test.sql` pint dat vast.

**Het bord ligt vast voordat het valt.** Toen het zaadje eruit ging, hield niets de vijf
gemeenschappelijke kaarten meer vast: `deck_commit` stond nog op het scherm maar ging nooit
meer open, dus een oneerlijke server kon de flop neerleggen die hem uitkwam. Daarom staat
er nu bij het delen per bordkaart een gezouten hash in `pk_rounds.board_commit`, en komen
bij het afrekenen de zouten vrij van precies de kaarten die ook echt gevallen zijn. Per
kaart en niet over het hele bord, want een hand hoeft niet uit te komen.

**En de browser moet die hashes vasthouden, anders is het geen bewijs.** Dat ging eerst mis:
`pokEerlijk()` haalde bord, hash en zout alle drie uit hetzelfde antwoord en vergeleek dus
één momentopname met zichzelf. Een server die bij het afrekenen het bord omgooit en de
hashes er meteen bij herrekent, kwam er met een groen vinkje doorheen -- precies de aanval
die de vastlegging moest tegenhouden. Nu zet de pagina de hashes in `localStorage` zodra ze
een hand voor het eerst ziet, en rekent bij het afrekenen tegen díé kopie.

Wat dit wel en niet bewijst:

- **Wel:** de server kan na het delen niets meer omgooien zonder dat de browser het ziet --
  maar alleen bij een browser die er vanaf het begin bij was. Kwam je pas na de flop
  binnen, dan is er niets van voor de flop bewaard, en zegt het scherm dat ook in plaats
  van een vinkje te zetten.
- **Niet:** dat de server de kaarten niet heeft gekozen. Alles wordt in één transactie
  weggeschreven, dus wie de server draait kan de hash meteen kloppend maken. Daar is een
  zaadje voor nodig dat de speler zelf meebrengt; dat zit er nog niet in.

`tools/pok_eerlijk_test.js` pint dit vast met tien gevallen, waaronder een server die bord
én hashes samen herrekent en een die alleen de river ruilt. Haal de vergelijking met de
bewaarde kopie weg en die twee krijgen meteen weer een groen vinkje.

**Het zaadje van de schudbeurt komt niet naar buiten.** Bij crash en roulette is het zaadje
achteraf tonen juist het bewijs. Bij poker niet: het zaadje stuurt de hele schudbeurt, dus
wie het heeft rekent ook de kaarten uit van iemand die gepast heeft en ze nooit heeft laten
zien. `pk_live` gaf het vrij zodra een hand was afgerekend, aan iedereen, ook aan wie niet
was ingelogd. Die kolom is weg.

Het bewijs loopt nu per stoel: voor het delen staat van elke hand een gezouten hash in
`pk_seats_public.card_commit`, en na het delen krijgt elke speler via `pk_my_hole` zijn
eigen zout. De pagina rekent daarmee na dat die hash bij zijn twee kaarten hoort -- je
controleert je eigen hand net zo hard als eerst, zonder iets over die van een ander te
leren. Het zaadje blijft in `poker.deck`, in het schema dat PostgREST niet serveert -- en `pk_settle`
gooit die rij weg zodra de hand is afgerekend. Wat er anders zou blijven staan is de hele
geschudde stok van elke hand die er ooit is gespeeld, inclusief elke gemuckte kaart, in elke
back-up en elke supportvraag.
