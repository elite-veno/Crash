# Neon Casino — Roblox

De game uit `crash.html`, nagebouwd in Luau. Alleen de UI en de systemen; nog geen parts.

## In Studio krijgen

Belangrijk: wat hier in de repo staat, komt **niet vanzelf** in je place terecht. Een
Roblox-place is een bestand op Roblox' servers; deze map is code op GitHub. Er moet een
keer iets van hier naar daar. Twee manieren:

### Een keer plakken, daarna een knop

View > **Command Bar**, en plak de inhoud van `tools/studio_install.luau`. Studio haalt de
laatste code zelf van GitHub en zet hem op zijn plek. Er hoeft niets gedownload te worden.

Diezelfde paste legt ook een plugin klaar in **ServerStorage**, `NeonSync`. Rechtsklik die
en kies **Save as Local Plugin**. Vanaf dat moment staat er een **Sync**-knop in je
werkbalk: één klik haalt de laatste versie op, en plakken hoeft nooit meer. De knop
**Auto** ernaast zet automatisch synchroniseren aan zodra Studio de place opent; die staat
met opzet uit, zodat de plugin nooit zomaar overschrijft waar je net aan werkte. Een sync
gaat in één ongedaanmaakstap, dus ctrl-z draait hem in zijn geheel terug.

Dat script staat er met opzet zo uit. De command bar is een invoerveld van **een regel**:
bij plakken worden de regels aan elkaar geplakt. Alle uitleg staat daarom in
blokcommentaar (`--[[ ... ]]`) en er staat nergens een los `--` commentaar, want dat zou
na het samenvoegen de rest van het script opeten. Hij is in beide vormen getest.

Werkt het nog steeds niet, dan staat HTTP uit: File > Game Settings > Security >
**Allow HTTP Requests**. Daarna opnieuw plakken. Het script zegt het ook zelf als dat het
probleem is.

### Zonder Rojo en zonder HTTP

1. Download `build/NeonCasino.rbxmx` uit deze repo (open het bestand op GitHub en klik op
   **Download raw file**). Dat model wordt bij elke wijziging opnieuw gebouwd, dus het is
   altijd de laatste stand.
2. In Studio: rechtsklik op **Workspace** in de Explorer > **Insert from File...** >
   kies dat bestand. Er verschijnt een map `NeonCasino`.
3. Plak de inhoud van `tools/install.luau` in de **command bar** (View > Command Bar) en
   druk op enter. Die zet `Shared`, `Server` en `Client` op hun plek en gooit het
   omhulsel weg.
4. Play.

Stap 3 doet dit:

```lua
local m = workspace.NeonCasino
m.Shared.Parent = game:GetService("ReplicatedStorage")
m.Server.Parent = game:GetService("ServerScriptService")
m.Client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
m:Destroy()
```

Bij een volgende versie: de drie mappen weggooien en stap 1 tot en met 3 opnieuw doen.

### Met Rojo, als je vaker gaat syncen

