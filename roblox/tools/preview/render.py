#!/usr/bin/env python3
"""Rekent de indeling van een Roblox-UI-boom uit en tekent er SVG van.

Genoeg van Roblox nagerekend om te kunnen zien of een scherm klopt: UIListLayout,
UIGridLayout, UIPadding, AutomaticSize, AnchorPoint, UICorner, UIStroke, UIGradient en
rotatie. Het is geen exacte kopie van de engine -- tekstbreedte wordt geschat -- maar je ziet
wel meteen of een paneel op de verkeerde plek staat of een bord te klein is.
"""
import re
import math
import os
import json
import sys


def kleur(c, val="#000000"):
    if not c or c.get("t") != "Color3":
        return val
    return "#%02x%02x%02x" % (
        max(0, min(255, round(c["r"] * 255))),
        max(0, min(255, round(c["g"] * 255))),
        max(0, min(255, round(c["b"] * 255))),
    )


def udim2(v, ouderB, ouderH):
    if not v or v.get("t") != "UDim2":
        return 0.0, 0.0
    return v["xs"] * ouderB + v["xo"], v["ys"] * ouderH + v["yo"]


def kind(n, klasse):
    for k in n["children"]:
        if k["class"] == klasse:
            return k
    return None


def kinderen(n, klasse):
    return [k for k in n["children"] if k["class"] == klasse]


# Letterbreedtes, als fractie van de tekstgrootte. Nagemeten in de browser op de fonts die
# de webversie gebruikt (Inter en JetBrains Mono), want een vaste factor per teken zit er
# flink naast: een hoofdletter A is 0,69 em en een i 0,24.
#
# Roblox tekent met Gotham, niet met Inter, dus dit blijft een schatting -- maar wel een
# van dezelfde soort letter, en dat scheelt met AutomaticSize tientallen pixels per label.
_GLYPHS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "glyphs.json")))


def tekstBreedte(tekst, maat, font):
    f = str(font)
    tabel = _GLYPHS["num"] if f.startswith("Code") else (
        _GLYPHS["uiMed"] if ("Bold" in f or "Med" in f) else _GLYPHS["ui"])
    standaard = tabel.get("110", 0.55)
    som = 0.0
    for ch in tekst:
        som += tabel.get(str(ord(ch)), standaard)
    return som * maat


def ontleedRijk(tekst):
    """RichText opsplitsen in stukken (tekst, kleur-of-None). Alleen <font color> en <b>,
    want meer gebruikt het project niet. Entiteiten gaan terug naar hun teken."""
    stukken, i, kleurnu = [], 0, None
    while i < len(tekst):
        m = re.compile(r'<font\s+color="([^"]*)"\s*>|</font>|<b>|</b>').search(tekst, i)
        if not m:
            stukken.append((tekst[i:], kleurnu))
            break
        if m.start() > i:
            stukken.append((tekst[i:m.start()], kleurnu))
        if m.group(0).startswith("<font"):
            kleurnu = m.group(1)
        elif m.group(0) == "</font>":
            kleurnu = None
        i = m.end()
    uit = []
    for t, c in stukken:
        t = (t.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"')
              .replace("&apos;", "'").replace("&amp;", "&"))
        if t:
            uit.append((t, c))
    return uit


def breekRegels(stukken, maat, font, breedte):
    """Woordafbreking zoals TextWrapped: vul een regel tot hij niet meer past. Geeft per
    regel een lijst stukken terug, zodat een gekleurd woord zijn kleur houdt."""
    regels, regel, x = [], [], 0.0
    for tekst, c in stukken:
        for woord in re.split(r"(\s+)", tekst):
            if not woord:
                continue
            w = tekstBreedte(woord, maat, font)
            if woord.strip() == "" :
                if regel:
                    regel.append((woord, c)); x += w
                continue
            if x + w > breedte and regel:
                regels.append(regel); regel, x = [], 0.0
            regel.append((woord, c)); x += w
    if regel:
        regels.append(regel)
    return regels or [[]]


