"""Builds the other helicopter classes next to the Little Bird (make_choppa.py):
assets/models/choppa/gunship.glb, heavy.glb and striker.glb.

Run:     python tools/blender/make_airframes.py [gunship] [heavy] [striker]
Preview: python tools/blender/make_airframes.py --preview DIR [gunship|heavy|striker]

Same conventions as make_choppa.py, whose helpers this reuses: Blender +Y is the nose,
objects "rotor" and "tail_rotor" spin in the game, empties "eye", "muzzle_l/r",
"exhaust_l/r" and "pod_l/r" (where rockets leave) mark points the game reads, and the
material names are the game's (the hull shader paints panels and wear).

- Gunship: a slim tandem two-seat attack helicopter. Narrow armoured fuselage, stepped
  canopy, twin engine pods on the shoulders, stub wings with rocket pods and missile
  rails, a chin gun turret, four-blade rotor, skids. Scale 1.1 of the scout.
- Heavy: an armoured twin-engine gunship-transport (a Hind in spirit). Bulky body with
  bolted armour plates, troop doors, two big engines with intakes, long stub wings with
  pods, a twin-barrel chin turret, five-blade rotor, wheels. Scale 1.3 of the scout.
- Striker: a coaxial attack helicopter (Ka-52 in spirit), two stacked counter-rotating
  rotors and no tail rotor, side-by-side cockpit, twin cannon. Scale 1.15.
"""
import math
import os
import sys

import bpy
import bmesh  # Only importable after bpy.
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import make_choppa as base  # noqa: E402

from make_choppa import ball, box, cyl, empty, fin, join, loft, ring, tube, wing  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "choppa")


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base.MATS.clear()
    base.HULL.clear()


def rotor(blades, mast, rotor_z, scale):
    base.BLADES = blades
    base.MAST = mast
    base.ROTOR_Z = rotor_z
    r = base.rotor()
    r.scale = (scale, scale, 1.0)
    return r


def rivets(a, b, count, material="metal", radius=0.014):
    a, b = Vector(a), Vector(b)
    return [ball(a.lerp(b, k / max(1, count - 1)), radius, material, segments=6, rings=3) for k in range(count)]


def rocket_pod(center, length, radius, tubes=7):
    """A cylindrical rocket pod along +Y with tube mouths at the front."""
    c = Vector(center)
    parts = [cyl(c + Vector((0, -length / 2, 0)), c + Vector((0, length / 2, 0)), radius, "paint", 28, bevel_width=0.02),
             cyl(c + Vector((0, -length / 2 - 0.12, 0)), c + Vector((0, -length / 2, 0)), radius * 0.6, "paint", 28,
                 radius2=radius, bevel_width=0.01)]
    for y in (length / 2 - 0.02, -length / 2 + 0.1):
        parts.append(ring(c + Vector((0, y, 0)), (0, 1, 0), radius, 0.016, "metal", 28))
    for k in range(tubes):
        if k == tubes - 1:
            off = Vector((0, 0, 0))
        else:
            a = 2 * math.pi * k / (tubes - 1)
            off = Vector((radius * 0.58 * math.cos(a), 0, radius * 0.58 * math.sin(a)))
        mouth = c + off + Vector((0, length / 2 + 0.01, 0))
        parts.append(cyl(mouth, mouth + Vector((0, 0.02, 0)), radius * 0.24, "dark", 12))
        parts.append(ball(mouth + Vector((0, -0.03, 0)), radius * 0.17, "hazard", segments=8, rings=4))
    return parts


