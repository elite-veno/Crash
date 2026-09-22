"""Material library. `lib.get_mat(name)` calls `make(name)` the first time a name is used.

Owned by the materials/scene builder. Every name listed in SPEC.md must be creatable.
These are baseline versions; replace them with properly weathered node setups.
"""
import bpy


def _principled(name, color, rough=0.6, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


BASE = {
    "paint_green": ((0.105, 0.12, 0.065), 0.75, 0.0),
    "paint_green_dark": ((0.07, 0.08, 0.045), 0.75, 0.0),
    "rubber": ((0.02, 0.02, 0.02), 0.85, 0.0),
    "track_steel": ((0.06, 0.05, 0.045), 0.6, 0.8),
    "metal_bare": ((0.5, 0.5, 0.5), 0.35, 1.0),
    "metal_dark": ((0.05, 0.05, 0.05), 0.5, 0.8),
    "glass": ((0.05, 0.07, 0.08), 0.05, 0.0),
    "lens_glass": ((0.3, 0.35, 0.35), 0.02, 0.0),
    "marking_white": ((0.75, 0.75, 0.7), 0.7, 0.0),
    "cable_steel": ((0.12, 0.11, 0.1), 0.55, 0.9),
    "mud": ((0.16, 0.12, 0.08), 0.95, 0.0),
    "grass": ((0.33, 0.28, 0.12), 0.9, 0.0),
    "ground": ((0.25, 0.2, 0.13), 0.95, 0.0),
    "smoke": ((0.8, 0.8, 0.8), 1.0, 0.0),
}


def make(name):
    if name not in BASE:
        return None
    return _principled(name, *BASE[name])
