"""Sculpts the rock formations in assets/models/rocks as .glb files.

Run:  python3 tools/blender/make_rocks.py [name ...]

Shapes are built from primitives and booleans, voxel-remeshed for even topology, then
displaced in Python: large lumpy noise, fine grain, and horizontal weathering grooves
(strata) that only bite into steep faces. No UVs: the game textures them triplanar.
Blender is Z-up; the glTF exporter converts to Godot's Y-up.
"""
import math
import os
import sys

import bpy
from mathutils import Vector, noise

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "rocks")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_modifiers(obj):
    activate(obj)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def cut(obj, cutter):
    mod = obj.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    apply_modifiers(obj)
    bpy.data.objects.remove(cutter)


def join(objs):
    activate(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.ops.object.join()
    return objs[0]


def remesh(obj, voxel):
    mod = obj.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    apply_modifiers(obj)


def decimate(obj, target_tris):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= target_tris:
        return
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = target_tris / tris
    apply_modifiers(obj)


def displace(obj, lumps, lump_scale, grain, groove_depth=0.0, groove_spacing=6.0, seed=0.0,
             keep=lambda co: 1.0):
    """Pushes every vertex along its normal. Grooves only cut into steep faces."""
    mesh = obj.data
    off = Vector((seed * 37.1, seed * 11.3, seed * 5.7))
    for v in mesh.vertices:
        p = v.co
        n = v.normal
        k = keep(p)
        amount = noise.fractal((p + off) * lump_scale, 0.6, 2.0, 4) * lumps
        amount += noise.fractal((p + off) * lump_scale * 6.0, 0.7, 2.1, 3) * grain
        if groove_depth:
            steep = max(0.0, 1.0 - abs(n.z) * 1.6)
            wobble = noise.noise((p + off) * 0.05) * 1.5
            phase = (p.z + wobble) / groove_spacing
            band = 0.5 + 0.5 * math.cos(2.0 * math.pi * phase)
            amount -= (band ** 6) * groove_depth * steep
        v.co = p + n * amount * k


def finish(obj, name, target_tris):
    decimate(obj, target_tris)
    activate(obj)
    bpy.ops.object.shade_smooth()
    obj.name = name
    path = os.path.abspath(os.path.join(OUT, name + ".glb"))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="NONE")
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"exported {path} ({tris} triangles)", flush=True)


# ---- shapes -------------------------------------------------------------------

def mesa():
    """Table mountain, ~110 m across and 44 m tall, with two crossing tunnels
    (22 m wide, 17 m high, arched) along X and Y. Origin at ground level."""
    reset()
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=56.0, depth=48.0, location=(0, 0, 20.0))
    body = bpy.context.active_object
    # Irregular footprint: push the rim in and out.
    for v in body.data.vertices:
        ang = math.atan2(v.co.y, v.co.x)
        r = 1.0 + 0.08 * math.sin(ang * 3.0 + 0.7) + 0.05 * math.sin(ang * 7.0 + 2.1)
        v.co.x *= r
        v.co.y *= r
    remesh(body, 1.2)
    # Each tunnel is a box (walls) plus a lying cylinder (arched roof). Cut them one at
    # a time: the exact solver dislikes a self-intersecting combined cutter.
    for rot in (0.0, math.pi / 2.0):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 3.5), rotation=(0, 0, rot))
        box = bpy.context.active_object
        box.scale = (150.0, 22.0, 13.0)
        cut(body, box)
        bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=11.0, depth=150.0, location=(0, 0, 6.0),
                                            rotation=(0, math.pi / 2.0, rot))
        cut(body, bpy.context.active_object)
    remesh(body, 0.9)

    def keep(co):
        # Gentle inside the tunnels so they stay flyable, full strength outside.
        in_x = abs(co.y) < 14.0 and co.z < 19.0
        in_y = abs(co.x) < 14.0 and co.z < 19.0
        return 0.35 if (in_x or in_y) else 1.0

    displace(body, lumps=3.2, lump_scale=0.03, grain=0.5, groove_depth=1.6, groove_spacing=5.5,
             seed=1.0, keep=keep)
    finish(body, "mesa", 60000)


