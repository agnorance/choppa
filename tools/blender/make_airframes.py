"""Builds the other helicopter classes next to the Little Bird (make_choppa.py):
assets/models/choppa/gunship.glb, heavy.glb, striker.glb and mule.glb.

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
from make_cockpit import STRIKER_POSTS, eye_post  # noqa: E402  (the cockpit's posts, framed the same outside)

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

def ell(c, r, a, e):
    """A point on an ellipsoid: azimuth 0 = ahead (+Y), + = right; elevation 0 = equator."""
    return Vector(c) + Vector((r[0] * math.cos(e) * math.sin(a), r[1] * math.cos(e) * math.cos(a), r[2] * math.sin(e)))


def framed_canopy(c, r, sill, roof, rear, posts, rails=(), bar=0.022, eye_posts=(), eye=None):
    """A canopy the way the Little Bird's cabin is made: one ellipsoid shell, glass only
    between the sill and the roof and ahead of the rear posts (azimuth +-rear), painted
    elsewhere, the cut lines on the mesh's own edges so the glass edge is clean; frame
    bars over every edge of the glass, the posts at `posts` and rails at the elevations
    `rails`. `eye_posts` are bearings from `eye`, laid out as the cockpit lays them out
    (make_cockpit.eye_post)."""
    steps_a = sorted(set([round(-math.pi + 2 * math.pi * k / 48, 5) for k in range(48)] + [round(-rear, 5), round(rear, 5)]))
    steps_e = sorted(set([round(-math.pi / 2 + math.pi * k / 24, 5) for k in range(1, 24)] + [round(sill, 5), round(roof, 5)]))
    bm = bmesh.new()
    grid = [[bm.verts.new(ell(c, r, a, e)) for a in steps_a] for e in steps_e]
    south = bm.verts.new(ell(c, r, 0.0, -math.pi / 2))
    north = bm.verts.new(ell(c, r, 0.0, math.pi / 2))
    n = len(steps_a)

    def glass(a, e):
        return sill < e < roof and abs(a) < rear

    for i in range(len(steps_e) - 1):
        for k in range(n):
            j = (k + 1) % n
            a_mid = (steps_a[k] + (steps_a[j] if j else steps_a[k] + 2 * math.pi / 48)) / 2
            face = bm.faces.new((grid[i][k], grid[i][j], grid[i + 1][j], grid[i + 1][k]))
            face.material_index = 1 if glass(a_mid, (steps_e[i] + steps_e[i + 1]) / 2) else 0
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((grid[0][j], grid[0][k], south)).material_index = 0
        bm.faces.new((grid[-1][k], grid[-1][j], north)).material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts = [base.link(bm, "canopy", ["paint", "glass"])]
    out = (r[0] + 0.012, r[1] + 0.012, r[2] + 0.012)

    def line(a0, e0, a1, e1, steps=20):
        return tube([ell(c, out, a0 + (a1 - a0) * k / steps, e0 + (e1 - e0) * k / steps) for k in range(steps + 1)],
                    bar, "paint", 8)

    parts.append(line(-rear, sill, rear, sill, 32))
    if roof < math.pi / 2 - 0.01:
        parts.append(line(-rear, roof, rear, roof, 32))
    for a in list(posts) + [-rear, rear]:
        parts.append(line(a, sill, a, roof, 12))
    for e in rails:
        parts.append(line(-rear, e, rear, e, 32))
    for bearing in eye_posts:
        points = eye_post(c, out, bearing, sill, roof, origin=Vector(eye))
        if len(points) > 1:
            parts.append(tube(points, bar, "paint", 8))
    return parts


def use_hull(body, sections):
    """Points the Little Bird's surface helpers (base.plate, base.surface) at this body:
    its loft outline for the first guess, its mesh for the exact spot."""
    base.HULL.clear()
    base.HULL.append(body)
    base.hull_x = lambda y, z: base.section_x(sections, y, z)


def louvres(side, y0, y1, z, count, height=0.22, lean=0.3):
    """A row of cooling slats standing proud of the skin."""
    parts = []
    for k in range(count):
        y = y0 + (y1 - y0) * k / max(1, count - 1)
        p, _ = base.surface(side, y, z, 0.025)
        parts.append(box(p, (0.03, 0.03, height), "dark", rotation=Matrix.Rotation(side * lean, 4, "Z"),
                         bevel_width=0.005))
    return parts


def blade_antenna(at, height, lean=0.35):
    """A swept blade antenna on a small base plate."""
    at = Vector(at)
    return [box(at, (0.08, 0.16, 0.015), "dark", bevel_width=0.004),
            box(at + Vector((0, -height * lean * 0.5, height / 2)), (0.012, 0.09, height), "dark",
                rotation=Matrix.Rotation(-lean, 4, "X"), bevel_width=0.004)]


def handholds(side, points):
    """Recessed steps and grab handles up the flank, where crews climb."""
    parts = []
    for y, z in points:
        p, n = base.surface(side, y, z, 0.0)
        parts.append(cyl(p - n * 0.01, p + n * 0.012, 0.035, "dark", 10))
        parts.append(cyl(p + n * 0.012 + Vector((0, -0.04, 0)), p + n * 0.012 + Vector((0, 0.04, 0)), 0.008, "metal", 6))
    return parts


def wire_cutter(at, up, length):
    """A wire-strike cutter: a serrated blade standing on the skin."""
    at, up = Vector(at), Vector(up).normalized()
    parts = [box(at + up * length / 2, (0.02, 0.06, length), "metal",
                 rotation=Vector((0, 0, 1)).rotation_difference(up).to_matrix().to_4x4(), bevel_width=0.004)]
    for k in range(3):
        parts.append(box(at + up * length * (0.3 + k * 0.25) + Vector((0, 0.04, 0)), (0.016, 0.04, 0.03), "metal",
                         bevel_width=0.003))
    return parts


def crack_spots(spots, first=0):
    """Where bullet hits crack the glass (the game shows more as the hull takes damage):
    `spots` are (centre, radii, azimuth, elevation) on a canopy ellipsoid, in the order
    they appear. Local +Z of each marker is the glass normal."""
    for k, (c, r, a, e) in enumerate(spots):
        c, r = Vector(c), Vector(r)
        p = ell(c, r * 1.0, a, e)
        q = p - c
        n = Vector((q.x / r.x ** 2, q.y / r.y ** 2, q.z / r.z ** 2)).normalized()
        m = empty("crack_%d" % (first + k), p + n * 0.006)
        m.rotation_mode = "QUATERNION"
        m.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(n)


def number(text, side, y, z, height, target):
    """The tail number, pressed onto the flank."""
    p, n = base.surface(side, y, z)
    return base.stencil(text, p, Vector((side, 0, 0)), Vector((0, 0, 1)), height, "decal", target)


def roundel(side, y, z, radius, target):
    p, _ = base.surface(side, y, z)
    return base.roundel(p, Vector((side, 0, 0)), Vector((0, 0, 1)), radius, target)


def nav_lights(left, right):
    return [ball(left, 0.04, "light_red", segments=10, rings=5), ball(right, 0.04, "light_green", segments=10, rings=5)]


def beacon(at):
    at = Vector(at)
    return [cyl(at, at + Vector((0, 0, 0.03)), 0.05, "dark", 12),
            ball(at + Vector((0, 0, 0.05)), 0.045, "light_red", scale=(1, 1, 0.8), segments=12, rings=6)]


# Slim, tall fuselage: nose, front seat, rear seat, engine bay, tail cone.
# (y, half width, z of the widest line, z top, z bottom, top exponent, bottom exponent)
GUNSHIP_BODY = [
    (3.25, 0.06, -0.15, -0.08, -0.22, 2.0, 2.0),
    (2.95, 0.3, -0.18, 0.2, -0.55, 2.2, 2.4),
    (2.3, 0.44, -0.15, 0.45, -0.72, 2.4, 2.8),
    (1.2, 0.5, -0.1, 0.62, -0.8, 2.6, 3.0),
    (0.0, 0.52, 0.0, 0.8, -0.78, 2.6, 3.0),
    (-1.1, 0.5, 0.1, 0.85, -0.6, 2.6, 2.8),
    (-1.9, 0.34, 0.28, 0.72, -0.2, 2.4, 2.4),
    (-2.5, 0.2, 0.42, 0.62, 0.15, 2.2, 2.2),
]
GUNSHIP_GUNNER = ((0, 1.75, 0.3), (0.36, 0.95, 0.42))
GUNSHIP_PILOT = ((0, 0.75, 0.68), (0.36, 0.95, 0.42))


def gunship_sensors():
    """The nose: a sight turret under the chin of the nose (a drum with two sensor windows
    and a laser port), a night-vision ball on top, a pitot probe and the wire cutter."""
    parts = []
    drum = Vector((0, 3.3, -0.3))  # Hung under the nose tip, out in the air.
    parts.append(cyl(drum + Vector((0, 0, 0.17)), drum + Vector((0, 0, 0.24)), 0.13, "dark", 20))  # Mount.
    parts.append(cyl(drum + Vector((-0.2, 0, 0)), drum + Vector((0.2, 0, 0)), 0.17, "paint", 28, bevel_width=0.03))
    for x in (-0.21, 0.21):
        parts.append(cyl(drum + Vector((x, 0, 0)), drum + Vector((x * 1.06, 0, 0)), 0.12, "dark", 24, bevel_width=0.01))
    for x, w in ((-0.09, 0.13), (0.09, 0.1)):  # Day and thermal windows, and the laser port.
        parts.append(box(drum + Vector((x, 0.165, 0.02)), (w, 0.02, 0.1), "glass", bevel_width=0.006))
        parts.append(box(drum + Vector((x, 0.158, 0.02)), (w + 0.03, 0.02, 0.13), "dark", bevel_width=0.006))
    parts.append(cyl(drum + Vector((0, 0.15, -0.09)), drum + Vector((0, 0.18, -0.09)), 0.025, "glass", 12))
    ball_at = Vector((0, 3.28, -0.02))  # Night-vision ball over the sight turret.
    parts.append(ball(ball_at, 0.1, "paint", segments=18, rings=9))
    parts.append(cyl(ball_at + Vector((0, 0.07, 0)), ball_at + Vector((0, 0.1, 0)), 0.05, "glass", 14))
    parts.append(cyl(ball_at + Vector((0, -0.08, -0.04)), ball_at + Vector((0, -0.25, -0.1)), 0.06, "paint", 14))
    # Pitot probes on both cheeks, the gun under the chin turret's yoke, a wire cutter.
    for side in (-1, 1):
        p, n = base.surface(side, 2.6, -0.1, 0.0)
        parts.append(cyl(p, p + Vector((side * 0.12, 0.3, 0.02)), 0.012, "metal", 6))
    parts += wire_cutter((0, 2.65, 0.55), (0, 0.35, 1), 0.28)  # Over the gunner's canopy.
    parts += wire_cutter((0, 2.6, -0.72), (0, 0.25, -1), 0.18)  # Under the chin.
    return parts


def gunship_skin():
    """Riveted access panels: the avionics bays in the cheeks, the engine bay, the nose,
    the tail cone; louvres over the engine bay; steps up the flank."""
    parts = []
    for side in (-1, 1):
        parts += base.plate(side, 2.35, 1.1, -0.62, -0.22)  # Forward avionics bay.
        parts += base.plate(side, 1.0, -0.1, -0.6, -0.15)  # Aft avionics bay, under the pilot.
        parts += base.plate(side, -0.2, -1.5, 0.3, 0.7)  # Engine bay.
        parts += base.plate(side, -1.6, -2.4, 0.38, 0.6, bolt_step=0.09)  # Tail cone.
        parts += louvres(side, -0.3, -1.3, 0.2, 9, 0.16)
        parts += handholds(side, [(1.4, -0.6), (1.2, -0.25), (0.6, 0.15)])
        # Hinges on the forward bay door.
        for z in (-0.55, -0.3):
            p, n = base.surface(side, 2.37, z, 0.02)
            parts.append(cyl(p + Vector((0, 0, -0.04)), p + Vector((0, 0, 0.04)), 0.014, "metal", 8))
    return parts


def gunship_engines():
    """Shoulder engines with dust-filter intakes and exhaust suppressors that turn the hot
    gas out sideways, an infrared jammer on the spine, the mast fairing and its gearbox."""
    parts, exhausts = [], []
    for side in (-1, 1):
        p, ex = engine_pod(side, 0.48, 0.2, -1.5, 0.82, 0.24)
        parts += p
        exhausts.append(ex)
        # Suppressor: a black box over the exhaust with its mouth turned outboard.
        sup = Vector((side * 0.6, -1.55, 0.9))
        parts.append(box(sup, (0.24, 0.4, 0.24), "dark", rotation=Matrix.Rotation(side * -0.25, 4, "Z"), bevel_width=0.04))
        parts.append(box(sup + Vector((side * 0.11, -0.05, 0)), (0.04, 0.3, 0.18), "exhaust",
                         rotation=Matrix.Rotation(side * -0.25, 4, "Z"), bevel_width=0.01))
        # Intake screen ahead of the engine face.
        face = Vector((side * 0.48, 0.26, 0.82))
        parts.append(ring(face, (0, 1, 0), 0.23, 0.018, "metal", 28))
        for k in range(5):
            parts.append(cyl(face + Vector((-0.2, 0.01, -0.12 + k * 0.06)), face + Vector((0.2, 0.01, -0.12 + k * 0.06)),
                             0.006, "metal", 5))
        parts += rivets((side * 0.7, 0.0, 0.82), (side * 0.7, -1.3, 0.82), 9)
    parts.append(cyl((0, -0.35, 0.95), (0, -0.35, 1.35), 0.22, "paint", 24, radius2=0.14, bevel_width=0.02))
    parts.append(cyl((0, -0.35, 1.35), (0, -0.35, 1.62), 0.09, "metal", 16))
    for k in range(8):  # Bolt ring on the mast fairing.
        a = 2 * math.pi * k / 8
        parts.append(ball((0.2 * math.cos(a), -0.35 + 0.2 * math.sin(a), 1.0), 0.014, "metal", segments=6, rings=3))
    jam = Vector((0, -1.25, 0.95))  # The infrared jammer: a faceted lantern on a post.
    parts.append(cyl(jam, jam + Vector((0, 0, 0.12)), 0.05, "paint", 12))
    parts.append(cyl(jam + Vector((0, 0, 0.12)), jam + Vector((0, 0, 0.3)), 0.11, "dark", 8, bevel_width=0.01))
    parts.append(cyl(jam + Vector((0, 0, 0.3)), jam + Vector((0, 0, 0.33)), 0.08, "paint", 12))
    parts += blade_antenna((0, -0.9, 0.86), 0.18)
    parts += blade_antenna((0, -2.1, 0.66), 0.14)
    parts += beacon((0, -1.7, 0.73))
    return parts, exhausts


def gunship_weapons():
    pods = []
    parts = []
    for side in (-1, 1):
        parts.append(stub_wing(side, (0.48, 0.15, -0.05), (1.75, 0.05, -0.12), 0.85, 0.6))
        parts += rivets((side * 0.6, 0.3, 0.0), (side * 1.65, 0.25, -0.06), 7)
        parts.append(box((side * 1.45, 0.1, -0.28), (0.06, 0.45, 0.3), "dark", bevel_width=0.015))
        pod = Vector((side * 1.45, 0.25, -0.55))
        parts += rocket_pod(pod, 1.2, 0.2)
        pods.append(pod + Vector((0, 0.65, 0)))
        parts += missile_rail((side * 1.85, 0.0, -0.3), 1.3)
        # Countermeasure dispensers on the wing tips, the navigation lights.
        parts.append(box((side * 1.78, -0.15, -0.02), (0.1, 0.3, 0.1), "dark", bevel_width=0.015))
        for k in range(3):
            parts.append(cyl((side * 1.78, -0.28 + k * 0.08, 0.03), (side * 1.78, -0.28 + k * 0.08, 0.04), 0.02,
                             "metal", 8))
    parts += nav_lights((-1.8, 0.05, -0.08), (1.8, 0.05, -0.08))
    turret, tips = chin_turret((0, 2.55, -0.72), 3, 0.75)
    parts += turret
    # Ammunition chute from the belly into the turret.
    parts.append(tube([(0, 1.6, -0.82), (0, 2.1, -0.88), (0, 2.45, -0.8)], 0.06, "dark", 10))
    return parts, pods, tips


def build_gunship():
    fresh()
    s = 1.1
    ground = -1.15 * s
    base.GROUND_Z = ground  # The preview floor.
    body = loft("fuselage", GUNSHIP_BODY, "paint", count=40)
    sub = body.modifiers.new("subsurf", "SUBSURF")
    sub.levels = 1
    base.apply_all(body)
    use_hull(body, GUNSHIP_BODY)
    parts = [body]
    # Stepped tandem canopy, framed panes like the Little Bird's cabin: the gunner low in
    # front, the pilot behind and higher, looking over his head. The pilot's frame is the
    # one the cockpit shows from inside (make_cockpit.py, build_gunship).
    parts += framed_canopy(*GUNSHIP_GUNNER, -0.15, 1.15, 1.9, [-0.6, 0.6], [0.5], bar=0.018)
    parts += framed_canopy(*GUNSHIP_PILOT, -0.18, 1.25, 2.4, [-1.3, 1.3, -1.8, 1.8], bar=0.018)  # As GUNSHIP_POSTS inside.
    for side in (-1, 1):  # Door latches and the canopy hinge line.
        parts.append(box(ell(GUNSHIP_PILOT[0], (0.38, 0.97, 0.44), side * 1.6, 0.1), (0.03, 0.1, 0.03), "brass",
                         bevel_width=0.008))
        parts.append(box(ell(GUNSHIP_GUNNER[0], (0.38, 0.97, 0.44), side * 1.2, 0.05), (0.03, 0.1, 0.03), "brass",
                         bevel_width=0.008))
    parts += gunship_sensors()
    parts += gunship_skin()
    engines, exhausts = gunship_engines()
    parts += engines
    weapons, pods, tips = gunship_weapons()
    parts += weapons
    t, rotor_at = tail(-2.3, -6.6, 0.5, 0.82, 0.2, 0.1, 1.05)
    parts += t
    # Tail-rotor driveshaft cover along the boom, a tail-rotor guard, a tail bumper.
    parts.append(cyl((0, -2.4, 0.71), (0, -6.3, 0.92), 0.045, "paint", 12, radius2=0.035))
    parts.append(tube([(0, -5.95, 0.6), (0, -6.25, 0.38), (0, -6.6, 0.42)], 0.025, "metal", 8))
    parts += skid_gear(ground, 0.85, -1.0, 1.9, [(1.5, -0.7), (-0.4, -0.6)])
    for side in (-1, 1):  # Boarding steps on the skids.
        z = ground + 0.05
        parts.append(tube([(side * 0.85, 1.05, z), (side * 0.97, 1.03, z + 0.12), (side * 0.97, 0.78, z + 0.12),
                           (side * 0.85, 0.76, z)], 0.014, "metal", 8))
    # Landing light under the nose.
    lamp = Vector((0, 2.2, -0.82))
    parts.append(cyl(lamp + Vector((0, -0.05, 0.06)), lamp, 0.07, "dark", 18, bevel_width=0.01))
    parts.append(cyl(lamp, lamp + Vector((0, 0.01, -0.01)), 0.06, "lamp", 18))
    # Markings: the number on the nose, a roundel on the tail cone, the number on the fin.
    for side in (-1, 1):
        parts.append(number("21", side, 1.55, 0.02, 0.2, body))
        parts += roundel(side, -1.95, 0.2, 0.11, body)
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
    g, p = GUNSHIP_GUNNER, GUNSHIP_PILOT
    crack_spots([(p[0], p[1], 1.2, 0.3), (p[0], p[1], -1.1, 0.5), (g[0], g[1], 0.4, 0.4), (p[0], p[1], 0.5, 0.2),
                 (g[0], g[1], -0.9, 0.3), (p[0], p[1], -0.4, 0.6), (g[0], g[1], -0.2, 0.7), (p[0], p[1], 1.6, 0.7)])


# --- the heavy ---------------------------------------------------------------------

HEAVY_BODY = [
    (3.9, 0.1, -0.3, -0.2, -0.4, 2.0, 2.0),
    (3.5, 0.55, -0.35, 0.25, -0.9, 2.2, 2.6),
    (2.7, 0.8, -0.3, 0.6, -1.05, 2.6, 3.2),
    (1.4, 0.95, -0.2, 0.95, -1.1, 3.0, 3.5),
    (-0.4, 1.0, -0.1, 1.1, -1.05, 3.0, 3.5),
    (-1.9, 0.92, 0.0, 1.05, -0.9, 2.8, 3.2),
    (-2.9, 0.6, 0.25, 0.92, -0.35, 2.4, 2.6),
    (-3.6, 0.32, 0.45, 0.8, 0.1, 2.2, 2.2),
]
HEAVY_GUNNER = ((0, 2.85, 0.05), (0.55, 0.85, 0.5))
HEAVY_PILOT = ((0, 1.8, 0.72), (0.66, 0.95, 0.58))  # Prouder than the shell the seat sees.


def heavy_nose():
    """The gunner's nose: a long air-data boom off the right, sensor domes and a missile
    guidance pod under the chin, wire cutters."""
    parts = []
    root = Vector((0.32, 3.55, -0.3))
    parts.append(cyl(root, root + Vector((0.1, 1.3, 0.05)), 0.03, "metal", 8, radius2=0.015))
    for k in range(3):  # Vanes along the boom.
        p = root + Vector((0.1, 1.3, 0.05)) * (0.55 + k * 0.15)
        parts.append(box(p, (0.004, 0.08, 0.06), "dark"))
    parts.append(cyl(root - Vector((0.04, 0.08, 0)), root, 0.06, "paint", 12))
    pod = Vector((-0.38, 3.2, -0.82))  # Guidance pod on the left cheek.
    parts.append(cyl(pod + Vector((0, -0.35, 0)), pod + Vector((0, 0.25, 0)), 0.12, "paint", 18, bevel_width=0.02))
    parts.append(ball(pod + Vector((0, 0.25, 0)), 0.12, "glass", scale=(1, 0.6, 1), segments=16, rings=8))
    parts.append(box(pod + Vector((0, -0.05, 0.12)), (0.05, 0.3, 0.1), "dark", bevel_width=0.01))
    for x in (-0.12, 0.12):  # Sensor domes under the gunner.
        parts.append(ball((x, 3.45, -0.62), 0.07, "dark", segments=14, rings=7))
    parts += wire_cutter((0, 3.0, 0.5), (0, 0.4, 1), 0.3)
    parts += wire_cutter((0, 3.45, -0.9), (0, 0.4, -1), 0.2)
    return parts


def heavy_cabin():
    """The troop cabin behind the cockpit: armour plates, a row of square windows, the
    sliding door with its rail and two windows, steps, the hull's riveted panels."""
    parts = []
    for side in (-1, 1):
        for y0, y1, z, h in ((2.3, 0.4, -0.35, 0.8), (0.3, -1.6, -0.25, 1.0)):  # Bolted armour.
            parts.append(box((side * 1.0, (y0 + y1) / 2, z), (0.06, abs(y0 - y1), h), "paint", bevel_width=0.02))
            parts += rivets((side * 1.04, y0 - 0.1, z + h / 2 - 0.06), (side * 1.04, y1 + 0.1, z + h / 2 - 0.06), 9)
            parts += rivets((side * 1.04, y0 - 0.1, z - h / 2 + 0.06), (side * 1.04, y1 + 0.1, z - h / 2 + 0.06), 9)
        # Sliding door: frame, two windows, the rail it runs on, a handle.
        parts.append(box((side * 1.06, -0.65, -0.05), (0.03, 0.9, 0.85), "dark", bevel_width=0.01))
        for y in (-0.45, -0.85):
            parts.append(box((side * 1.08, y, 0.2), (0.02, 0.26, 0.22), "glass", bevel_width=0.01))
            parts.append(box((side * 1.075, y, 0.2), (0.02, 0.3, 0.26), "metal", bevel_width=0.01))
        parts.append(cyl((side * 1.08, 0.1, 0.42), (side * 1.08, -1.4, 0.42), 0.018, "metal", 8))
        parts.append(box((side * 1.1, -0.28, -0.1), (0.04, 0.1, 0.04), "brass", bevel_width=0.008))
        for y in (-1.75, -2.25):  # Cabin windows behind the door.
            p, n = base.surface(side, y, 0.3, 0.01)
            parts.append(cyl(p - n * 0.02, p + n * 0.012, 0.13, "glass", 18))
            parts.append(ring(p + n * 0.01, n, 0.14, 0.02, "metal", 18))
        parts += base.plate(side, 3.3, 2.5, -0.75, -0.35)  # Nose bay.
        parts += base.plate(side, -1.75, -2.75, -0.55, -0.15, bolt_step=0.1)  # Cabin rear.
        parts += base.plate(side, -2.95, -3.5, 0.3, 0.65, bolt_step=0.09)  # Tail cone.
        parts += handholds(side, [(1.5, -0.75), (1.3, -0.35), (1.0, 0.1)])
        parts.append(box((side * 0.98, -0.65, -0.95), (0.08, 0.7, 0.05), "metal", bevel_width=0.01))  # Door step.
    parts.append(box((0, 0.6, -1.12), (1.3, 3.0, 0.08), "paint", bevel_width=0.02))  # Belly armour.
    parts += rivets((-0.6, 2.0, -1.17), (0.6, 2.0, -1.17), 7)
    parts += rivets((-0.6, -0.8, -1.17), (0.6, -0.8, -1.17), 7)
    return parts


