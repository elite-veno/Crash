"""Shared helpers for the T-34-85 build. Every part module imports this.

Conventions: metres, +Z up, tank faces +X, +Y is the tank's left. See SPEC.md.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

# ---------------------------------------------------------------------------
# Collections and objects
# ---------------------------------------------------------------------------

def collection(name):
    """Return (creating if needed) a top-level collection."""
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def link(obj, part):
    """Link obj to the collection of `part` (unlinking it from any other)."""
    col = collection(part)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def new_object(name, data, part, mat=None, location=(0, 0, 0), rotation=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = rotation
    link(obj, part)
    if mat is not None and data is not None and hasattr(data, "materials"):
        assign(obj, mat)
    if parent is not None:
        obj.parent = parent
    return obj


def instance(src, name, part, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1), parent=None):
    """Linked duplicate of `src` (shares mesh data) — use for repeated parts."""
    obj = bpy.data.objects.new(name, src.data)
    obj.location = location
    obj.rotation_euler = rotation
    obj.scale = scale
    for m in src.modifiers:  # copy modifier stack
        nm = obj.modifiers.new(m.name, m.type)
        for attr in dir(m):
            if attr.startswith("_") or attr in {"bl_rna", "rna_type", "name", "type", "is_override_data"}:
                continue
            try:
                setattr(nm, attr, getattr(m, attr))
            except (AttributeError, TypeError):
                pass
    link(obj, part)
    if parent is not None:
        obj.parent = parent
    return obj


def mesh_from_bmesh(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def mesh_from_pydata(name, verts, faces, edges=()):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], list(edges), [tuple(f) for f in faces])
    me.validate()
    me.update()
    return me


_TURRET_ROOT = None


def turret_root():
    """Empty at the turret ring centre (x=0.55, z=1.45). Parent turret-mounted objects to it."""
    global _TURRET_ROOT
    obj = bpy.data.objects.get("turret_root")
    if obj is None:
        obj = bpy.data.objects.new("turret_root", None)
        obj.location = (0.55, 0.0, 1.45)
        obj.empty_display_type = "PLAIN_AXES"
        link(obj, "turret")
    _TURRET_ROOT = obj
    return obj


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

def get_mat(name):
    """Look up a material by name; materials.py defines them. Falls back to a grey placeholder."""
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    try:
        import materials
        m = materials.make(name)
    except Exception as exc:  # materials.py broken or unknown name: keep building
        print(f"[lib] material {name!r} fallback ({exc})")
        m = None
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.22, 0.15, 1)
    return m


def assign(obj, mat):
    if isinstance(mat, str):
        mat = get_mat(mat)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


# ---------------------------------------------------------------------------
# Modifiers and shading
# ---------------------------------------------------------------------------

def smooth(obj, angle_deg=35.0):
    """Smooth shading with edges sharper than angle_deg kept hard."""
    me = obj.data
    for p in me.polygons:
        p.use_smooth = True
    if hasattr(me, "set_sharp_from_angle"):
        me.set_sharp_from_angle(angle=math.radians(angle_deg))
    return obj


def bevel(obj, width=0.01, segments=3, angle_deg=30.0, profile=0.5, harden=True):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle_deg)
    m.profile = profile
    m.harden_normals = harden
    m.use_clamp_overlap = True
    return m


def subsurf(obj, levels=2, render_levels=None):
    m = obj.modifiers.new("Subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels if render_levels is None else render_levels
    return m


def weighted_normals(obj):
    m = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    m.keep_sharp = True
    return m


def solidify(obj, thickness, offset=-1.0):
    m = obj.modifiers.new("Solidify", "SOLIDIFY")
    m.thickness = thickness
    m.offset = offset
    m.use_even_offset = True
    return m


def boolean(obj, cutter, operation="DIFFERENCE", solver="EXACT", hide_cutter=True):
    m = obj.modifiers.new(f"Bool_{cutter.name}", "BOOLEAN")
    m.operation = operation
    m.object = cutter
    m.solver = solver
    if hide_cutter:
        cutter.hide_render = True
        cutter.hide_viewport = True
        cutter.display_type = "WIRE"
    return m


def apply_modifiers(obj):
    """Bake the modifier stack into the mesh (evaluated copy)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def displace_noise(obj, strength=0.004, size=0.15, name="CastSurface"):
    """Subtle cast-steel surface roughness via a Displace modifier with a cloud texture."""
    tex = bpy.data.textures.get(name) or bpy.data.textures.new(name, "CLOUDS")
    tex.noise_scale = size
    tex.noise_depth = 2
    m = obj.modifiers.new("Displace", "DISPLACE")
    m.texture = tex
    m.strength = strength
    m.mid_level = 0.5
    m.texture_coords = "GLOBAL"
    return m


# ---------------------------------------------------------------------------
# Geometry builders
# ---------------------------------------------------------------------------

