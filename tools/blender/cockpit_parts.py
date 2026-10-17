"""Building blocks for the cockpit interiors (make_cockpit.py): panels that face the
pilot, gauge bezels, multi-function displays with their bezel keys, switch fields,
circuit breakers, annunciators, seats with harnesses, pedals, the stick and collective,
canopy frame struts on an ellipsoid, wiring and small fittings.

Coordinates are eye space: origin = the pilot's eye, +Y forward (Godot -Z), +Z up,
+X right, metres. A Panel is a flat board somewhere in front of the pilot: its local
x runs across, y up the board and "out" toward the eye. Empties named "mount_*" mark
where the game puts live instruments (scripts/cockpit.gd); their local -Y points out
of the panel, which is +Z (toward the viewer) once in Godot.

Material names are swapped for the game's in Cockpit.shell(): paint (the panel colour
of the class), metal, dark, brass, rubber, glass, fabric, screen, placard, lamp_off,
hazard.
"""
import math

import bpy
import bmesh  # Only importable after bpy.
from mathutils import Euler, Matrix, Vector

MATS = {}


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


def box(center, size, material, rotation=(0, 0, 0), bevel_width=0.0):
    """A box of full `size` (not half sizes) at `center`."""
    return prim("cube", material, location=center, rotation=rotation, scale=Vector(size) / 2, bevel_width=bevel_width)


def cyl(a, b, radius, material, verts=12, radius2=None):
    """A cylinder (or a cone with radius2) from a to b."""
    a, b = Vector(a), Vector(b)
    if radius2 is None:
        o = prim("cylinder", material, vertices=verts, radius=radius, depth=(b - a).length)
    else:
        o = prim("cone", material, vertices=verts, radius1=radius, radius2=radius2, depth=(b - a).length)
    rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    o.data.transform(Matrix.Translation((a + b) / 2) @ rot)
    return o


def ball(center, radius, material, scale=(1, 1, 1), segments=12, rings=6):
    return prim("uv_sphere", material, location=center, scale=scale, segments=segments, ring_count=rings, radius=radius)


def mesh_object(bm, name, material):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def tube(points, radius, material="paint", sides=10):
    """A swept tube through points (frame members, cables, hoses)."""
    points = [Vector(p) for p in points]
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
    return mesh_object(bm, "tube", material)


