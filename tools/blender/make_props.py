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
radio_mast (a 52 m lattice mast with a beacon), silo (a 30 m grain silo), conveyor (a 40 m
enclosed belt bridge along X at z = 16..19 on two lattice towers), rail_wagon (a 14 m
flatcar along X, deck at z = 1.4, for a container on top), straddle_carrier (a 15 m
portal along X that straddles a container row), lamp_mast (a 28 m floodlight mast),
lighthouse (26 m), tetrapod (a 3.5 m breakwater block), tugboat (22 m along X), barge
(40 x 14 m, deck at z = 3), pipe_rack (30 m along X, pipes at z = 5.5 and 7.6),
scrap_pile_1 / _2 (heaps of crushed cars, about 12 m across and 6 m high), buoy.
Battlefield (Mesa Basin, Slot Canyon): wreck_heli (a crashed helicopter on its side,
11 m), wreck_truck (a burnt-out army truck, 8 m along X), wreck_tank (a tank hull with
its turret knocked askew, 7 m), radar_station (a 14 m lattice tower with a dish and a
cabin), sandbags (a 6 m curved sandbag wall).

Materials are named for the game to swap (Props.materials): wood, wood_dark, rust,
concrete, metal, dark, hazard, decal, glass, corrugated, lamp.
Blender +Y becomes Godot -Z, so a prop "facing" +Y faces the game's forward.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import make_choppa as base  # noqa: E402
from make_choppa import ball, box, cyl, join, ring, tube  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "props", "props.glb")