def heavy_engines():
    """Two big engines on the roof: dust filters over the intakes, cowlings with louvres,
    exhaust suppressors bent outboard, the main gearbox and its oil cooler fan between."""
    parts, exhausts = [], []
    for side in (-1, 1):
        p, ex = engine_pod(side, 0.62, 1.0, -1.6, 1.25, 0.36)
        parts += p
        exhausts.append(ex)
        # The intake's dust filter: a domed mesh basket.
        parts.append(ball((side * 0.62, 1.08, 1.25), 0.3, "metal", scale=(1, 0.55, 1), segments=20, rings=10))
        for k in range(6):
            a = math.pi * k / 6
            parts.append(ring((side * 0.62, 1.08 + 0.01 * k, 1.25), (math.cos(a), 0, math.sin(a)), 0.3, 0.008, "dark", 20))
        for k in range(8):  # Cowling louvres.
            y = 0.6 - k * 0.2
            parts.append(box((side * (0.62 + 0.36 * 0.75), y, 1.42), (0.03, 0.04, 0.16), "dark",
                             rotation=Matrix.Rotation(side * -0.8, 4, "Y"), bevel_width=0.004))
        sup = Vector((side * 0.9, -1.75, 1.3))  # Suppressor.
        parts.append(box(sup, (0.32, 0.55, 0.3), "dark", rotation=Matrix.Rotation(side * -0.3, 4, "Z"), bevel_width=0.05))
        parts.append(box(sup + Vector((side * 0.15, -0.05, 0)), (0.04, 0.42, 0.22), "exhaust",
                         rotation=Matrix.Rotation(side * -0.3, 4, "Z"), bevel_width=0.01))
    parts.append(box((0, -0.3, 1.2), (0.7, 2.4, 0.35), "paint", bevel_width=0.05))
    parts.append(cyl((0, -0.4, 1.35), (0, -0.4, 1.78), 0.3, "paint", 24, radius2=0.18, bevel_width=0.02))
    parts.append(cyl((0, -0.4, 1.78), (0, -0.4, 2.05), 0.12, "metal", 16))
    fan = Vector((0, -1.35, 1.42))  # Oil cooler fan behind the gearbox.
    parts.append(cyl(fan + Vector((0, -0.12, 0)), fan + Vector((0, 0.12, 0)), 0.22, "paint", 24, bevel_width=0.02))
    parts.append(cyl(fan + Vector((0, -0.13, 0)), fan + Vector((0, -0.12, 0)), 0.18, "dark", 24))
    for k in range(5):
        parts.append(cyl(fan + Vector((-0.17, -0.135, -0.12 + k * 0.06)), fan + Vector((0.17, -0.135, -0.12 + k * 0.06)),
                         0.006, "metal", 5))
    parts += blade_antenna((0, 0.6, 1.38), 0.2)
    parts += blade_antenna((0, -2.6, 0.92), 0.16)
    parts += beacon((0, -2.2, 1.0))
    return parts, exhausts