def missile_rail(center, length):
    c = Vector(center)
    parts = [box(c + Vector((0, 0, 0.08)), (0.06, length * 0.8, 0.06), "dark", bevel_width=0.01),
             cyl(c + Vector((0, -length / 2, 0)), c + Vector((0, length / 2 - 0.2, 0)), 0.09, "decal", 16),
             cyl(c + Vector((0, length / 2 - 0.2, 0)), c + Vector((0, length / 2, 0)), 0.09, "decal", 16, radius2=0.01)]
    for k in range(4):
        rot = Matrix.Rotation(math.pi / 2 * k + math.pi / 4, 4, "Y")
        parts.append(base.place(box(Vector((0, 0, 0)), (0.01, 0.22, 0.2), "dark"),
                                Matrix.Translation(c + Vector((0, -length / 2 + 0.15, 0))) @ rot @ Matrix.Translation((0, 0, 0.12))))
    return parts


def stub_wing(side, root, tip, chord_root, chord_tip):
    return wing("stub", (side * root[0], root[1], root[2]), (side * tip[0], tip[1], tip[2]), "paint",
                chord_root, chord_tip, 0.13, count=16, steps=2)


def tail(boom_start, boom_end, z0, z1, r0, r1, fin_scale, rotor_side=-1.0):
    parts = [cyl((0, boom_start, z0), (0, boom_end, z1), r0, "paint", 24, radius2=r1)]
    for k in range(5):
        t = (k + 0.5) / 5
        y = boom_start + (boom_end - boom_start) * t
        z = z0 + (z1 - z0) * t
        parts.append(ring((0, y, z), (0, 1, 0), r0 + (r1 - r0) * t + 0.004, 0.012, "paint", 24))
    end = Vector((0, boom_end, z1))
    s = fin_scale
    parts.append(fin([(0.15 * s, 0.0), (-0.55 * s, 1.2 * s), (-0.95 * s, 1.25 * s), (-1.0 * s, 1.0 * s),
                      (-0.6 * s, -0.05)], end, 0.08 * s))
    parts.append(fin([(0.0, 0.0), (-0.45 * s, 0.0), (-0.7 * s, -0.45 * s), (-0.45 * s, -0.5 * s)], end, 0.06 * s))
    parts.append(ball(end + Vector((0, -0.92 * s, 1.24 * s)), 0.04, "light_red", segments=10, rings=5))
    stab_y = boom_end + 1.0
    zs = z0 + (z1 - z0) * ((stab_y - boom_start) / (boom_end - boom_start))
    for side in (-1, 1):
        root = Vector((0, stab_y, zs))
        tip_ = Vector((side * 1.0 * s, stab_y - 0.08, zs))
        parts.append(wing("stabiliser", root, tip_, "paint", 0.5 * s, 0.36 * s, 0.1, count=16, steps=2))
        parts.append(fin([(0.22 * s, -0.2 * s), (-0.22 * s, -0.14 * s), (-0.28 * s, 0.26 * s), (0.12 * s, 0.28 * s)],
                         tip_, 0.03))
    gearbox = end + Vector((0, -0.1, 0.9 * s))
    parts.append(ball(gearbox, 0.16 * s, "metal", scale=(0.9, 1.4, 1.0), segments=20, rings=10))
    return parts, gearbox + Vector((rotor_side * 0.3 * s, 0, 0))


def engine_pod(side, x, y0, y1, z, radius):
    parts = [cyl((side * x, y0, z), (side * x, y1, z), radius, "paint", 28, bevel_width=0.03),
             ring((side * x, y0, z), (0, 1, 0), radius * 0.92, 0.03, "metal", 28),
             cyl((side * x, y0 + 0.01, z), (side * x, y0 - 0.02, z), radius * 0.8, "dark", 24)]
    # Intake grille and the exhaust stub turned out and back.
    for k in range(6):
        a = math.pi * k / 5
        parts.append(cyl((side * x + radius * 0.75 * math.cos(a), y0 + 0.03, z + radius * 0.75 * math.sin(a) * 0.3),
                         (side * x - radius * 0.75 * math.cos(a), y0 + 0.03, z - radius * 0.75 * math.sin(a) * 0.3),
                         0.008, "metal", 6))
    ex = Vector((side * (x + radius * 0.4), y1 - 0.05, z + 0.05))
    parts.append(cyl(ex, ex + Vector((side * 0.25, -0.35, 0.05)), radius * 0.45, "exhaust", 16, bevel_width=0.01))
    parts.append(ring(ex + Vector((side * 0.25, -0.35, 0.05)), (side * 0.6, -1.0, 0.1), radius * 0.45, 0.02, "exhaust",
                      20))
    parts += rivets((side * (x + radius), y0 + 0.2, z), (side * (x + radius), y1 - 0.2, z), 8)
    return parts, ex + Vector((side * 0.3, -0.45, 0.06))