base.PREVIEW.update({
    "wood": ((0.45, 0.32, 0.2), 0.0, 0.85), "wood_dark": ((0.25, 0.17, 0.11), 0.0, 0.9),
    "rust": ((0.42, 0.2, 0.1), 0.4, 0.8), "concrete": ((0.55, 0.54, 0.5), 0.0, 0.9),
    "corrugated": ((0.5, 0.48, 0.44), 0.6, 0.6),
    "container_red": ((0.45, 0.12, 0.08), 0.3, 0.6), "container_blue": ((0.1, 0.22, 0.42), 0.3, 0.6),
    "container_green": ((0.15, 0.3, 0.18), 0.3, 0.6), "container_orange": ((0.62, 0.3, 0.08), 0.3, 0.6),
    "crane": ((0.78, 0.56, 0.08), 0.3, 0.55), "hull_dark": ((0.12, 0.13, 0.14), 0.3, 0.7),
    "sand": ((0.62, 0.55, 0.4), 0.0, 0.95),
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


def windsock(at, height, toward):
    """A windsock on its own pole: a hoop and a drooping striped cone."""
    at, toward = Vector(at), Vector(toward).normalized()
    parts = [cyl(at, at + Vector((0, 0, height)), 0.06, "metal", 10)]
    top = at + Vector((0, 0, height))
    parts.append(cyl(top - Vector((0, 0, 0.05)), top + Vector((0, 0, 0.05)), 0.09, "dark", 10))
    mouth = top + toward * 0.15 + Vector((0, 0, -0.05))
    parts.append(ring(mouth, toward, 0.32, 0.02, "metal", 18))
    for k in range(5):  # Bands: hazard and white, narrowing and drooping toward the tail.
        t0, t1 = k / 5, (k + 1) / 5
        a = mouth + toward * 1.8 * t0 + Vector((0, 0, -0.35 * t0 * t0))
        b = mouth + toward * 1.8 * t1 + Vector((0, 0, -0.35 * t1 * t1))
        parts.append(cyl(a, b, 0.31 * (1 - 0.55 * t0), "hazard" if k % 2 == 0 else "decal", 18,
                         radius2=0.31 * (1 - 0.55 * t1)))
    return parts


def fuel_bowser(at, yaw):
    """A small fuel trailer: a tank on a frame with two wheels, a drawbar, a hose reel
    at the back, placards and a ladder."""
    parts = []
    rot = Matrix.Rotation(yaw, 4, "Z")
    o = Vector(at)

    def p(x, y, z):
        return o + rot @ Vector((x, y, z))

    parts.append(cyl(p(-1.3, 0, 1.05), p(1.3, 0, 1.05), 0.62, "paint", 24, bevel_width=0.06))  # The tank.
    for x in (-1.0, 0.0, 1.0):
        parts.append(cyl(p(x - 0.03, 0, 1.05), p(x + 0.03, 0, 1.05), 0.635, "dark", 24))  # Straps.
    parts.append(cyl(p(0.2, 0, 1.66), p(0.2, 0, 1.76), 0.18, "metal", 16, bevel_width=0.01))  # Hatch.
    parts.append(box(p(0, -0.63, 1.05), (1.0, 0.02, 0.32), "hazard"))  # Placard.
    parts.append(box(p(0, 0.63, 1.05), (1.0, 0.02, 0.32), "hazard"))
    parts.append(box(p(0, 0, 0.42), (2.6, 0.9, 0.12), "dark", bevel_width=0.02))  # Frame.
    for side in (-1, 1):
        parts.append(cyl(p(-0.2, side * 0.62, 0.42), p(-0.2, side * 0.82, 0.42), 0.4, "rubber", 20, bevel_width=0.04))
        parts.append(cyl(p(-0.2, side * 0.6, 0.42), p(-0.2, side * 0.84, 0.42), 0.2, "metal", 14))
        parts.append(box(p(-0.2, side * 0.72, 0.85), (0.9, 0.24, 0.06), "dark", bevel_width=0.01))  # Mudguard.
    parts.append(tube([p(1.3, 0, 0.45), p(1.9, 0, 0.4), p(2.3, 0, 0.3)], 0.05, "dark", 8))  # Drawbar.
    parts.append(ring(p(2.33, 0, 0.3), (0, 0, 1), 0.08, 0.02, "metal", 12))
    parts.append(cyl(p(2.1, 0, 0.3), p(2.1, 0, 0.0), 0.04, "metal", 8))  # Prop stand.
    reel = p(-1.55, 0, 0.9)  # Hose reel at the back.
    parts.append(cyl(reel + rot @ Vector((0, -0.35, 0)), reel + rot @ Vector((0, 0.35, 0)), 0.3, "metal", 20,
                     bevel_width=0.02))
    parts.append(cyl(reel + rot @ Vector((0, -0.3, 0)), reel + rot @ Vector((0, 0.3, 0)), 0.34, "rubber", 20))
    for side in (-1, 1):
        parts.append(cyl(reel + rot @ Vector((0, side * 0.36, 0)), reel + rot @ Vector((0, side * 0.38, 0)), 0.42, "dark", 20))
    for k in range(4):  # Ladder up the side.
        parts.append(cyl(p(0.9, -0.66, 0.6 + k * 0.28) + rot @ Vector((-0.15, 0, 0)),
                         p(0.9, -0.66, 0.6 + k * 0.28) + rot @ Vector((0.15, 0, 0)), 0.018, "metal", 6))
    return parts, reel


def ammo_rack(at):
    """A rack of rocket and missile crates under a tarp frame, by the pad."""
    at = Vector(at)
    parts = [box(at + Vector((0, 0, 0.08)), (2.2, 1.1, 0.16), "wood_dark", bevel_width=0.02)]  # Pallet.
    for k, (x, z) in enumerate([(-0.55, 0.4), (0.55, 0.4), (0.0, 0.88)]):
        c = at + Vector((x, 0, z))
        parts.append(box(c, (1.05, 0.95, 0.46), "paint", bevel_width=0.03))
        parts.append(box(c + Vector((0, 0, 0.0)), (1.07, 0.97, 0.06), "hazard"))
        for s in (-1, 1):  # Handles.
            parts.append(box(c + Vector((s * 0.53, 0, 0.05)), (0.04, 0.3, 0.06), "dark", bevel_width=0.01))
    return parts


def sandbag_ring(center, radius, a0, a1, rows=2):
    """A low curved wall of sandbags."""
    parts = []
    c = Vector(center)
    n = max(2, int(abs(a1 - a0) * radius / 0.62))
    for row in range(rows):
        for k in range(n):
            a = a0 + (a1 - a0) * (k + 0.5 * (row % 2)) / n
            p = c + Vector((math.cos(a) * radius, math.sin(a) * radius, 0.16 + row * 0.27))
            parts.append(box(p, (0.6, 0.34, 0.26), "sand", rotation=Matrix.Rotation(a + math.pi / 2, 4, "Z"),
                             bevel_width=0.1))
    return parts


def station_pad():
    """A forward refuelling point: a concrete pad of cast slabs with a raised kerb, its
    markings worn in by skids, light fittings round the rim (the game lights them), the
    mast (the game puts the status lamp on top) with a ladder and a floodlight, a fuel
    trailer with its hose run out to the pad, an ammo rack, a windsock, sandbags and a
    fire point. Keeps clear: the mast at (r + 1.2, 0) and, beside it, where ammo pads
    stack their crates (x r + 0.8..r + 2.1, y -1.1..-3.1)."""
    r = 6.0
    # The slab's top stays at 0.3, where the game's landing check expects it.
    parts = [cyl((0, 0, -0.3), (0, 0, 0.3), r, "concrete", 64),
             cyl((0, 0, -0.35), (0, 0, -0.1), r + 0.35, "concrete", 64)]
    parts.append(ring((0, 0, 0.28), (0, 0, 1), r + 0.1, 0.13, "concrete", 64))  # A rounded kerb round the edge.
    # Joints between the cast slabs: a grid of dark seams clipped to the circle.
    for k in range(-4, 5):
        v = k * 1.4
        half = math.sqrt(max(0.0, (r - 0.1) ** 2 - v * v))
        if half > 0.3:
            parts.append(box((v, 0, 0.302), (0.04, half * 2, 0.01), "dark"))
            parts.append(box((0, v, 0.302), (half * 2, 0.04, 0.01), "dark"))
    # Markings: the ring, the H, touchdown dashes, skid marks scuffed across the middle.
    parts.append(ring((0, 0, 0.305), (0, 0, 1), r - 0.6, 0.12, "hazard", 64))
    for x in (-1.3, 1.3):
        parts.append(box((x, 0, 0.308), (0.5, 3.6, 0.02), "hazard"))
    parts.append(box((0, 0, 0.308), (2.1, 0.5, 0.02), "hazard"))
    for k in range(16):
        a = 2 * math.pi * k / 16
        parts.append(box((math.cos(a) * (r - 1.2), math.sin(a) * (r - 1.2), 0.306), (0.12, 0.6, 0.015), "decal",
                         rotation=Matrix.Rotation(a, 4, "Z")))
    rng = random.Random(7)
    for k in range(4):
        a = rng.uniform(0, math.pi)
        parts.append(box((rng.uniform(-1.8, 1.8), rng.uniform(-1.8, 1.8), 0.307), (1.4, 0.07, 0.01), "rubber",
                         rotation=Matrix.Rotation(a, 4, "Z")))
    # Light fittings under the game's rim lights; tie-down rings.
    for k in range(8):
        a = 2 * math.pi * k / 8
        p = Vector((math.cos(a) * (r - 0.3), math.sin(a) * (r - 0.3), 0.3))
        parts.append(cyl(p, p + Vector((0, 0, 0.08)), 0.2, "dark", 14, bevel_width=0.02))
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        parts.append(ring((math.cos(a) * 3.4, math.sin(a) * 3.4, 0.32), (0, 0, 1), 0.12, 0.025, "metal", 12))
        parts.append(cyl((math.cos(a) * 3.4, math.sin(a) * 3.4, 0.3), (math.cos(a) * 3.4, math.sin(a) * 3.4, 0.32),
                         0.07, "dark", 10))
    # The mast: a footing with bolts, a pole with a ladder, a cable box, a floodlight.
    mast = Vector((r + 1.2, 0, 0))
    parts.append(cyl(mast + Vector((0, 0, -0.3)), mast + Vector((0, 0, 0.25)), 0.5, "concrete", 18, bevel_width=0.03))
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        parts.append(cyl(mast + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.25)),
                         mast + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.33)), 0.035, "metal", 6))
    parts.append(cyl(mast + Vector((0, 0, 0.25)), mast + Vector((0, 0, 6.0)), 0.16, "metal", 12, radius2=0.11))
    parts.append(cyl(mast + Vector((0, 0, 5.9)), mast + Vector((0, 0, 6.05)), 0.3, "dark", 16))
    for k in range(3):
        parts.append(ring(mast + Vector((0, 0, 1.0 + k * 1.6)), (0, 0, 1), 0.15, 0.02, "hazard", 12))
    for k in range(14):  # Ladder rungs up the outside of the pole.
        z = 0.6 + k * 0.36
        parts.append(cyl(mast + Vector((0.2, -0.18, z)), mast + Vector((0.2, 0.18, z)), 0.015, "metal", 6))
    for y in (-0.18, 0.18):
        parts.append(cyl(mast + Vector((0.2, y, 0.5)), mast + Vector((0.2, y, 5.6)), 0.018, "metal", 6))
    parts.append(box(mast + Vector((-0.24, 0, 1.3)), (0.18, 0.36, 0.5), "dark", bevel_width=0.02))  # Cable box.
    flood = mast + Vector((-0.25, 0, 4.8))
    parts.append(cyl(mast + Vector((0, 0, 4.8)), flood, 0.03, "metal", 6))
    parts.append(box(flood + Vector((-0.12, 0, -0.05)), (0.22, 0.42, 0.3), "dark",
                     rotation=Matrix.Rotation(math.radians(35), 4, "Y"), bevel_width=0.02))
    parts.append(box(flood + Vector((-0.24, 0, -0.13)), (0.02, 0.36, 0.24), "lamp",
                     rotation=Matrix.Rotation(math.radians(35), 4, "Y")))
    # Fuel trailer on the far side of the mast, its hose run out to the pad's edge.
    bowser, reel = fuel_bowser((r + 2.4, 2.8, 0.0), math.radians(-70))
    parts += bowser
    parts.append(tube([reel, reel + Vector((-0.3, -0.4, -0.75)), Vector((r + 0.7, 1.6, 0.06)), Vector((r - 0.2, 1.0, 0.4))],
                      0.05, "rubber", 8))
    parts.append(cyl((r - 0.2, 1.0, 0.4), (r - 0.55, 0.9, 0.42), 0.07, "metal", 10))  # Nozzle.
    # Fire point: an extinguisher on a stand with a sign.
    fire = Vector((r + 0.9, 4.4, 0))
    parts.append(box(fire + Vector((0, 0, 0.6)), (0.05, 0.4, 1.2), "marking_red", bevel_width=0.01))
    parts.append(cyl(fire + Vector((0.12, 0, 0.15)), fire + Vector((0.12, 0, 0.75)), 0.1, "marking_red", 14,
                     bevel_width=0.02))
    parts.append(box(fire + Vector((0.0, 0, 1.3)), (0.04, 0.45, 0.3), "decal"))
    # Ammo rack and a windsock behind the pad, sandbags along the back edge.
    parts += ammo_rack((-r - 1.6, -2.4, 0.0))
    parts += windsock((-r - 1.4, 3.2, 0.0), 4.2, (0.3, -1.0, 0))
    parts += sandbag_ring((0, 0, 0), r + 1.2, math.radians(140), math.radians(220))
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