def heavy_weapons():
    """Long stub wings with a pod and a rail each side, end-plate pylons, the chin turret."""
    parts, pods = [], []
    for side in (-1, 1):
        parts.append(stub_wing(side, (0.95, -0.4, 0.2), (2.6, -0.5, -0.05), 1.1, 0.75))
        parts += rivets((side * 1.1, -0.15, 0.24), (side * 2.5, -0.25, 0.0), 9)
        for x, kind in ((1.6, "pod"), (2.4, "rail")):
            parts.append(box((side * x, -0.45, -0.03), (0.07, 0.5, 0.3), "dark", bevel_width=0.015))
            if kind == "pod":
                pod = Vector((side * x, -0.25, -0.38))
                parts += rocket_pod(pod, 1.5, 0.26, tubes=9)
                pods.append(pod + Vector((0, 0.8, 0)))
            else:
                parts += missile_rail((side * x, -0.45, -0.32), 1.5)
        # Wing-tip end plate with a countermeasure dispenser.
        parts.append(box((side * 2.64, -0.5, -0.1), (0.05, 0.6, 0.35), "paint", bevel_width=0.015))
        parts.append(box((side * 2.68, -0.6, -0.2), (0.06, 0.3, 0.12), "dark", bevel_width=0.01))
    parts += nav_lights((-2.68, -0.3, 0.05), (2.68, -0.3, 0.05))
    turret, tips = chin_turret((0, 3.25, -0.82), 2, 0.9)
    parts += turret
    parts.append(ring((0, 3.25, -0.6), (0, 0, 1), 0.25, 0.025, "metal", 24))
    return parts, pods, tips


