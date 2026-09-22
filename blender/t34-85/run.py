"""Build the T-34-85 and render views.

    python3 run.py --parts all --views photo,side,front34 --out /tmp/renders
    python3 run.py --parts turret,gun --views front34,side,top --frame turret --out /tmp/t
    python3 run.py --parts all --save t34_85.blend --views none

Each part module in parts/ exposes build(). A part that raises is reported and skipped so the
rest still builds. Parts views (anything but `photo`) use a neutral studio unless --scene is set.
"""
import argparse
import importlib
import math
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "parts"))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

PART_ORDER = ["hull", "running_gear", "tracks", "turret", "gun", "hull_details", "markings"]

# name: (direction from target towards camera, orthographic?)
VIEWS = {
    "side": ((0, -1, 0), True),
    "left": ((0, 1, 0), True),
    "front": ((1, 0, 0), True),
    "rear": ((-1, 0, 0), True),
    "top": ((0, 0, 1), True),
    "front34": ((0.75, -1, 0.45), False),
    "rear34": ((-0.8, -1, 0.5), False),
    "front34l": ((0.75, 1, 0.45), False),
    "rear34l": ((-0.8, 1, 0.5), False),
    "low": ((0.35, -1, 0.08), False),
    "high": ((0.4, -0.6, 1.2), False),
}


def parse():
    ap = argparse.ArgumentParser()
    ap.add_argument("--parts", default="all", help="comma list or 'all'")
    ap.add_argument("--views", default="photo,side,front34", help="comma list, 'none', or 'all'. "
                    "Available: photo, " + ", ".join(VIEWS))
    ap.add_argument("--out", default=os.path.join(HERE, "renders"))
    ap.add_argument("--res", type=int, default=640, help="image width in px")
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--frame", default=None, help="part name (or comma list) to frame the views on")
    ap.add_argument("--zoom", type=float, default=1.0, help=">1 moves the camera closer")
    ap.add_argument("--scene", action="store_true", help="use the full scene for all views")
    ap.add_argument("--save", default=None, help="save the .blend here")
    ap.add_argument("--threads", type=int, default=2)
    ap.add_argument("--prefix", default="", help="filename prefix for renders")
    return ap.parse_args()


def build_parts(names):
    errors = {}
    for name in names:
        t = time.time()
        try:
            mod = importlib.import_module(name)
            mod.build()
            print(f"[run] built {name} in {time.time() - t:.1f}s")
        except Exception:
            errors[name] = traceback.format_exc()
            print(f"[run] PART FAILED: {name}\n{errors[name]}")
    return errors


def bbox_of(collections):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    found = False
    for cname in collections:
        col = bpy.data.collections.get(cname)
        if not col:
            continue
        for obj in col.all_objects:
            if obj.type not in {"MESH", "CURVE", "FONT"} or obj.hide_render:
                continue
            for c in obj.bound_box:
                w = obj.matrix_world @ Vector(c)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
                found = True
    if not found:
        return Vector((-3, -1.5, 0)), Vector((5, 1.5, 2.7))
    return lo, hi


def studio(scene):
    world = bpy.data.worlds.new("studio")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.58, 0.62, 1)
    bg.inputs["Strength"].default_value = 0.45
    scene.world = world
    sun = bpy.data.lights.new("studio_sun", "SUN")
    sun.energy = 2.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("studio_sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(so)
    me = bpy.data.meshes.new("studio_floor")
    s = 40
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    fl = bpy.data.objects.new("studio_floor", me)
    m = bpy.data.materials.new("studio_floor")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.35, 0.35, 0.35, 1)
    me.materials.append(m)
    scene.collection.objects.link(fl)


def fallback_photo_camera(scene):
    cam = bpy.data.objects.get("cam_photo")
    if cam:
        return cam
    cd = bpy.data.cameras.new("cam_photo")
    cd.lens = 40
    cam = bpy.data.objects.new("cam_photo", cd)
    scene.collection.objects.link(cam)
    cam.location = (4.2, -8.8, 1.7)
    d = Vector((0.4, 0, 1.1)) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return cam


def view_camera(scene, name, frame_cols, zoom):
    direction, ortho = VIEWS[name]
    lo, hi = bbox_of(frame_cols)
    center = (lo + hi) / 2
    size = hi - lo
    cd = bpy.data.cameras.new("cam_" + name)
    cam = bpy.data.objects.new("cam_" + name, cd)
    scene.collection.objects.link(cam)
    d = Vector(direction).normalized()
    aspect = scene.render.resolution_x / scene.render.resolution_y
    if ortho:
        cd.type = "ORTHO"
        # extent across the image plane
        if name in ("side", "left"):
            w, h = size.x, size.z
        elif name in ("front", "rear"):
            w, h = size.y, size.z
        else:
            w, h = size.x, size.y
        cd.ortho_scale = max(w, h * aspect) * 1.08 / zoom
        cam.location = center + d * 30
        cd.clip_end = 100
    else:
        cd.lens = 50
        radius = size.length / 2
        fov = 2 * math.atan(36 / 2 / cd.lens) / max(1.0, 1.0 / aspect)
        dist = radius / math.sin(min(fov, 2 * math.atan(36 / aspect / 2 / cd.lens)) / 2) * 0.95 / zoom
        cam.location = center + d * dist
        cd.clip_start = 0.02
    up = "Y"
    rot = (center - cam.location).to_track_quat("-Z", up).to_euler()
    cam.rotation_euler = rot
    if name == "top":
        cam.rotation_euler = (0, 0, 0)
    return cam


def setup_render(scene, args):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_adaptive_sampling = True
    try:
        scene.cycles.use_denoising = True
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 6
    scene.render.resolution_x = args.res
    scene.render.resolution_y = int(args.res * 266 / 474)  # same aspect as the photo
    scene.render.resolution_percentage = 100
    scene.render.threads_mode = "FIXED"
    scene.render.threads = args.threads
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"


def main():
    args = parse()
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    parts = PART_ORDER if args.parts == "all" else [p.strip() for p in args.parts.split(",") if p.strip()]
    errors = build_parts(parts)

    views = [] if args.views == "none" else (["photo"] + list(VIEWS) if args.views == "all"
                                               else [v.strip() for v in args.views.split(",")])
    use_scene = args.scene or "photo" in views
    if use_scene:
        try:
            import scene as scene_mod
            scene_mod.build()
        except Exception:
            errors["scene"] = traceback.format_exc()
            print(f"[run] SCENE FAILED\n{errors['scene']}")
            studio(scene)
    else:
        studio(scene)
    setup_render(scene, args)
    if args.save:
        fallback_photo_camera(scene)
        scene.camera = bpy.data.objects["cam_photo"]
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.save))
        print(f"[run] saved {args.save}")

    os.makedirs(args.out, exist_ok=True)
    frame_cols = parts if not args.frame else [p.strip() for p in args.frame.split(",")]
    for v in views:
        if v == "photo":
            cam = fallback_photo_camera(scene)
        elif v in VIEWS:
            cam = view_camera(scene, v, frame_cols, args.zoom)
        else:
            print(f"[run] unknown view {v}")
            continue
        scene.camera = cam
        scene.render.filepath = os.path.join(args.out, f"{args.prefix}{v}.png")
        t = time.time()
        bpy.ops.render.render(write_still=True)
        print(f"[run] rendered {scene.render.filepath} in {time.time() - t:.1f}s")

    if errors:
        print("[run] ===== ERRORS in: " + ", ".join(errors))
    print(f"[run] done in {time.time() - t0:.1f}s")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