def silo():
    """A 30 m concrete grain silo: a 6 m radius drum, a cone roof, a cage ladder."""
    parts = [cyl((0, 0, 0), (0, 0, 26), 6.0, "concrete", 40, bevel_width=0.05)]
    parts.append(cyl((0, 0, 26), (0, 0, 29.5), 6.05, "rust", 40, radius2=1.2))
    parts.append(cyl((0, 0, 29.5), (0, 0, 30.4), 1.2, "dark", 16))
    for z in (6, 13, 20, 25.8):
        parts.append(ring((0, 0, z), (0, 0, 1), 6.04, 0.08, "rust", 40))
    for sy in (-0.35, 0.35):  # Ladder up the south side.
        parts.append(beam((sy, -6.25, 0.2), (sy, -6.25, 26.5), 0.07, "metal"))
    for k in range(52):
        parts.append(beam((-0.35, -6.25, 0.5 + k * 0.5), (0.35, -6.25, 0.5 + k * 0.5), 0.04, "metal"))
    for k in range(12):  # The cage round it.
        z = 3 + k * 2.0
        parts.append(ring((0, -6.6, z), (0, 0, 1), 0.55, 0.03, "metal", 12))
    parts.append(box((0, 0, 0.3), (12.6, 12.6, 0.6), "concrete"))
    return join(parts, "silo")


