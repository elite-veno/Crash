# Neon Casino — Roblox

De game uit `crash.html`, nagebouwd in Luau. Alleen de UI en de systemen; nog geen parts.

## In Studio krijgen

Belangrijk: wat hier in de repo staat, komt **niet vanzelf** in je place terecht. Een
Roblox-place is een bestand op Roblox' servers; deze map is code op GitHub. Er moet een
keer iets van hier naar daar. Twee manieren:

### Een keer plakken in Studio (het snelst)

View > **Command Bar**, en plak de inhoud van `tools/studio_install.luau`. Studio haalt
de laatste code zelf van GitHub en zet hem op zijn plek. Nog een keer plakken werkt alles
bij: de oude mappen gaan eerst weg. Er hoeft niets gedownload te worden.

Werkt dat niet, dan staat HTTP waarschijnlijk uit: File > Game Settings > Security >
**Allow HTTP Requests**. Daarna opnieuw plakken.

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
`tests/*_test.luau` — samen bijna duizend beweringen. De wiskunde in `src/shared/Odds`
gebruikt met opzet geen enkel Roblox-type, juist zodat dit kan.

De serverbestanden gebruiken die types wel, en worden toch getest: `tools/bundle_server.py`
zet ze als tekst in `tests/server_sources.luau`, en `tests/roblox_stub.luau` laadt ze met
`loadstring` in een nagemaakte omgeving — eigen `Players`, eigen DataStore, eigen trekker.
Daardoor draait `tests/server_test.luau` op de code die straks echt in Studio staat, en
niet op een kopie ervan. Dat is de plek waar de valsspeelwegen getest worden: dezelfde
mijnentegel twee keer insturen, een inzet van NaN, een call bij Ride the Bus die niet kan
uitkomen, weggaan met een ronde open, en twee servers die dezelfde speler willen opslaan.

## Stand

| stap | wat | staat |
|---|---|---|
| 0 | skelet, Rojo, testharnas | af |
| 1 | Odds: alle elf spellen | af, 734 bewijzen |
| 2 | thema en UI-bouwstenen | af |
| 3 | netwerklaag en geldregels | af |
| 4 | profiel op DataStore, spellen in een beurt | af, met slot en herhaling |
| 5 | de elf spellen, serverzijdig | negen af, crash en blackjack volgen |
| 3b | de schermen | acht spellen hebben hun scherm; de rest volgt |
| 6 | seizoenen, VIP, prestaties | volgt |
| 7 | vrienden, lobby's, gedeelde tafels | volgt |
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
