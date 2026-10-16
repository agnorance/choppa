"""Builds the player helicopter, assets/models/choppa/choppa.glb.

Run:     python3 tools/blender/make_choppa.py
Preview: python3 tools/blender/make_choppa.py --preview DIR   (Cycles renders, no export)

A single-seat dieselpunk take on the Little Bird: an egg-shaped cabin whose glass wraps
down under the pilot's feet (shared with the cockpit interior through choppa_shared.py),
a seven-cylinder radial engine lying flat around the rotor mast, a five-blade rotor
with an articulated head, a slim tail boom with a T-tail, skids, and an AH-6 style
weapons bench with machine guns and rocket pods.

Blender +Y is the nose (becomes -Z, Godot's forward). Objects named "rotor" and
"tail_rotor" spin in the game. Empties mark points the game uses: "eye", "muzzle_l",
"muzzle_r", "exhaust_l", "exhaust_r". Materials are named so the game can swap in its
own: paint, metal, dark, glass, brass, rubber, exhaust, lamp, hazard, decal,
marking_red, light_red, light_green. Panel lines, rivets and wear come from the game's
hull shader, so no UVs are needed.
"""
import math
import os
import sys

import bpy
import bmesh  # Only importable after bpy.
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import choppa_shared as shared  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "choppa", "choppa.glb")
MATS = {}
# Preview colours only; the game replaces every material by name.
PREVIEW = {
    "paint": ((0.2, 0.26, 0.2), 0.2, 0.55), "metal": ((0.4, 0.4, 0.4), 0.9, 0.35),
    "dark": ((0.04, 0.04, 0.045), 0.4, 0.55), "glass": ((0.6, 0.7, 0.75), 0.0, 0.05),
    "brass": ((0.75, 0.55, 0.25), 1.0, 0.3), "rubber": ((0.02, 0.02, 0.02), 0.0, 0.85),
    "exhaust": ((0.25, 0.16, 0.1), 0.8, 0.6), "lamp": ((1.0, 0.9, 0.7), 0.0, 0.1),
    "hazard": ((0.8, 0.55, 0.05), 0.1, 0.5), "decal": ((0.85, 0.8, 0.65), 0.0, 0.6),
    "marking_red": ((0.55, 0.06, 0.04), 0.0, 0.55), "light_red": ((1, 0.05, 0.02), 0, 0.3),
    "light_green": ((0.05, 1, 0.1), 0, 0.3),
}
GROUND_Z = -1.15  # Choppa.GROUND_CLEARANCE below the origin.


# --- helpers -----------------------------------------------------------------------

def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        col, metal, rough = PREVIEW[name]
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        if name == "glass":
            bsdf.inputs["Alpha"].default_value = 0.25
        if name in ("lamp", "light_red", "light_green"):
            bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        MATS[name] = m
    return MATS[name]


def link(bm, name, material):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if isinstance(material, (list, tuple)):
        for m in material:
            obj.data.materials.append(mat(m))
    else:
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


def bevel(obj, width, segments=2, angle=40):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    apply_all(obj)
    return obj


def prim(kind, material, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1), bevel_width=0.0, **kw):
    getattr(bpy.ops.mesh, "primitive_%s_add" % kind)(location=location, rotation=rotation, **kw)
    o = bpy.context.active_object
    o.scale = scale
    activate(o)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel_width:
        bevel(o, bevel_width)
    o.data.materials.append(mat(material))
    return o


def align_z(direction):
    """Rotation matrix taking +Z to `direction`."""
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()