def build_heavy():
    fresh()
    s = 1.3
    ground = -1.15 * s
    base.GROUND_Z = ground  # The preview floor.
    body = loft("fuselage", HEAVY_BODY, "paint", count=44)
    sub = body.modifiers.new("subsurf", "SUBSURF")
    sub.levels = 1
    base.apply_all(body)
    use_hull(body, HEAVY_BODY)
    parts = [body]
    # Two framed canopies, the gunner in the nose and the pilot above and behind: glass
    # panes between a sill and a solid roof, like the Little Bird's cabin. The pilot's
    # posts are where the cockpit shows them from inside (HEAVY_POSTS in make_cockpit.py).
    parts += framed_canopy(*HEAVY_GUNNER, -0.25, 1.3, 1.6, [0.0, -0.5, 0.5, -1.1, 1.1], [0.55])
    parts += framed_canopy(*HEAVY_PILOT, -0.38, 0.95, 2.1, [-0.78, 0.78, -1.45, 1.45])
    for side in (-1, 1):  # The pilot's blister door and its latch.
        parts.append(box(ell(HEAVY_PILOT[0], (0.68, 0.97, 0.6), side * 1.75, 0.1), (0.03, 0.12, 0.03), "brass",
                         bevel_width=0.008))
    parts += heavy_nose()
    parts += heavy_cabin()
    engines, exhausts = heavy_engines()
    parts += engines
    weapons, pods, tips = heavy_weapons()
    parts += weapons
    t, rotor_at = tail(-3.4, -8.2, 0.6, 1.0, 0.32, 0.14, 1.35)
    parts += t
    parts.append(cyl((0, -3.5, 0.92), (0, -7.9, 1.12), 0.06, "paint", 12, radius2=0.045))  # Driveshaft cover.
    parts.append(tube([(0, -7.6, 0.75), (0, -8.0, 0.45), (0, -8.5, 0.5)], 0.03, "metal", 8))  # Tail bumper.
    # Wheels: two main legs with oleo struts and a twin nose wheel.
    for side in (-1, 1):
        hub = Vector((side * 1.15, -0.6, ground + 0.32))
        parts.append(tube([(side * 0.9, -0.6, -0.7), (side * 1.12, -0.6, -1.0), hub], 0.06, "metal", 12))
        parts.append(cyl((side * 0.95, -0.35, -0.6), hub + Vector((0, 0.1, 0.25)), 0.04, "metal", 10))
        parts += wheel(hub, 0.32, 0.22)
    nose = Vector((0, 2.6, ground + 0.24))
    parts.append(tube([(0, 2.6, -0.95), nose], 0.05, "metal", 12))
    for side in (-1, 1):
        parts += wheel(nose + Vector((side * 0.13, 0, 0)), 0.24, 0.12)
    lamp = Vector((0, 2.2, -1.12))  # Landing light.
    parts.append(cyl(lamp + Vector((0, 0, 0.06)), lamp, 0.09, "dark", 18, bevel_width=0.01))
    parts.append(cyl(lamp, lamp + Vector((0, 0.01, -0.01)), 0.08, "lamp", 18))
    for side in (-1, 1):
        parts.append(number("45", side, 2.2, 0.15, 0.3, body))
        parts += roundel(side, -3.1, 0.15, 0.16, body)
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
    g, p = HEAVY_GUNNER, HEAVY_PILOT
    crack_spots([(p[0], p[1], 1.1, 0.3), (p[0], p[1], -1.2, 0.4), (g[0], g[1], 0.6, 0.6), (p[0], p[1], 0.4, 0.2),
                 (g[0], g[1], -0.8, 0.3), (p[0], p[1], -0.5, 0.6), (g[0], g[1], -0.2, 0.9), (p[0], p[1], 1.7, 0.6)])


