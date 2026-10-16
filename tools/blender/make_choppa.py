"""Builds the player helicopter, assets/models/choppa/choppa.glb.

Run:  python3 tools/blender/make_choppa.py

WW2 / dieselpunk attack helicopter: lofted fuselage with a framed greenhouse canopy,
engine deck with intake slats and exhaust stacks, stub wings with gun and rocket pods,
skids, fin, stabiliser. Blender +Y is the nose (becomes -Z, Godot's forward).
Objects named "rotor" and "tail_rotor" spin in the game; materials are named so the
game can swap in its own: paint, metal, dark, glass, brass, light_red, light_green.
Panel lines, rivets and wear are added by the game's hull shader, so no UVs needed.
"""
import math
import os

import bpy
import bmesh  # Only importable after bpy.

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "choppa", "choppa.glb")
MATS = {}


def mat(name):
    if name not in MATS:
        MATS[name] = bpy.data.materials.new(name)
    return MATS[name]


def obj_from_bmesh(bm, name, material):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat(material))
    return obj


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_all(obj):
    activate(obj)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def subsurf(obj, levels=2):
    obj.modifiers.new("subsurf", "SUBSURF").levels = levels
    apply_all(obj)


def bevel(obj, width, segments=2):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    apply_all(obj)


def smooth(obj):
    activate(obj)
    bpy.ops.object.shade_smooth()


def prim(kind, material, name, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1), **kw):
    getattr(bpy.ops.mesh, "primitive_%s_add" % kind)(location=location, rotation=rotation, **kw)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    activate(o)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    o.data.materials.append(mat(material))
    return o


def loft(name, sections, material, ring=16, exponent=2.6):
    """sections: (y, half_width, half_height, z_center); superellipse rings joined."""
    bm = bmesh.new()
    rings = []
    for y, w, h, zc in sections:
        verts = []
        for i in range(ring):
            a = 2.0 * math.pi * i / ring
            c, s = math.cos(a), math.sin(a)
            x = w * math.copysign(abs(c) ** (2.0 / exponent), c)
            z = zc + h * math.copysign(abs(s) ** (2.0 / exponent), s)
            verts.append(bm.verts.new((x, y, z)))
        rings.append(verts)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(ring):
            j = (i + 1) % ring
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bmesh(bm, name, material)