def verloopStops(verloop, basis):
    """De stops van een UIGradient als SVG: kleur en doorzichtigheid samen.

    Roblox houdt die twee apart -- Color is een ColorSequence, Transparency een
    NumberSequence -- en ze mogen hun eigen tijdstippen hebben. Hier worden ze samengelegd,
    want een SVG-stop draagt allebei. Zonder de doorzichtigheid tekende een verloop dat naar
    niets uitdooft hier als een volle vlakte.
    """
    # Beide velden kunnen ook een kaal getal of niets zijn: een UIGradient die er niets
    # over zegt staat op de standaardwaarde en wordt dan niet als reeks weggeschreven.
    def reeks(veld):
        v = verloop["props"].get(veld)
        return (v.get("k") or []) if isinstance(v, dict) else []

    kp = reeks("Color")
    tp = reeks("Transparency")
    kleuren = [(k.get("t", 0), kleur(k["v"])) for k in kp if isinstance(k.get("v"), dict)]
    doorzicht = [(k.get("t", 0), k.get("v", 0)) for k in tp if isinstance(k.get("v"), (int, float))]
    if not kleuren and not doorzicht:
        return ""
    if not kleuren:
        kleuren = [(0.0, basis), (1.0, basis)]

    def waarde(punten, t, standaard):
        if not punten:
            return standaard
        if t <= punten[0][0]:
            return punten[0][1]
        if t >= punten[-1][0]:
            return punten[-1][1]
        for i in range(1, len(punten)):
            t0, v0 = punten[i - 1]
            t1, v1 = punten[i]
            if t <= t1:
                if t1 == t0:
                    return v1
                f = (t - t0) / (t1 - t0)
                if isinstance(v0, str):
                    return v0 if f < 0.5 else v1
                return v0 + (v1 - v0) * f
        return punten[-1][1]

    tijden = sorted({t for t, _ in kleuren} | {t for t, _ in doorzicht})
    uit = []
    for t in tijden:
        c = waarde(kleuren, t, basis)
        d = waarde(doorzicht, t, 0.0)
        uit.append('<stop offset="%.4f" stop-color="%s" stop-opacity="%.3f"/>'
                   % (t, c, max(0.0, 1.0 - d)))
    return "".join(uit)


LAYOUTS = ("UIListLayout", "UIGridLayout", "UIPadding", "UICorner", "UIStroke", "UIGradient",
           "UIAspectRatioConstraint", "UITextSizeConstraint", "UIScale", "UISizeConstraint",
           "UIFlexItem", "UITableLayout", "UIPageLayout")