# --- the striker -------------------------------------------------------------------

STRIKER_BODY = [
    (3.35, 0.1, -0.2, -0.1, -0.3, 2.0, 2.0),
    (3.0, 0.45, -0.25, 0.25, -0.65, 2.2, 2.4),
    (2.3, 0.72, -0.2, 0.55, -0.82, 2.5, 2.8),
    (1.1, 0.78, -0.12, 0.8, -0.86, 2.8, 3.2),
    (-0.2, 0.74, -0.05, 0.95, -0.8, 2.8, 3.0),
    (-1.3, 0.6, 0.1, 0.95, -0.55, 2.6, 2.6),
    (-2.1, 0.38, 0.3, 0.8, -0.15, 2.4, 2.2),
    (-2.6, 0.24, 0.42, 0.68, 0.18, 2.2, 2.2),
]
STRIKER_CANOPY = ((0, 2.15, 0.42), (0.7, 1.05, 0.5))
STRIKER_EYE = Vector((-0.36, 2.0, 0.62))  # The pilot sits on the left (make_cockpit.py).


def striker_nose():
    """A radar dome on the nose tip, the sight ball under the chin, wire cutters, pitots."""
    parts = []
    dome = Vector((0, 3.3, -0.2))
    parts.append(ball(dome, 0.2, "paint", scale=(1, 1.35, 0.95), segments=24, rings=12))
    parts.append(ring(dome + Vector((0, -0.12, 0)), (0, 1, 0), 0.2, 0.015, "dark", 24))
    sight = Vector((0, 3.0, -0.72))
    parts.append(cyl(sight + Vector((0, 0, 0.1)), sight + Vector((0, 0, 0.2)), 0.08, "dark", 16))
    parts.append(ball(sight, 0.15, "paint", segments=20, rings=10))
    parts.append(cyl(sight + Vector((0, 0.11, 0.02)), sight + Vector((0, 0.15, 0.02)), 0.07, "glass", 16))
    parts.append(box(sight + Vector((0, 0.13, -0.06)), (0.1, 0.02, 0.04), "dark", bevel_width=0.005))
    for side in (-1, 1):
        p, n = base.surface(side, 2.85, -0.25, 0.0)
        parts.append(cyl(p, p + Vector((side * 0.1, 0.32, 0.02)), 0.012, "metal", 6))
    parts += wire_cutter((0, 3.15, 0.3), (0, 0.6, 1), 0.25)
    return parts


