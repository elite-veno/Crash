#!/usr/bin/env python3
"""Meet de Roblox-tekening op: waar staat elk vak, en hoe hoog is het.

    python3 meet_rbx.py <scherm> [naam ...]

Dezelfde getallen als tools/preview/meet_web.js van de webversie geeft, zodat de twee
regel voor regel naast elkaar te leggen zijn. Zonder namen krijg je de boom tot zes
lagen diep; met namen elke tak waar die naam of die tekst in voorkomt, hoe diep ook.

Dit draait de echte schermcode door dezelfde tekenaar als de plaatjes, dus wat hier staat
is wat er getekend wordt -- niet wat de broncode belooft.
"""
import json
import subprocess
import sys
import pathlib
import importlib.util

HIER = pathlib.Path(__file__).parent
LUAU = "/tmp/claude-0/luaubin/luau"


def tekenaar():
    spec = importlib.util.spec_from_file_location("render", HIER / "render.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def boom(scherm):
    subprocess.run([sys.executable, str(HIER / "bundle.py")], cwd=HIER,
                   check=True, stdout=subprocess.DEVNULL)
    uit = subprocess.run([LUAU, "dump.luau", "-a", scherm], cwd=HIER,
                         capture_output=True, text=True, timeout=120)
    laatste = uit.stdout.strip().split("\n")[-1] if uit.stdout.strip() else ""
    if not laatste.startswith("{"):
        print("tekenen mislukt:", (uit.stderr or uit.stdout)[:400], file=sys.stderr)
        raise SystemExit(1)
    return json.loads(laatste)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    scherm, wil = sys.argv[1], [w.lower() for w in sys.argv[2:]]
    R = tekenaar()
    wortel = boom(scherm)

    regels = []
    origineel = R.plaats

    def plaats(n, x, y, b, h, uit, diepte=0):
        p = n["props"]
        # AnchorPoint verschuift het vak; de tekenaar doet dat pas binnenin. Zonder deze
        # correctie leest een vak dat aan de onderkant hangt als stond het onderaan de
        # ouder -- en dan jaag je op een fout die er niet is.
        anker = p.get("AnchorPoint")
        ax, ay = x, y
        if anker and anker.get("t") == "Vector2":
            ax -= anker.get("x", 0) * b
            ay -= anker.get("y", 0) * h
        regels.append((diepte, str(p.get("Name", n["class"])), n["class"], ax, ay, b, h,
                       str(p.get("Text", ""))[:30]))
        return origineel(n, x, y, b, h, uit, diepte)

    R.plaats = plaats
    bb, hh = R.udim2(wortel["props"].get("Size"), 0, 0)
    R.plaats(wortel, 0, 0, bb, hh, [])

    stapel: list = []
    for d, naam, klasse, x, y, b, h, tekst in regels:
        # Zonder een naam zou de hele boom eruit rollen; met een naam wil je juist ook de
        # diepe takken zien.
        if not wil and d > 6:
            continue
        if wil:
            # Een tak die je noemt komt er helemaal uit, met alles wat eronder hangt.
            while stapel and stapel[-1] >= d:
                stapel.pop()
            if any(w in naam.lower() or w in tekst.lower() for w in wil):
                stapel.append(d)
            elif not stapel:
                continue
        staart = ("  «" + tekst + "»") if tekst else ""
        print("%s%-24s %-12s x=%6.1f top=%6.1f b=%6.1f h=%6.1f%s"
              % ("  " * d, naam[:24], klasse, x, y, b, h, staart))
    return 0


if __name__ == "__main__":
    sys.exit(main())
