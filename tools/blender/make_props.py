"""Builds the map props, assets/models/props/props.glb: one object per prop, origin at
its base (ground level), named so the game can pick it out (scripts/props.gd).

Run:     python tools/blender/make_props.py
Preview: python tools/blender/make_props.py --preview DIR

Props: station_pad (service station helipad and mast), pylon (power-line tower, the
cable arms at z = 26 and x = +-4.5), water_tower, headframe (mine shaft tower with its
sheave wheel), shack, shack_long, trestle (a 32 m timber bridge span along X, deck at
z = 12), fuel_tank, crates.

Materials are named for the game to swap (Props.materials): wood, wood_dark, rust,
concrete, metal, dark, hazard, decal, glass, corrugated, lamp.
Blender +Y becomes Godot -Z, so a prop "facing" +Y faces the game's forward.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import make_choppa as base  # noqa: E402
from make_choppa import ball, box, cyl, join, ring  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "props", "props.glb")

base.PREVIEW.update({
    "wood": ((0.45, 0.32, 0.2), 0.0, 0.85), "wood_dark": ((0.25, 0.17, 0.11), 0.0, 0.9),
    "rust": ((0.42, 0.2, 0.1), 0.4, 0.8), "concrete": ((0.55, 0.54, 0.5), 0.0, 0.9),
    "corrugated": ((0.5, 0.48, 0.44), 0.6, 0.6),
})


def beam(a, b, size, material="wood"):
    """A square timber or steel beam from a to b."""
    a, b = Vector(a), Vector(b)
    o = box(Vector((0, 0, 0)), (size, size, (b - a).length), material)
    return base.place(o, Matrix.Translation((a + b) / 2) @ base.align_z(b - a))


def lattice_leg(a, b, width, material="rust", bays=6):
    """Four angle-iron posts with zig-zag bracing, from a to b."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    side = axis.orthogonal().normalized()
    other = axis.cross(side)
    parts = []
    corners = [side * width + other * width, -side * width + other * width, -side * width - other * width,
               side * width - other * width]
    for c in corners:
        parts.append(beam(a + c, b + c, 0.08, material))
    for k in range(bays):
        p0 = a.lerp(b, k / bays)
        p1 = a.lerp(b, (k + 1) / bays)
        for i in range(4):
            c0, c1 = corners[i], corners[(i + 1) % 4]
            parts.append(beam(p0 + c0, p1 + c1, 0.04, material))
    return parts


def station_pad():
    r = 6.0
    parts = [cyl((0, 0, -0.3), (0, 0, 0.3), r, "concrete", 48),
             cyl((0, 0, -0.35), (0, 0, -0.1), r + 0.35, "concrete", 48)]
    # Painted ring and H.
    parts.append(ring((0, 0, 0.3), (0, 0, 1), r - 0.6, 0.12, "hazard", 48))
    for x in (-1.3, 1.3):
        parts.append(box((x, 0, 0.31), (0.5, 3.6, 0.03), "hazard"))
    parts.append(box((0, 0, 0.31), (2.1, 0.5, 0.03), "hazard"))
    # Tie-down rings, a fuel hose drum and a toolbox by the mast.
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        parts.append(ring((math.cos(a) * 3.4, math.sin(a) * 3.4, 0.32), (0, 0, 1), 0.12, 0.025, "metal", 12))
    mast = Vector((r + 1.2, 0, 0))
    parts.append(cyl(mast + Vector((0, 0, -0.3)), mast + Vector((0, 0, 0.2)), 0.45, "concrete", 16))
    parts.append(cyl(mast, mast + Vector((0, 0, 6.0)), 0.16, "metal", 12, radius2=0.11))
    parts.append(cyl(mast + Vector((0, 0, 5.9)), mast + Vector((0, 0, 6.05)), 0.3, "dark", 16))
    for k in range(3):
        parts.append(ring(mast + Vector((0, 0, 1.0 + k * 1.6)), (0, 0, 1), 0.15, 0.02, "hazard", 12))
    drum = Vector((r + 1.0, -1.6, 0.6))
    parts.append(cyl(drum - Vector((0.35, 0, 0)), drum + Vector((0.35, 0, 0)), 0.6, "rust", 20, bevel_width=0.03))
    parts.append(box((r + 0.9, 1.8, 0.35), (0.9, 0.5, 0.5), "hazard", bevel_width=0.04))
    parts.append(box((r + 0.9, 1.8, 0.62), (0.95, 0.55, 0.05), "dark"))
    return join(parts, "station_pad")


