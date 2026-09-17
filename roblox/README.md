# Neon Casino — Roblox

De game uit `crash.html`, nagebouwd in Luau. Alleen de UI en de systemen; nog geen parts.

## In Studio krijgen

Met [Rojo](https://rojo.space): `rojo serve` in deze map, dan in Studio verbinden.
Zonder Rojo: `tools/bootstrap.luau` in de command bar plakken (komt in stap 3).

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
| 6 | seizoenen, VIP, prestaties | volgt |
| 7 | vrienden, lobby's, gedeelde tafels | volgt |
| 8 | review met agents | ronde 1 verwerkt (19 bevindingen) |

Het volledige plan staat in `PLAN.md`.

## Hoe het typechecken werkt

`tools/run_tests.sh` doet vier dingen:

1. `tools/sourcemap.py` maakt `sourcemap.json` uit `default.project.json`. Dat is wat Rojo
   normaal met `rojo sourcemap` doet; deze versie loopt de mappen zelf af zodat het ook
   zonder Rojo werkt. Zonder die kaart kan de analyzer `require(script.Parent.X)` niet volgen.
2. `luau-lsp analyze` met `tools/globalTypes.d.luau` typecheckt elk bestand tegen de echte
   Roblox-API — `Color3`, `Enum`, `Instance`, alles.
3. `tools/bundle_server.py` pakt de serverbestanden in als tekst, zodat de testomgeving
   ze kan laden zonder Studio.
4. De losse Luau-uitvoerder draait elke `tests/*_test.luau`.

Gereedschap zelf ophalen:

```
curl -sSL -o luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
curl -sSL -o lsp.zip  https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip
curl -sSL -o roblox/tools/globalTypes.d.luau \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
unzip luau.zip -d luaubin && unzip lsp.zip -d lspbin && chmod +x luaubin/* lspbin/*
LUAU=./luaubin/luau LSP=./lspbin/luau-lsp bash roblox/tools/run_tests.sh
```