def place(o, matrix):
    o.data.transform(matrix @ o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    return o


def cyl(a, b, radius, material, verts=12, radius2=None, bevel_width=0.0):
    """Cylinder (or cone with radius2) from a to b."""
    a, b = Vector(a), Vector(b)
    if radius2 is None:
        o = prim("cylinder", material, vertices=verts, radius=radius, depth=(b - a).length)
    else:
        o = prim("cone", material, vertices=verts, radius1=radius, radius2=radius2, depth=(b - a).length)
    if bevel_width:
        bevel(o, bevel_width)
    return place(o, Matrix.Translation((a + b) / 2) @ align_z(b - a))


def box(center, size, material, rotation=Matrix.Identity(4), bevel_width=0.0, segments=2):
    o = prim("cube", material, scale=Vector(size) / 2)
    if bevel_width:
        bevel(o, bevel_width, segments)
    return place(o, Matrix.Translation(center) @ rotation)


def ball(center, radius, material, scale=(1, 1, 1), segments=16, rings=8):
    o = prim("uv_sphere", material, segments=segments, ring_count=rings, radius=radius, scale=scale)
    return place(o, Matrix.Translation(center))


def ring(center, axis, major, minor, material, segments=32):
    o = prim("torus", material, major_radius=major, minor_radius=minor, major_segments=segments, minor_segments=8)
    return place(o, Matrix.Translation(center) @ align_z(axis))


def tube(points, radius, material, sides=10, closed=False):
    """A swept round tube through points (parallel-transported rings, smooth joints)."""
    points = [Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    normal = None
    n = len(points)
    for k, p in enumerate(points):
        if closed:
            t = (points[(k + 1) % n] - points[k - 1]).normalized()
        elif k == 0:
            t = (points[1] - p).normalized()
        elif k == n - 1:
            t = (p - points[k - 1]).normalized()
        else:
            t = (points[k + 1] - points[k - 1]).normalized()
        if normal is None:
            normal = t.orthogonal().normalized()
        normal = (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        rings.append([bm.verts.new(p + (normal * math.cos(a) + binormal * math.sin(a)) * radius)
                      for a in (2 * math.pi * i / sides for i in range(sides))])
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for r0, r1 in pairs:
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    return link(bm, "tube", material)


def section_ring(y, w, zmid, ztop, zbot, etop, ebot, count):
    """Superellipse cross-section, separate top and bottom halves. Index 0 = right side."""
    pts = []
    for i in range(count):
        a = 2.0 * math.pi * i / count
        c, s = math.cos(a), math.sin(a)
        e = etop if s >= 0 else ebot
        x = w * math.copysign(abs(c) ** (2.0 / e), c)
        h = (ztop - zmid) if s >= 0 else (zmid - zbot)
        pts.append(Vector((x, y, zmid + h * math.copysign(abs(s) ** (2.0 / e), s))))
    return pts


def loft(name, sections, material, count=40, cap_start=True, cap_end=True):
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in section_ring(*s, count)] for s in sections]
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if cap_start:
        bm.faces.new(rings[0])
    if cap_end:
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    return link(bm, name, material)


def airfoil(chord, thickness, count=16):
    """Symmetric NACA 00xx outline, leading edge at +y, around the chord line (x=0)."""
    pts = []
    for i in range(count):
        a = 2.0 * math.pi * i / count
        t = (1.0 - math.cos(a)) / 2.0  # 0 at the leading edge, 1 at the trailing edge.
        half = 5 * thickness * (0.2969 * math.sqrt(t) - 0.126 * t - 0.3516 * t ** 2 + 0.2843 * t ** 3 - 0.1036 * t ** 4)
        side = 1.0 if i < count / 2 else -1.0
        pts.append((side * half * chord, chord * (0.25 - t)))  # (thickness, along chord)
    return pts


def wing(name, root, tip, material, chord_root, chord_tip, thickness, count=20, twist=0.0, steps=1,
         band_materials=None, pitch=0.0, edge_material=None):
    """Lofted airfoil from root to tip along X (chord along Y, thickness Z).
    band_materials: list of (start_fraction, material index) along the span; faces of
    band 0 within the front tenth of the chord get edge_material (a leading-edge strip)."""
    root, tip = Vector(root), Vector(tip)
    bm = bmesh.new()
    rings = []
    for k in range(steps + 1):
        t = k / steps
        c = chord_root + (chord_tip - chord_root) * t
        rot = Matrix.Rotation(pitch + twist * t, 3, "X")
        centre = root.lerp(tip, t)
        rings.append([bm.verts.new(centre + rot @ Vector((0.0, along, z)))
                      for z, along in airfoil(c, thickness, count)])
    for k, (r0, r1) in enumerate(zip(rings, rings[1:])):
        t = (k + 0.5) / steps
        index = 0
        for start, idx in band_materials or []:
            if t >= start:
                index = idx
        for i in range(count):
            j = (i + 1) % count
            f = bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
            leading = i in (0, 1, count - 2, count - 1)
            f.material_index = edge_material if leading and index == 0 and edge_material is not None else index
            f.smooth = True
    for r, rev in ((rings[0], True), (rings[-1], False)):
        f = bm.faces.new(list(reversed(r)) if rev else r)
        f.material_index = 0 if rev else (band_materials[-1][1] if band_materials else 0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return link(bm, name, material)


def join(parts, name):
    parts = [p for p in parts if p is not None]
    activate(parts[0])
    for p in parts[1:]:
        p.select_set(True)
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def empty(name, location):
    e = bpy.data.objects.new(name, None)
    e.location = location
    bpy.context.collection.objects.link(e)
    return e


def mirrored(build_fn):
    """Calls build_fn(side) for side -1 and 1 and returns all parts."""
    out = []
    for side in (-1, 1):
        out += build_fn(side)
    return out


# --- fuselage and canopy -----------------------------------------------------------

# (y, half width, z of the widest line, z top, z bottom, top exponent, bottom exponent)
# --- cabin and tail cone -----------------------------------------------------------

# Tail cone and engine deck behind the egg:
# (y, half width, z of the widest line, z top, z bottom, top exponent, bottom exponent)
TAIL_CONE = [
    (0.55, 0.6, 0.3, 1.0, -0.62, 2.6, 2.4),
    (0.0, 0.7, 0.35, 1.18, -0.55, 3.2, 2.6),
    (-0.6, 0.64, 0.4, 1.16, -0.3, 3.2, 2.5),
    (-1.2, 0.48, 0.45, 1.05, 0.02, 2.8, 2.4),
    (-1.8, 0.3, 0.5, 0.85, 0.26, 2.5, 2.2),
    (-2.3, 0.17, 0.56, 0.73, 0.4, 2.2, 2.2),
    (-2.35, 0.16, 0.56, 0.72, 0.41, 2.2, 2.2),
]
BOOM_START = -2.3
BOOM_END = -5.5


def boom_axis(y):
    """Centre and radius of the tail boom at y."""
    t = (y - BOOM_START) / (BOOM_END - BOOM_START)
    return Vector((0, y, 0.56 + 0.16 * t)), 0.16 + (0.085 - 0.16) * t


def section_x(sections, y, z):
    for a, b in zip(sections, sections[1:]):
        if b[0] <= y <= a[0]:
            t = (y - a[0]) / (b[0] - a[0])
            _, w, zmid, ztop, zbot, etop, ebot = [p + (q - p) * t for p, q in zip(a, b)]
            break
    else:
        return 0.0
    f, e = ((z - zmid) / (ztop - zmid), etop) if z >= zmid else ((zmid - z) / (zmid - zbot), ebot)
    if f > 1.0:
        return 0.0
    s = max(0.0, f) ** (e / 2.0)
    return w * math.sqrt(max(0.0, 1.0 - s * s)) ** (2.0 / e)


def hull_x(y, z):
    """Half width of the body (egg or tail cone) at y and height z, for placing details."""
    c, r = shared.EGG_CENTER, shared.EGG_RADII
    k = 1.0 - ((y - c.y) / r.y) ** 2 - ((z - c.z) / r.z) ** 2
    egg = r.x * math.sqrt(k) if k > 0 else 0.0
    return max(egg, section_x(TAIL_CONE, y, z))


def on_hull(side, y, z, out=0.0):
    return Vector((side * (hull_x(y, z) + out), y, z))


HULL = []  # The body surfaces, once built, for projecting details onto them.


def surface(side, y, z, out=0.0):
    """Point on the body near (side, y, z) pushed `out` along its normal, and the normal."""
    guess = on_hull(side, y, z)
    best = None
    for o in HULL:
        ok, loc, normal, _ = o.closest_point_on_mesh(guess)
        if ok and (best is None or (loc - guess).length < (best[0] - guess).length):
            best = (loc, normal)
    if best is None:
        return guess + Vector((side * out, 0, 0)), Vector((side, 0, 0))
    return best[0] + best[1] * out, best[1]


def plate(side, y0, y1, z0, z1, thickness=0.018, bolt_step=0.11, material="paint"):
    """Riveted access panel following the body between y0..y1 and z0..z1."""
    nu, nv = 10, 6
    bm = bmesh.new()
    top, bottom = [], []
    for i in range(nu + 1):
        for j in range(nv + 1):
            y = y0 + (y1 - y0) * i / nu
            z = z0 + (z1 - z0) * j / nv
            p, n = surface(side, y, z)
            top.append(bm.verts.new(p + n * thickness))
            bottom.append(bm.verts.new(p - n * 0.01))
    idx = lambda i, j: i * (nv + 1) + j
    for i in range(nu):
        for j in range(nv):
            q = [idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)]
            bm.faces.new([top[k] for k in q])
            bm.faces.new([bottom[k] for k in reversed(q)])
    edge = [idx(i, 0) for i in range(nu)] + [idx(nu, j) for j in range(nv)] + \
           [idx(i, nv) for i in range(nu, 0, -1)] + [idx(0, j) for j in range(nv, 0, -1)]
    for a, b in zip(edge, edge[1:] + edge[:1]):
        bm.faces.new((top[a], bottom[a], bottom[b], top[b]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = link(bm, "plate", material)
    bevel(o, 0.008, 1, angle=50)
    parts = [o]
    inset = 0.035
    ya, yb = min(y0, y1) + inset, max(y0, y1) - inset
    za, zb = min(z0, z1) + inset, max(z0, z1) - inset
    ny, nz = max(1, round((yb - ya) / bolt_step)), max(1, round((zb - za) / bolt_step))
    spots = [(ya + (yb - ya) * k / ny, z) for k in range(ny + 1) for z in (za, zb)]
    spots += [(y, za + (zb - za) * k / nz) for k in range(1, nz) for y in (ya, yb)]
    for y, z in spots:
        p, n = surface(side, y, z, thickness + 0.002)
        parts.append(ball(p, 0.013, "metal", segments=8, rings=4))
    return parts


def cabin():
    """The egg: glass in front of the rear hoop and above the sill, painted below and behind."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1.0)
    c, r = shared.EGG_CENTER, shared.EGG_RADII
    for v in bm.verts:
        v.co = c + Vector((v.co.x * r.x, v.co.y * r.y, v.co.z * r.z))
    # Cut along the sill plane and the rear hoop so the glass edge is clean.
    slope = shared.SILL_SLOPE
    for co, no in (((0, shared.REAR_Y, shared.SILL_REAR_Z), (0, -slope, 1)), ((0, shared.REAR_Y, 0), (0, 1, 0))):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=Vector(no).normalized())
    for f in bm.faces:
        f.smooth = True
        f.material_index = 1 if shared.is_glass(f.calc_center_median()) else 0
    egg = link(bm, "cabin", ["paint", "glass"])
    HULL.append(egg)
    return [egg]


def tail_cone():
    cone = loft("tail_cone", TAIL_CONE, "paint", count=40)
    sub = cone.modifiers.new("subsurf", "SUBSURF")
    sub.levels = 1
    apply_all(cone)
    HULL.append(cone)
    parts = [cone]
    # Tapered boom with riveted collars.
    a, ra = boom_axis(BOOM_START + 0.05)
    b, rb = boom_axis(BOOM_END)
    parts.append(cyl(a, b, ra, "paint", 24, radius2=rb))
    for k in range(5):
        y = BOOM_START - 0.15 - k * 0.75
        p, r = boom_axis(y)
        parts.append(ring(p, (0, 1, 0), r + 0.004, 0.012, "paint", 24))
    # Driveshaft cover along the top.
    a2, b2 = a + Vector((0, 0, ra * 0.95)), b + Vector((0, 0, rb * 0.95))
    parts.append(cyl(a2, b2, 0.04, "paint", 12, radius2=0.03))
    return parts


def frames():
    parts = [tube(shared.sill_points(0.02), 0.04, "paint", 10),
             tube(shared.roof_points(0.015), 0.032, "paint", 10),
             tube(shared.chin_points(0.015), 0.026, "paint", 10),
             tube(shared.rear_hoop_points(0.02), 0.05, "paint", 12)]
    for side in (-1, 1):
        parts.append(tube(shared.pillar_points(side, 0.015), 0.034, "paint", 10))
    # Wiper on the upper windscreen and a door latch.
    base = shared.canopy_point(0.0, shared.CHIN, 0.04)
    parts.append(cyl(base, shared.canopy_point(0.25, 0.45, 0.04), 0.008, "dark", 6))
    latch = shared.canopy_point(math.radians(95), 0.25, 0.03)
    parts.append(box(latch, (0.03, 0.12, 0.04), "brass", bevel_width=0.008))
    return parts


def cockpit_tub():
    """What you see of the cockpit from outside: the seat (the game adds the panel)."""
    eye = shared.EYE
    parts = [box(eye + Vector((0, -0.38, -0.55)), (0.5, 0.48, 0.12), "dark", bevel_width=0.03),
             box(eye + Vector((0, -0.6, -0.1)), (0.48, 0.1, 0.8), "dark",
                 rotation=Matrix.Rotation(math.radians(12), 4, "X"), bevel_width=0.03),
             box(eye + Vector((0, -0.66, 0.32)), (0.3, 0.12, 0.22), "dark", bevel_width=0.04)]
    for side in (-1, 1):
        parts.append(cyl(eye + Vector((side * 0.27, -0.6, -0.55)), eye + Vector((side * 0.27, -0.66, 0.25)),
                         0.02, "metal", 8))
    return parts


MAST = Vector((0.0, -0.45, 1.25))  # Crankcase centre on the engine deck.
ROTOR_Z = 1.98


def radial_engine():
    parts = []
    c = MAST
    # Crankcase, mounting ring and the reduction gearbox on top.
    parts.append(cyl(c + Vector((0, 0, -0.1)), c + Vector((0, 0, 0.16)), 0.3, "metal", 28, bevel_width=0.03))
    parts.append(cyl(c + Vector((0, 0, -0.14)), c + Vector((0, 0, -0.1)), 0.42, "dark", 28, bevel_width=0.01))
    parts.append(cyl(c + Vector((0, 0, 0.16)), c + Vector((0, 0, 0.36)), 0.24, "paint", 28, radius2=0.16,
                     bevel_width=0.02))
    for k in range(12):
        a = 2 * math.pi * k / 12
        parts.append(ball(c + Vector((0.27 * math.cos(a), 0.27 * math.sin(a), 0.165)), 0.016, "brass", segments=8,
                          rings=4))
    # Mast with a rubber boot; the swashplate's fixed half (the rotating half is on the rotor).
    parts.append(cyl(c + Vector((0, 0, 0.36)), (c.x, c.y, ROTOR_Z), 0.075, "metal", 16))
    parts.append(cyl(c + Vector((0, 0, 0.34)), c + Vector((0, 0, 0.46)), 0.11, "rubber", 16, radius2=0.08))
    parts.append(cyl((c.x, c.y, ROTOR_Z - 0.33), (c.x, c.y, ROTOR_Z - 0.28), 0.22, "dark", 28, bevel_width=0.01))
    for side in (-1, 1):  # Swashplate actuators down to the gearbox.
        p = Vector((c.x + side * 0.2, c.y + 0.05, 0.0))
        parts.append(cyl(p + Vector((0, 0, c.z + 0.28)), p + Vector((0, 0, ROTOR_Z - 0.33)), 0.022, "metal", 8))
        parts.append(cyl(p + Vector((0, 0, c.z + 0.2)), p + Vector((0, 0, c.z + 0.32)), 0.035, "dark", 10))

    cylinders = 7
    for k in range(cylinders):
        a = 2 * math.pi * (k + 0.5) / cylinders + math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        base = c + d * 0.28 + Vector((0, 0, 0.03))
        # Barrel with cooling fins, then the head with its own fins and rocker boxes.
        parts.append(cyl(base, base + d * 0.36, 0.085, "dark", 16))
        for f in range(8):
            r = base + d * (0.06 + f * 0.035)
            parts.append(cyl(r, r + d * 0.012, 0.125, "dark", 20))
        head = base + d * 0.36
        parts.append(cyl(head, head + d * 0.13, 0.11, "metal", 18, radius2=0.08, bevel_width=0.01))
        for f in range(3):
            r = head + d * (0.02 + f * 0.035)
            parts.append(cyl(r, r + d * 0.01, 0.135, "metal", 16))
        for s in (-1, 1):
            rocker = head + d * 0.06 + side * s * 0.07 + Vector((0, 0, 0.1))
            parts.append(box(rocker, (0.08, 0.08, 0.06), "metal", rotation=Matrix.Rotation(a, 4, "Z"),
                             bevel_width=0.015))
            # Pushrod tube from the crankcase up to the rocker box.
            parts.append(cyl(c + d * 0.26 + side * s * 0.05 + Vector((0, 0, 0.12)), rocker + Vector((0, 0, -0.02)),
                             0.012, "metal", 6))
        # Spark plug lead from the ignition ring, and the exhaust down into the collector.
        plug = head + d * 0.09 + Vector((0, 0, 0.12))
        parts.append(cyl(plug, plug + Vector((0, 0, 0.04)), 0.012, "brass", 6))
        parts.append(tube([c + d * 0.2 + Vector((0, 0, 0.22)), c + d * 0.36 + Vector((0, 0, 0.24)),
                           plug + Vector((0, 0, 0.04))], 0.006, "brass", 5))
        port = head + d * 0.05 + Vector((0, 0, -0.08))
        parts.append(tube([port, port + Vector((0, 0, -0.05)) - d * 0.02, c + d * 0.6 + Vector((0, 0, -0.12))],
                          0.03, "exhaust", 8))
    # Ignition harness ring and the exhaust collector ring under the cylinders.
    parts.append(ring(c + Vector((0, 0, 0.22)), (0, 0, 1), 0.28, 0.012, "brass", 32))
    parts.append(ring(c + Vector((0, 0, -0.12)), (0, 0, 1), 0.6, 0.045, "exhaust", 48))
    return parts


def exhausts():
    """Two pipes from the collector ring down the deck into flared stubs."""
    parts = []
    for side in (-1, 1):
        c = MAST
        pts = [c + Vector((side * 0.55, -0.24, -0.12)), c + Vector((side * 0.66, -0.5, -0.2)),
               on_hull(side, -1.2, 0.82, 0.07), on_hull(side, -1.6, 0.72, 0.07)]
        parts.append(tube(pts, 0.06, "exhaust", 12))
        tip = pts[-1]
        out = tip + Vector((side * 0.06, -0.26, -0.04))
        parts.append(cyl(tip, out, 0.065, "exhaust", 14, radius2=0.09))
        parts.append(ring(out, out - tip, 0.085, 0.012, "dark", 18))
        for t in (0.35, 0.7):
            p = pts[1].lerp(pts[2], t)
            parts.append(ring(p, pts[2] - pts[1], 0.07, 0.012, "metal", 14))
    return parts


EXHAUST_TIPS = [Vector((-0.42, -1.86, 0.68)), Vector((0.42, -1.86, 0.68))]  # Refined in build().


def deck_details():
    parts = []
    # Air filter canister between the canopy and the engine, ducted to the carburettor.
    can = Vector((0, 0.48, 1.24))
    parts.append(cyl(can + Vector((-0.26, 0, 0)), can + Vector((0.26, 0, 0)), 0.11, "metal", 24, bevel_width=0.02))
    for x in (-0.26, 0.26):
        parts.append(cyl(can + Vector((x, 0, 0)), can + Vector((x * 1.08, 0, 0)), 0.08, "brass", 18, bevel_width=0.008))
    for x in (-0.12, 0.12):
        parts.append(ring(can + Vector((x, 0, 0)), (1, 0, 0), 0.112, 0.01, "dark", 24))
    parts.append(tube([can + Vector((0, -0.08, -0.04)), can + Vector((0, -0.3, -0.08)), MAST + Vector((0, 0.3, -0.04))],
                      0.045, "rubber", 10))
    # Oil tank behind the engine, strapped down.
    tank = Vector((0, -1.42, 1.07))
    parts.append(cyl(tank + Vector((-0.3, 0, 0)), tank + Vector((0.3, 0, 0)), 0.15, "paint", 24, bevel_width=0.04))
    for x in (-0.16, 0.16):
        parts.append(ring(tank + Vector((x, 0, 0)), (1, 0, 0), 0.152, 0.012, "dark", 24))
    parts.append(cyl(tank + Vector((0.1, 0, 0.14)), tank + Vector((0.1, 0, 0.19)), 0.04, "brass", 14, bevel_width=0.005))
    # Engine access panels with louvres on both flanks.
    for side in (-1, 1):
        parts += plate(side, 0.05, -0.95, 0.42, 0.88)
        for k in range(7):
            y = -0.05 - k * 0.13
            p, n = surface(side, y, 0.65, 0.03)
            parts.append(box(p, (0.03, 0.035, 0.28), "dark", rotation=Matrix.Rotation(side * 0.3, 4, "Z"),
                             bevel_width=0.005))
    # Antenna mast on the tail cone, wire to the fin.
    mast_top = Vector((0, -2.05, 1.25))
    parts.append(cyl((0, -1.9, 0.8), mast_top, 0.016, "metal", 8, radius2=0.009))
    parts.append(cyl(mast_top, Vector((0, BOOM_END - 0.95, 1.85)), 0.005, "dark", 4))
    return parts


# --- tail --------------------------------------------------------------------------

def tail_end():
    parts = []
    end, _ = boom_axis(BOOM_END)
    # Tail gearbox casting.
    parts.append(ball(end + Vector((0, -0.1, 0)), 0.15, "metal", scale=(0.9, 1.4, 1.0), segments=20, rings=10))
    parts.append(cyl(end + Vector((0, -0.1, 0)), end + Vector((-0.22, -0.1, 0)), 0.065, "metal", 16, bevel_width=0.01))
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(ball(end + Vector((0.12, -0.1 + 0.1 * math.cos(a), 0.1 * math.sin(a))), 0.013, "brass",
                          segments=6, rings=3))
    # Swept vertical fin and a ventral fin with the tail bumper.
    parts.append(fin([(0.1, 0.0), (-0.65, 1.1), (-0.98, 1.16), (-1.02, 0.95), (-0.65, -0.02)], end, 0.07))
    parts.append(fin([(0.0, 0.0), (-0.5, 0.0), (-0.72, -0.5), (-0.5, -0.55)], end, 0.06))
    parts.append(cyl(end + Vector((0, -0.48, -0.56)), end + Vector((0, -0.78, -0.56)), 0.03, "metal", 8))
    parts.append(ball(end + Vector((0, -0.95, 1.16)), 0.035, "light_red", segments=10, rings=5))
    # Horizontal stabiliser through the boom, with end plates.
    stab_y = -4.75
    centre, r = boom_axis(stab_y)
    for side in (-1, 1):
        root = Vector((0, stab_y, centre.z))
        tip = Vector((side * 0.95, stab_y - 0.06, centre.z))
        parts.append(wing("stabiliser", root, tip, "paint", 0.46, 0.34, 0.1, count=16, steps=2))
        parts.append(fin([(0.22, -0.18), (-0.22, -0.12), (-0.28, 0.24), (0.12, 0.26)], tip, 0.03))
    return parts


# --- weapons and skids -------------------------------------------------------------

BENCH_Y = 0.5
BENCH_Z = -0.62
GUN_X = 1.12
GUN_Z = -0.8
MUZZLE_Y = 2.35
SKID_X = 0.95


def bench():
    """AH-6 style weapons bench through the cabin floor: machine guns and rocket pods."""
    parts = [box((0, BENCH_Y, BENCH_Z), (3.1, 0.16, 0.12), "paint", bevel_width=0.03)]
    for side in (-1, 1):
        end = Vector((side * 1.55, BENCH_Y, BENCH_Z))
        parts.append(ball(end + Vector((side * 0.02, 0, 0)), 0.045, "light_green" if side > 0 else "light_red",
                          segments=12, rings=6))
        for k in range(6):
            parts.append(ball(Vector((side * (0.62 + k * 0.17), BENCH_Y + 0.085, BENCH_Z + 0.03)), 0.012, "metal",
                              segments=6, rings=3))
        # Machine gun: receiver, fluted cooling jacket, barrel, flash hider, ammo drum.
        x = side * GUN_X
        parts.append(box((x, BENCH_Y, (BENCH_Z + GUN_Z) / 2), (0.06, 0.2, abs(GUN_Z - BENCH_Z)), "dark",
                         bevel_width=0.01))
        parts.append(box((x, BENCH_Y + 0.05, GUN_Z), (0.13, 0.75, 0.16), "dark", bevel_width=0.025))
        parts.append(box((x, BENCH_Y - 0.36, GUN_Z - 0.04), (0.06, 0.12, 0.12), "metal", bevel_width=0.015))
        jacket = prim("cylinder", "dark", vertices=24, radius=0.06, depth=0.8)
        bm = bmesh.new()
        bm.from_mesh(jacket.data)
        for v in bm.verts:
            k = round(math.atan2(v.co.y, v.co.x) / (2 * math.pi / 24))
            if k % 2:
                v.co.x *= 0.82
                v.co.y *= 0.82
        bm.to_mesh(jacket.data)
        bm.free()
        jy = BENCH_Y + 0.42 + 0.4
        place(jacket, Matrix.Translation((x, jy, GUN_Z)) @ align_z((0, 1, 0)))
        parts.append(jacket)
        for y in (jy - 0.35, jy, jy + 0.35):
            parts.append(ring((x, y, GUN_Z), (0, 1, 0), 0.062, 0.012, "metal", 18))
        parts.append(cyl((x, jy + 0.4, GUN_Z), (x, MUZZLE_Y - 0.1, GUN_Z), 0.022, "metal", 10))
        parts.append(cyl((x, MUZZLE_Y - 0.13, GUN_Z), (x, MUZZLE_Y, GUN_Z), 0.034, "dark", 12, radius2=0.042))
        drum = Vector((x + side * 0.16, BENCH_Y + 0.05, GUN_Z + 0.02))
        parts.append(cyl(drum - Vector((0.07, 0, 0)), drum + Vector((0.07, 0, 0)), 0.15, "paint", 24, bevel_width=0.02))
        parts.append(ring(drum, (1, 0, 0), 0.15, 0.012, "metal", 24))
        parts.append(ball(drum + Vector((side * 0.075, 0, 0)), 0.03, "brass", segments=10, rings=5))
        # Rocket pod at the bench end.
        pod = Vector((side * 1.5, BENCH_Y + 0.05, BENCH_Z - 0.26))
        parts.append(box(pod + Vector((0, 0, 0.16)), (0.05, 0.4, 0.14), "dark", bevel_width=0.015))
        parts.append(cyl(pod + Vector((0, -0.55, 0)), pod + Vector((0, 0.5, 0)), 0.17, "paint", 28, bevel_width=0.02))
        parts.append(cyl(pod + Vector((0, -0.65, 0)), pod + Vector((0, -0.55, 0)), 0.11, "paint", 28, radius2=0.17,
                         bevel_width=0.01))
        for y in (0.5, -0.4):
            parts.append(ring(pod + Vector((0, y, 0)), (0, 1, 0), 0.17, 0.016, "metal", 28))
        for k in range(7):
            off = Vector((0, 0, 0)) if k == 6 else Vector((0.1 * math.cos(k * math.pi / 3), 0, 0.1 * math.sin(k * math.pi / 3)))
            mouth = pod + off + Vector((0, 0.51, 0))
            parts.append(cyl(mouth, mouth + Vector((0, 0.02, 0)), 0.042, "dark", 12))
            parts.append(ball(mouth + Vector((0, -0.03, 0)), 0.03, "hazard", segments=8, rings=4))
    return parts


def skids():
    parts = []
    skid_z = GROUND_Z + 0.045
    for side in (-1, 1):
        # Cross tubes bowing out of the belly down to the skids.
        for y, top in ((1.45, -0.8), (-0.35, -0.5)):
            parts.append(tube([(side * 0.3, y, top + 0.05), (side * 0.62, y, top - 0.05),
                               (side * 0.86, y, (top + skid_z) / 2 - 0.08), (side * SKID_X, y, skid_z)], 0.04,
                              "paint", 12))
            parts.append(cyl((side * SKID_X, y, skid_z - 0.01), (side * SKID_X, y, skid_z + 0.09), 0.055, "metal", 12,
                             bevel_width=0.01))
        parts.append(tube([(side * SKID_X, -0.95, skid_z + 0.02), (side * SKID_X, -0.8, skid_z),
                           (side * SKID_X, 1.85, skid_z), (side * SKID_X, 2.15, skid_z + 0.07),
                           (side * SKID_X, 2.3, skid_z + 0.25)], 0.045, "paint", 12))
        # Wear shoes and a boarding step.
        for y in (-0.2, 1.2):
            parts.append(box((side * SKID_X, y, skid_z - 0.035), (0.05, 0.4, 0.02), "metal", bevel_width=0.005))
        parts.append(tube([(side * SKID_X, 0.9, skid_z), (side * (SKID_X + 0.12), 0.88, skid_z + 0.12),
                           (side * (SKID_X + 0.12), 0.62, skid_z + 0.12), (side * SKID_X, 0.6, skid_z)], 0.014,
                          "metal", 8))
    # Searchlight under the belly.
    lamp = Vector((0, 1.15, -0.9))
    aim = Vector((0, 1, -0.3)).normalized()
    parts.append(cyl(lamp - aim * 0.16, lamp, 0.09, "dark", 20, bevel_width=0.015))
    parts.append(ring(lamp, aim, 0.09, 0.016, "brass", 24))
    parts.append(cyl(lamp, lamp + aim * 0.01, 0.08, "lamp", 20))
    return parts


def fin(outline, origin, thickness):
    """Flat fin from a (dy, dz) outline in the YZ plane, extruded along X and bevelled."""
    bm = bmesh.new()
    verts = [bm.verts.new((-thickness / 2, y, z)) for y, z in outline]
    face = bm.faces.new(verts)
    bmesh.ops.recalc_face_normals(bm, faces=[face])
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in ext["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co.x += thickness
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = link(bm, "fin", "paint")
    bevel(o, thickness * 0.45, 3, angle=30)
    o.data.transform(Matrix.Translation(origin))
    return o


# --- rotors ------------------------------------------------------------------------

BLADES = 5


def rotor():
    parts = []
    parts.append(cyl((0, 0, -0.07), (0, 0, 0.07), 0.2, "metal", 28, bevel_width=0.02))
    parts.append(cyl((0, 0, 0.07), (0, 0, 0.12), 0.14, "dark", 24, bevel_width=0.01))
    parts.append(ball((0, 0, 0.14), 0.1, "brass", scale=(1, 1, 0.7), segments=20, rings=10))
    # Rotating half of the swashplate.
    parts.append(cyl((0, 0, -0.27), (0, 0, -0.23), 0.2, "metal", 28, bevel_width=0.01))
    for k in range(10):
        a = 2 * math.pi * k / 10
        parts.append(ball((0.165 * math.cos(a), 0.165 * math.sin(a), 0.075), 0.014, "brass", segments=8, rings=4))
    for k in range(BLADES):
        rot = Matrix.Rotation(2 * math.pi * k / BLADES, 4, "Z")
        arm = []
        # Yoke arm, flapping hinge, blade grip, pitch horn and link.
        arm.append(box((0.3, 0, 0), (0.24, 0.16, 0.1), "metal", bevel_width=0.025))
        arm.append(cyl((0.42, -0.1, 0), (0.42, 0.1, 0), 0.04, "dark", 12))
        arm.append(cyl((0.44, 0, 0), (0.82, 0, 0), 0.07, "metal", 18, radius2=0.055, bevel_width=0.01))
        for x in (0.52, 0.72):
            arm.append(ring((x, 0, 0), (1, 0, 0), 0.068, 0.012, "dark", 16))
        arm.append(box((0.5, -0.13, -0.03), (0.06, 0.16, 0.035), "metal", bevel_width=0.008))
        arm.append(cyl((0.5, -0.2, -0.04), (0.14, -0.14, -0.23), 0.014, "metal", 8))
        arm.append(ball((0.5, -0.2, -0.04), 0.022, "brass", segments=8, rings=4))
        # Blade: twisted airfoil, metal leading edge, hazard-striped tip.
        arm.append(wing("blade", (0.8, 0, 0), (4.3, 0, 0), ["dark", "hazard", "decal", "metal"], 0.28, 0.24, 0.12,
                        count=20, pitch=math.radians(8), twist=math.radians(-7), steps=12,
                        band_materials=[(0.0, 0), (0.9, 1), (0.94, 2), (0.97, 1)], edge_material=3))
        for o in arm:
            place(o, rot)
        parts += arm
    r = join(parts, "rotor")
    r.location = (MAST.x, MAST.y, ROTOR_Z)
    return r


def tail_rotor(at):
    parts = [cyl((-0.06, 0, 0), (0.06, 0, 0), 0.07, "metal", 16, bevel_width=0.01),
             ball((-0.08, 0, 0), 0.05, "brass", scale=(0.8, 1, 1), segments=12, rings=6)]
    for k in range(3):
        rot = Matrix.Rotation(2 * math.pi * k / 3, 4, "X")
        blade = wing("tail_blade", (0.06, 0, 0), (0.62, 0, 0), ["dark", "hazard"], 0.13, 0.1, 0.12, count=12,
                     pitch=math.radians(10), steps=4, band_materials=[(0.0, 0), (0.75, 1)])
        # wing() spans along X; turn it to span along Z with the chord along Y.
        blade.data.transform(Matrix.Rotation(math.radians(-90), 4, "Y"))
        parts.append(place(blade, rot))
        parts.append(place(cyl((0, 0, 0.04), (0, 0, 0.14), 0.025, "metal", 8), rot))
    t = join(parts, "tail_rotor")
    t.location = at
    return t


# --- markings ----------------------------------------------------------------------

def stencil(text, center, normal, up, height, material, target):
    """Flat text pressed onto the hull, a hair outside it."""
    bpy.ops.object.text_add()
    t = bpy.context.active_object
    t.data.body = text
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.size = height
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    return press(o, center, normal, up, material, target)


def press(o, center, normal, up, material, target):
    """Orient a flat mesh made in the XY plane onto the hull at center, facing normal.
    With a target it is shrink-wrapped onto that surface, otherwise left flat."""
    normal, up = Vector(normal).normalized(), Vector(up).normalized()
    right = up.cross(normal)
    basis = Matrix((right, up, normal)).transposed().to_4x4()
    o.data.transform(Matrix.Translation(center) @ basis)
    o.matrix_world = Matrix.Identity(4)
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    if target is not None:
        sw = o.modifiers.new("press", "SHRINKWRAP")
        sw.target = target
        sw.wrap_method = "NEAREST_SURFACEPOINT"
        sw.wrap_mode = "OUTSIDE_SURFACE"
        sw.offset = 0.006
        apply_all(o)
    return o


def disc(r_outer, r_inner, segments=40, steps=3):
    """Flat ring (or disc when r_inner is 0) in the XY plane, finely split for pressing."""
    bm = bmesh.new()
    rows = []
    for k in range(steps + 1):
        r = r_inner + (r_outer - r_inner) * k / steps
        if r == 0.0:
            rows.append([bm.verts.new((0, 0, 0))] * segments)
            continue
        rows.append([bm.verts.new((r * math.cos(2 * math.pi * i / segments), r * math.sin(2 * math.pi * i / segments), 0))
                     for i in range(segments)])
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            quad = [r0[i], r0[j], r1[j], r1[i]]
            unique = list(dict.fromkeys(quad))
            bm.faces.new(unique)
    return link(bm, "disc", "decal")


def roundel(center, normal, up, radius, target):
    return [press(disc(radius, radius * 0.7), center, normal, up, "decal", target),
            press(disc(radius * 0.6, 0.0), center, normal, up, "marking_red", target)]


def markings():
    parts = []
    for side in (-1, 1):
        n = Vector((side, 0, 0))
        up = Vector((0, 0, 1))
        p, _ = surface(side, 0.3, -0.2)
        parts.append(stencil("07", p, n, up, 0.3, "decal", HULL[0]))
        p, _ = surface(side, -1.15, 0.45)
        parts += roundel(p, n, up, 0.17, HULL[1])
        parts.append(stencil("07", Vector((side * 0.037, BOOM_END - 0.62, boom_axis(BOOM_END)[0].z + 0.5)), n, up,
                             0.22, "decal", None))
    return parts


# --- assembly ----------------------------------------------------------------------

def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    HULL.clear()
    parts = cabin()
    parts += tail_cone()
    parts += frames()
    parts += cockpit_tub()
    parts += radial_engine()
    parts += exhausts()
    parts += deck_details()
    parts += tail_end()
    parts += bench()
    parts += skids()
    parts += markings()
    body = join(parts, "body")
    activate(body)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

    rotor()
    tail_rotor(Vector((-0.28, BOOM_END - 0.1, boom_axis(BOOM_END)[0].z)))
    empty("eye", shared.EYE)
    empty("muzzle_l", (-GUN_X, MUZZLE_Y, GUN_Z))
    empty("muzzle_r", (GUN_X, MUZZLE_Y, GUN_Z))
    for side, name in ((-1, "exhaust_l"), (1, "exhaust_r")):
        empty(name, on_hull(side, -1.6, 0.72, 0.07) + Vector((side * 0.06, -0.3, -0.05)))



def export():
    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.abspath(OUT)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    tris = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
    print(f"exported {path} ({tris} triangles)", flush=True)


VIEWS = {
    "front": ((7.5, 7.5, 2.2), (0, 0.0, 0.3)),
    "chase": ((0.0, -13.0, 4.5), (0, 0.0, 0.6)),
    "side": ((11.0, -1.0, 0.8), (0, -1.4, 0.4)),
    "top": ((3.0, -3.5, 9.0), (0, -1.0, 0.5)),
    "engine": ((2.2, -2.6, 2.9), (0, -0.6, 1.4)),
    "nose": ((2.2, 4.6, 0.3), (0, 2.2, -0.2)),
}


def preview(directory, views):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 500
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.5, 0.45, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.85, 0.65)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    bpy.context.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, GROUND_Z))
    ground = bpy.context.active_object
    ground.data.materials.append(mat("decal"))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 40
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(directory, exist_ok=True)
    for name in views:
        eye, target = VIEWS[name]
        cam.location = eye
        cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(directory, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath, flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    build()
    if args and args[0] == "--preview":
        preview(args[1], args[2:] or list(VIEWS))
    else:
        export()
