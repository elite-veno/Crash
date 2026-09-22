"""Armoured hull. PLACEHOLDER — the hull builder replaces this. See SPEC.md."""
from lib import *


def build():
    prof = [(3.05, 0.85), (2.45, 0.40), (-2.80, 0.40), (-3.05, 0.85), (-2.55, 1.40), (2.01, 1.45)]
    obj = extrude_profile("hull_lower", prof, 1.94, "hull", "paint_green")
    bevel(obj, 0.02, 2)
    up = extrude_profile("hull_sponson", [(3.0, 0.9), (-3.0, 0.9), (-2.6, 1.42), (2.05, 1.44)], 2.9, "hull", "paint_green")
    bevel(up, 0.02, 2)
