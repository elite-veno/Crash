# Neon Casino in Roblox — bouwplan

Doel: dezelfde game, dezelfde functies, dezelfde uitstraling. Nog geen echte parts —
alleen de UI en de systemen.

## Wat er overgezet moet worden

Gemeten in `crash.html`: 8.298 regels, waarvan 1.661 CSS, 5.224 JavaScript en 1.413
markup. 252 functies, 16 schermen, 5 canvassen, 11 spellen, 13 systeemobjecten.

| onderdeel | web | Roblox |
|---|---|---|
| spellen | crash, roulette, tower, mines, plinko, blackjack, horse, scratch, wheel, 777, ride the bus | zelfde elf |
| tekenwerk | `<canvas>` | Frames met rotatie en UIGradient; geen canvas in Roblox |
| account | eigen inlogscherm op Supabase GoTrue | vervalt: Roblox kent de speler al |
| vrienden | eigen lijst met uitnodigingen en RLS | vervalt: Roblox kent de vrienden al |
| privélobby | eigen tabel met codes | Roblox' eigen privéservers (ReserveServer) |
| eerlijk spel | `sha256()` in Postgres | met de hand in Luau, tegen de testvectoren |
| opslag | PostgreSQL met RLS | DataStore, ranglijst via OrderedDataStore |
| serverlogica | SECURITY DEFINER-functies | ServerScriptService; de client kan er niet bij |
| gedeelde ronde | polling op een view | RemoteEvents, de server duwt |

## Waarom dit op punten beter uitpakt

In de webversie rekent alleen crash op de server af; de tien andere spellen rekenen in de
browser en zijn daarmee in principe te bewerken. In Roblox staat alle afrekening in
ServerScriptService en kan de client er per definitie niet bij. Dat gat sluit vanzelf.

## Stappen

0. **Skelet** — Rojo-project, mappen, en een testharnas die Luau buiten Studio draait.
1. **Odds** — alle vijftig functies uit `ODDS` één op één over, met dezelfde RTP-bewijzen
   als `odds_test.js`. Dit is pure wiskunde en dus volledig te bewijzen zonder Studio.
2. **Thema en bouwstenen** — kleuren, letters en maten uit de CSS; Panel, Button, Chip,
   Toast, StatGrid als herbruikbare modules.
3. **Schil** — zijbalk, routing, de zestien schermen, saldo, meldingen.
4. **Profiel** — DataStore, statistieken, saldo. Alles server-authoritative.
5. **De elf spellen** — één voor één, telkens met de afrekening op de server.
6. **Seizoenen** — sprints van drie dagen, seizoenen van twaalf, de reset naar $1000 plus
   een tiende, titels, VIP-zone, prestaties, ranglijsten.
7. **Sociaal** — vrienden, privélobby's met codes, quick play, de gedeelde crash- en
   blackjacktafel.
8. **Review** — een workflow met review agents over het geheel, en de bevindingen die
   standhouden repareren.

## Waar het staat

Alle acht stappen zijn af. Zestien schermen, elf spellen, alles afgerekend op de server.
Wat er nog niet is: echte parts in de wereld (bewust: de opdracht was de UI en de systemen),
en de gedeelde blackjacktafel, die nu per speler loopt in plaats van als één tafel voor
iedereen -- crash is dat wel.

## Wat er per stap bewijsbaar is

`luau` en `luau-analyze` draaien in deze omgeving. Daarmee is te bewijzen, zonder Studio:

- de kansen en uitbetalingen van elk spel (stap 1)
- de seizoens- en sprintrekensom (stap 6)
- dat elk bestand typecheckt (elke stap)

Wat alleen in Studio te zien is: hoe het eruitziet en of de UI goed schaalt. Daar lever ik
schermafdrukken van zodra jij het project hebt gesynct.