def pylon():
    parts = []
    # Tapering lattice: four legs from a wide base to a narrow waist, then the head.
    for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        parts.append(beam((sx * 2.6, sy * 2.6, 0), (sx * 0.7, sy * 0.7, 24), 0.18, "rust"))
        parts.append(beam((sx * 0.7, sy * 0.7, 24), (sx * 0.6, sy * 0.6, 28), 0.15, "rust"))
        parts.append(cyl((sx * 2.6, sy * 2.6, -0.4), (sx * 2.6, sy * 2.6, 0.3), 0.45, "concrete", 12))
    for k in range(8):
        z0, z1 = k * 3.0, (k + 1) * 3.0
        t0, t1 = z0 / 24, z1 / 24
        w0 = 2.6 + (0.7 - 2.6) * t0
        w1 = 2.6 + (0.7 - 2.6) * t1
        for (ax, ay), (bx, by) in (((1, 1), (-1, 1)), ((-1, 1), (-1, -1)), ((-1, -1), (1, -1)), ((1, -1), (1, 1))):
            parts.append(beam((ax * w0, ay * w0, z0), (bx * w1, by * w1, z1), 0.07, "rust"))
            parts.append(beam((bx * w0, by * w0, z0), (ax * w1, ay * w1, z1), 0.07, "rust"))
    # Cross arm with insulator strings at the cable points (x = +-4.5, z = 26).
    parts.append(beam((-5.0, 0, 26.6), (5.0, 0, 26.6), 0.25, "rust"))
    for x in (-5.0, 5.0):
        parts.append(beam((x, 0, 26.6), (x * 0.15, 0, 28.0), 0.12, "rust"))
    for x in (-4.5, 0.0, 4.5):
        for k in range(5):
            parts.append(cyl((x, 0, 26.45 - k * 0.12), (x, 0, 26.4 - k * 0.12), 0.11, "glass", 12))
    # Warning plate and climbing pegs.
    parts.append(box((0, 2.0, 3.0), (0.6, 0.02, 0.4), "hazard"))
    return join(parts, "pylon")


def water_tower():
    parts = []
    for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        parts.append(beam((sx * 2.4, sy * 2.4, 0), (sx * 1.8, sy * 1.8, 9.0), 0.3, "wood_dark"))
        parts.append(box((sx * 2.4, sy * 2.4, 0.2), (0.8, 0.8, 0.5), "concrete"))
    for z in (2.5, 5.5, 8.5):
        w = 2.4 - 0.6 * z / 9.0
        for (ax, ay), (bx, by) in (((1, 1), (-1, 1)), ((-1, 1), (-1, -1)), ((-1, -1), (1, -1)), ((1, -1), (1, 1))):
            parts.append(beam((ax * w, ay * w, z), (bx * w, by * w, z), 0.16, "wood_dark"))
            parts.append(beam((ax * w, ay * w, z - 2.5), (bx * w, by * w, z), 0.08, "wood_dark"))
    parts.append(box((0, 0, 9.2), (4.6, 4.6, 0.3), "wood"))
    parts.append(cyl((0, 0, 9.35), (0, 0, 13.6), 2.4, "wood", 32))
    for z in (9.8, 11.0, 12.2, 13.3):
        parts.append(ring((0, 0, z), (0, 0, 1), 2.42, 0.05, "rust", 32))
    roof = cyl((0, 0, 13.6), (0, 0, 15.0), 2.6, "corrugated", 32, radius2=0.2)
    parts.append(roof)
    parts.append(cyl((0, 0, 1.0), (0, 0, 9.2), 0.18, "rust", 10))  # Down pipe.
    parts.append(cyl((0, 0.6, 9.0), (0.0, 3.4, 8.4), 0.14, "rust", 10))  # Spout.
    for k in range(18):  # Ladder.
        parts.append(beam((-0.25, -2.5, 0.5 + k * 0.5), (0.25, -2.5, 0.5 + k * 0.5), 0.04, "rust"))
    for x in (-0.25, 0.25):
        parts.append(beam((x, -2.5, 0.2), (x, -2.5, 9.4), 0.05, "rust"))
    return join(parts, "water_tower")