def rasterMaat(raster, binnenB, binnenH, aantal):
    """Celmaat, tussenruimte en het aantal kolommen van een UIGridLayout."""
    rp = raster["props"]
    cel = rp.get("CellSize", {})
    cp = rp.get("CellPadding", {})
    gx = cp.get("xs", 0) * binnenB + cp.get("xo", 0)
    gy = cp.get("ys", 0) * binnenH + cp.get("yo", 0)
    cb = cel.get("xs", 0) * binnenB + cel.get("xo", 0)
    ch = cel.get("ys", 0) * binnenH + cel.get("yo", 0)
    maxCellen = rp.get("FillDirectionMaxCells", 0) or 0
    if maxCellen > 0:
        perRij = int(maxCellen)
    else:
        perRij = max(1, int((binnenB + gx) // max(1, cb + gx)))
    return cb, ch, gx, gy, max(1, perRij)


def beperk(n, b, h):
    """UISizeConstraint knijpt een knoop binnen een maat."""
    c = kind(n, "UISizeConstraint")
    if not c:
        return b, h
    mx = c["props"].get("MaxSize")
    mn = c["props"].get("MinSize")
    if mx and mx.get("t") == "Vector2":
        b, h = min(b, mx["x"]), min(h, mx["y"])
    if mn and mn.get("t") == "Vector2":
        b, h = max(b, mn["x"]), max(h, mn["y"])
    return b, h


def zichtbaar(n):
    return n["props"].get("Visible", True)


def meet(n, ouderB, ouderH):
    """Geeft (breedte, hoogte) van een knoop, met AutomaticSize meegerekend."""
    p = n["props"]
    b, h = udim2(p.get("Size"), ouderB, ouderH)
    auto = p.get("AutomaticSize")

    # de eigen inhoud meten
    pad = kind(n, "UIPadding")
    pl = pr = pt = pb = 0
    if pad:
        pl = pad["props"].get("PaddingLeft", {}).get("o", 0)
        pr = pad["props"].get("PaddingRight", {}).get("o", 0)
        pt = pad["props"].get("PaddingTop", {}).get("o", 0)
        pb = pad["props"].get("PaddingBottom", {}).get("o", 0)

    if auto in ("X", "XY") and n["class"] in ("TextLabel", "TextButton", "TextBox"):
        b = tekstBreedte(p.get("Text", ""), p.get("TextSize", 14), p.get("Font", "")) + pl + pr

    lijst = kind(n, "UILayout") or kind(n, "UIListLayout")
    raster = kind(n, "UIGridLayout")
    echteKinderen = [k for k in n["children"] if k["class"] not in LAYOUTS and zichtbaar(k)]

    # AutomaticSize.X met een liggende UIListLayout erin: de breedte is de som van de
    # kinderen plus de tussenruimte. Zonder dit klapt een knop die zijn tekst in een label
    # heeft staan in plaats van in zijn eigen Text helemaal dicht.
    if auto in ("X", "XY") and echteKinderen and lijst \
            and lijst["props"].get("FillDirection") == "Horizontal":
        gap = lijst["props"].get("Padding", {}).get("o", 0)
        som = 0.0
        for k in echteKinderen:
            kb, _kh = meet(k, max(0.0, b - pl - pr), max(0.0, h - pt - pb))
            som += kb
        b = som + gap * max(0, len(echteKinderen) - 1) + pl + pr

    # Een tekstlabel dat zelf hoog mag worden: Roblox meet de tekst en maakt het label zo
    # hoog als de regels die eruit komen. Zonder dit werd zo'n label op zijn Size gelegd --
    # en dat is bij een omlopende regel nul, waardoor het in de tekening verdween en alles
    # eronder te hoog kwam te staan.
    if auto in ("Y", "XY") and not echteKinderen \
            and n["class"] in ("TextLabel", "TextButton", "TextBox"):
        tekst = p.get("Text", "")
        maat = p.get("TextSize", 14)
        if tekst == "":
            # Een leeg label heeft geen regels, dus ook geen hoogte -- net als een lege div.
            return beperk(n, b, pt + pb)
        stukken = ontleedRijk(tekst) if p.get("RichText") else [(tekst, None)]
        if p.get("TextWrapped"):
            regels = breekRegels(stukken, maat, p.get("Font", ""), max(1.0, b - pl - pr - 4))
        else:
            regels = [stukken]
        h = len(regels) * maat * (p.get("LineHeight", 1) or 1) + pt + pb

    if auto in ("Y", "XY") and echteKinderen:
        binnenB = max(0.0, b - pl - pr)
        if lijst:
            gap = lijst["props"].get("Padding", {}).get("o", 0)
            horizontaal = lijst["props"].get("FillDirection") == "Horizontal"
            tot = 0.0
            hoogste = 0.0
            for k in echteKinderen:
                kb, kh = meet(k, binnenB, 0)
                if horizontaal:
                    hoogste = max(hoogste, kh)
                else:
                    tot += kh
            if horizontaal:
                h = hoogste + pt + pb
            else:
                h = tot + gap * max(0, len(echteKinderen) - 1) + pt + pb
        elif raster:
            cb, ch, gx, gy, perRij = rasterMaat(raster, binnenB, max(0.0, h - pt - pb), len(echteKinderen))
            rijen = (len(echteKinderen) + perRij - 1) // perRij
            h = rijen * ch + max(0, rijen - 1) * gy + pt + pb
        else:
            onderkant = 0.0
            for k in echteKinderen:
                kb, kh = meet(k, binnenB, 0)
                kx, ky = udim2(k["props"].get("Position"), binnenB, 0)
                onderkant = max(onderkant, ky + kh)
            h = onderkant + pt + pb
    return beperk(n, b, h)


def plaats(n, x, y, b, h, uit, diepte=0):
    """Tekent een knoop op (x, y) met maat (b, h) en gaat door met de kinderen."""
    if not zichtbaar(n):
        return
    p = n["props"]
    anker = p.get("AnchorPoint")
    if anker and anker.get("t") == "Vector2":
        x -= anker["x"] * b
        y -= anker["y"] * h

    rot = p.get("Rotation", 0) or 0
    groep = None
    if abs(rot) > 0.01:
        groep = '<g transform="rotate(%.2f %.2f %.2f)">' % (rot, x + b / 2, y + h / 2)
        uit.append(groep)

    # CanvasGroup.GroupTransparency: de hele inhoud gaat als geheel doorschijnen, niet elk
    # onderdeel apart. Zo dimt de webversie een veld dat nog niet aan de beurt is.
    groepDek = None
    gt = p.get("GroupTransparency", 0) or 0
    if gt > 0.001:
        groepDek = '<g opacity="%.3f">' % max(0.0, 1 - gt)
        uit.append(groepDek)

    klasse = n["class"]
    if klasse in ("Frame", "TextLabel", "TextButton", "TextBox", "ScrollingFrame", "ImageLabel"):
        doorzicht = p.get("BackgroundTransparency", 0)
        if doorzicht < 0.999:
            hoek = kind(n, "UICorner")
            r = hoek["props"].get("CornerRadius", {}).get("o", 0) if hoek else 0
            verloop = kind(n, "UIGradient")
            vul = kleur(p.get("BackgroundColor3"), "#ffffff")
            if verloop:
                gid = "g%d" % len(uit)
                stops = verloopStops(verloop, vul)
                if stops:
                    # De richting uit Rotation: 0 is links naar rechts, en de hoek loopt
                    # met de klok mee omdat y in Roblox naar beneden wijst. De lijn gaat
                    # door het midden van het vak, dus hij begint en eindigt een halve
                    # slag aan weerszijden daarvan.
                    draai = math.radians(verloop["props"].get("Rotation", 0) or 0)
                    dx, dy = math.cos(draai) / 2, math.sin(draai) / 2
                    uit.append(
                        '<defs><linearGradient id="%s" x1="%.4f" y1="%.4f" x2="%.4f" y2="%.4f">'
                        "%s</linearGradient></defs>"
                        % (gid, 0.5 - dx, 0.5 - dy, 0.5 + dx, 0.5 + dy, stops))
                    vul = "url(#%s)" % gid
            uit.append(
                '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" '
                'fill-opacity="%.2f"/>' % (x, y, max(0, b), max(0, h), r, vul, 1 - doorzicht))
        streep = kind(n, "UIStroke")
        if streep:
            sp = streep["props"]
            st = sp.get("Transparency", 0)
            if st < 0.999:
                hoek = kind(n, "UICorner")
                r = hoek["props"].get("CornerRadius", {}).get("o", 0) if hoek else 0
                uit.append(
                    '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="none" '
                    'stroke="%s" stroke-width="%.1f" stroke-opacity="%.2f"/>'
                    % (x, y, max(0, b), max(0, h), r, kleur(sp.get("Color"), "#888888"),
                       sp.get("Thickness", 1), 1 - st))

    tekst = p.get("Text", "")
    if klasse in ("TextLabel", "TextButton", "TextBox") and tekst and p.get("TextTransparency", 0) < 0.999:
        maat = p.get("TextSize", 14)
        uitlijn = p.get("TextXAlignment", "Left")
        anchor = {"Left": "start", "Center": "middle", "Right": "end"}.get(str(uitlijn), "start")
        tx = x + (2 if anchor == "start" else (b / 2 if anchor == "middle" else b - 2))
        yalign = str(p.get("TextYAlignment", "Center"))
        if yalign == "Top":
            ty = y + maat
        elif yalign == "Bottom":
            ty = y + h - 2
        else:
            ty = y + h / 2 + maat * 0.36
        font = "monospace" if str(p.get("Font", "")).startswith("Code") else "Inter, sans-serif"
        gewicht = "600" if "Bold" in str(p.get("Font", "")) or "Med" in str(p.get("Font", "")) else "400"
        basis = kleur(p.get("TextColor3"), "#ffffff")
        dek = 1 - p.get("TextTransparency", 0)
        fontnaam = str(p.get("Font", ""))

        # RichText: <font color> geeft een stuk zijn eigen kleur. Staat het uit, dan is de
        # markup gewoon tekst -- precies zoals Roblox het dan ook laat zien.
        stukken = ontleedRijk(tekst) if p.get("RichText") else [(tekst, None)]

        # TextWrapped breekt op woorden binnen de breedte van het label.
        if p.get("TextWrapped"):
            regels = breekRegels(stukken, maat, fontnaam, max(1.0, b - 4))
        else:
            regels = [stukken]

        regelhoogte = maat * (p.get("LineHeight", 1) or 1)
        # Bij meer dan één regel schuift het blok als geheel, net als in Roblox.
        totaal = regelhoogte * len(regels)
        if yalign == "Top":
            y0 = y + maat
        elif yalign == "Bottom":
            y0 = y + h - totaal + maat
        else:
            y0 = y + h / 2 - totaal / 2 + maat * 0.86

        for r, regel in enumerate(regels):
            ry = y0 + r * regelhoogte
            regelB = sum(tekstBreedte(t, maat, fontnaam) for t, _ in regel)
            if anchor == "start":
                rx = x + 2
            elif anchor == "middle":
                rx = x + b / 2 - regelB / 2
            else:
                rx = x + b - 2 - regelB
            for stuk, c in regel:
                veilig = stuk.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                uit.append(
                    '<text x="%.1f" y="%.1f" font-family="%s" font-size="%.1f" font-weight="%s" '
                    'fill="%s" fill-opacity="%.2f" text-anchor="start" '
                    'xml:space="preserve">%s</text>'
                    % (rx, ry, font, maat, gewicht, c or basis, dek, veilig))
                rx += tekstBreedte(stuk, maat, fontnaam)

    # ---------- de kinderen ----------
    # ClipsDescendants: alles buiten het vak wordt afgesneden. Zonder dit lijken de parten
    # van het rad buiten de cirkel te steken, terwijl Roblox ze netjes bijknipt.
    clip = None
    if p.get("ClipsDescendants"):
        hoek = kind(n, "UICorner")
        r = hoek["props"].get("CornerRadius", {}).get("o", 0) if hoek else 0
        cid = "c%d" % len(uit)
        uit.append('<defs><clipPath id="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" '
                   'rx="%.1f"/></clipPath></defs>' % (cid, x, y, max(0, b), max(0, h), r))
        uit.append('<g clip-path="url(#%s)">' % cid)
        clip = True

    pad = kind(n, "UIPadding")
    pl = pr = pt = pb = 0
    if pad:
        pl = pad["props"].get("PaddingLeft", {}).get("o", 0)
        pr = pad["props"].get("PaddingRight", {}).get("o", 0)
        pt = pad["props"].get("PaddingTop", {}).get("o", 0)
        pb = pad["props"].get("PaddingBottom", {}).get("o", 0)
    bx, by = x + pl, y + pt
    bb, bh = max(0.0, b - pl - pr), max(0.0, h - pt - pb)

    echteKinderen = [k for k in n["children"] if k["class"] not in LAYOUTS and zichtbaar(k)]
    # Roblox sorteert op LayoutOrder en houdt bij gelijke waarde de volgorde waarin de
    # kinderen zijn toegevoegd. sorted() in Python is stabiel, dus dat komt overeen.
    echteKinderen = sorted(echteKinderen, key=lambda k: k["props"].get("LayoutOrder", 0))

    lijst = kind(n, "UIListLayout")
    raster = kind(n, "UIGridLayout")

    if lijst:
        lp = lijst["props"]
        gap = lp.get("Padding", {}).get("o", 0)
        horizontaal = lp.get("FillDirection") == "Horizontal"
        maten = [meet(k, bb, bh) for k in echteKinderen]
        totaal = sum((m[0] if horizontaal else m[1]) for m in maten) + gap * max(0, len(maten) - 1)
        hAlign = str(lp.get("HorizontalAlignment", "Left"))
        vAlign = str(lp.get("VerticalAlignment", "Top"))
        if horizontaal:
            cx = bx + (0 if hAlign == "Left" else ((bb - totaal) / 2 if hAlign == "Center" else bb - totaal))
            for k, (kb, kh) in zip(echteKinderen, maten):
                cy = by + (0 if vAlign == "Top" else ((bh - kh) / 2 if vAlign == "Center" else bh - kh))
                plaats(k, cx, cy, kb, kh, uit, diepte + 1)
                cx += kb + gap
        else:
            cy = by + (0 if vAlign == "Top" else ((bh - totaal) / 2 if vAlign == "Center" else bh - totaal))
            for k, (kb, kh) in zip(echteKinderen, maten):
                cx = bx + (0 if hAlign == "Left" else ((bb - kb) / 2 if hAlign == "Center" else bb - kb))
                plaats(k, cx, cy, kb, kh, uit, diepte + 1)
                cy += kh + gap
    elif raster:
        rp = raster["props"]
        cb, ch, gx, gy, perRij = rasterMaat(raster, bb, bh, len(echteKinderen))
        hAlign = str(rp.get("HorizontalAlignment", "Left"))
        rijBreed = perRij * cb + max(0, perRij - 1) * gx
        start = bx + (0 if hAlign == "Left" else ((bb - rijBreed) / 2 if hAlign == "Center" else bb - rijBreed))
        for i, k in enumerate(echteKinderen):
            rij, kol = divmod(i, perRij)
            plaats(k, start + kol * (cb + gx), by + rij * (ch + gy), cb, ch, uit, diepte + 1)
    else:
        for k in echteKinderen:
            kb, kh = meet(k, bb, bh)
            kx, ky = udim2(k["props"].get("Position"), bb, bh)
            plaats(k, bx + kx, by + ky, kb, kh, uit, diepte + 1)

    if clip:
        uit.append("</g>")
    if groepDek:
        uit.append("</g>")
    if groep:
        uit.append("</g>")


def main() -> int:
    boom = json.load(sys.stdin)
    b, h = udim2(boom["props"].get("Size"), 0, 0)
    uit = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
           % (b, h, b, h),
           '<rect width="%d" height="%d" fill="#0e1116"/>' % (b, h)]
    plaats(boom, 0, 0, b, h, uit)
    uit.append("</svg>")
    sys.stdout.write("\n".join(uit))
    return 0


if __name__ == "__main__":
    sys.exit(main())