def skid_gear(ground, x, y0, y1, struts):
    parts = []
    z = ground + 0.05
    for side in (-1, 1):
        parts.append(tube([(side * x, y0 - 0.25, z + 0.2), (side * x, y0, z), (side * x, y1, z),
                           (side * x, y1 + 0.3, z + 0.08), (side * x, y1 + 0.42, z + 0.28)], 0.05, "paint", 12))
        for y, top in struts:
            parts.append(tube([(side * 0.32, y, top), (side * (x - 0.15), y, (top + z) / 2), (side * x, y, z)],
                              0.045, "paint", 12))
    return parts


def wheel(center, radius, width):
    c = Vector(center)
    return [cyl(c - Vector((width / 2, 0, 0)), c + Vector((width / 2, 0, 0)), radius, "rubber", 24, bevel_width=0.03),
            cyl(c - Vector((width / 2 + 0.01, 0, 0)), c + Vector((width / 2 + 0.01, 0, 0)), radius * 0.55, "metal", 16)]


def chin_turret(center, barrels, length):
    c = Vector(center)
    parts = [ball(c, 0.24, "dark", segments=20, rings=10),
             cyl(c + Vector((0, 0, 0.12)), c + Vector((0, 0, 0.3)), 0.2, "metal", 20, bevel_width=0.02)]
    tips = []
    for k in range(barrels):
        x = (k - (barrels - 1) / 2) * 0.09
        a = c + Vector((x, 0.15, -0.02))
        b = a + Vector((0, length, 0))
        parts.append(cyl(a, b, 0.03, "metal", 10))
        parts.append(cyl(b - Vector((0, 0.1, 0)), b, 0.045, "dark", 12))
        tips.append(b)
    return parts, tips


# --- the gunship -------------------------------------------------------------------