def join(parts, name):
    parts = [p for p in parts if p is not None]
    activate(parts[0])
    for p in parts[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    parts[0].name = name
    activate(parts[0])
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    return parts[0]


def empty(name, location, rotation=(0, 0, 0), scale=1.0):
    e = bpy.data.objects.new(name, None)
    e.location = location
    e.rotation_euler = rotation
    e.scale = (scale, scale, scale)
    bpy.context.collection.objects.link(e)
    return e


class Panel:
    """A board facing the pilot: centre, tilt (degrees back from vertical, negative leans
    the top away), yaw (degrees, turns it to face the eye from the side) and roll."""

    def __init__(self, center, tilt=-30.0, yaw=0.0, roll=0.0):
        self.c = Vector(center)
        self.euler = Euler((math.radians(tilt), math.radians(roll), math.radians(yaw)), "XYZ")
        self.m = self.euler.to_matrix()

    def at(self, x, y, out=0.0):
        return self.c + self.m @ Vector((x, -out, y))

    def rot(self, extra=(0, 0, 0)):
        m = self.m @ Euler(extra).to_matrix()
        return m.to_euler()

    def box(self, x, y, out, size, material, bevel_width=0.0):
        """size = (across, depth out of the board, up the board), full sizes."""
        return prim("cube", material, location=self.at(x, y, out + size[1] / 2), rotation=self.rot(),
                    scale=Vector(size) / 2, bevel_width=bevel_width)

    def disc(self, x, y, out, radius, depth, material, verts=24):
        return prim("cylinder", material, location=self.at(x, y, out + depth / 2), rotation=self.rot((math.pi / 2, 0, 0)),
                    vertices=verts, radius=radius, depth=depth)

    def ring(self, x, y, out, radius, minor, material, segments=32):
        return prim("torus", material, location=self.at(x, y, out), rotation=self.rot((math.pi / 2, 0, 0)),
                    major_radius=radius, minor_radius=minor, major_segments=segments, minor_segments=6)

    def mount(self, name, x, y, out=0.0, scale=1.0):
        return empty("mount_" + name, self.at(x, y, out), self.euler, scale)


# --- panel fittings ----------------------------------------------------------------

def screws(panel, x, y, out, half_w, half_h, step=0.06):
    """Dzus fasteners round the edge of a sub-panel."""
    parts = []
    nx = max(2, int(half_w * 2 / step))
    for k in range(nx + 1):
        px = -half_w + k * 2 * half_w / nx
        for py in (-half_h, half_h):
            parts.append(panel.disc(x + px, y + py, out, 0.0045, 0.003, "metal", 8))
    return parts


def subpanel(panel, x, y, w, h, out=0.0, material="paint"):
    """A raised, screwed-down sub-panel (the boards instruments sit in)."""
    parts = [panel.box(x, y, out, (w, 0.012, h), material, bevel_width=0.003)]
    parts += screws(panel, x, y, out + 0.012, w / 2 - 0.012, h / 2 - 0.012)
    return parts


def bezel(panel, x, y, radius, out=0.012, material="dark"):
    """A round instrument case set into the panel, with four mounting screws."""
    parts = [panel.disc(x, y, out, radius + 0.006, 0.01, material, 32),
             panel.ring(x, y, out + 0.011, radius + 0.002, 0.004, "dark", 32)]
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(panel.disc(x + math.cos(a) * (radius + 0.012), y + math.sin(a) * (radius + 0.012), out + 0.01,
                                0.004, 0.003, "metal", 8))
    return parts


def gauge(panel, name, x, y, radius=0.045, out=0.012):
    """A bezel with a live gauge mounted in it (Cockpit.Gauge is 0.05 m: scaled to fit)."""
    parts = bezel(panel, x, y, radius, out)
    panel.mount(name, x, y, out + 0.013, radius / 0.05)
    return parts


def dummy_gauge(panel, x, y, radius=0.03, out=0.012):
    """A small instrument whose face is painted in the model (no live needle)."""
    parts = bezel(panel, x, y, radius, out)
    parts.append(panel.disc(x, y, out + 0.01, radius, 0.002, "screen", 24))
    for k in range(9):  # Tick marks.
        a = math.radians(225 - k * 33.75)
        px, py = x + math.cos(a) * radius * 0.8, y + math.sin(a) * radius * 0.8
        parts.append(panel.box(px, py, out + 0.012, (0.002, 0.001, radius * 0.18), "placard"))
    a = math.radians(140 + (hash((round(x, 3), round(y, 3))) % 90))
    parts.append(panel.box(x + math.cos(a) * radius * 0.35, y + math.sin(a) * radius * 0.35, out + 0.013,
                           (0.002, 0.001, radius * 0.7), "placard"))
    return parts


def toggle(panel, x, y, out=0.012, up=True, guard=False):
    """A bat-handle toggle switch, optionally under a red guard."""
    parts = [panel.disc(x, y, out, 0.008, 0.006, "metal", 12)]
    tilt = 0.45 if up else -0.45
    tip = panel.at(x, y + math.sin(tilt) * 0.022, out + 0.006 + math.cos(tilt) * 0.022)
    parts.append(cyl(panel.at(x, y, out + 0.006), tip, 0.0028, "metal", 8, radius2=0.0018))
    parts.append(ball(tip, 0.0035, "metal", segments=8, rings=4))
    if guard:
        parts.append(panel.box(x, y, out, (0.024, 0.026, 0.004), "hazard"))
        parts.append(panel.box(x, y + 0.014, out + 0.012, (0.024, 0.026, 0.003), "hazard"))
    return parts


def knob(panel, x, y, out=0.012, radius=0.011, pointer=True):
    parts = [panel.disc(x, y, out, radius, 0.012, "dark", 16)]
    parts.append(panel.disc(x, y, out + 0.012, radius * 0.75, 0.006, "dark", 16))
    if pointer:
        parts.append(panel.box(x, y + radius * 0.4, out + 0.018, (0.002, 0.001, radius * 0.7), "placard"))
    return parts


def button(panel, x, y, out=0.012, w=0.014, h=0.01, material="dark"):
    return [panel.box(x, y, out, (w, 0.007, h), material, bevel_width=0.0015)]


def placard(panel, x, y, w, h, out=0.012):
    """A small engraved label plate (pale strip)."""
    return [panel.box(x, y, out, (w, 0.0012, h), "placard")]


def switch_field(panel, x, y, cols, rows, dx=0.03, dy=0.045, out=0.012, guards=()):
    """Rows of toggles with a label plate under each, the classic overhead look."""
    parts = []
    for r in range(rows):
        for c in range(cols):
            px, py = x + (c - (cols - 1) / 2) * dx, y - (r - (rows - 1) / 2) * dy
            parts += toggle(panel, px, py, out, up=(c + r) % 3 != 0, guard=(r, c) in guards)
            parts += placard(panel, px, py - dy * 0.38, dx * 0.75, 0.006, out)
    return parts


def breakers(panel, x, y, cols, rows, dx=0.018, dy=0.024, out=0.012):
    """Circuit breakers: rows of black buttons with white collars, one or two pulled."""
    parts = []
    for r in range(rows):
        for c in range(cols):
            px, py = x + (c - (cols - 1) / 2) * dx, y - (r - (rows - 1) / 2) * dy
            pulled = (r * 7 + c * 3) % 23 == 0
            parts.append(panel.disc(px, py, out, 0.0055, 0.004, "placard", 10))
            parts.append(panel.disc(px, py, out + 0.004, 0.004, 0.012 if pulled else 0.006, "dark", 10))
    return parts


def annunciators(panel, x, y, cols, rows, w=0.026, h=0.014, out=0.012):
    """A caution panel: a grid of unlit legend lamps in a black frame."""
    parts = [panel.box(x, y, out, (cols * (w + 0.003) + 0.01, 0.008, rows * (h + 0.003) + 0.01), "dark")]
    for r in range(rows):
        for c in range(cols):
            px, py = x + (c - (cols - 1) / 2) * (w + 0.003), y - (r - (rows - 1) / 2) * (h + 0.003)
            parts.append(panel.box(px, py, out + 0.008, (w, 0.002, h), "lamp_off"))
    return parts


def mfd(panel, page, x, y, size=0.17, out=0.012, keys=5):
    """A multi-function display: a deep bezel with push keys on all four sides, the
    rocker switches at the corners, and a live screen mounted at "mount_mfd_<page>"."""
    outer = size + 0.07
    parts = [panel.box(x, y, out, (outer, 0.03, outer), "dark", bevel_width=0.006)]
    parts.append(panel.box(x, y, out + 0.03, (size + 0.012, 0.004, size + 0.012), "screen"))
    step = size / (keys + 1)
    for k in range(keys):
        o = -size / 2 + step * (k + 1)
        for side in (-1, 1):
            parts += button(panel, x + o, y + side * (size / 2 + 0.019), out + 0.03, 0.016, 0.011)
            parts += button(panel, x + side * (size / 2 + 0.019), y + o, out + 0.03, 0.011, 0.016)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts += knob(panel, x + sx * (outer / 2 - 0.014), y + sy * (outer / 2 - 0.014), out + 0.03, 0.007, False)
    panel.mount("mfd_" + page, x, y, out + 0.0345, size / 0.2)
    return parts


def hood(panel, x, y, w, depth, out=0.0):
    """A glare shield hood over the top of the instruments."""
    return [panel.box(x, y, out, (w, depth, 0.012), "dark", bevel_width=0.004)]


def keypad(panel, x, y, cols=6, rows=5, out=0.012):
    """A control-display unit: a small screen above a block of square keys."""
    parts = [panel.box(x, y, out, (cols * 0.019 + 0.02, 0.012, rows * 0.019 + 0.07), "dark", bevel_width=0.003)]
    parts.append(panel.box(x, y + rows * 0.0095 + 0.016, out + 0.012, (cols * 0.019 - 0.004, 0.002, 0.04), "screen"))
    for r in range(rows):
        for c in range(cols):
            parts += button(panel, x + (c - (cols - 1) / 2) * 0.019, y - 0.012 + (rows / 2 - r) * 0.019 - 0.02,
                            out + 0.012, 0.015, 0.015, "rubber")
    return parts


# --- furniture ----------------------------------------------------------------------

def seat(x, y, z, width=0.48, back_height=0.7, material="fabric", armoured=False, harness=True):
    """A crew seat: pan at (x, y, z) top surface, back behind it, headrest, harness."""
    parts = [box((x, y + 0.02, z - 0.05), (width, 0.46, 0.1), material, bevel_width=0.025),
             box((x, y - 0.24, z + back_height / 2), (width, 0.1, back_height), material, bevel_width=0.025),
             box((x, y - 0.27, z + back_height + 0.08), (width * 0.55, 0.09, 0.16), material, bevel_width=0.025)]
    shell_mat = "paint" if armoured else "dark"
    parts.append(box((x, y - 0.31, z + back_height / 2), (width + 0.06, 0.04, back_height + 0.1), shell_mat,
                     bevel_width=0.01))
    for side in (-1, 1):
        parts.append(box((x + side * (width / 2 + 0.02), y - 0.05, z + 0.05), (0.03, 0.55, 0.28), shell_mat,
                         bevel_width=0.008))
        if armoured:  # Side armour wings beside the shoulders.
            parts.append(box((x + side * (width / 2 + 0.03), y - 0.2, z + 0.45), (0.025, 0.2, 0.5), "paint",
                             bevel_width=0.006))
    parts.append(box((x, y + 0.02, z - 0.25), (width * 0.8, 0.4, 0.3), "dark"))  # Bucket support.
    if harness:
        top = z + back_height - 0.06
        for side in (-1, 1):  # Shoulder straps over the back, lap belt, a central buckle.
            sx = x + side * 0.1
            parts.append(tube([(sx, y - 0.2, top + 0.05), (sx, y - 0.13, top), (sx * 0.9 + x * 0.1, y + 0.02, z + 0.3),
                               (x + side * 0.04, y + 0.12, z + 0.08)], 0.018, "rubber", 6))
            parts.append(tube([(x + side * (width / 2 - 0.02), y - 0.12, z + 0.02),
                               (x + side * 0.12, y + 0.1, z + 0.06), (x, y + 0.14, z + 0.08)], 0.016, "rubber", 6))
        parts.append(ball((x, y + 0.14, z + 0.09), 0.035, "metal", scale=(1, 0.4, 1)))
    return parts


def pedals(x, y, z, spread=0.16):
    """Yaw pedals on their rails, toe brakes on top."""
    parts = []
    for side in (-1, 1):
        px = x + side * spread
        parts.append(box((px, y, z), (0.09, 0.03, 0.2), "dark", rotation=(math.radians(-55), 0, 0), bevel_width=0.006))
        parts.append(cyl((px, y - 0.12, z - 0.12), (px, y + 0.02, z - 0.02), 0.012, "metal", 8))
        for k in range(3):
            parts.append(box((px, y + 0.016, z - 0.06 + k * 0.05), (0.08, 0.004, 0.012), "rubber",
                             rotation=(math.radians(-55), 0, 0)))
    parts.append(box((x, y - 0.12, z - 0.14), (spread * 2 + 0.12, 0.08, 0.03), "metal"))
    return parts


def stick(location, name="stick", grip_buttons=True):
    """The cyclic: a rubber boot, shaft and a grip with trigger, hat switches and a
    guarded button; pivots at its base (separate object, the game tilts it)."""
    parts = [prim("cone", "rubber", location=(0, 0, 0.045), vertices=16, radius1=0.075, radius2=0.025, depth=0.09),
             prim("cylinder", "metal", location=(0, 0, 0.25), vertices=12, radius=0.013, depth=0.36),
             prim("cylinder", "dark", location=(0, 0.01, 0.47), rotation=(math.radians(12), 0, 0), vertices=14,
                  radius=0.024, depth=0.12, bevel_width=0.006),
             prim("uv_sphere", "dark", location=(0, 0.02, 0.535), segments=12, ring_count=6, radius=0.026,
                  scale=(1, 1.2, 0.8))]
    if grip_buttons:
        parts.append(prim("cube", "metal", location=(0, 0.035, 0.455), scale=(0.006, 0.012, 0.016)))  # Trigger.
        parts.append(prim("cylinder", "brass", location=(0, 0.028, 0.555), rotation=(math.radians(60), 0, 0),
                          vertices=10, radius=0.007, depth=0.01))
        parts.append(prim("cylinder", "metal", location=(0.016, 0.0, 0.55), vertices=8, radius=0.006, depth=0.01))
        parts.append(prim("cube", "hazard", location=(-0.012, 0.02, 0.548), scale=(0.007, 0.007, 0.004)))
    s = join(parts, name)
    s.location = location
    return s


def collective(location, length=0.45, name="collective", twist=True):
    """The collective lever with its throttle twist grip and switch box (separate)."""
    parts = [cyl((0, 0, 0), (0, length, 0.12), 0.013, "metal", 10)]
    end = Vector((0, length, 0.12))
    parts.append(prim("cylinder", "rubber" if twist else "dark", location=end + Vector((0, 0.04, 0.01)),
                      rotation=(math.radians(78), 0, 0), vertices=14, radius=0.022, depth=0.09, bevel_width=0.004))
    parts.append(prim("cube", "dark", location=end + Vector((0, 0.1, 0.025)), scale=(0.025, 0.03, 0.025),
                      bevel_width=0.004))
    for k in range(3):
        parts.append(prim("cylinder", "metal", location=end + Vector((-0.012 + k * 0.012, 0.115, 0.052)),
                          vertices=8, radius=0.004, depth=0.008))
    parts.append(cyl((0, -0.06, -0.02), (0, 0.02, 0.0), 0.03, "dark", 12))  # Pivot housing.
    lv = join(parts, name)
    lv.location = location
    return lv


def console(x, y, z, length, width, height, tilt_side, material="paint"):
    """A side console box with its top face as a Panel (returned with the parts)."""
    parts = [box((x, y, z - height / 2), (width, length, height), material, bevel_width=0.01)]
    top = Panel((x, y, z + 0.001), tilt=-90.0 + 0.0, yaw=0.0, roll=tilt_side)
    return parts, top


def extinguisher(x, y, z, axis=(0, 0, 1)):
    a = Vector((x, y, z))
    b = a + Vector(axis).normalized() * 0.32
    parts = [cyl(a, b, 0.04, "hazard", 16), ball(b, 0.04, "hazard", segments=12, rings=6),
             cyl(b, b + Vector(axis).normalized() * 0.06, 0.012, "metal", 8)]
    for t in (0.2, 0.75):
        p = a.lerp(b, t)
        parts.append(prim("torus", "metal", location=p, rotation=Vector((0, 0, 1)).rotation_difference(Vector(axis)).to_euler(),
                          major_radius=0.045, minor_radius=0.006, major_segments=16, minor_segments=4))
    return parts


def compass(location):
    """The whiskey compass: a little round case on a bracket."""
    loc = Vector(location)
    return [prim("cylinder", "dark", location=loc, rotation=(math.pi / 2, 0, 0), vertices=20, radius=0.032, depth=0.04,
                 bevel_width=0.004),
            prim("cylinder", "placard", location=loc + Vector((0, -0.021, 0)), rotation=(math.pi / 2, 0, 0), vertices=20,
                 radius=0.024, depth=0.002),
            prim("cube", "dark", location=loc + Vector((0, 0.02, 0.04)), scale=(0.008, 0.008, 0.03))]


def wiring(points, count=4, spread=0.012):
    """A loom of a few cables along points (behind panels, along walls)."""
    parts = []
    for k in range(count):
        off = Vector(((k % 2 - 0.5) * spread, 0, (k // 2 - 0.5) * spread))
        parts.append(tube([Vector(p) + off for p in points], 0.005, ["dark", "rubber", "hazard", "dark"][k % 4], 6))
    return parts


# --- canopy frames -----------------------------------------------------------------

def ell(center, radii, azimuth, elevation):
    """A point on an ellipsoid: azimuth 0 = ahead, + = right; elevation 0 = equator."""
    return Vector(center) + Vector((radii[0] * math.cos(elevation) * math.sin(azimuth),
                                    radii[1] * math.cos(elevation) * math.cos(azimuth),
                                    radii[2] * math.sin(elevation)))


def ell_curve(center, radii, a0, e0, a1, e1, steps=16):
    return [ell(center, radii, a0 + (a1 - a0) * k / steps, e0 + (e1 - e0) * k / steps) for k in range(steps + 1)]


def frame_member(center, radii, a0, e0, a1, e1, radius=0.022, steps=16, material="paint"):
    """A canopy frame bar along the inside of the glass, from (a0, e0) to (a1, e1)."""
    return tube(ell_curve(center, radii, a0, e0, a1, e1, steps), radius, material, 10)