def conveyor():
    """A 40 m enclosed belt bridge along X (z 16 to 19), on two lattice towers at x = +-15."""
    parts = [box((0, 0, 17.5), (40, 3.0, 3.0), "corrugated")]
    for sy in (-1.6, 1.6):  # Truss chords and diagonals along both sides.
        for z in (16.0, 19.0):
            parts.append(beam((-20, sy, z), (20, sy, z), 0.3, "rust"))
        for k in range(10):
            x0 = -20 + k * 4
            parts.append(beam((x0, sy, 16.0), (x0 + 4, sy, 19.0), 0.16, "rust"))
            parts.append(beam((x0, sy, 16.0), (x0, sy, 19.0), 0.16, "rust"))
    parts.append(box((0, 0, 19.15), (40.4, 3.6, 0.3), "rust"))  # Roof lip.
    for x in (-15, 15):
        parts += lattice_leg((x, 0, 0), (x, 0, 16), 1.3, "rust", bays=5)
        parts.append(box((x, 0, 0.3), (3.4, 3.4, 0.6), "concrete"))
        parts.append(box((x, 0, 15.8), (3.2, 3.6, 0.4), "rust"))
    return join(parts, "conveyor")


def rail_wagon():
    """A 14 m container flatcar along X: deck at z = 1.4 on two bogies."""
    parts = [box((0, 0, 1.2), (14, 2.7, 0.4), "rust")]
    for sy in (-1.2, 1.2):
        parts.append(box((0, sy, 0.9), (14, 0.3, 0.5), "dark"))
    for x in (-5.0, 5.0):
        parts.append(box((x, 0, 0.75), (2.6, 2.2, 0.5), "dark"))
        for dx in (-0.8, 0.8):
            for sy in (-0.75, 0.75):
                parts.append(cyl((x + dx, sy - 0.08, 0.45), (x + dx, sy + 0.08, 0.45), 0.45, "metal", 16))
    for x in (-7.2, 7.2):
        parts.append(box((x, 0, 1.0), (0.6, 0.4, 0.3), "dark"))  # Couplers.
    return join(parts, "rail_wagon")


def straddle_carrier():
    """A container straddle carrier: four legs 12 m apart along X and 5.6 m across, a
    15 m high frame, the cab up on one side. It stands over a row of containers."""
    parts = []
    for sx in (-6, 6):
        for sy in (-2.8, 2.8):
            parts.append(box((sx, sy, 7.0), (0.8, 0.8, 14.0), "crane"))
            parts.append(cyl((sx - 0.6, sy, 0.6), (sx + 0.6, sy, 0.6), 0.6, "dark", 16))  # Wheels.
            parts.append(cyl((sx, sy - 0.6, 0.6), (sx, sy + 0.6, 0.6), 0.6, "dark", 16))
        parts.append(box((sx, 0, 14.4), (1.0, 6.4, 1.0), "crane"))
    for sy in (-2.8, 2.8):
        parts.append(box((0, sy, 14.4), (13.0, 1.0, 1.0), "crane"))
        parts.append(beam((-6, sy, 1.6), (6, sy, 1.6), 0.5, "crane"))
    parts.append(box((6.6, 2.8, 12.4), (2.2, 2.2, 2.4), "crane"))
    parts.append(box((7.72, 2.8, 12.8), (0.04, 1.8, 1.2), "glass"))
    parts.append(box((0, 0, 11.8), (12.2, 2.44, 0.5), "dark"))  # The spreader.
    parts.append(ball((0, 0, 15.2), 0.3, "lamp", segments=8, rings=4))
    return join(parts, "straddle_carrier")


