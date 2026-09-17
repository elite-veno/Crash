#!/usr/bin/env python3
"""Zet de gedeelde modules en de schermen als tekst in een Luau-bestand, zodat de
voorbeeldtekenaar ze met loadstring kan laden. De losse Luau-uitvoerder kan geen bestanden
lezen, vandaar deze omweg -- dezelfde als bij de servertests."""
import pathlib, sys

HIER = pathlib.Path(__file__).resolve().parent
WORTEL = HIER.parent.parent
UIT = HIER / "sources.luau"


def haakjes(t: str) -> str:
    n = 0
    while ("]" + "=" * n + "]") in t:
        n += 1
    h = "=" * n
    return "[" + h + "[\n" + t + "]" + h + "]"


def main() -> int:
    delen = ["-- GEGENEREERD door tools/preview/bundle.py", "return {"]
    for p in sorted((WORTEL / "src" / "shared").iterdir()):
        f = p / "init.luau"
        if f.exists():
            delen.append('\t["' + p.name + '"] = ' + haakjes(f.read_text()) + ",")
    for f in sorted((WORTEL / "src" / "client" / "Views").glob("*.luau")):
        delen.append('\t["' + f.stem + '"] = ' + haakjes(f.read_text()) + ",")
    icons = WORTEL / "src" / "client" / "Icons" / "init.luau"
    if icons.exists():
        delen.append('\t["Icons"] = ' + haakjes(icons.read_text()) + ",")
    delen.append("}")
    UIT.write_text("\n".join(delen) + "\n")
    print("sources.luau geschreven (" + str(len(delen) - 3) + " modules)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