def build_gunship():
    fresh()
    s = 1.1
    ground = -1.15 * s
    base.GROUND_Z = ground  # The preview floor.
    # Slim, tall fuselage: nose, front seat, rear seat, engine bay, tail cone.
    body = loft("fuselage", [
        (3.25, 0.06, -0.15, -0.08, -0.22, 2.0, 2.0),
        (2.95, 0.3, -0.18, 0.2, -0.55, 2.2, 2.4),
        (2.3, 0.44, -0.15, 0.45, -0.72, 2.4, 2.8),
        (1.2, 0.5, -0.1, 0.62, -0.8, 2.6, 3.0),
        (0.0, 0.52, 0.0, 0.8, -0.78, 2.6, 3.0),
        (-1.1, 0.5, 0.1, 0.85, -0.6, 2.6, 2.8),
        (-1.9, 0.34, 0.28, 0.72, -0.2, 2.4, 2.4),
        (-2.5, 0.2, 0.42, 0.62, 0.15, 2.2, 2.2),
    ], "paint", count=40)
    base.HULL.append(body)
    parts = [body]
    # Stepped tandem canopy: gunner in front, pilot behind and higher.
    for y, z, length, height in ((1.75, 0.42, 0.95, 0.42), (0.75, 0.68, 0.95, 0.42)):
        parts.append(ball((0, y, z), 1.0, "glass", scale=(0.36, length, height), segments=28, rings=14))
        parts.append(ring((0, y - length * 0.55, z), (0, 1, 0), 0.33, 0.025, "paint", 24))
    parts.append(tube([(0, 2.7, 0.1), (0, 2.2, 0.62), (0, 1.25, 0.84), (0, 0.2, 1.06), (0, -0.4, 1.02)], 0.035,
                      "paint", 10))
    # Armour plates and rivet lines along the flanks.
    for side in (-1, 1):
        parts.append(box((side * 0.5, 0.9, -0.3), (0.04, 1.8, 0.5), "paint", bevel_width=0.015))
        parts += rivets((side * 0.53, 0.05, -0.08), (side * 0.53, 1.75, -0.08), 10)
        parts += rivets((side * 0.53, 0.05, -0.52), (side * 0.53, 1.75, -0.52), 10)
    # Engine pods on the shoulders.
    exhausts = []
    for side in (-1, 1):
        p, ex = engine_pod(side, 0.48, 0.2, -1.5, 0.82, 0.24)
        parts += p
        exhausts.append(ex)
    # Mast fairing and rotor.
    parts.append(cyl((0, -0.35, 0.95), (0, -0.35, 1.35), 0.22, "paint", 24, radius2=0.14, bevel_width=0.02))
    parts.append(cyl((0, -0.35, 1.35), (0, -0.35, 1.62), 0.09, "metal", 16))
    # Stub wings with rocket pods underneath and missile rails at the tips.
    pods = []
    for side in (-1, 1):
        parts.append(stub_wing(side, (0.48, 0.15, -0.05), (1.75, 0.05, -0.12), 0.85, 0.6))
        parts.append(box((side * 1.45, 0.1, -0.28), (0.06, 0.45, 0.3), "dark", bevel_width=0.015))
        pod = Vector((side * 1.45, 0.25, -0.55))
        parts += rocket_pod(pod, 1.2, 0.2)
        pods.append(pod + Vector((0, 0.65, 0)))
        parts += missile_rail((side * 1.85, 0.0, -0.3), 1.3)
        parts.append(ball((side * 1.78, 0.0, -0.1), 0.04, "light_green" if side > 0 else "light_red", segments=10,
                          rings=5))
    # Chin turret.
    turret, tips = chin_turret((0, 2.55, -0.72), 3, 0.75)
    parts += turret
    # Tail.
    t, rotor_at = tail(-2.3, -6.6, 0.5, 0.82, 0.2, 0.1, 1.05)
    parts += t
    parts += skid_gear(ground, 0.85, -1.0, 1.9, [(1.5, -0.7), (-0.4, -0.6)])
    body = join(parts, "body")
    base.activate(body)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    rotor(4, Vector((0, -0.35, 1.62)), 1.75, 1.05)
    base.tail_rotor(rotor_at)
    empty("eye", (0, 0.78, 0.82))
    empty("muzzle_l", tips[0])
    empty("muzzle_r", tips[-1])
    empty("pod_l", pods[0])
    empty("pod_r", pods[1])
    empty("exhaust_l", exhausts[0])
    empty("exhaust_r", exhausts[1])


# --- the heavy ---------------------------------------------------------------------