def cylinder_between(name, a, b, radius, material, verts=10):
    a, b = [x for x in a], [x for x in b]
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
    o = prim("cylinder", material, name, location=mid, vertices=verts, radius=radius, depth=length)
    # Align the cylinder's Z with a->b.
    from mathutils import Vector
    rot = Vector((0, 0, 1)).rotation_difference(Vector((dx, dy, dz)).normalized())
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = rot
    activate(o)
    bpy.ops.object.transform_apply(rotation=True)
    return o


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = []

    # Fuselage: nose at +Y, boxy-rounded sections tapering into the tail boom.
    body = loft("fuselage", [
        (2.55, 0.18, 0.2, -0.15),
        (2.35, 0.55, 0.55, -0.2),
        (1.9, 0.82, 0.78, -0.12),
        (1.1, 0.95, 0.95, 0.0),
        (0.1, 0.98, 1.0, 0.05),
        (-0.8, 0.92, 0.95, 0.1),
        (-1.6, 0.7, 0.75, 0.2),
        (-2.3, 0.38, 0.42, 0.32),
        (-3.2, 0.26, 0.28, 0.38),
        (-4.6, 0.2, 0.22, 0.45),
        (-5.6, 0.16, 0.2, 0.55),
        (-5.8, 0.08, 0.1, 0.58),
    ], "paint", ring=20)
    subsurf(body, 2)
    smooth(body)
    parts.append(body)

    # Greenhouse canopy: a glass dome with a metal frame lattice over it.
    glass = prim("uv_sphere", "glass", "canopy", location=(0, 1.15, 0.3), segments=32, ring_count=16, radius=1.0,
                 scale=(0.86, 1.3, 0.82))
    frame = prim("uv_sphere", "metal", "canopy_frame", location=(0, 1.15, 0.3), segments=10, ring_count=7,
                 radius=1.012, scale=(0.86, 1.3, 0.82))
    for o in (glass, frame):
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.18 or v.co.y < 0.1], context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
    wire = frame.modifiers.new("wire", "WIREFRAME")
    wire.thickness = 0.05
    apply_all(frame)
    smooth(glass)
    parts += [glass, frame]

    # Engine deck behind the cockpit, intake slats on both sides, exhaust stacks.
    deck = prim("cube", "paint", "engine_deck", location=(0, -0.55, 1.02), scale=(0.62, 1.25, 0.32))
    bevel(deck, 0.12, 3)
    parts.append(deck)
    for side in (-1, 1):
        for k in range(7):
            parts.append(prim("cube", "dark", "slat", location=(side * 0.63, -0.05 - k * 0.16, 1.02),
                              scale=(0.03, 0.05, 0.22)))
        pipe = [cylinder_between("exhaust", (side * 0.55, -1.05, 0.95), (side * 0.85, -1.35, 0.85), 0.1, "dark"),
                cylinder_between("exhaust", (side * 0.85, -1.35, 0.85), (side * 0.9, -2.05, 0.7), 0.1, "dark")]
        parts += pipe
        parts.append(cylinder_between("exhaust_tip", (side * 0.9, -2.0, 0.71), (side * 0.91, -2.15, 0.69), 0.12, "metal"))

    # Mast and swashplate (the hub and blades are the separate "rotor" object).
    parts.append(prim("cylinder", "metal", "mast", location=(0, -0.4, 1.5), vertices=16, radius=0.13, depth=0.45))
    parts.append(prim("cylinder", "dark", "swashplate", location=(0, -0.4, 1.42), vertices=20, radius=0.26, depth=0.08))

    # Tail: fin, stabiliser, antenna.
    fin = prim("cube", "paint", "fin", location=(0, -5.45, 1.15), scale=(0.07, 0.45, 0.65))
    bm = bmesh.new()
    bm.from_mesh(fin.data)
    for v in bm.verts:
        if v.co.z > 1.2:
            v.co.y -= 0.35  # Sweep the top back.
    bm.to_mesh(fin.data)
    bm.free()
    bevel(fin, 0.03, 2)
    parts.append(fin)
    stab = prim("cube", "paint", "stabiliser", location=(0, -4.5, 0.5), scale=(0.85, 0.22, 0.035))
    bevel(stab, 0.02, 2)
    parts.append(stab)
    parts.append(cylinder_between("antenna", (0, -3.0, 0.75), (0, -3.5, 1.5), 0.012, "dark", verts=6))

    # Stub wings with gun pods (outer) and rocket pods (under).
    for side in (-1, 1):
        wing = prim("cube", "paint", "stub_wing", location=(side * 1.25, 0.15, -0.05), scale=(0.45, 0.32, 0.05))
        bevel(wing, 0.03, 2)
        parts.append(wing)
        parts.append(cylinder_between("gun_pod", (side * 0.9, 0.5, -0.45), (side * 0.9, 1.75, -0.45), 0.15, "dark", 16))
        parts.append(cylinder_between("gun_barrel", (side * 0.9, 1.7, -0.45), (side * 0.9, 2.25, -0.45), 0.05, "metal", 10))
        parts.append(cylinder_between("gun_mount", (side * 0.9, 1.0, -0.33), (side * 0.9, 1.0, -0.08), 0.05, "metal", 8))
        parts.append(cylinder_between("rocket_pod", (side * 1.45, -0.35, -0.35), (side * 1.45, 0.85, -0.35), 0.22, "paint", 16))
        parts.append(cylinder_between("rocket_face", (side * 1.45, 0.85, -0.35), (side * 1.45, 0.9, -0.35), 0.2, "dark", 16))
        parts.append(cylinder_between("pod_mount", (side * 1.45, 0.25, -0.15), (side * 1.45, 0.25, -0.05), 0.05, "metal", 8))
        light = prim("uv_sphere", "light_red" if side < 0 else "light_green", "nav_light",
                     location=(side * 1.72, 0.15, -0.03), segments=12, ring_count=6, radius=0.06)
        parts.append(light)

    # Skids and struts.
    for side in (-1, 1):
        parts.append(cylinder_between("skid", (side * 0.82, -1.4, -1.18), (side * 0.82, 1.3, -1.18), 0.055, "dark"))
        parts.append(cylinder_between("skid_tip", (side * 0.82, 1.3, -1.18), (side * 0.82, 1.62, -1.0), 0.055, "dark"))
        for y in (-0.8, 0.8):
            parts.append(cylinder_between("strut", (side * 0.55, y, -0.7), (side * 0.82, y, -1.16), 0.04, "metal"))

    fuse = parts[0]
    activate(fuse)
    for p in parts[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    fuse.name = "body"

    # Main rotor: hub and four twisted blades, origin on the mast axis.
    rotor_parts = [prim("cylinder", "metal", "hub", location=(0, 0, 0), vertices=20, radius=0.32, depth=0.16)]
    for k in range(4):
        ang = k * math.pi / 2.0
        blade = prim("cube", "dark", "blade", location=(2.25, 0, 0.02), scale=(2.05, 0.15, 0.022))
        twist = blade.modifiers.new("twist", "SIMPLE_DEFORM")
        twist.deform_method = "TWIST"
        twist.deform_axis = "X"
        twist.angle = math.radians(-8.0)
        apply_all(blade)
        bevel(blade, 0.01, 1)
        grip = prim("cube", "metal", "grip", location=(0.45, 0, 0.0), scale=(0.25, 0.09, 0.07))
        blade_obj = blade
        activate(blade_obj)
        grip.select_set(True)
        bpy.ops.object.join()
        blade_obj.rotation_euler = (0, 0, ang)
        activate(blade_obj)
        bpy.ops.object.transform_apply(rotation=True)
        rotor_parts.append(blade_obj)
    rotor_parts.append(prim("uv_sphere", "brass", "cap", location=(0, 0, 0.1), segments=12, ring_count=6, radius=0.14))
    rotor = rotor_parts[0]
    activate(rotor)
    for p in rotor_parts[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    rotor.name = "rotor"
    rotor.location = (0, -0.4, 1.78)

    # Tail rotor on the left of the fin, spinning around X.
    tail = [prim("cylinder", "metal", "tail_hub", rotation=(0, math.pi / 2, 0), vertices=12, radius=0.09, depth=0.12)]
    for k in range(2):
        b = prim("cube", "dark", "tail_blade", location=(0, 0, 0.42), scale=(0.02, 0.08, 0.4))
        b.rotation_euler = (k * math.pi, 0, 0)
        activate(b)
        bpy.ops.object.transform_apply(rotation=True)
        tail.append(b)
    tail_rotor = tail[0]
    activate(tail_rotor)
    for p in tail[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    tail_rotor.name = "tail_rotor"
    tail_rotor.location = (-0.14, -5.55, 1.1)

    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.abspath(OUT)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects)
    print(f"exported {path} ({tris} triangles)", flush=True)


if __name__ == "__main__":
    build()