def arch(seed):
    """Natural sandstone arch: span ~30 m, ~22 m tall, feet go 3 m into the ground."""
    reset()
    bpy.ops.mesh.primitive_torus_add(major_radius=15.0, minor_radius=4.5, major_segments=64,
                                     minor_segments=20, rotation=(math.pi / 2.0, 0, 0))
    ring = bpy.context.active_object
    apply_modifiers(ring)
    activate(ring)
    bpy.ops.object.transform_apply(rotation=True)
    # Thicker feet, thinner span, flattened to a slab front-to-back.
    for v in ring.data.vertices:
        t = max(0.0, v.co.z) / 19.5
        width = 1.5 - 0.6 * t
        v.co.y *= width
        v.co.x *= 1.0 + 0.1 * (1.0 - t)
    # Cut away everything below ground.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -23.0))
    floor = bpy.context.active_object
    floor.scale = (100.0, 100.0, 40.0)
    activate(floor)
    bpy.ops.object.transform_apply(scale=True)
    cut(ring, floor)
    remesh(ring, 0.45)
    displace(ring, lumps=1.6, lump_scale=0.06, grain=0.25, groove_depth=0.7, groove_spacing=3.0, seed=seed)
    activate(ring)
    ring.location.z = 3.0  # So the ground can hide the cut feet when sunk 3 m.
    bpy.ops.object.transform_apply(location=True)
    finish(ring, "arch_%d" % int(seed), 14000)


def hoodoo(seed, height, radius):
    """Eroded rock column with a wider cap rock."""
    reset()
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=height, location=(0, 0, height / 2.0))
    column = bpy.context.active_object
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius * 1.45, depth=radius * 0.9,
                                        location=(0.3, -0.2, height + radius * 0.3))
    cap = bpy.context.active_object
    body = join([column, cap])
    remesh(body, 0.35)
    # Waist the column in and out with height, like stacked weathered layers.
    for v in body.data.vertices:
        if v.co.z < height - 0.5:
            r = 1.0 + 0.16 * math.sin(v.co.z * 0.55 + seed) + 0.08 * math.sin(v.co.z * 1.7 + seed * 2.0)
            v.co.x *= r
            v.co.y *= r
    displace(body, lumps=0.7, lump_scale=0.12, grain=0.15, groove_depth=0.35, groove_spacing=2.2, seed=seed)
    finish(body, "hoodoo_%d" % int(seed), 9000)


def boulder(seed):
    """Unit-sized boulder (about 2 m across), flat-ish bottom."""
    reset()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=1.0)
    rock = bpy.context.active_object
    off = Vector((seed * 3.1, seed * 7.7, seed * 1.3))
    for v in rock.data.vertices:
        p = v.co.copy()
        d = noise.fractal(p * 0.9 + off, 0.55, 2.0, 5) * 0.32
        cell = noise.voronoi(p * 1.4 + off)[0][0]
        d -= cell * 0.25
        v.co = p * (1.0 + d)
        if v.co.z < -0.35:
            v.co.z = -0.35 + (v.co.z + 0.35) * 0.2
    rock.scale = (1.0 + 0.3 * math.sin(seed), 1.0, 0.75 + 0.15 * math.cos(seed * 2.0))
    activate(rock)
    bpy.ops.object.transform_apply(scale=True)
    finish(rock, "boulder_%d" % int(seed), 2200)


SHAPES = {
    "mesa": mesa,
    "arch_1": lambda: arch(1.0), "arch_2": lambda: arch(2.0),
    "hoodoo_1": lambda: hoodoo(1.0, 30.0, 4.0), "hoodoo_2": lambda: hoodoo(2.0, 42.0, 4.5),
    "hoodoo_3": lambda: hoodoo(3.0, 22.0, 3.4),
    "boulder_1": lambda: boulder(1.0), "boulder_2": lambda: boulder(2.0),
    "boulder_3": lambda: boulder(3.0), "boulder_4": lambda: boulder(4.0),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or list(SHAPES):
        SHAPES[name]()


if __name__ == "__main__":
    main()