def build_heavy():
    fresh()
    s = 1.3
    ground = -1.15 * s
    base.GROUND_Z = ground  # The preview floor.
    body = loft("fuselage", [
        (3.9, 0.1, -0.3, -0.2, -0.4, 2.0, 2.0),
        (3.5, 0.55, -0.35, 0.25, -0.9, 2.2, 2.6),
        (2.7, 0.8, -0.3, 0.6, -1.05, 2.6, 3.2),
        (1.4, 0.95, -0.2, 0.95, -1.1, 3.0, 3.5),
        (-0.4, 1.0, -0.1, 1.1, -1.05, 3.0, 3.5),
        (-1.9, 0.92, 0.0, 1.05, -0.9, 2.8, 3.2),
        (-2.9, 0.6, 0.25, 0.92, -0.35, 2.4, 2.6),
        (-3.6, 0.32, 0.45, 0.8, 0.1, 2.2, 2.2),
    ], "paint", count=44)
    base.HULL.append(body)
    parts = [body]
    # Two bubble canopies, gunner in the nose and pilot above and behind.
    parts.append(ball((0, 2.85, 0.05), 1.0, "glass", scale=(0.55, 0.85, 0.5), segments=28, rings=14))
    parts.append(ball((0, 1.75, 0.65), 1.0, "glass", scale=(0.6, 0.85, 0.5), segments=28, rings=14))
    for y, z, r in ((2.15, 0.05, 0.52), (1.05, 0.62, 0.57)):
        parts.append(ring((0, y, z), (0, 1, 0), r, 0.03, "paint", 28))
    # Bolted armour: big plates over the flanks and belly, rivet rows.
    for side in (-1, 1):
        for y0, y1, z, h in ((2.3, 0.4, -0.35, 0.8), (0.3, -1.6, -0.25, 1.0)):
            parts.append(box((side * 1.0, (y0 + y1) / 2, z), (0.06, abs(y0 - y1), h), "paint", bevel_width=0.02))
            parts += rivets((side * 1.04, y0 - 0.1, z + h / 2 - 0.06), (side * 1.04, y1 + 0.1, z + h / 2 - 0.06), 9)
            parts += rivets((side * 1.04, y0 - 0.1, z - h / 2 + 0.06), (side * 1.04, y1 + 0.1, z - h / 2 + 0.06), 9)
        # Troop door: frame and window.
        parts.append(box((side * 1.06, -0.65, -0.05), (0.03, 0.9, 0.85), "dark", bevel_width=0.01))
        parts.append(box((side * 1.08, -0.65, 0.18), (0.02, 0.45, 0.25), "glass"))
        parts.append(box((side * 1.08, -0.3, -0.1), (0.04, 0.1, 0.04), "brass"))
    parts.append(box((0, 0.6, -1.12), (1.3, 3.0, 0.08), "paint", bevel_width=0.02))
    # Engines on top with a big intake each and an exhaust turned out.
    exhausts = []
    for side in (-1, 1):
        p, ex = engine_pod(side, 0.62, 1.0, -1.6, 1.25, 0.36)
        parts += p
        exhausts.append(ex)
        parts.append(ball((side * 0.62, 1.05, 1.25), 0.2, "metal", scale=(1, 0.5, 1), segments=16, rings=8))
    parts.append(box((0, -0.3, 1.2), (0.7, 2.4, 0.35), "paint", bevel_width=0.05))
    parts.append(cyl((0, -0.4, 1.35), (0, -0.4, 1.78), 0.3, "paint", 24, radius2=0.18, bevel_width=0.02))
    parts.append(cyl((0, -0.4, 1.78), (0, -0.4, 2.05), 0.12, "metal", 16))
    # Long stub wings, drooping, with two pods and rails each.
    pods = []
    for side in (-1, 1):
        parts.append(stub_wing(side, (0.95, -0.4, 0.2), (2.6, -0.5, -0.05), 1.1, 0.75))
        for x, kind in ((1.6, "pod"), (2.4, "rail")):
            parts.append(box((side * x, -0.45, -0.03), (0.07, 0.5, 0.3), "dark", bevel_width=0.015))
            if kind == "pod":
                pod = Vector((side * x, -0.25, -0.38))
                parts += rocket_pod(pod, 1.5, 0.26, tubes=9)
                pods.append(pod + Vector((0, 0.8, 0)))
            else:
                parts += missile_rail((side * x, -0.45, -0.32), 1.5)
        parts.append(ball((side * 2.62, -0.5, -0.02), 0.05, "light_green" if side > 0 else "light_red", segments=10,
                          rings=5))
    turret, tips = chin_turret((0, 3.25, -0.82), 2, 0.9)
    parts += turret
    t, rotor_at = tail(-3.4, -8.2, 0.6, 1.0, 0.32, 0.14, 1.35)
    parts += t
    # Retractable-look wheels: two main gear legs and a nose wheel.
    for side in (-1, 1):
        hub = Vector((side * 1.15, -0.6, ground + 0.32))
        parts.append(tube([(side * 0.9, -0.6, -0.7), (side * 1.12, -0.6, -1.0), hub], 0.06, "metal", 12))
        parts += wheel(hub, 0.32, 0.22)
    nose = Vector((0, 2.6, ground + 0.24))
    parts.append(tube([(0, 2.6, -0.95), nose], 0.05, "metal", 12))
    for side in (-1, 1):
        parts += wheel(nose + Vector((side * 0.13, 0, 0)), 0.24, 0.12)
    body = join(parts, "body")
    base.activate(body)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    rotor(5, Vector((0, -0.4, 2.05)), 2.2, 1.3)
    tr = base.tail_rotor(rotor_at)
    tr.scale = (1.3, 1.3, 1.3)
    empty("eye", (0, 1.75, 0.68))
    empty("muzzle_l", tips[0])
    empty("muzzle_r", tips[-1])
    empty("pod_l", pods[0])
    empty("pod_r", pods[1])
    empty("exhaust_l", exhausts[0])
    empty("exhaust_r", exhausts[1])