def headframe():
    parts = []
    # A-frame mine headframe with the sheave wheel at the top.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(beam((sx * 2.5, sy * 2.0, 0), (sx * 1.0, sy * 1.0, 16), 0.35, "wood_dark"))
        parts.append(beam((sx * 1.0, 1.0, 16), (sx * 1.0, -1.0, 16), 0.3, "wood_dark"))
        parts.append(beam((sx * 1.2, -1.5, 0), (sx * 1.2, -7.5, 0), 0.3, "wood_dark"))
        parts.append(beam((sx * 1.2, -7.5, 0), (sx * 1.0, -0.8, 15), 0.3, "wood_dark"))
    for z in (4, 8, 12):
        w = 2.5 - 1.5 * z / 16
        for sy in (-1, 1):
            parts.append(beam((-w, sy * (2.0 - z / 16), z), (w, sy * (2.0 - z / 16), z), 0.2, "wood_dark"))
    parts.append(beam((-1.0, 0, 16), (1.0, 0, 16), 0.3, "wood_dark"))
    wheel = Vector((0, 0, 16.9))
    parts.append(ring(wheel, (1, 0, 0), 1.3, 0.1, "rust", 32))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(beam(wheel, wheel + Vector((0, math.cos(a), math.sin(a))) * 1.25, 0.06, "rust"))
    parts.append(cyl(wheel - Vector((0.3, 0, 0)), wheel + Vector((0.3, 0, 0)), 0.15, "dark", 12))
    parts.append(box((0, 0, 0.3), (3.0, 3.0, 0.6), "concrete"))
    # Winch house: corrugated walls, a pitched roof and the cable drum showing in the door.
    parts.append(box((0, -9.0, 0.2), (4.4, 3.4, 0.4), "concrete"))
    parts.append(box((0, -9.0, 1.8), (4.0, 3.0, 2.8), "corrugated"))
    for side in (-1, 1):
        plate = box((0, 0, 0), (4.6, 1.8, 0.08), "rust")
        base.place(plate, Matrix.Translation((0, -9.0 + side * 0.8, 3.5)) @ Matrix.Rotation(side * math.radians(-20), 4, "X"))
        parts.append(plate)
    parts.append(box((0, -7.48, 1.4), (1.6, 0.05, 2.0), "dark"))
    parts.append(cyl((-0.6, -7.7, 1.3), (0.6, -7.7, 1.3), 0.5, "rust", 20))
    return join(parts, "headframe")


def shack(name, length):
    parts = [box((0, 0, 0.25), (length + 0.4, 4.4, 0.5), "concrete")]
    walls = box((0, 0, 1.9), (length, 4.0, 2.8), "wood")
    parts.append(walls)
    for k in range(int(length / 0.6)):
        x = -length / 2 + 0.3 + k * 0.6
        for y in (-2.01, 2.01):
            parts.append(box((x, y, 1.9), (0.04, 0.02, 2.7), "wood_dark"))
    # Pitched corrugated roof with a little overhang.
    for side in (-1, 1):
        plate = box((0, 0, 0), (length + 0.8, 2.5, 0.08), "corrugated")
        base.place(plate, Matrix.Translation((0, side * 1.1, 3.75)) @ Matrix.Rotation(side * math.radians(-18), 4, "X"))
        parts.append(plate)
    parts.append(box((length / 2 - 1.2, 2.02, 1.6), (0.9, 0.05, 2.0), "wood_dark"))  # Door.
    parts.append(box((-length / 2 + 1.0, 2.02, 2.1), (0.9, 0.05, 0.8), "glass"))
    parts.append(cyl((length / 2 - 0.5, -1.2, 3.4), (length / 2 - 0.5, -1.2, 4.9), 0.15, "rust", 10))  # Stove pipe.
    return join(parts, name)