def lamp_mast():
    """A 28 m quay floodlight mast with a ring of four lamps."""
    parts = [cyl((0, 0, 0), (0, 0, 27), 0.5, "metal", 14, radius2=0.22)]
    parts.append(box((0, 0, 0.5), (1.6, 1.6, 1.0), "concrete"))
    parts.append(ring((0, 0, 27), (0, 0, 1), 1.2, 0.1, "dark", 20))
    for k in range(4):
        a = k * math.pi / 2
        x, y = math.cos(a) * 1.2, math.sin(a) * 1.2
        parts.append(box((x, y, 27.6), (0.9, 0.9, 0.5), "dark"))
        parts.append(box((x, y, 27.33), (0.8, 0.8, 0.04), "lamp"))
    for k in range(9):  # Climbing rungs.
        parts.append(beam((-0.3, 0.45, 2 + k * 2.8), (0.3, 0.45, 2 + k * 2.8), 0.05, "metal"))
    return join(parts, "lamp_mast")


def lighthouse():
    """A 26 m harbour light in red and white bands with a gallery and a lit lantern."""
    parts = []
    for k in range(6):
        z0, z1 = k * 4.0, (k + 1) * 4.0
        r0, r1 = 4.0 - k * 0.22, 4.0 - (k + 1) * 0.22
        parts.append(cyl((0, 0, z0), (0, 0, z1), r0, "container_red" if k % 2 == 0 else "concrete", 32, radius2=r1))
    parts.append(cyl((0, 0, 24), (0, 0, 24.4), 3.6, "dark", 32))
    parts.append(ring((0, 0, 25.3), (0, 0, 1), 3.5, 0.06, "metal", 32))
    for k in range(16):
        a = k * math.tau / 16
        parts.append(beam((math.cos(a) * 3.5, math.sin(a) * 3.5, 24.4), (math.cos(a) * 3.5, math.sin(a) * 3.5, 25.3), 0.05, "metal"))
    parts.append(cyl((0, 0, 24.4), (0, 0, 27.4), 1.8, "glass", 16))
    parts.append(ball((0, 0, 25.9), 0.9, "lamp", segments=12, rings=6))
    parts.append(cyl((0, 0, 27.4), (0, 0, 29), 1.9, "dark", 16, radius2=0.3))
    parts.append(box((0, -3.9, 1.3), (1.4, 0.4, 2.4), "dark"))  # Door.
    return join(parts, "lighthouse")


def tetrapod():
    """A concrete breakwater tetrapod: four stubby cones from a centre, 3.5 m across."""
    parts = [ball((0, 0, 1.2), 0.9, "concrete", segments=12, rings=6)]
    dirs = [(0, 0, 1), (0.943, 0, -0.333), (-0.471, 0.816, -0.333), (-0.471, -0.816, -0.333)]
    for d in dirs:
        tip = Vector((0, 0, 1.2)) + Vector(d) * 1.9
        parts.append(cyl((0, 0, 1.2), tip, 0.75, "concrete", 12, radius2=0.45))
    return join(parts, "tetrapod")


def tugboat():
    """A 22 m harbour tug along X (bow at +X): a hull with tyre fenders, a wheelhouse."""
    deck = [(-10, -3.6), (6, -3.6), (11, -1.6), (12, 0), (11, 1.6), (6, 3.6), (-10, 3.6)]
    keel = [(-9.5, -2.6), (5.5, -2.6), (9.5, -1.0), (10.5, 0), (9.5, 1.0), (5.5, 2.6), (-9.5, 2.6)]
    parts = [prism(keel, deck, 0.0, 3.6, "container_red")]
    parts.append(prism([(x * 1.01, y * 1.01) for x, y in deck], [(x * 1.01, y * 1.01) for x, y in deck], 3.4, 4.0, "dark"))
    parts.append(box((-1, 0, 5.5), (7, 5.2, 3.0), "paint"))
    parts.append(box((0.5, 0, 8.0), (4.5, 4.6, 2.0), "paint"))
    for sy in (-2.32, 2.32):
        parts.append(box((0.5, sy, 8.2), (3.6, 0.04, 0.9), "glass"))
    parts.append(box((2.77, 0, 8.2), (0.04, 3.6, 0.9), "glass"))
    parts.append(cyl((-3.5, 0, 7), (-3.5, 0, 10.5), 0.7, "dark", 12))
    parts.append(cyl((1, 0, 9), (1, 0, 13), 0.12, "metal", 6))
    for k in range(8):  # Tyre fenders along the sides.
        x = -8 + k * 2
        for sy in (-3.7, 3.7):
            parts.append(ring((x, sy, 2.6), (0, 1, 0), 0.45, 0.18, "dark", 12))
    return join(parts, "tugboat")


