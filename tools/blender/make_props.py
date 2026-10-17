"""Builds the map props, assets/models/props/props.glb: one object per prop, origin at
its base (ground level), named so the game can pick it out (scripts/props.gd).

Run:     python tools/blender/make_props.py
Preview: python tools/blender/make_props.py --preview DIR

Props: station_pad (service station helipad and mast), pylon (power-line tower, the
cable arms at z = 26 and x = +-4.5), water_tower, headframe (mine shaft tower with its
sheave wheel), shack, shack_long, trestle (a 32 m timber bridge span along X, deck at
z = 12), fuel_tank, crates.
Harbour (Rust Harbor): container_red / _blue / _green / _orange (a 40 ft box, 12.2 x
2.44 x 2.6 m, long side along X), gantry_crane (a ship-to-shore crane: portal 24 m
wide along Y, boom along X at z = 34), warehouse (40 x 24 m, open at both ends and
with holes in the roof: fly through it), ship_hulk (a 72 m rusting freighter along X),
radio_mast (a 52 m lattice mast with a beacon).

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
    "container_red": ((0.45, 0.12, 0.08), 0.3, 0.6), "container_blue": ((0.1, 0.22, 0.42), 0.3, 0.6),
    "container_green": ((0.15, 0.3, 0.18), 0.3, 0.6), "container_orange": ((0.62, 0.3, 0.08), 0.3, 0.6),
    "crane": ((0.78, 0.56, 0.08), 0.3, 0.55), "hull_dark": ((0.12, 0.13, 0.14), 0.3, 0.7),
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


def container(name, paint):
    """A 40 ft shipping container: ribbed sides, corner posts, door bars at the +X end."""
    L, W, H = 12.2, 2.44, 2.6
    parts = [box((0, 0, H / 2), (L - 0.1, W - 0.12, H - 0.1), paint)]
    for k in range(30):  # Corrugation on the long sides.
        x = -L / 2 + 0.3 + k * (L - 0.6) / 29
        for side in (-1, 1):
            parts.append(box((x, side * (W / 2 - 0.04), H / 2), (0.14, 0.08, H - 0.3), paint))
    for k in range(5):  # And the roof.
        parts.append(box((-L / 2 + 1.2 + k * (L - 2.4) / 4, 0, H - 0.03), (0.2, W - 0.3, 0.06), paint))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((sx * (L / 2 - 0.1), sy * (W / 2 - 0.1), H / 2), (0.2, 0.2, H), "dark"))
    for sy in (-0.55, -0.2, 0.2, 0.55):  # Locking bars on the doors.
        parts.append(cyl((L / 2 + 0.02, sy, 0.25), (L / 2 + 0.02, sy, H - 0.25), 0.03, "metal", 6))
    parts.append(box((L / 2 + 0.01, 0, H / 2), (0.02, 0.04, H - 0.4), "dark"))
    return join(parts, name)


def gantry_crane():
    """Ship-to-shore crane: a portal on four legs (24 m apart along Y, 16 m along X), a
    machinery house, and a long boom along X at z = 34 with a trolley and its cables."""
    parts = []
    for sx in (-8, 8):
        for sy in (-12, 12):
            parts.append(beam((sx, sy, 0), (sx * 0.8, sy, 30), 1.0, "crane"))
            parts.append(box((sx, sy, 0.6), (2.4, 1.6, 1.2), "dark"))  # Bogies on the rail.
        parts.append(beam((sx, -12, 14), (sx, 12, 14), 0.8, "crane"))  # Portal cross beams.
        parts.append(beam((sx * 0.8, -12, 30), (sx * 0.8, 12, 30), 1.0, "crane"))
        parts.append(beam((sx, -12, 0.5), (sx * 0.8, 12, 30), 0.35, "crane"))  # Diagonal bracing.
    for sy in (-12, 12):
        parts.append(beam((-8, sy, 14), (8, sy, 14), 0.8, "crane"))
        parts.append(beam((-6.4, sy, 30), (6.4, sy, 30), 1.0, "crane"))
    # Boom: two girders from x = -22 (backreach) to +40 (over the water).
    for sy in (-2.2, 2.2):
        parts.append(beam((-22, sy, 34), (40, sy, 34), 1.4, "crane"))
        for k in range(16):
            x0 = -22 + k * 62 / 16
            parts.append(beam((x0, sy, 33.3), (x0 + 62 / 16, sy, 35.3), 0.18, "crane"))
    for k in range(9):
        x = -22 + k * 62 / 8
        parts.append(beam((x, -2.2, 34), (x, 2.2, 34), 0.3, "crane"))
    # A-frame and stays holding the boom.
    for sy in (-2.2, 2.2):
        parts.append(beam((-2, sy, 30), (0, sy, 46), 0.7, "crane"))
        parts.append(beam((0, sy, 46), (38, sy, 35), 0.25, "metal"))
        parts.append(beam((0, sy, 46), (-20, sy, 35), 0.25, "metal"))
    parts.append(box((-14, 0, 37.5), (9, 6, 6), "crane"))  # Machinery house.
    parts.append(box((-14, -3.02, 38.5), (6, 0.04, 1.2), "glass"))
    parts.append(box((6, 0, 31.6), (3.2, 3.6, 2.6), "crane"))  # Operator cab.
    parts.append(box((6, 0, 31.4), (3.0, 3.62, 1.0), "glass"))
    # Trolley over the water, cables down to a spreader.
    parts.append(box((24, 0, 32.5), (4, 5, 1.6), "dark"))
    for sy in (-1.6, 1.6):
        parts.append(cyl((24, sy, 31.7), (24, sy, 18), 0.06, "metal", 6))
    parts.append(box((24, 0, 17.6), (12.2, 2.6, 0.6), "crane"))
    parts.append(ball((0, 0, 47), 0.4, "light_red", segments=10, rings=6))
    return join(parts, "gantry_crane")


def warehouse():
    """A big shed, 40 m along X by 24 m, open at both ends to fly through, with the roof
    panels partly gone (holes to drop through) and steel portal frames inside."""
    L, W, H = 40.0, 24.0, 12.0
    parts = []  # No floor of its own: it stands on the quay, and a pad can sit inside.
    frames = 6
    for k in range(frames):
        x = -L / 2 + 2 + k * (L - 4) / (frames - 1)
        for sy in (-1, 1):
            parts.append(beam((x, sy * W / 2, 0), (x, sy * W / 2, H), 0.5, "rust"))
            parts.append(beam((x, sy * W / 2, H), (x, 0, H + 4), 0.45, "rust"))
    for sy in (-1, 1):  # Long walls of corrugated sheet, a gap low down for doors.
        for k in range(10):
            x = -L / 2 + 2 + k * (L - 4) / 10 + (L - 4) / 20
            if k in (3, 6):
                parts.append(box((x, sy * W / 2, H * 0.75), ((L - 4) / 10 - 0.1, 0.12, H * 0.5), "corrugated"))
            else:
                parts.append(box((x, sy * W / 2, H / 2), ((L - 4) / 10 - 0.1, 0.12, H), "corrugated"))
    # Roof panels on both slopes; a few are missing.
    import math as _m
    slope = _m.atan2(4.0, W / 2)
    missing = {(1, -1), (2, 1), (4, -1)}
    for k in range(5):
        x = -L / 2 + 2 + k * (L - 4) / 5 + (L - 4) / 10
        for sy in (-1, 1):
            if (k, sy) in missing:
                continue
            panel = box((0, 0, 0), ((L - 4) / 5 - 0.2, _m.hypot(W / 2, 4.0), 0.12), "corrugated")
            base.place(panel, Matrix.Translation((x, sy * W / 4, H + 2)) @ Matrix.Rotation(-sy * slope, 4, "X"))
            parts.append(panel)
    # Crane rail along the inside, crates and a forklift-sized block for cover.
    for sy in (-1, 1):
        parts.append(beam((-L / 2 + 2, sy * (W / 2 - 1.5), H - 1.5), (L / 2 - 2, sy * (W / 2 - 1.5), H - 1.5), 0.5, "crane"))
    parts.append(box((-6, -5, 1.2), (6, 3, 2.4), "wood"))
    parts.append(box((8, 6, 1.0), (4, 2.5, 2.0), "wood_dark"))
    return join(parts, "warehouse")


def prism(bottom, top, z0, z1, material):
    """A solid from a bottom outline at z0 to a top outline at z1 (same point count)."""
    n = len(bottom)
    verts = [(x, y, z0) for x, y in bottom] + [(x, y, z1) for x, y in top]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for k in range(n):
        faces.append([k, (k + 1) % n, n + (k + 1) % n, n + k])
    mesh = bpy.data.meshes.new("prism")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(base.mat(material))
    o = bpy.data.objects.new("prism", mesh)
    bpy.context.collection.objects.link(o)
    return o


def ship_hulk():
    """A rusting freighter, 72 m along X (bow at +X), 13 m wide, deck at z = 9, with open
    cargo holds, a superstructure aft and a funnel. It sits on the harbour bed."""
    # The hull: one body, a flared pointed bow, narrower at the keel than at the deck.
    deck = [(-34, -6.5), (22, -6.5), (30, -4.6), (37, 0), (30, 4.6), (22, 6.5), (-34, 6.5)]
    keel = [(-33, -5.2), (21, -5.2), (27, -3.4), (31, 0), (27, 3.4), (21, 5.2), (-33, 5.2)]
    parts = [prism(keel, deck, 0.0, 9.0, "hull_dark")]
    band = [(x * 1.004, y * 1.01) for x, y in keel]
    parts.append(prism(band, [(x * 1.004, y * 1.01) for x, y in keel], 0.0, 2.4, "rust"))  # Waterline rust.
    for x in (-18, -4, 10):  # Open holds with coamings.
        parts.append(box((x, 0, 8.95), (10, 9, 0.2), "dark"))
        for sy in (-1, 1):
            parts.append(box((x, sy * 4.6, 9.6), (10.4, 0.3, 1.2), "rust"))
        for sx in (-1, 1):
            parts.append(box((x + sx * 5.1, 0, 9.6), (0.3, 9.2, 1.2), "rust"))
    parts.append(box((-29, 0, 15), (10, 12, 12), "paint"))  # Superstructure aft.
    for z in (12, 15.5, 19):
        parts.append(box((-23.98, 0, z), (0.05, 10, 1.0), "glass"))
    parts.append(box((-29, 0, 21.4), (11, 14, 0.4), "rust"))  # Bridge wings.
    parts.append(cyl((-31, 0, 21.4), (-31, 0, 28), 1.6, "rust", 16))
    parts.append(box((-31, 0, 28.2), (3.4, 3.4, 0.4), "dark"))
    for x in (-12, 4):  # Derrick posts.
        parts.append(cyl((x, 0, 9), (x, 0, 20), 0.5, "rust", 12))
        parts.append(beam((x, 0, 12), (x + 9, 0, 17), 0.35, "rust"))
    return join(parts, "ship_hulk")


def radio_mast():
    """A 52 m triangular lattice mast in red and white bands, with a beacon on top."""
    parts = []
    corners = [(1.0, 0.0), (-0.5, 0.87), (-0.5, -0.87)]
    for k in range(13):
        z0, z1 = k * 4.0, (k + 1) * 4.0
        paint = "marking_red" if k % 2 == 0 else "concrete"
        for i, (x, y) in enumerate(corners):
            nx, ny = corners[(i + 1) % 3]
            parts.append(beam((x, y, z0), (x, y, z1), 0.12, paint))
            parts.append(beam((x, y, z0), (nx, ny, z1), 0.05, paint))
            parts.append(beam((x, y, z1), (nx, ny, z1), 0.05, paint))
    parts.append(box((0, 0, 0.4), (3.0, 3.0, 0.8), "concrete"))
    for z in (26, 52):
        parts.append(ball((0, 0, z + 0.4), 0.35, "light_red", segments=10, rings=6))
    parts.append(box((0.6, 0.9, 40), (0.2, 1.2, 2.0), "metal"))  # Antenna panels.
    parts.append(box((-0.9, -0.3, 44), (1.2, 0.2, 2.0), "metal"))
    return join(parts, "radio_mast")


BUILDS = [station_pad, pylon, water_tower, headframe, lambda: shack("shack", 5.0), lambda: shack("shack_long", 9.0),
          trestle, fuel_tank, crates,
          lambda: container("container_red", "container_red"), lambda: container("container_blue", "container_blue"),
          lambda: container("container_green", "container_green"), lambda: container("container_orange", "container_orange"),
          gantry_crane, warehouse, ship_hulk, radio_mast]


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
                 "crates", "container_red", "container_blue", "container_green", "container_orange", "gantry_crane",
                 "warehouse", "ship_hulk", "radio_mast"]
        only = args[2:]
        for k, name in enumerate(names):
            if only and name not in only:
                continue
            size = {"pylon": 30, "trestle": 34, "headframe": 22, "water_tower": 17, "gantry_crane": 60,
                    "warehouse": 42, "ship_hulk": 75, "radio_mast": 55}.get(name, 13)
            base.VIEWS[name] = ((k * 40.0 + size * 1.1, -size * 1.5, size * 0.75), (k * 40.0, -size * 0.1, size * 0.4))
        base.preview(args[1], list(base.VIEWS))
    else:
        base.OUT = OUT
        base.export()