def trestle():
    """A 32 m timber trestle span along X, deck top at z = 12, legs down to z = 0."""
    parts = []
    span = 32.0
    for x in (-span / 2, -span / 6, span / 6, span / 2):
        for y in (-1.6, 1.6):
            parts.append(beam((x, y * 1.6, 0), (x, y, 11.7), 0.35, "wood_dark"))
        for z in (3.5, 7.5):
            parts.append(beam((x, -2.2, z), (x, 2.2, z), 0.25, "wood_dark"))
            parts.append(beam((x, -2.4, z - 3.5), (x, 2.0, z), 0.15, "wood_dark"))
        parts.append(box((x, 0, 0.3), (1.2, 6.0, 0.6), "concrete"))
    for y in (-1.6, 1.6):
        parts.append(beam((-span / 2, y, 11.6), (span / 2, y, 11.6), 0.5, "wood_dark"))
    parts.append(box((0, 0, 11.95), (span + 0.5, 3.6, 0.2), "wood"))
    for k in range(int(span / 0.7)):
        x = -span / 2 + 0.35 + k * 0.7
        parts.append(box((x, 0, 12.1), (0.22, 3.2, 0.12), "wood_dark"))
    for y in (-0.75, 0.75):
        parts.append(beam((-span / 2, y, 12.2), (span / 2, y, 12.2), 0.1, "rust"))
    # A tipped ore cart on the deck.
    parts.append(box((5.0, 0.0, 12.75), (1.6, 1.1, 0.9), "rust", bevel_width=0.05))
    return join(parts, "trestle")


def fuel_tank():
    parts = [cyl((-3.5, 0, 1.6), (3.5, 0, 1.6), 1.4, "rust", 32, bevel_width=0.05)]
    for x in (-3.55, 3.55):
        parts.append(ball((x, 0, 1.6), 1.4, "rust", scale=(0.25, 1, 1), segments=24, rings=12))
    for x in (-2.0, 2.0):
        parts.append(box((x, 0, 0.5), (0.5, 2.6, 1.0), "concrete"))
        parts.append(ring((x, 0, 1.6), (1, 0, 0), 1.42, 0.06, "dark", 32))
    parts.append(box((0, -1.42, 1.6), (3.0, 0.03, 0.8), "hazard"))
    parts.append(cyl((0, 0, 3.0), (0, 0, 3.4), 0.3, "dark", 12))
    return join(parts, "fuel_tank")


def crates():
    parts = []
    for (x, y, z, s, yaw) in ((0, 0, 0, 1.4, 0), (1.5, 0.2, 0, 1.3, 0.2), (0.7, 0.1, 1.4, 1.2, -0.3), (-1.4, 1.2, 0, 1.0, 0.5)):
        rot = Matrix.Rotation(yaw, 4, "Z")
        c = box((0, 0, 0), (s, s, s), "wood", bevel_width=0.03)
        base.place(c, Matrix.Translation((x, y, z + s / 2)) @ rot)
        parts.append(c)
        for k in (-1, 1):
            band = box((0, 0, 0), (s + 0.02, 0.12, s + 0.02), "wood_dark")
            base.place(band, Matrix.Translation((x, y, z + s / 2)) @ rot @ Matrix.Translation((0, k * s * 0.3, 0)))
            parts.append(band)
    return join(parts, "crates")


BUILDS = [station_pad, pylon, water_tower, headframe, lambda: shack("shack", 5.0), lambda: shack("shack_long", 9.0),
          trestle, fuel_tank, crates]


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base.MATS.clear()
    x = 0.0
    for make in BUILDS:
        o = make()
        o.location = (x, 0, 0)  # Spread out for the preview; the game resets it.
        x += 40.0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            base.activate(o)
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    build()
    if args and args[0] == "--preview":
        base.GROUND_Z = 0.0
        base.VIEWS.clear()
        names = ["station_pad", "pylon", "water_tower", "headframe", "shack", "shack_long", "trestle", "fuel_tank",
                 "crates"]
        for k, name in enumerate(names):
            size = {"pylon": 30, "trestle": 34, "headframe": 22, "water_tower": 17}.get(name, 13)
            base.VIEWS[name] = ((k * 40.0 + size * 1.1, -size * 1.5, size * 0.75), (k * 40.0, -size * 0.1, size * 0.4))
        base.preview(args[1], list(base.VIEWS))
    else:
        base.OUT = OUT
        base.export()