[Rojo](https://rojo.space) installeren, de Roblox-plugin erbij, dan `rojo serve` in deze
map en in Studio op **Connect** klikken. Vanaf dan gaat elke wijziging in `src/` meteen
naar je place, zonder opnieuw invoegen. `default.project.json` staat al klaar.

Het model wordt gebouwd door `tools/build_rbxmx.py`; dat leest dezelfde
`default.project.json` als Rojo en schrijft het XML zelf, zodat het ook werkt als Rojo er
niet is.

## Testen zonder Studio

```
bash tools/run_tests.sh
```

Typecheckt elk bestand tegen de echte Roblox-API en draait daarna elke
`tests/*_test.luau` — samen ruim achttienhonderd beweringen. De wiskunde in `src/shared/Odds`
gebruikt met opzet geen enkel Roblox-type, juist zodat dit kan.

De serverbestanden gebruiken die types wel, en worden toch getest: `tools/bundle_server.py`
zet ze als tekst in `tests/server_sources.luau`, en `tests/roblox_stub.luau` laadt ze met
`loadstring` in een nagemaakte omgeving — eigen `Players`, eigen DataStore, eigen trekker.
Daardoor draait `tests/server_test.luau` op de code die straks echt in Studio staat, en
niet op een kopie ervan. Dat is de plek waar de valsspeelwegen getest worden: dezelfde
mijnentegel twee keer insturen, een inzet van NaN, een call bij Ride the Bus die niet kan
uitkomen, weggaan met een ronde open, en twee servers die dezelfde speler willen opslaan.

## Naast de pagina leggen

De port moet er pixel voor pixel uitzien als `crash.html`. Zonder Studio is dat toch te
meten, want beide kanten zijn uit te rekenen:

```
bash tools/preview/alles.sh            # tekent elk scherm als PNG, zonder Studio
cd tools/preview
node meet_web.js <scherm> [kiezer ...]  # waar staat elk blok op de PAGINA
python3 meet_rbx.py <scherm> [naam ...] # waar staat elk vak in de PORT
```

`meet_web.js` opent `crash.html` in een browser, zet hem in dezelfde stand als de
schermafdrukken (zijbalk dicht, verbonden, met of zonder pas) en leest per blok top,
hoogte, marge, padding en lettergrootte uit. `meet_rbx.py` draait de echte schermcode door
dezelfde tekenaar als de plaatjes en geeft per vak x, top, breedte en hoogte. Beide rekenen
op een doek van 1536 bij 1000, dus de getallen zijn regel voor regel naast elkaar te leggen
en een verschil is aan te wijzen in plaats van te vermoeden.

Twee dingen die je moet weten voor je iets een fout noemt:

- **Een rand telt anders.** CSS rekent de rand mee in de hoogte die je opgeeft; een
  `UIStroke` ligt buiten het vak. De afspraak hier is daarom: een vak met een streep krijgt
  de maat die de CSS in border-box geeft, en waar het vak padding heeft komt `UI.RAND`
  erbij. De streep valt dan een pixel buiten de lijn die de browser trekt, maar alles
  eronder stapelt precies — en dat is waar een kolom panelen mee staat of valt.
- **Een regel tekst is niet zo hoog als de letter.** De CSS zet nergens een `line-height`,
  dus kiest de browser `normal`: wat het font zelf opgeeft, en dat springt onregelmatig.
  `Theme.lineBox(maat, font)` heeft die hoogtes in de browser opgemeten staan, per maat,
  voor de gewone letter en voor de mono.

Wat Roblox niet kan en wat dus bewust afwijkt: `letter-spacing`, `box-shadow`, gestippelde
randen, radiale verlopen en CSS-filters.

## Stand

| stap | wat | staat |
|---|---|---|
| 0 | skelet, Rojo, testharnas | af |
| 1 | Odds: alle elf spellen | af, 734 bewijzen |
| 2 | thema en UI-bouwstenen | af |
| 3 | netwerklaag en geldregels | af |
| 4 | profiel op DataStore, spellen in een beurt | af, met slot en herhaling |
| 5 | de elf spellen, serverzijdig | alle elf af |
| 3b | de schermen | alle zestien af |
| 6 | seizoenen, VIP, prestaties | af, 34 prestaties en de ranglijst |
| 7 | vrienden, lobby's, gedeelde tafels | af, via Roblox' eigen vrienden en privéservers |
| 8 | review met agents | ronde 1 verwerkt (19 bevindingen) |

Het volledige plan staat in `PLAN.md`.

## Hoe het typechecken werkt

`tools/run_tests.sh` doet vijf dingen:

1. `tools/build_rbxmx.py` bouwt `build/NeonCasino.rbxmx` (het model om in te voegen) en
   `build/install.json` (wat de command-bar-installer ophaalt).
2. `tools/sourcemap.py` maakt `sourcemap.json` uit `default.project.json`. Dat is wat Rojo
   normaal met `rojo sourcemap` doet; deze versie loopt de mappen zelf af zodat het ook
   zonder Rojo werkt. Zonder die kaart kan de analyzer `require(script.Parent.X)` niet volgen.
3. `luau-lsp analyze` met `tools/globalTypes.d.luau` typecheckt elk bestand tegen de echte
   Roblox-API — `Color3`, `Enum`, `Instance`, alles.
4. `tools/bundle_server.py` pakt de serverbestanden in als tekst, zodat de testomgeving
   ze kan laden zonder Studio.
5. De losse Luau-uitvoerder draait elke `tests/*_test.luau`.

Gereedschap zelf ophalen:

```
curl -sSL -o luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
curl -sSL -o lsp.zip  https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip
curl -sSL -o roblox/tools/globalTypes.d.luau \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
unzip luau.zip -d luaubin && unzip lsp.zip -d lspbin && chmod +x luaubin/* lspbin/*
LUAU=./luaubin/luau LSP=./lspbin/luau-lsp bash roblox/tools/run_tests.sh
```
