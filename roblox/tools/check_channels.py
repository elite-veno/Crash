#!/usr/bin/env python3
"""Kijkt of elk kanaal dat client of server aanroept ook echt in Net staat.

Een tikfout in een kanaalnaam is hier bijzonder vervelend: WaitForChild wacht dertig
seconden op iets dat niet bestaat en het scherm meldt daarna alleen dat de server niet
antwoordt -- terwijl er niets mis is met de server. Zo was het noodfonds een tijd lang
onbereikbaar: de twee aanroepen schreven "bet" en "act" in plaats van "Bet" en "Act".

Dit staat hier en niet in tests/, omdat de losse Luau-uitvoerder geen bestanden kan lezen.
"""
import os
import re
import sys

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lees(pad):
    with open(os.path.join(WORTEL, pad), encoding="utf-8") as f:
        return f.read()


def namen_uit(bron, veld):
    blok = re.search(re.escape(veld) + r"\s*=\s*\{(.*?)\n\}", bron, re.S)
    if not blok:
        sys.exit("kon %s niet vinden in Net" % veld)
    return re.findall(r'"([A-Za-z_]\w*)"', blok.group(1))


def main():
    net = lees("src/shared/Net/init.luau")
    bekend = set(namen_uit(net, "Net.FUNCTIONS")) | set(namen_uit(net, "Net.EVENTS"))
    if len(bekend) < 10:
        sys.exit("Net lijkt leeg: %d kanalen" % len(bekend))

    if "onbekend kanaal" not in net:
        sys.exit("Net.fn heeft geen bewaker meer op onbekende namen")

    bestanden = ["src/client/init.client.luau", "src/server/init.server.luau"]
    for map_ in ("src/client/Views", "src/server"):
        vol = os.path.join(WORTEL, map_)
        for naam in sorted(os.listdir(vol)):
            pad = os.path.join(map_, naam)
            if naam.endswith(".luau"):
                bestanden.append(pad)
            elif os.path.isdir(os.path.join(vol, naam)):
                bestanden.append(os.path.join(pad, "init.luau"))

    patronen = [r'Common\.call\("(\w+)"', r'Net\.fn\("(\w+)"', r'Net\.ev\("(\w+)"']
    gevonden, fouten = 0, []
    for pad in bestanden:
        try:
            tekst = lees(pad)
        except FileNotFoundError:
            continue
        for p in patronen:
            for kanaal in re.findall(p, tekst):
                gevonden += 1
                if kanaal not in bekend:
                    fouten.append("%s roept kanaal '%s' aan, dat niet in Net staat" % (pad, kanaal))

    if gevonden < 20:
        sys.exit("te weinig aanroepen gevonden (%d); klopt het zoekpatroon nog?" % gevonden)
    if fouten:
        for f in fouten:
            print("  " + f)
        sys.exit("%d aanroep(en) naar een kanaal dat niet bestaat" % len(fouten))
    print("alle %d kanaalaanroepen wijzen naar een bestaand kanaal (%d kanalen)"
          % (gevonden, len(bekend)))


main()
