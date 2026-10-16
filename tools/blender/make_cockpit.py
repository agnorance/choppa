"""Builds the cockpit interior, assets/models/choppa/cockpit.glb.

Run:  python3 tools/blender/make_cockpit.py

Origin = the pilot's eye. The canopy frame and the tub walls come from choppa_shared.py,
the same geometry the exterior (make_choppa.py) uses. Blender +Y is forward (Godot -Z). The static shell (panel,
glare shield, consoles, tub, inner canopy frame, switches) is one mesh; the stick and
collective are separate objects so the game can move them. Empty objects named
"mount_*" mark where the game puts live instruments: their local -Y (Godot +Z) points
out of the panel toward the pilot. Materials: paint, metal, dark, brass.
"""
import math
import os

import sys

import bpy
import bmesh  # Only importable after bpy.
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import choppa_shared as shared  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "choppa", "cockpit.glb")
MATS = {}
PANEL_TILT = math.radians(-30.0)  # Lean the panel back so it faces the eye.
# Low and compact: the panel fills 13-32 degrees below the horizon (all of it on screen
# at the 70 degree FOV), the rest is window. It stands on a pedestal in the chin glass.
PANEL_CENTER = Vector((0.0, 0.64, -0.26))
PANEL_HALF = (0.44, 0.12)


def mat(name):
    if name not in MATS:
        MATS[name] = bpy.data.materials.new(name)
    return MATS[name]


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_all(obj):
    activate(obj)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel(obj, width, segments=2):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    apply_all(obj)


def prim(kind, material, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1), bevel_width=0.0, **kw):
    getattr(bpy.ops.mesh, "primitive_%s_add" % kind)(location=location, rotation=rotation, **kw)
    o = bpy.context.active_object
    o.scale = scale
    activate(o)
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    if bevel_width:
        bevel(o, bevel_width)
    o.data.materials.append(mat(material))
    return o


def on_panel(x, y_up, out=0.0):
    """Point on the tilted panel plane: x across, y_up along the panel, out toward the eye."""
    local = Vector((x, -out, y_up))
    return PANEL_CENTER + Euler((PANEL_TILT, 0, 0)).to_matrix() @ local


def panel_prim(kind, material, x, y_up, out, scale, rotation=(0, 0, 0), bevel_width=0.0, **kw):
    rot = Euler((PANEL_TILT + rotation[0], rotation[1], rotation[2]))
    return prim(kind, material, location=on_panel(x, y_up, out), rotation=rot, scale=scale,
                bevel_width=bevel_width, **kw)


def mount(name, x, y_up, out=0.0):
    empty = bpy.data.objects.new("mount_" + name, None)
    empty.location = on_panel(x, y_up, out)
    empty.rotation_euler = (PANEL_TILT, 0, 0)
    if name == "beacon":
        # Stands upright on top of the glare shield.
        empty.location += Vector((0, 0, 0.045))
        empty.rotation_euler = (0, 0, 0)
    bpy.context.collection.objects.link(empty)
    return empty


def cylinder_between(a, b, radius, material, verts=10):
    a, b = Vector(a), Vector(b)
    o = prim("cylinder", material, vertices=verts, radius=radius, depth=(b - a).length)
    rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    o.data.transform(Matrix.Translation((a + b) / 2) @ rot)
    return o


def strut(points, radius=0.022, material="paint", sides=12):
    """A bent canopy frame member (a swept tube) through model-space points, in eye space."""
    points = [p - shared.EYE for p in points]
    bm = bmesh.new()
    rings = []
    normal = None
    for k, p in enumerate(points):
        t = (points[min(k + 1, len(points) - 1)] - points[max(k - 1, 0)]).normalized()
        normal = t.orthogonal().normalized() if normal is None else (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        rings.append([bm.verts.new(p + (normal * math.cos(a) + binormal * math.sin(a)) * radius)
                      for a in (2 * math.pi * i / sides for i in range(sides))])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    o = _mesh_object(bm, "strut")
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    return [o]


FLOOR_Z = shared.EYE.z - 1.0  # Model space.


def _mesh_object(bm, name):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("paint"))
    return o


