#!/usr/bin/env python3
"""Maakt de sourcemap die luau-lsp nodig heeft om require(script.Parent.X) te volgen.

Rojo doet dit normaal met `rojo sourcemap`. Deze versie leest default.project.json en
loopt de mappen af, zodat het typechecken ook werkt zonder Rojo geinstalleerd.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# Zoals Rojo het doet: een init-bestand maakt de MAP zelf tot script, en de soort hangt
# af van het achtervoegsel. Zonder dit onderscheid denkt de analyzer dat init.server een
# gewone kindmodule is, en dan klopt require(script.X) nergens meer.
INIT = {
    "init.luau": "ModuleScript",
    "init.server.luau": "Script",
    "init.client.luau": "LocalScript",
}


def soortVan(bestand: str) -> str:
    if bestand.endswith(".server.luau"):
        return "Script"
    if bestand.endswith(".client.luau"):
        return "LocalScript"
    return "ModuleScript"


def naamVan(bestand: str) -> str:
    for achter in (".server.luau", ".client.luau", ".luau"):
        if bestand.endswith(achter):
            return bestand[: -len(achter)]
    return bestand


def boom(pad: str, naam: str) -> dict:
    """Een map wordt een Folder, tenzij er een init-bestand in zit; dan wordt de map zelf
    dat script."""
    vol = os.path.join(ROOT, pad)
    kinderen = []
    eigenInit = None
    for item in sorted(os.listdir(vol)):
        vol_item = os.path.join(vol, item)
        if item in INIT:
            eigenInit = item
            continue
        if os.path.isdir(vol_item):
            kinderen.append(boom(os.path.join(pad, item), item))
        elif item.endswith(".luau"):
            kinderen.append({
                "name": naamVan(item),
                "className": soortVan(item),
                "filePaths": [os.path.join(pad, item)],
            })
    knoop = {"name": naam}
    if eigenInit:
        knoop["className"] = INIT[eigenInit]
        knoop["filePaths"] = [os.path.join(pad, eigenInit)]
    else:
        knoop["className"] = "Folder"
    if kinderen:
        knoop["children"] = kinderen
    return knoop


def main() -> int:
    with open(os.path.join(ROOT, "default.project.json")) as f:
        project = json.load(f)

    def loop(knoop: dict, naam: str) -> dict:
        pad = knoop.get("$path")
        if pad:
            uit = boom(pad, naam)
            uit["className"] = knoop.get("$className", uit["className"])
            return uit
        uit = {"name": naam, "className": knoop.get("$className", "Folder")}
        kinderen = [loop(v, k) for k, v in knoop.items() if not k.startswith("$")]
        if kinderen:
            uit["children"] = kinderen
        return uit

    kaart = loop(project["tree"], project["name"])
    with open(os.path.join(ROOT, "sourcemap.json"), "w") as f:
        json.dump(kaart, f, indent=1)
    print("sourcemap.json geschreven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
