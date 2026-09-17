#!/usr/bin/env python3
"""Zet de serverbestanden als tekst in een Luau-module, zodat de tests ze kunnen laden
met loadstring() en een nagemaakte Roblox-omgeving eromheen kunnen zetten. De losse
Luau-uitvoerder kan geen bestanden lezen, vandaar deze omweg."""
import pathlib, sys

WORTEL = pathlib.Path(__file__).resolve().parent.parent
BRONNEN = {
    "Profiles": "src/server/Profiles/init.luau",
    "Games": "src/server/Games/init.luau",
    "Multi": "src/server/Games/Multi.luau",
}
UIT = WORTEL / "tests" / "server_sources.luau"


def haakjes(tekst: str) -> str:
    """Een Luau-tekstblok met genoeg = tekens dat de inhoud hem niet kan sluiten."""
    n = 0
    while ("]" + "=" * n + "]") in tekst:
        n += 1
    h = "=" * n
    return "[" + h + "[\n" + tekst + "]" + h + "]"


def main() -> int:
    delen = [
        "-- GEGENEREERD door tools/bundle_server.py -- niet met de hand aanpassen.",
        "return {",
    ]
    for naam, pad in BRONNEN.items():
        p = WORTEL / pad
        if not p.exists():
            print("ontbreekt: " + pad, file=sys.stderr)
            return 1
        delen.append('\t["' + naam + '"] = ' + haakjes(p.read_text()) + ",")
    delen.append("}")
    UIT.write_text("\n".join(delen) + "\n")
    print(UIT.name + " geschreven (" + str(len(BRONNEN)) + " modules)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
