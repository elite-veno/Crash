#!/usr/bin/env python3
"""Bouwt twee dingen uit de bronmappen, allebei zonder Rojo:

1. build/NeonCasino.rbxmx -- een Roblox-model om met Insert from File toe te voegen.
2. build/install.json -- dezelfde boom als JSON, die tools/studio_install.luau in de
   command bar van Studio ophaalt. Dan hoeft er niets gedownload te worden: een keer
   plakken installeert de laatste versie, en nog een keer plakken werkt hem bij.

Rojo doet het eerste normaal met `rojo build -o model.rbxmx`. Deze versie leest dezelfde
default.project.json en schrijft het XML zelf, zodat het ook werkt als Rojo er niet is.
"""
import json
import os
import sys

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Net als bij de sourcemap: een init-bestand maakt de MAP zelf tot script.
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


def ontsnap(tekst: str) -> str:
    """XML kent maar drie tekens die stuk kunnen; de rest gaat als UTF-8 mee."""
    return tekst.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Bouwer:
    def __init__(self) -> None:
        self.regels: list[str] = []
        self.teller = 0
        self.scripts = 0

    def ref(self) -> int:
        self.teller += 1
        return self.teller

    def knoop(self, naam: str, soort: str, bron: str | None, diep: int) -> None:
        inspring = "\t" * diep
        self.regels.append(f'{inspring}<Item class="{soort}" referent="RBX{self.ref()}">')
        self.regels.append(f"{inspring}\t<Properties>")
        self.regels.append(f'{inspring}\t\t<string name="Name">{ontsnap(naam)}</string>')
        if bron is not None:
            self.scripts += 1
            self.regels.append(
                f'{inspring}\t\t<ProtectedString name="Source">{ontsnap(bron)}</ProtectedString>'
            )
        self.regels.append(f"{inspring}\t</Properties>")

    def sluit(self, diep: int) -> None:
        self.regels.append("\t" * diep + "</Item>")

    def map(self, pad: str, naam: str, diep: int) -> None:
        vol = os.path.join(WORTEL, pad)
        eigenInit = None
        kinderen = []
        for item in sorted(os.listdir(vol)):
            if item in INIT:
                eigenInit = item
                continue
            volItem = os.path.join(vol, item)
            if os.path.isdir(volItem):
                kinderen.append(("map", os.path.join(pad, item), item))
            elif item.endswith(".luau"):
                kinderen.append(("bestand", os.path.join(pad, item), item))

        if eigenInit:
            bron = open(os.path.join(vol, eigenInit), encoding="utf-8").read()
            self.knoop(naam, INIT[eigenInit], bron, diep)
        else:
            self.knoop(naam, "Folder", None, diep)

        for soort, p, item in kinderen:
            if soort == "map":
                self.map(p, item, diep + 1)
            else:
                bron = open(os.path.join(WORTEL, p), encoding="utf-8").read()
                self.knoop(naamVan(item), soortVan(item), bron, diep + 1)
                self.sluit(diep + 1)
        self.sluit(diep)


def jsonBoom(pad: str, naam: str) -> dict:
    """Dezelfde boom, maar als gewone data: naam, klasse, bron en kinderen."""
    vol = os.path.join(WORTEL, pad)
    eigenInit = None
    kinderen = []
    for item in sorted(os.listdir(vol)):
        if item in INIT:
            eigenInit = item
            continue
        volItem = os.path.join(vol, item)
        if os.path.isdir(volItem):
            kinderen.append(jsonBoom(os.path.join(pad, item), item))
        elif item.endswith(".luau"):
            kinderen.append({
                "name": naamVan(item),
                "class": soortVan(item),
                "source": open(volItem, encoding="utf-8").read(),
            })
    knoop: dict = {"name": naam}
    if eigenInit:
        knoop["class"] = INIT[eigenInit]
        knoop["source"] = open(os.path.join(vol, eigenInit), encoding="utf-8").read()
    else:
        knoop["class"] = "Folder"
    if kinderen:
        knoop["children"] = kinderen
    return knoop


def main() -> int:
    with open(os.path.join(WORTEL, "default.project.json"), encoding="utf-8") as f:
        project = json.load(f)

    # De drie mappen die een eigen plek in de DataModel hebben, met de plek erbij.
    doelen = []

    def loop(knoop: dict, naam: str, ouder: str) -> None:
        pad = knoop.get("$path")
        if pad:
            doelen.append((naam, pad, ouder))
            return
        for k, v in knoop.items():
            if k.startswith("$"):
                continue
            if naam == "":
                pad_ouder = ouder
            elif ouder == "":
                pad_ouder = naam
            else:
                pad_ouder = ouder + "." + naam
            loop(v, k, pad_ouder)

    loop(project["tree"], "", "")

    b = Bouwer()
    b.regels.append('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
                    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
                    'version="4">')
    b.knoop(project["name"], "Folder", None, 1)
    for naam, pad, _ouder in doelen:
        b.map(pad, naam, 2)
    b.sluit(1)
    b.regels.append("</roblox>")

    uitmap = os.path.join(WORTEL, "build")
    os.makedirs(uitmap, exist_ok=True)
    uit = os.path.join(uitmap, project["name"] + ".rbxmx")
    with open(uit, "w", encoding="utf-8") as f:
        f.write("\n".join(b.regels) + "\n")

    kb = os.path.getsize(uit) // 1024
    print(f"build/{project['name']}.rbxmx geschreven -- {b.scripts} scripts, {kb} KB")

    plan = {
        "name": project["name"],
        "roots": [
            {"parent": ouder, "node": jsonBoom(pad, naam)}
            for naam, pad, ouder in doelen
        ],
    }
    uitJson = os.path.join(uitmap, "install.json")
    with open(uitJson, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, separators=(",", ":"))
    print(f"build/install.json geschreven -- {os.path.getsize(uitJson) // 1024} KB")

    for naam, _pad, ouder in doelen:
        print(f"    {naam} hoort in {ouder}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