def striker_skin():
    parts = []
    for side in (-1, 1):
        parts += base.plate(side, 2.7, 1.6, -0.65, -0.3)  # Nose avionics bay.
        parts += base.plate(side, 1.2, 0.2, -0.7, -0.3)  # Under the cockpit.
        parts += base.plate(side, 0.0, -1.2, 0.35, 0.8)  # Engine bay.
        parts += base.plate(side, -1.4, -2.4, 0.3, 0.6, bolt_step=0.09)  # Tail cone.
        parts.append(box((side * 0.76, 0.7, -0.35), (0.04, 1.6, 0.5), "paint", bevel_width=0.015))  # Armour.
        parts += rivets((side * 0.79, 0.0, -0.12), (side * 0.79, 1.4, -0.12), 8)
        parts += louvres(side, -0.1, -1.0, 0.2, 8, 0.15)
        parts += handholds(side, [(1.0, -0.75), (0.85, -0.4), (0.7, 0.0)])
        # The crew doors' hinge line and latch under the canopy sill.
        parts.append(box(ell(STRIKER_CANOPY[0], (0.72, 1.07, 0.52), side * 1.5, -0.3), (0.03, 0.12, 0.03), "brass",
                         bevel_width=0.008))
    return parts


def striker_engines():
    parts, exhausts = [], []
    for side in (-1, 1):
        p, ex = engine_pod(side, 0.6, 0.4, -1.4, 0.95, 0.27)
        parts += p
        exhausts.append(ex)
        parts.append(ball((side * 0.6, 0.46, 0.95), 0.24, "metal", scale=(1, 0.5, 1), segments=18, rings=9))  # Dust guard.
        for k in range(5):
            a = math.pi * k / 5
            parts.append(ring((side * 0.6, 0.47, 0.95), (math.cos(a), 0, math.sin(a)), 0.24, 0.007, "dark", 18))
        sup = Vector((side * 0.82, -1.5, 1.0))  # Suppressor, its mouth turned up and out.
        parts.append(box(sup, (0.26, 0.42, 0.26), "dark", rotation=Matrix.Rotation(side * -0.3, 4, "Z"), bevel_width=0.04))
        parts.append(box(sup + Vector((side * 0.06, -0.05, 0.11)), (0.18, 0.3, 0.04), "exhaust",
                         rotation=Matrix.Rotation(side * -0.3, 4, "Z"), bevel_width=0.01))
        parts += rivets((side * 0.87, 0.2, 0.95), (side * 0.87, -1.2, 0.95), 8)
    # The coaxial mast: a fairing, the shaft, and the links between the two hubs.
    parts.append(cyl((0, -0.3, 0.98), (0, -0.3, 1.42), 0.26, "paint", 24, radius2=0.16, bevel_width=0.02))
    parts.append(cyl((0, -0.3, 1.42), (0, -0.3, 2.42), 0.08, "metal", 16))
    parts.append(cyl((0, -0.3, 1.82), (0, -0.3, 2.02), 0.14, "paint", 20, bevel_width=0.02))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        p = Vector((0.12 * math.cos(a), -0.3 + 0.12 * math.sin(a), 0))
        parts.append(cyl(p + Vector((0, 0, 1.96)), p + Vector((0, 0, 2.3)), 0.012, "metal", 6))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(ball((0.24 * math.cos(a), -0.3 + 0.24 * math.sin(a), 1.02), 0.013, "metal", segments=6, rings=3))
    parts += blade_antenna((0, 0.5, 0.92), 0.16)
    parts += blade_antenna((0, -2.0, 0.78), 0.14)
    parts += beacon((0, -1.6, 0.92))
    return parts, exhausts


def striker_weapons():
    parts, pods = [], []
    for side in (-1, 1):
        parts.append(stub_wing(side, (0.7, 0.2, -0.1), (2.05, 0.1, -0.2), 0.9, 0.62))
        parts += rivets((side * 0.85, 0.42, -0.06), (side * 1.95, 0.3, -0.16), 7)
        parts.append(box((side * 1.35, 0.15, -0.32), (0.06, 0.45, 0.3), "dark", bevel_width=0.015))
        pod = Vector((side * 1.35, 0.3, -0.6))
        parts += rocket_pod(pod, 1.25, 0.21)
        pods.append(pod + Vector((0, 0.68, 0)))
        parts += missile_rail((side * 1.95, 0.05, -0.38), 1.3)
        parts.append(box((side * 2.06, -0.15, -0.16), (0.08, 0.3, 0.12), "dark", bevel_width=0.012))  # Dispenser.
    parts += nav_lights((-2.08, 0.1, -0.12), (2.08, 0.1, -0.12))
    turret, tips = chin_turret((0, 2.6, -0.82), 2, 1.05)
    parts += turret
    parts.append(ring((0, 2.6, -0.58), (0, 0, 1), 0.22, 0.022, "metal", 24))
    return parts, pods, tips


