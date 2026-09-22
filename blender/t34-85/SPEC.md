# T-34-85 — build specification

Target: a 1:1 replica of the tank in `reference/photo.png` — a Soviet **T-34-85**
(1944/45 pattern, cast turret with the two-piece commander's cupola at the rear left,
85 mm ZiS-S-53 gun with no muzzle brake), painted in faded Soviet 4BO green with
white tactical number **"201"** plus a small white winged emblem on the turret side.
It is driving on a dry, dusty grass field with white smoke drifting at the left and a
tree line behind.

Everything is modelled in real metres, built from Python with `bpy` (Blender 4.2).

## Quality bar (non-negotiable)

- **No box primitives left as-is.** Every armour plate has chamfered or bevelled edges
  (Bevel modifier, 2–3 segments, `limit_method='ANGLE'`), smooth shading with sharp
  edges set by angle (`lib.smooth()`), and correct thickness. Real armour is 45–90 mm thick;
  show that thickness at every exposed edge.
- **Round things are round.** Use enough segments (wheels ≥ 64, barrel ≥ 48, bolts ≥ 12).
- **The cast turret is organic.** Build it by lofting cross-sections or by sculpt-like
  displacement, with a subtle cast-surface roughness, not by combining cubes.
- **Welds, bolts, hinges, rivets, handles** are modelled geometry, not texture.
- Use instancing (linked duplicates) for repeated parts (track links, bolts, wheels) so
  the build stays fast.

## Coordinate system

- Units: metres. +Z up. Ground plane is z = 0 (track bottom touches it).
- The tank faces **+X** (the gun points to +X). **+Y is the tank's left**, −Y its right.
- The photo shows the tank's **right side (−Y)** with the front to the right of the image.
- Origin: x = 0 is the middle of the hull length, y = 0 is the centre line.

## Key dimensions (use these so all parts line up)

| Item | Value |
|---|---|
| Hull length | 6.10 m → nose at x = +3.05, rear at x = −3.05 |
| Overall width (over tracks) | 3.00 m |
| Overall height (cupola top) | 2.72 m |
| Ground clearance / belly | z = 0.40 |
| Lower hull side plates (vertical, between tracks) | y = ±0.97 |
| Upper hull / sponson: fender (track guard) level | z = 0.99, fender outer edge y = ±1.50 |
| Upper hull side plates | 40° from vertical; bottom edge y = ±1.42 at z = 0.99, top edge y = ±1.03 at z = 1.45 |
| Hull roof / deck (turret ring level) | z = 1.45 |
| Upper glacis | 45 mm, 60° from vertical: from nose (x = 3.05, z = 0.85) to (x = 2.01, z = 1.45) |
| Lower glacis | 45 mm, 53° from vertical: from nose (x = 3.05, z = 0.85) to (x = 2.45, z = 0.40) |
| Rear | upper rear plate sloping from engine deck (x ≈ −2.55, z = 1.40) down to (x = −3.05, z = 0.85); lower rear plate back to belly (x = −2.80, z = 0.40) |
| Track centre line | y = ±1.225, track width 0.50 (y 0.975 … 1.475) |
| Track link | pitch 0.172 m, 72 links per side, thickness ≈ 0.06 m; every other link has a centre guide horn |
| Road wheels | 5 per side, Ø 0.830 m (rubber-tyred, double disc with gap for the guide horns), centre z = 0.475 |
| Road wheel centres x | +1.95, +1.07, +0.10, −0.80, −1.68 (gap between 2nd and 3rd is larger) |
| Front idler (x, z) | (+2.62, 0.60), Ø 0.83 (like a road wheel, with crank arm) |
| Rear drive sprocket (x, z) | (−2.63, 0.62), Ø ≈ 0.83, roller-type (6 rollers engage the guide horns) |
| Turret ring | centre (x = +0.55, y = 0), z = 1.45, Ø 1.60 |
| Turret | ~2.60 m long incl. rear bustle, ~2.10 m wide, roof at z ≈ 2.36 |
| Commander cupola | rear-left of turret roof (+Y side), top at z = 2.72 |
| Gun axis | trunnion at (x = +1.30, z = 1.95); barrel runs along +X to the muzzle at x ≈ +5.10 |

## Part ownership (one file per part; never edit a file you don't own)

| File | Contents | Collection name |
|---|---|---|
| `parts/hull.py` | armoured hull: glacis, lower/upper sides, belly, rear plates, deck/engine deck plates, engine grilles, fenders + mudguard flaps, driver hatch, weld seams, turret ring collar | `hull` |
| `parts/running_gear.py` | road wheels, front idler + crank, rear drive sprocket, suspension arms/hubs, hub caps, bolts | `running_gear` |
| `parts/tracks.py` | both tracks as individual links wrapped around sprocket, wheels and idler, with sag between wheels on the top run (the T-34 track rests on the road wheels, there are no return rollers) | `tracks` |
| `parts/turret.py` | cast turret body, gun mantlet, commander cupola + hatch, loader hatch, periscopes, ventilator domes, grab rails, pistol ports, lifting eyes, casting seams | `turret` |
| `parts/gun.py` | 85 mm barrel (tapered tube, muzzle, mantlet sleeve/collar), coaxial MG port | `gun` |
| `parts/hull_details.py` | external fuel tanks, tool boxes, tow cables (coiled + draped on turret front), tow hooks, headlight + horn, bow machine-gun ball mount, grab handles, hinges, exhausts, rear smoke canisters, spare track links, antenna mount | `hull_details` |
| `parts/markings.py` | turret number "201" and emblem as real geometry or a projected decal | `markings` |
| `materials.py` | all materials (`lib.get_mat(name)` looks them up here) | — |
| `scene.py` | ground, grass, trees/backdrop, smoke, sky, sun, photo camera and render settings | `scene` |

Turret, gun, markings and hull details that sit on the turret belong to the turret
coordinate frame: build them relative to the turret ring centre. `lib.turret_root()` returns an
Empty at the ring centre; parent turret-mounted objects to it so the turret can be rotated as
one unit.

## Materials (names available via `lib.get_mat`)

`paint_green` (weathered 4BO green, dust towards the bottom, edge wear), `paint_green_dark`,
`rubber` (road wheel tyres), `track_steel` (dark rusty cast steel, bright on contact faces),
`metal_bare`, `metal_dark`, `glass`, `marking_white`, `cable_steel`, `mud`,
`grass`, `ground`, `smoke`, `lens_glass`.

## Tools

- `python3 run.py --parts all --views photo,side,front34 --out <dir>` builds and renders.
  See `python3 run.py --help`.
- `python3 compare.py <render.png> [--out <file>]` puts the reference photo and a render side by side.
- Renders are small and quick by default (`--res 640 --samples 24`); raise them only for final checks.
