# Neon Casino — Roblox

De game uit `crash.html`, nagebouwd in Luau. Alleen de UI en de systemen; nog geen parts.

## In Studio krijgen

Met [Rojo](https://rojo.space): `rojo serve` in deze map, dan in Studio verbinden.
Zonder Rojo: `tools/bootstrap.luau` in de command bar plakken (komt in stap 3).

## Testen zonder Studio

```
bash tools/run_tests.sh
```

Draait `luau-analyze` over elk bestand en daarna elke `tests/*_test.luau`. De wiskunde in
`src/shared/Odds` gebruikt met opzet geen enkel Roblox-type, juist zodat dit kan.

Een Luau-binary halen als je die nog niet hebt:

```
curl -sSL -o luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
unzip luau.zip -d luaubin && chmod +x luaubin/*
LUAU=./luaubin/luau ANALYZE=./luaubin/luau-analyze bash tools/run_tests.sh
```

## Stand

| stap | wat | staat |
|---|---|---|
| 0 | skelet, Rojo, testharnas | af |
| 1 | Odds: alle elf spellen | af, 734 bewijzen |
| 2 | thema en UI-bouwstenen | af |
| 3 | schil: navigatie en schermen | volgt |
| 4 | profiel op DataStore | volgt |
| 5 | de elf spellen | volgt |
| 6 | seizoenen, VIP, prestaties | volgt |
| 7 | vrienden, lobby's, gedeelde tafels | volgt |
| 8 | review met agents | volgt |

Het volledige plan staat in `PLAN.md`.

## Hoe het typechecken werkt

`tools/run_tests.sh` doet drie dingen:

1. `tools/sourcemap.py` maakt `sourcemap.json` uit `default.project.json`. Dat is wat Rojo
   normaal met `rojo sourcemap` doet; deze versie loopt de mappen zelf af zodat het ook
   zonder Rojo werkt. Zonder die kaart kan de analyzer `require(script.Parent.X)` niet volgen.
2. `luau-lsp analyze` met `tools/globalTypes.d.luau` typecheckt elk bestand tegen de echte
   Roblox-API — `Color3`, `Enum`, `Instance`, alles.
3. De losse Luau-uitvoerder draait elke `tests/*_test.luau`.

Gereedschap zelf ophalen:

```
curl -sSL -o luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
curl -sSL -o lsp.zip  https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip
curl -sSL -o roblox/tools/globalTypes.d.luau \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
unzip luau.zip -d luaubin && unzip lsp.zip -d lspbin && chmod +x luaubin/* lspbin/*
LUAU=./luaubin/luau LSP=./lspbin/luau-lsp bash roblox/tools/run_tests.sh
```