def cylinder(name, radius, depth, part, mat=None, segments=64, location=(0, 0, 0),
             rotation=(0, 0, 0), bevel_width=0.0, cap=True):
    """Cylinder along local Z, centred at origin."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segments,
                          radius1=radius, radius2=radius, depth=depth)
    obj = new_object(name, mesh_from_bmesh(name, bm), part, mat, location, rotation)
    smooth(obj, 40)
    if bevel_width > 0:
        bevel(obj, bevel_width, 2, 40)
    return obj


def lathe(name, profile, part, mat=None, segments=64, location=(0, 0, 0), rotation=(0, 0, 0),
          close=True, smooth_angle=35):
    """Revolve a (r, z) profile around local Z. profile: list of (radius, z) from bottom to top.
    Points with r == 0 become poles. Returns the object."""
    verts, faces = [], []
    n = len(profile)
    ring_idx = []
    for i, (r, z) in enumerate(profile):
        if r <= 1e-6:
            verts.append((0.0, 0.0, z))
            ring_idx.append([len(verts) - 1] * segments)
        else:
            row = []
            for s in range(segments):
                a = 2 * math.pi * s / segments
                verts.append((r * math.cos(a), r * math.sin(a), z))
                row.append(len(verts) - 1)
            ring_idx.append(row)
    for i in range(n - 1):
        a, b = ring_idx[i], ring_idx[i + 1]
        for s in range(segments):
            s2 = (s + 1) % segments
            quad = [a[s], a[s2], b[s2], b[s]]
            uniq = []
            for q in quad:
                if q not in uniq:
                    uniq.append(q)
            if len(uniq) >= 3:
                faces.append(uniq)
    if close:
        if profile[0][0] > 1e-6:
            faces.append(list(reversed(ring_idx[0])))
        if profile[-1][0] > 1e-6:
            faces.append(list(ring_idx[-1]))
    me = mesh_from_pydata(name, verts, faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = new_object(name, me, part, mat, location, rotation)
    smooth(obj, smooth_angle)
    return obj


def loft(name, sections, part, mat=None, close_ends=True, location=(0, 0, 0), smooth_angle=40):
    """Skin a list of closed cross-sections (each a list of Vector/3-tuples with the same point
    count) into a watertight mesh. Great for the cast turret and the hull shell."""
    verts, faces = [], []
    m = len(sections[0])
    for sec in sections:
        assert len(sec) == m, "all sections need the same number of points"
        verts.extend(tuple(p) for p in sec)
    for i in range(len(sections) - 1):
        for j in range(m):
            j2 = (j + 1) % m
            faces.append([i * m + j, i * m + j2, (i + 1) * m + j2, (i + 1) * m + j])
    if close_ends:
        faces.append(list(reversed(range(m))))
        last = (len(sections) - 1) * m
        faces.append([last + j for j in range(m)])
    me = mesh_from_pydata(name, verts, faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = new_object(name, me, part, mat, location)
    smooth(obj, smooth_angle)
    return obj


def extrude_profile(name, profile2d, depth, part, mat=None, axis="Y", location=(0, 0, 0),
                    rotation=(0, 0, 0), centered=True):
    """Extrude a closed 2D polygon. For axis='Y' the profile is (x, z) and depth goes along Y
    (ideal for plates seen from the side, e.g. the hull silhouette)."""
    m = len(profile2d)
    d0, d1 = (-depth / 2, depth / 2) if centered else (0.0, depth)
    verts = []
    for d in (d0, d1):
        for (u, v) in profile2d:
            if axis == "Y":
                verts.append((u, d, v))
            elif axis == "X":
                verts.append((d, u, v))
            else:
                verts.append((u, v, d))
    faces = [list(reversed(range(m))), [m + i for i in range(m)]]
    for i in range(m):
        i2 = (i + 1) % m
        faces.append([i, i2, m + i2, m + i])
    me = mesh_from_pydata(name, verts, faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return new_object(name, me, part, mat, location, rotation)


def tube_along(name, points, radius, part, mat=None, resolution=12, bevel_res=4, cyclic=False,
               to_mesh=True):
    """A round tube following a poly/smooth path — cables, handles, pipes, grab rails."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = bevel_res
    cu.use_fill_caps = True
    cu.resolution_u = resolution
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points):
        p.co = (co[0], co[1], co[2], 1.0)
    sp.order_u = min(4, len(points))
    sp.use_endpoint_u = not cyclic
    sp.use_cyclic_u = cyclic
    obj = new_object(name, cu, part)
    if mat is not None:
        cu.materials.append(get_mat(mat) if isinstance(mat, str) else mat)
    if to_mesh:
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), depsgraph=dg)
        bpy.data.objects.remove(obj)
        obj = new_object(name, me, part)
        smooth(obj, 60)
    return obj


def bolt(name, part, radius=0.012, height=0.008, hex_head=True, mat="paint_green", location=(0, 0, 0),
         rotation=(0, 0, 0)):
    """A bolt head (hex or dome) along local +Z."""
    if hex_head:
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=radius, radius2=radius, depth=height)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
        obj = new_object(name, mesh_from_bmesh(name, bm), part, mat, location, rotation)
        bevel(obj, height * 0.25, 2, 30)
    else:
        obj = lathe(name, [(radius, 0), (radius, height * 0.3), (radius * 0.7, height * 0.9), (0, height)],
                    part, mat, 16, location, rotation)
    return obj


def look_rotation(direction, up=(0, 0, 1)):
    """Euler rotation that points local +Z along `direction`."""
    d = Vector(direction).normalized()
    return d.to_track_quat("Z", "Y").to_euler()


def mirror_y(obj, name=None):
    """Linked mirror copy across y = 0 (for left/right symmetric parts)."""
    cp = obj.copy()
    cp.name = name or obj.name + ".L"
    for c in obj.users_collection:
        c.objects.link(cp)
    cp.location.y = -obj.location.y
    cp.scale.y = -obj.scale.y
    cp.rotation_euler.x = -obj.rotation_euler.x
    cp.rotation_euler.z = -obj.rotation_euler.z
    return cp


__all__ = [n for n in dir() if not n.startswith("_")] + ["Vector", "Matrix", "math", "bmesh", "bpy"]