def barge():
    """A 40 x 14 m flat deck barge (deck at z = 3), rusty, with a low coaming."""
    parts = [box((0, 0, 1.5), (40, 14, 3.0), "rust", bevel_width=0.2)]
    for sy in (-6.8, 6.8):
        parts.append(box((0, sy, 3.3), (40, 0.3, 0.6), "dark"))
    for sx in (-19.8, 19.8):
        parts.append(box((sx, 0, 3.3), (0.3, 14, 0.6), "dark"))
    for x in (-16, 16):
        for sy in (-5.5, 5.5):
            parts.append(cyl((x, sy, 3.0), (x, sy, 3.7), 0.3, "metal", 10))  # Bitts.
    return join(parts, "barge")


def pipe_rack():
    """A 30 m pipe bridge along X: portals every 6 m, four pipes on top, two below."""
    parts = []
    for k in range(6):
        x = -15 + k * 6
        for sy in (-2, 2):
            parts.append(beam((x, sy, 0), (x, sy, 7.0), 0.4, "rust"))
        for z in (5.0, 7.0):
            parts.append(beam((x, -2.2, z), (x, 2.2, z), 0.4, "rust"))
        parts.append(box((x, 0, 0.25), (1.0, 5.0, 0.5), "concrete"))
    for k, sy in enumerate((-1.5, -0.5, 0.5, 1.5)):
        r = 0.45 if k % 2 == 0 else 0.3
        parts.append(cyl((-16, sy, 7.2 + r), (16, sy, 7.2 + r), r, "metal" if k % 2 else "rust", 16))
    for sy in (-1.0, 1.0):
        parts.append(cyl((-16, sy, 5.55), (16, sy, 5.55), 0.35, "dark", 14))
    return join(parts, "pipe_rack")


def scrap_pile(name, seed):
    """A heap of crushed cars round a rusty mound, about 12 m across and 6 m high."""
    rng = random.Random(seed)
    parts = [cyl((0, 0, 0), (0, 0, 3.2), 6.0, "rust", 14, radius2=2.0)]
    paints = ["container_red", "container_blue", "container_green", "rust", "rust", "dark"]
    for k in range(34):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 5.2)
        z = max(0.4, 3.2 * (1 - r / 6.0)) + rng.uniform(0.0, 1.8)
        car = box((0, 0, 0), (rng.uniform(3.2, 4.4), rng.uniform(1.6, 1.9), rng.uniform(0.6, 1.2)),
                  paints[rng.randrange(len(paints))], bevel_width=0.08)
        rot = (Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z") @ Matrix.Rotation(rng.uniform(-0.6, 0.6), 4, "X")
               @ Matrix.Rotation(rng.uniform(-0.4, 0.4), 4, "Y"))
        base.place(car, Matrix.Translation((math.cos(a) * r, math.sin(a) * r, z)) @ rot)
        parts.append(car)
    return join(parts, name)


def buoy():
    """A red channel buoy: a float, a cage and a lamp."""
    parts = [cyl((0, 0, -0.6), (0, 0, 1.0), 1.3, "container_red", 20, radius2=1.1)]
    parts.append(cyl((0, 0, 1.0), (0, 0, 3.2), 0.5, "container_red", 12, radius2=0.25))
    parts.append(ring((0, 0, 1.0), (0, 0, 1), 1.15, 0.1, "dark", 20))
    parts.append(ball((0, 0, 3.4), 0.25, "lamp", segments=8, rings=4))
    return join(parts, "buoy")


def burnt(parts, rng, count, center, spread, size=(0.6, 0.6, 0.05)):
    """Scorch flakes and bits of debris strewn round a wreck."""
    for _ in range(count):
        p = Vector(center) + Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), 0.02))
        parts.append(base.place(box((0, 0, 0), (rng.uniform(0.2, size[0]), rng.uniform(0.2, size[1]), size[2]),
                                    "dark"), Matrix.Translation(p) @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "Z")))