def build_striker():
    """A coaxial attack helicopter (a Ka-52 in spirit): side-by-side cockpit under a wide
    canopy, two counter-rotating rotors on one mast and no tail rotor (the game spins
    "rotor" one way and "rotor_upper" the other; "tail_rotor" is only an empty marking the
    tail end, for smoke and sparks), twin fins, a twin cannon under the chin, wheels."""
    fresh()
    s = 1.15
    ground = -1.15 * s
    base.GROUND_Z = ground
    body = loft("fuselage", STRIKER_BODY, "paint", count=40)
    sub = body.modifiers.new("subsurf", "SUBSURF")
    sub.levels = 1
    base.apply_all(body)
    use_hull(body, STRIKER_BODY)
    parts = [body]
    # The wide canopy, framed with the posts the cockpit shows (STRIKER_POSTS, laid out
    # from the pilot's eye).
    parts += framed_canopy(*STRIKER_CANOPY, -0.38, 1.2, 2.45, [], bar=0.02, eye_posts=STRIKER_POSTS, eye=STRIKER_EYE)
    parts += striker_nose()
    parts += striker_skin()
    engines, exhausts = striker_engines()
    parts += engines
    weapons, pods, tips = striker_weapons()
    parts += weapons
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
        for z in (-0.1, 0.4):  # Rudder hinges.
            parts.append(cyl(tip_ + Vector((-0.04, -0.4, z)), tip_ + Vector((0.04, -0.4, z)), 0.015, "metal", 6))
    parts.append(cyl((0, -2.5, 0.72), (0, -6.0, 0.86), 0.04, "paint", 12, radius2=0.03))  # Cable duct on the boom.
    # Wheels: two main legs under the wings and a nose wheel.
    for side in (-1, 1):
        hub = Vector((side * 0.95, -0.3, ground + 0.28))
        parts.append(tube([(side * 0.7, -0.3, -0.7), (side * 0.92, -0.3, -0.95), hub], 0.055, "metal", 12))
        parts.append(cyl((side * 0.72, -0.1, -0.62), hub + Vector((0, 0.08, 0.22)), 0.035, "metal", 10))
        parts += wheel(hub, 0.28, 0.18)
    nose = Vector((0, 2.3, ground + 0.22))
    parts.append(tube([(0, 2.3, -0.85), nose], 0.05, "metal", 12))
    parts += wheel(nose, 0.22, 0.12)
    lamp = Vector((0, 1.8, -0.87))
    parts.append(cyl(lamp + Vector((0, 0, 0.06)), lamp, 0.08, "dark", 18, bevel_width=0.01))
    parts.append(cyl(lamp, lamp + Vector((0, 0.01, -0.01)), 0.07, "lamp", 18))
    for side in (-1, 1):
        parts.append(number("08", side, 1.0, 0.05, 0.24, body))
        parts += roundel(side, -1.95, 0.08, 0.12, body)
    body = join(parts, "body")
    base.activate(body)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    upper = rotor(3, Vector((0, -0.3, 2.42)), 2.42, 1.0)
    upper.name = "rotor_upper"
    rotor(3, Vector((0, -0.3, 1.86)), 1.86, 1.0)
    empty("tail_rotor", (end.x, end.y, end.z))
    empty("eye", tuple(STRIKER_EYE))
    empty("muzzle_l", tips[0])
    empty("muzzle_r", tips[-1])
    empty("pod_l", pods[0])
    empty("pod_r", pods[1])
    empty("exhaust_l", exhausts[0])
    empty("exhaust_r", exhausts[1])
    c, r = STRIKER_CANOPY
    crack_spots([(c, r, 1.2, 0.3), (c, r, -1.3, 0.4), (c, r, 0.5, 0.5), (c, r, -0.6, 0.25), (c, r, 1.6, 0.6),
                 (c, r, -1.7, 0.6), (c, r, 0.1, 0.75), (c, r, -0.2, 0.4)])


