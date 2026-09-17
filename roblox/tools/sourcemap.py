#!/usr/bin/env python3
"""Maakt de sourcemap die luau-lsp nodig heeft om require(script.Parent.X) te volgen.

Rojo doet dit normaal met `rojo sourcemap`. Deze versie leest default.project.json en
loopt de mappen af, zodat het typechecken ook werkt zonder Rojo geinstalleerd.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def boom(pad: str, naam: str) -> dict:
    """Een map wordt een Folder; een map met init.luau wordt zelf een ModuleScript."""
    vol = os.path.join(ROOT, pad)
    init = os.path.join(vol, "init.luau")
    kinderen = []
    for item in sorted(os.listdir(vol)):
        vol_item = os.path.join(vol, item)
        if item == "init.luau":
            continue
        if os.path.isdir(vol_item):
            kinderen.append(boom(os.path.join(pad, item), item))
        elif item.endswith(".luau"):
            kinderen.append({
                "name": item[:-5],
                "className": "ModuleScript",
                "filePaths": [os.path.join(pad, item)],
            })
    knoop = {"name": naam}
    if os.path.isfile(init):
        knoop["className"] = "ModuleScript"
        knoop["filePaths"] = [os.path.join(pad, "init.luau")]
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