def wreck_heli():
    """A crashed helicopter lying on its side: the cabin, the boom broken off and lying
    beside it, blades bent into the ground, burnt patches."""
    rng = random.Random(5)
    parts = []
    tilt = Matrix.Rotation(math.radians(70), 4, "Y")  # Rolled onto its right side.
    body = cyl((0, 1.6, 0), (0, -1.4, 0), 1.0, "rust", 18, radius2=0.8)
    nose = ball((0, 1.6, 0), 1.0, "rust", scale=(1, 0.9, 1), segments=16, rings=8)
    for o in (body, nose):
        parts.append(base.place(o, Matrix.Translation((0, 0, 0.95)) @ tilt))
    parts.append(base.place(ball((0, 2.0, 0.4), 0.7, "dark", scale=(0.9, 0.7, 0.6), segments=12, rings=6),
                            Matrix.Translation((0, 0, 0.95)) @ tilt))  # The burnt-out canopy hole.
    parts.append(cyl((0.4, -1.6, 0.6), (1.9, -5.8, 0.4), 0.28, "rust", 12, radius2=0.18))  # Broken boom.
    parts.append(fin_plate((2.0, -5.9, 0.4)))
    for k, (a, b) in enumerate((((0.6, 0.0, 1.9), (4.6, 2.5, 0.05)), ((0.6, 0.0, 1.9), (-1.0, -3.8, 0.05)),
                                ((0.6, 0.0, 1.9), (3.2, -2.6, 1.2)))):
        parts.append(beam(a, b, 0.12 if k else 0.14, "dark"))  # Bent blades, two in the dirt.
    parts.append(cyl((0.3, 0.0, 1.6), (0.7, 0.0, 2.1), 0.15, "metal", 10))
    for side in (-1, 1):  # Skids torn loose.
        parts.append(beam((side * 1.4 + 0.6, 2.2, 0.08), (side * 1.2 + 0.4, -1.5, 0.08), 0.09, "metal"))
    burnt(parts, rng, 14, (0.5, 0.0, 0), 4.0)
    return join(parts, "wreck_heli")


def fin_plate(at):
    return box(at, (0.08, 1.0, 1.1), "rust")


def wreck_truck():
    """A burnt-out army truck along X (cab at +X): cab, flat bed with a torn canvas frame,
    six wheels, one gone."""
    rng = random.Random(9)
    parts = [box((2.7, 0, 1.55), (1.9, 2.4, 1.7), "rust", bevel_width=0.06),
             box((3.62, 0, 1.25), (0.15, 2.3, 0.9), "dark"),  # Grille.
             box((2.95, 0, 2.05), (0.9, 2.2, 0.7), "dark"),  # Empty windows.
             box((-0.9, 0, 1.15), (5.4, 2.5, 0.25), "rust"),
             box((0.0, 0, 0.75), (7.6, 0.9, 0.35), "dark")]
    for side in (-1, 1):
        parts.append(box((-0.9, side * 1.22, 1.6), (5.4, 0.08, 0.7), "rust"))
        for k in range(4):
            x = -3.4 + k * 1.6
            parts.append(beam((x, side * 1.2, 1.3), (x + 0.2, side * 1.1, 2.9), 0.06, "metal"))
        parts.append(beam((-3.4, side * 1.2, 2.9), (1.6, side * 1.1, 2.6), 0.06, "metal"))
    for x in (2.6, -1.6, -3.0):
        for side in (-1, 1):
            if x == -3.0 and side == 1:
                continue  # Blown off.
            parts.append(cyl((x, side * 1.05, 0.55), (x, side * 1.4, 0.55), 0.55, "rubber" if rng.random() < 0.5 else "dark", 16))
    burnt(parts, rng, 10, (0, 0, 0), 4.5)
    return join(parts, "wreck_truck")


def wreck_tank():
    """A tank hull with its tracks, the turret knocked askew and the gun pointing down."""
    rng = random.Random(13)
    parts = [box((0, 0, 1.05), (6.6, 2.6, 1.1), "rust", bevel_width=0.12),
             box((2.9, 0, 0.9), (1.0, 2.4, 0.9), "rust", rotation=Matrix.Rotation(math.radians(-25), 4, "Y"))]
    for side in (-1, 1):
        parts.append(box((0, side * 1.55, 0.6), (6.9, 0.6, 1.0), "dark", bevel_width=0.2))
        for k in range(6):
            parts.append(cyl((-2.6 + k * 1.05, side * 1.25, 0.5), (-2.6 + k * 1.05, side * 1.85, 0.5), 0.42, "metal", 14))
    turret = [cyl((0, 0, 0), (0, 0, 0.8), 1.35, "rust", 20, radius2=1.1), box((-1.2, 0, 0.4), (1.2, 1.8, 0.7), "rust"),
              cyl((1.2, 0, 0.4), (4.8, 0, 0.4), 0.13, "rust", 10)]
    m = Matrix.Translation((-0.3, 0.4, 1.55)) @ Matrix.Rotation(0.7, 4, "Z") @ Matrix.Rotation(math.radians(14), 4, "Y")
    for o in turret:
        parts.append(base.place(o, m))
    burnt(parts, rng, 12, (0, 0, 0), 4.5)
    return join(parts, "wreck_tank")