def build_mule():
    """A tandem-rotor transport gunship (a Chinook in spirit): a long box of a fuselage,
    a low rotor pylon over the cockpit and a tall one at the back, both three-bladed and
    turning against each other (the game spins "rotor" one way and "rotor_upper" the
    other), no tail rotor ("tail_rotor" only marks the tail end), engine pods on the aft
    pylon, fuel sponsons along the belly carrying missile rails, door guns forward, a
    loading ramp, four wheels. The pilot sits on the right."""
    fresh()
    s = 1.4
    ground = -1.15 * s
    base.GROUND_Z = ground
    body = loft("fuselage", [
        (4.75, 0.35, -0.35, 0.05, -0.75, 2.2, 2.4),
        (4.45, 0.95, -0.3, 0.55, -1.05, 2.6, 3.0),
        (3.9, 1.18, -0.2, 0.85, -1.15, 3.2, 3.6),
        (3.0, 1.25, -0.15, 1.05, -1.2, 3.6, 4.0),
        (0.0, 1.28, -0.12, 1.1, -1.2, 4.0, 4.0),
        (-3.2, 1.26, -0.08, 1.12, -1.15, 4.0, 4.0),
        (-4.3, 1.15, 0.05, 1.12, -0.85, 3.6, 3.2),
        (-4.9, 0.95, 0.25, 1.1, -0.45, 3.2, 2.6),
    ], "paint", count=44)
    base.HULL.append(body)
    parts = [body]
    # The cockpit: a flat windscreen, side windows, chin windows, a centre post.
    tilt = Matrix.Rotation(math.radians(-42), 4, "X")
    for side in (-1, 1):
        # On the nose slope and inside its outline (the hull narrows toward the top).
        parts.append(box((side * 0.34, 4.4, 0.47), (0.58, 0.05, 0.56), "glass", rotation=tilt @ Matrix.Rotation(side * 0.15, 4, "Y")))
        parts.append(box((side * 0.34, 4.39, 0.47), (0.64, 0.035, 0.62), "dark", rotation=tilt @ Matrix.Rotation(side * 0.15, 4, "Y")))
        parts.append(box((side * 1.27, 3.75, 0.38), (0.05, 1.0, 0.52), "glass"))
        parts.append(box((side * 1.255, 3.75, 0.38), (0.04, 1.08, 0.6), "dark"))
        parts.append(box((side * 0.55, 4.66, -0.5), (0.48, 0.3, 0.05), "glass",
                         rotation=Matrix.Rotation(math.radians(55), 4, "X")))
    parts.append(box((0, 4.41, 0.47), (0.08, 0.07, 0.62), "paint", rotation=tilt))
    # Round windows down both sides, the crew doors forward, rivet lines.
    for side in (-1, 1):
        for k in range(7):
            y = 2.3 - k * 0.95
            parts.append(cyl((side * 1.26, y, 0.25), (side * 1.3, y, 0.25), 0.2, "glass", 20))
            parts.append(ring((side * 1.29, y, 0.25), (1, 0, 0), 0.21, 0.025, "dark", 20))
        parts.append(box((side * 1.29, 2.95, -0.25), (0.03, 0.8, 1.25), "dark", bevel_width=0.01))
        parts += rivets((side * 1.3, 3.9, -0.62), (side * 1.3, -4.0, -0.62), 22)
        parts += rivets((side * 1.3, 3.9, 0.82), (side * 1.3, -4.0, 0.82), 22)
    # Forward pylon: a low hump over the cockpit with the front mast.
    parts.append(loft("front_pylon", [
        (4.2, 0.2, 0.95, 1.1, 0.95, 2.0, 2.0), (3.6, 0.55, 1.0, 1.55, 1.0, 2.4, 2.0),
        (2.6, 0.55, 1.0, 1.6, 1.0, 2.4, 2.0), (1.8, 0.3, 1.0, 1.2, 1.0, 2.0, 2.0)], "paint", count=24))
    parts.append(cyl((0, 3.2, 1.55), (0, 3.2, 1.95), 0.12, "metal", 16))
    # Aft pylon: tall, with the engines hung on its sides and the rear mast.
    parts.append(loft("aft_pylon", [
        (-1.6, 0.25, 1.05, 1.15, 1.05, 2.0, 2.0), (-2.6, 0.55, 1.05, 2.1, 1.05, 2.4, 2.0),
        (-4.0, 0.55, 1.05, 2.45, 1.05, 2.4, 2.0), (-4.85, 0.35, 1.0, 2.2, 1.0, 2.2, 2.0)], "paint", count=24))
    parts.append(cyl((0, -3.6, 2.4), (0, -3.6, 2.8), 0.12, "metal", 16))
    exhausts = []
    for side in (-1, 1):
        p, ex = engine_pod(side, 1.05, -2.3, -4.4, 1.35, 0.32)
        parts += p
        exhausts.append(ex)
        parts.append(box((side * 0.8, -3.3, 1.35), (0.5, 0.9, 0.18), "paint", bevel_width=0.03))  # Engine mounts.
    # Fuel sponsons along the belly; missile rails on their fronts.
    pods = []
    for side in (-1, 1):
        parts.append(loft("sponson", [
            (2.4, 0.05, -0.75, -0.7, -0.8, 2.0, 2.0), (2.0, 0.32, -0.8, -0.45, -1.1, 2.6, 2.6),
            (-2.6, 0.32, -0.8, -0.45, -1.1, 2.6, 2.6), (-3.1, 0.05, -0.75, -0.7, -0.8, 2.0, 2.0)], "paint", count=20))
        parts[-1].location = (side * 1.42, 0, 0)
        base.activate(parts[-1])
        bpy.ops.object.transform_apply(location=True)
        parts += missile_rail((side * 1.78, 0.6, -0.55), 1.4)
        pods.append(Vector((side * 1.78, 1.4, -0.55)))
        parts.append(ball((side * 1.75, -0.4, -0.45), 0.05, "light_green" if side > 0 else "light_red", segments=10,
                          rings=5))
    # Door guns in the crew doors, pointing forward.
    tips = []
    for side in (-1, 1):
        mount = Vector((side * 1.42, 2.95, -0.15))
        parts.append(cyl(mount - Vector((side * 0.15, 0, 0)), mount, 0.05, "dark", 10))
        parts.append(box(mount + Vector((0, 0.15, 0)), (0.16, 0.5, 0.16), "dark", bevel_width=0.02))
        for k in range(3):
            a = 2 * math.pi * k / 3
            off = Vector((math.cos(a) * 0.035, 0, math.sin(a) * 0.035))
            parts.append(cyl(mount + off + Vector((0, 0.4, 0)), mount + off + Vector((0, 1.2, 0)), 0.018, "metal", 8))
        tip = mount + Vector((0, 1.22, 0))
        parts.append(ring(tip, (0, 1, 0), 0.05, 0.012, "dark", 12))
        tips.append(tip)
    # The rear ramp, hinged at the belly, and its hinge line.
    parts.append(box((0, -4.6, -0.75), (2.1, 0.08, 0.95), "paint", rotation=Matrix.Rotation(math.radians(-30), 4, "X"),
                     bevel_width=0.02))
    parts.append(cyl((-1.0, -4.15, -1.12), (1.0, -4.15, -1.12), 0.05, "metal", 12))
    parts.append(ball((0, -4.95, 1.0), 0.05, "light_red", segments=10, rings=5))
    # Four wheels on short legs.
    for y, x in ((2.6, 1.0), (-2.9, 1.05)):
        for side in (-1, 1):
            hub = Vector((side * x, y, ground + 0.32))
            parts.append(tube([(side * (x - 0.2), y, -1.0), hub], 0.07, "metal", 12))
            parts += wheel(hub, 0.32, 0.22)
    body = join(parts, "body")
    base.activate(body)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    rear = rotor(3, Vector((0, -3.6, 2.4)), 2.8, 1.05)
    rear.name = "rotor_upper"
    rotor(3, Vector((0, 3.2, 1.55)), 1.95, 1.05)
    empty("tail_rotor", (0, -4.9, 1.0))
    empty("eye", (0.42, 3.55, 0.45))  # The pilot sits on the right (make_cockpit.py).
    empty("muzzle_l", tips[0])
    empty("muzzle_r", tips[1])
    empty("pod_l", pods[0])
    empty("pod_r", pods[1])
    empty("exhaust_l", exhausts[0])
    empty("exhaust_r", exhausts[1])


# Closer looks for judging the details (scaled for the bigger classes in preview).
base.VIEWS.update({
    "quarter": ((4.6, 6.0, 1.4), (0, 1.2, 0.1)),
    "rear": ((-5.5, -7.5, 3.2), (0, -1.8, 0.6)),
})

BUILDS = {"gunship": build_gunship, "heavy": build_heavy, "striker": build_striker, "mule": build_mule}


def export(name):
    base.OUT = os.path.join(OUT_DIR, name + ".glb")
    base.export()


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args and args[0] == "--preview":
        directory = args[1]
        for name in args[2:] or list(BUILDS):
            BUILDS[name]()
            base.preview(os.path.join(directory, name), ["front", "side", "top", "quarter", "rear"])
    else:
        for name in args or list(BUILDS):
            BUILDS[name]()
            export(name)