# --- the striker -------------------------------------------------------------------

def build_striker():
    """A coaxial attack helicopter (a Ka-52 in spirit): side-by-side cockpit under a wide
    canopy, two counter-rotating rotors on one mast and no tail rotor (the game spins
    "rotor" one way and "rotor_upper" the other; "tail_rotor" is only an empty marking the
    tail end, for smoke and sparks), twin fins, a twin cannon under the chin, wheels."""
    fresh()
    s = 1.15
    ground = -1.15 * s
    base.GROUND_Z = ground
    body = loft("fuselage", [
        (3.35, 0.1, -0.2, -0.1, -0.3, 2.0, 2.0),
        (3.0, 0.45, -0.25, 0.25, -0.65, 2.2, 2.4),
        (2.3, 0.72, -0.2, 0.55, -0.82, 2.5, 2.8),
        (1.1, 0.78, -0.12, 0.8, -0.86, 2.8, 3.2),
        (-0.2, 0.74, -0.05, 0.95, -0.8, 2.8, 3.0),
        (-1.3, 0.6, 0.1, 0.95, -0.55, 2.6, 2.6),
        (-2.1, 0.38, 0.3, 0.8, -0.15, 2.4, 2.2),
        (-2.6, 0.24, 0.42, 0.68, 0.18, 2.2, 2.2),
    ], "paint", count=40)
    base.HULL.append(body)
    parts = [body]
    # Wide side-by-side canopy and its frame.
    parts.append(ball((0, 2.15, 0.42), 1.0, "glass", scale=(0.7, 1.05, 0.5), segments=32, rings=16))
    parts.append(ring((0, 1.25, 0.45), (0, 1, 0), 0.62, 0.03, "paint", 28))
    parts.append(tube([(0, 3.1, 0.05), (0, 2.6, 0.62), (0, 1.9, 0.88), (0, 1.2, 0.9)], 0.03, "paint", 10))
    for side in (-1, 1):
        parts.append(box((side * 0.76, 0.7, -0.35), (0.04, 1.6, 0.5), "paint", bevel_width=0.015))
        parts += rivets((side * 0.79, 0.0, -0.12), (side * 0.79, 1.4, -0.12), 8)
    # Shoulder engines, the coaxial mast with two hubs, a fairing between them.
    exhausts = []
    for side in (-1, 1):
        p, ex = engine_pod(side, 0.6, 0.4, -1.4, 0.95, 0.27)
        parts += p
        exhausts.append(ex)
    parts.append(cyl((0, -0.3, 0.98), (0, -0.3, 1.42), 0.26, "paint", 24, radius2=0.16, bevel_width=0.02))
    parts.append(cyl((0, -0.3, 1.42), (0, -0.3, 2.42), 0.08, "metal", 16))
    parts.append(cyl((0, -0.3, 1.82), (0, -0.3, 2.02), 0.14, "paint", 20, bevel_width=0.02))
    # Stub wings: rocket pods inboard, missile rails outboard.
    pods = []
    for side in (-1, 1):
        parts.append(stub_wing(side, (0.7, 0.2, -0.1), (2.05, 0.1, -0.2), 0.9, 0.62))
        parts.append(box((side * 1.35, 0.15, -0.32), (0.06, 0.45, 0.3), "dark", bevel_width=0.015))
        pod = Vector((side * 1.35, 0.3, -0.6))
        parts += rocket_pod(pod, 1.25, 0.21)
        pods.append(pod + Vector((0, 0.68, 0)))
        parts += missile_rail((side * 1.95, 0.05, -0.38), 1.3)
        parts.append(ball((side * 2.07, 0.1, -0.18), 0.04, "light_green" if side > 0 else "light_red", segments=10,
                          rings=5))
    turret, tips = chin_turret((0, 2.6, -0.82), 2, 1.05)
    parts += turret
    # Tail boom with twin fins and a stabiliser; no tail rotor.
    parts.append(cyl((0, -2.4, 0.5), (0, -6.4, 0.75), 0.24, "paint", 24, radius2=0.12))
    for k in range(4):
        t = (k + 0.5) / 4
        parts.append(ring((0, -2.4 - 4.0 * t, 0.5 + 0.25 * t), (0, 1, 0), 0.24 - 0.12 * t + 0.004, 0.012, "paint", 24))
    end = Vector((0, -6.2, 0.74))
    parts.append(wing("stabiliser", (-1.0, end.y + 0.1, end.z), (1.0, end.y + 0.1, end.z), "paint", 0.6, 0.55, 0.1,
                      count=16, steps=2))
    for side in (-1, 1):
        tip_ = end + Vector((side * 1.0, 0.1, 0))
        parts.append(fin([(0.3, -0.35), (-0.35, -0.3), (-0.55, 0.85), (-0.15, 0.95)], tip_, 0.06))
        parts.append(ball(tip_ + Vector((0, -0.45, 0.9)), 0.04, "light_red", segments=10, rings=5))
    # Wheels: two main legs under the wings and a nose wheel.
    for side in (-1, 1):
        hub = Vector((side * 0.95, -0.3, ground + 0.28))
        parts.append(tube([(side * 0.7, -0.3, -0.7), (side * 0.92, -0.3, -0.95), hub], 0.055, "metal", 12))
        parts += wheel(hub, 0.28, 0.18)
    nose = Vector((0, 2.3, ground + 0.22))
    parts.append(tube([(0, 2.3, -0.85), nose], 0.05, "metal", 12))
    parts += wheel(nose, 0.22, 0.12)
    body = join(parts, "body")
    base.activate(body)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    upper = rotor(3, Vector((0, -0.3, 2.42)), 2.42, 1.0)
    upper.name = "rotor_upper"
    rotor(3, Vector((0, -0.3, 1.86)), 1.86, 1.0)
    empty("tail_rotor", (end.x, end.y, end.z))
    empty("eye", (0, 2.0, 0.62))
    empty("muzzle_l", tips[0])
    empty("muzzle_r", tips[-1])
    empty("pod_l", pods[0])
    empty("pod_r", pods[1])
    empty("exhaust_l", exhausts[0])
    empty("exhaust_r", exhausts[1])


BUILDS = {"gunship": build_gunship, "heavy": build_heavy, "striker": build_striker}


def export(name):
    base.OUT = os.path.join(OUT_DIR, name + ".glb")
    base.export()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args and args[0] == "--preview":
        directory = args[1]
        for name in args[2:] or list(BUILDS):
            BUILDS[name]()
            base.preview(os.path.join(directory, name), ["front", "side", "top"])
    else:
        for name in args or list(BUILDS):
            BUILDS[name]()
            export(name)