def radar_station():
    """An old early-warning radar: a lattice tower with a mesh dish and a feed horn, a
    cabin at its foot with an aerial and a stair."""
    parts = []
    parts += lattice_leg((0, 0, 0), (0, 0, 12), 1.6, "metal", bays=6)
    parts.append(box((0, 0, 12.1), (3.8, 3.8, 0.25), "metal"))
    for side in (-1, 1):
        parts.append(beam((side * 1.9, -1.9, 12.25), (side * 1.9, 1.9, 12.25), 0.05, "metal"))
        parts.append(beam((side * 1.9, -1.9, 13.2), (side * 1.9, 1.9, 13.2), 0.04, "metal"))
    # The dish: a curved mesh of ribs on a pedestal, tilted up toward the horizon.
    dish = []
    focal = 1.6  # A parabolic dish facing +Y: depth = r^2 / (4 f).
    for k in range(12):
        phi = k * math.tau / 12
        dish.append(tube([Vector((r * math.cos(phi), -0.9 + r * r / (4 * focal), r * math.sin(phi) * 0.6))
                          for r in [0.2 + 3.0 * j / 6 for j in range(7)]], 0.045, "metal", 6))
    for r in (1.2, 2.2, 3.2):
        dish.append(tube([Vector((r * math.cos(phi), -0.9 + r * r / (4 * focal), r * math.sin(phi) * 0.6))
                          for phi in [math.tau * j / 24 for j in range(25)]], 0.04, "metal", 6))
    dish.append(beam((0, -0.9, 0), (0, 0.7, 0.0), 0.08, "metal"))  # The feed arm and horn at the focus.
    dish.append(box((0, 0.75, 0.0), (0.3, 0.3, 0.3), "dark"))
    for o in dish:
        parts.append(base.place(o, Matrix.Translation((0, 0, 14.4)) @ Matrix.Rotation(math.radians(-12), 4, "X")))
    parts.append(cyl((0, 0, 12.2), (0, 0, 14.2), 0.35, "dark", 14))
    parts.append(box((6.0, 1.0, 1.4), (5.0, 3.2, 2.8), "corrugated", bevel_width=0.04))
    parts.append(box((6.0, 1.0, 2.9), (5.4, 3.6, 0.2), "rust"))
    parts.append(box((3.48, 1.0, 1.1), (0.05, 0.9, 1.9), "dark"))
    parts.append(cyl((7.6, 1.8, 3.0), (7.6, 1.8, 8.0), 0.04, "metal", 6))
    for k in range(10):  # Stair up the tower.
        z = 0.6 + k * 1.15
        parts.append(box((1.3, -1.0 + (k % 2) * 2.0, z), (0.9, 0.5, 0.06), "metal"))
    return join(parts, "radar_station")


def sandbags():
    """A 6 m curved wall of sandbags, three courses high, staggered."""
    rng = random.Random(21)
    parts = []
    for course in range(3):
        n = 10 - course
        for k in range(n):
            a = math.radians(-35 + (k + 0.5 * (course % 2)) * 70 / 10)
            x, y = math.sin(a) * 5.0, math.cos(a) * 5.0 - 5.0
            bag = box((0, 0, 0), (0.62, 0.36, 0.24), "sand", bevel_width=0.1)
            parts.append(base.place(bag, Matrix.Translation((x, y, 0.13 + course * 0.23)) @
                                    Matrix.Rotation(-a + rng.uniform(-0.08, 0.08), 4, "Z")))
    return join(parts, "sandbags")


BUILDS = [station_pad, pylon, water_tower, headframe, lambda: shack("shack", 5.0), lambda: shack("shack_long", 9.0),
          trestle, fuel_tank, crates,
          lambda: container("container_red", "container_red"), lambda: container("container_blue", "container_blue"),
          lambda: container("container_green", "container_green"), lambda: container("container_orange", "container_orange"),
          gantry_crane, warehouse, ship_hulk, radio_mast, silo, conveyor, rail_wagon, straddle_carrier, lamp_mast,
          lighthouse, tetrapod, tugboat, barge, pipe_rack, lambda: scrap_pile("scrap_pile_1", 3),
          lambda: scrap_pile("scrap_pile_2", 11), buoy, wreck_heli, wreck_truck, wreck_tank, radar_station, sandbags]


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
                 "warehouse", "ship_hulk", "radio_mast", "silo", "conveyor", "rail_wagon", "straddle_carrier",
                 "lamp_mast", "lighthouse", "tetrapod", "tugboat", "barge", "pipe_rack", "scrap_pile_1", "scrap_pile_2",
                 "buoy", "wreck_heli", "wreck_truck", "wreck_tank", "radar_station", "sandbags"]
        only = args[2:]
        for k, name in enumerate(names):
            if only and name not in only:
                continue
            # Framed on the prop itself: its size from its bounding box.
            size = max(max(bpy.data.objects[name].dimensions), 2.0)
            base.VIEWS[name] = ((k * 40.0 + size * 0.75, -size * 1.0, size * 0.55), (k * 40.0, 0.0, size * 0.22))
        base.preview(args[1], list(base.VIEWS))
    else:
        base.OUT = OUT
        base.export()
