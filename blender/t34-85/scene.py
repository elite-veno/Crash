"""Ground, sky, sun, backdrop, smoke and the photo camera. BASELINE — the scene builder replaces this."""
from lib import *


def build():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    nt = world.node_tree
    sky = nt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(35)
    sky.sun_rotation = math.radians(200)
    nt.links.new(sky.outputs["Color"], nt.nodes["Background"].inputs["Color"])
    nt.nodes["Background"].inputs["Strength"].default_value = 0.35
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    sun.angle = math.radians(2)
    so = new_object("sun", sun, "scene", rotation=(math.radians(55), 0, math.radians(200)))
    me = mesh_from_pydata("ground", [(-60, -60, 0), (60, -60, 0), (60, 60, 0), (-60, 60, 0)], [(0, 1, 2, 3)])
    new_object("ground", me, "scene", "ground")
    cd = bpy.data.cameras.new("cam_photo")
    cd.lens = 40
    cam = new_object("cam_photo", cd, "scene", location=(4.2, -8.8, 1.7))
    d = Vector((0.4, 0, 1.1)) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