def tub_wall():
    """Inner cockpit wall hanging from the sill down to the floor, following the egg.
    Toward the nose the sill drops below the floor and the wall runs out: chin glass."""
    bm = bmesh.new()
    sill = [p for p in shared.sill_points(-0.05, 48)]
    top = [bm.verts.new(p - shared.EYE) for p in sill]
    bottom = [bm.verts.new(Vector((p.x, p.y, min(p.z, FLOOR_Z))) - shared.EYE) for p in sill]
    c = shared.EGG_CENTER
    inner = [bm.verts.new(Vector((p.x * 0.9, c.y + (p.y - c.y) * 0.95, p.z)) - shared.EYE) for p in sill]
    for k in range(len(sill) - 1):
        if sill[k].z <= FLOOR_Z and sill[k + 1].z <= FLOOR_Z:
            continue
        bm.faces.new((top[k], top[k + 1], bottom[k + 1], bottom[k]))
        bm.faces.new((inner[k], inner[k + 1], top[k + 1], top[k]))  # Sill ledge.
    o = _mesh_object(bm, "tub")
    solid = o.modifiers.new("solid", "SOLIDIFY")
    solid.thickness = 0.02
    apply_all(o)
    return o


def floor():
    bm = bmesh.new()
    outline = shared.floor_outline(FLOOR_Z, 0.06, y_max=1.9)
    top = [bm.verts.new(p - shared.EYE) for p in outline]
    low = [bm.verts.new(p - shared.EYE - Vector((0, 0, 0.03))) for p in outline]
    bm.faces.new(top)
    bm.faces.new(list(reversed(low)))
    for k in range(len(top)):
        j = (k + 1) % len(top)
        bm.faces.new((top[k], low[k], low[j], top[j]))
    return _mesh_object(bm, "floor")


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = []

    # Compact instrument panel: board, raised rim, rivets.
    hw, hh = PANEL_HALF
    shell.append(panel_prim("cube", "paint", 0, 0, 0.0, (hw, 0.025, hh), bevel_width=0.01))
    for yu in (hh, -hh):
        shell.append(panel_prim("cube", "dark", 0, yu, 0.02, (hw + 0.01, 0.03, 0.012), bevel_width=0.006))
    for k in range(5):
        for x in (-hw + 0.02, hw - 0.02):
            shell.append(panel_prim("uv_sphere", "metal", x, -0.08 + k * 0.04, 0.027, (0.006, 0.006, 0.006),
                                    segments=8, ring_count=4))
    # Thin coaming rail along the top edge (no tall glare shield: keep the view open).
    shell.append(prim("cube", "dark", location=on_panel(0, hh + 0.01, 0.05) + Vector((0, 0, 0.015)),
                      rotation=(math.radians(10), 0, 0), scale=(hw, 0.05, 0.012), bevel_width=0.008))

    def bezel(x, yu, radius, material="brass", screws=4):
        """Instrument bezel ring with screw heads."""
        out = [panel_prim("torus", material, x, yu, 0.028, (1, 1, 1), rotation=(math.pi / 2, 0, 0),
                          major_radius=radius, minor_radius=0.008, major_segments=40, minor_segments=8),
               panel_prim("cylinder", "dark", x, yu, 0.024, (1, 1, 1), rotation=(math.pi / 2, 0, 0),
                          vertices=40, radius=radius + 0.004, depth=0.008)]
        for k in range(screws):
            a = math.pi / 4 + k * 2 * math.pi / screws
            out.append(panel_prim("cylinder", "metal", x + math.cos(a) * (radius + 0.016),
                                  yu + math.sin(a) * (radius + 0.016), 0.03, (1, 1, 1),
                                  rotation=(math.pi / 2, 0, 0), vertices=10, radius=0.006, depth=0.006))
        return out

    # Left: four gauges in a 2x2 block.
    for (x, yu), name in zip([(-0.33, 0.054), (-0.2, 0.054), (-0.33, -0.058), (-0.2, -0.058)],
                             ["speed", "altitude", "boost", "heat"]):
        shell += bezel(x, yu, 0.054)
        mount(name, x, yu, 0.026)
    # Lower panel, angled on down toward the floor so no gap opens under the main panel
    # when the view widens at speed: rotor gauge, switch rows and placards.
    lower = -hh - 0.15
    shell.append(panel_prim("cube", "paint", 0, lower, -0.005, (hw - 0.03, 0.022, 0.15), bevel_width=0.01))
    shell.append(panel_prim("cube", "dark", 0, lower - 0.15, 0.015, (hw - 0.02, 0.03, 0.012), bevel_width=0.006))
    for k in range(4):
        for x in (-hw + 0.05, hw - 0.05):
            shell.append(panel_prim("uv_sphere", "metal", x, lower - 0.1 + k * 0.065, 0.02, (0.006, 0.006, 0.006),
                                    segments=8, ring_count=4))
    shell += bezel(-0.27, lower + 0.02, 0.054)
    mount("rpm", -0.27, lower + 0.02, 0.026)
    for row in range(2):
        for k in range(6):
            x = 0.04 + k * 0.055
            yu = lower + 0.06 - row * 0.09
            shell.append(panel_prim("cylinder", "metal", x, yu, 0.025, (1, 1, 1), rotation=(math.pi / 2, 0, 0),
                                    vertices=12, radius=0.01, depth=0.012))
            shell.append(panel_prim("cylinder", "metal", x, yu + 0.012, 0.04, (1, 1, 1),
                                    rotation=(math.pi / 2 - 0.5 + (0.9 if (k + row) % 3 == 0 else 0.0), 0, 0),
                                    vertices=8, radius=0.0035, depth=0.035))
            shell.append(panel_prim("cube", "brass", x, yu - 0.022, 0.022, (0.018, 0.003, 0.006)))
    shell.append(panel_prim("cube", "dark", -0.08, lower + 0.04, 0.02, (0.06, 0.012, 0.035), bevel_width=0.004))
    shell.append(panel_prim("cube", "brass", -0.08, lower - 0.07, 0.02, (0.07, 0.006, 0.025), bevel_width=0.003))

    # Centre: the radar in its own hooded housing, below the gunsight.
    shell.append(panel_prim("cube", "dark", 0.0, -0.012, 0.04, (0.11, 0.05, 0.11), bevel_width=0.02))
    shell.append(panel_prim("torus", "metal", 0.0, -0.012, 0.09, (1, 1, 1), rotation=(math.pi / 2, 0, 0),
                            major_radius=0.092, minor_radius=0.01, major_segments=44, minor_segments=8))
    for k in range(6):
        a = k * math.pi / 3
        shell.append(panel_prim("uv_sphere", "brass", math.cos(a) * 0.104, -0.012 + math.sin(a) * 0.104, 0.092,
                                (0.007, 0.007, 0.007), segments=8, ring_count=4))
    mount("radar", 0.0, -0.012, 0.097)
    # Right: nixie kill counter, hull lamp bar, ordnance plate, warning lamp column.
    shell.append(panel_prim("cube", "dark", 0.21, 0.07, 0.025, (0.055, 0.025, 0.04), bevel_width=0.006))
    mount("kills", 0.21, 0.07, 0.05)
    shell.append(panel_prim("cube", "dark", 0.22, -0.015, 0.02, (0.085, 0.015, 0.025), bevel_width=0.005))
    mount("health", 0.22, -0.015, 0.036)
    shell.append(panel_prim("cube", "dark", 0.22, -0.08, 0.02, (0.085, 0.015, 0.028), bevel_width=0.005))
    mount("item", 0.22, -0.08, 0.036)
    for k, name in enumerate(["missile", "overheat", "shield", "scrambled"]):
        yu = 0.075 - k * 0.05
        shell.append(panel_prim("cylinder", "brass", 0.37, yu, 0.025, (1, 1, 1), rotation=(math.pi / 2, 0, 0),
                                vertices=16, radius=0.021, depth=0.016))
        mount("lamp_" + name, 0.37, yu, 0.035)
    mount("beacon", 0.36, hh + 0.01, 0.05)

    # Reflector gunsight on a short post from the coaming, its glass dead ahead of the eye.
    # The game draws the reticle at "mount_sight". It stands above the radar, not in front.
    top = on_panel(0, hh + 0.01, 0.05) + Vector((0, 0, 0.02))
    shell.append(cylinder_between(top, (0, 0.6, -0.13), 0.014, "metal", 10))
    shell.append(prim("cylinder", "dark", location=(0, 0.6, -0.11), vertices=24, radius=0.045, depth=0.04,
                      bevel_width=0.008))
    shell.append(prim("torus", "brass", location=(0, 0.6, -0.09), major_radius=0.045, minor_radius=0.006,
                      major_segments=28, minor_segments=6))
    for side in (-1, 1):
        shell.append(cylinder_between((side * 0.04, 0.6, -0.09), (side * 0.04, 0.6, 0.06), 0.005, "metal", 6))
    sight = bpy.data.objects.new("mount_sight", None)
    sight.location = (0, 0.6, 0.0)
    bpy.context.collection.objects.link(sight)

    # Side consoles with toggle switches and rotary knobs.
    for side in (-1, 1):
        shell.append(prim("cube", "paint", location=(side * 0.56, 0.1, -0.66), rotation=(0, side * math.radians(12), 0),
                          scale=(0.11, 0.38, 0.13), bevel_width=0.02))
        for k in range(6):
            y = -0.17 + k * 0.08
            shell.append(prim("cylinder", "metal", location=(side * 0.54, y, -0.525), vertices=12, radius=0.01,
                              depth=0.012))
            shell.append(cylinder_between((side * 0.54, y, -0.52), (side * 0.54, y + 0.015, -0.49), 0.0035,
                                          "metal", 8))
        for k in range(2):
            shell.append(prim("cylinder", "dark", location=(side * 0.6, 0.0 + k * 0.2, -0.52), vertices=16,
                              radius=0.022, depth=0.025, bevel_width=0.005))

    # Cockpit tub: floor and walls hanging from the sill.
    shell.append(floor())
    shell.append(tub_wall())
    # Centre pedestal holding up the panel, and the pedals in the chin glass.
    shell.append(prim("cube", "paint", location=(0, 0.56, -0.71), scale=(0.1, 0.07, 0.3), bevel_width=0.015))
    for side in (-1, 1):
        shell.append(prim("cube", "dark", location=(side * 0.17, 0.8, -0.93), rotation=(math.radians(-50), 0, 0),
                          scale=(0.05, 0.1, 0.012), bevel_width=0.006))
        shell.append(cylinder_between((side * 0.17, 0.72, -0.99), (side * 0.17, 0.78, -0.92), 0.012, "metal", 8))

    # Canopy frame, the inside of the exterior's members: sill, two A-pillars, the roof
    # ring and the rear hoop behind the head.
    shell += strut(shared.sill_points(-0.03, 30), 0.03)
    shell += strut(shared.roof_points(-0.025, 24), 0.024)
    shell += strut(shared.rear_hoop_points(-0.03, 16), 0.035)
    shell += strut(shared.chin_points(-0.025, 12), 0.02)
    for side in (-1, 1):
        shell += strut(shared.pillar_points(side, -0.025, 8), 0.024)

    body = shell[0]
    activate(body)
    for p in shell[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    body.name = "shell"
    activate(body)
    bpy.ops.object.shade_smooth()

    # Control stick: boot, shaft and grip, pivot at its base.
    stick = [prim("cone", "dark", location=(0, 0, 0.04), vertices=16, radius1=0.08, radius2=0.03, depth=0.08),
             prim("cylinder", "metal", location=(0, 0, 0.2), vertices=12, radius=0.015, depth=0.3),
             prim("cylinder", "dark", location=(0, 0.01, 0.38), rotation=(math.radians(15), 0, 0), vertices=12,
                  radius=0.028, depth=0.11, bevel_width=0.008),
             prim("cylinder", "brass", location=(0, 0.04, 0.42), rotation=(math.pi / 2, 0, 0), vertices=10,
                  radius=0.009, depth=0.02)]
    s = stick[0]
    activate(s)
    for p in stick[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    s.name = "stick"
    s.location = (0, 0.25, -0.98)

    # Collective lever on the left.
    lever = [cylinder_between((0, 0, 0), (0, 0.42, 0.1), 0.014, "metal", 10),
             prim("cylinder", "dark", location=(0, 0.45, 0.11), rotation=(math.radians(75), 0, 0), vertices=12,
                  radius=0.024, depth=0.09, bevel_width=0.006)]
    lv = lever[0]
    activate(lv)
    lever[1].select_set(True)
    bpy.ops.object.join()
    lv.name = "collective"
    lv.location = (-0.45, -0.25, -0.7)

    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.abspath(OUT)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print(f"exported {path} ({tris} triangles)", flush=True)


if __name__ == "__main__":
    build()
