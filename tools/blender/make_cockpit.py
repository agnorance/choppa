"""Builds the cockpit interiors, one per helicopter class, as
assets/models/choppa/cockpit_<class>.glb (owner 2026-10-17: "each helicopter's cockpit
should be individual and way more detailed and realistic"):

- scout: Little Bird. A bubble of glass, a compact pedestal panel of round gauges, a
  radar scope, switch rows, the canopy frame shared with the exterior (choppa_shared).
- gunship: Apache style, tandem, the pilot behind and above the gunner. A narrow tub,
  two multi-function displays under a glare hood, standby gauges, the gunner's seat
  and blast shield ahead, the stepped canopy's frame.
- heavy: a Hind style gunship-transport, the pilot's raised bubble. A wide analog
  panel (three rows of round instruments), an overhead switch panel, busy side
  consoles, the gunner's glass nose ahead and below.
- striker: Ka-52 style, side by side, the pilot on the left. A glass cockpit with four
  displays, a head-up display combiner, a centre console with a keypad, two seats.
- mule: Chinook style, side by side, the pilot on the right. A wide panel of five
  displays under a long glare shield, a big overhead console, a flat windscreen of two
  panes, side windows, a centre console with the levers, the door to the cabin behind.

Run:     python tools/blender/make_cockpit.py [scout] [gunship] [heavy] [striker] [mule]
Preview: python tools/blender/make_cockpit.py --preview DIR [class...]

Origin = the pilot's eye (the "eye" empty of the class's exterior model). Objects:
"shell" (everything fixed), "frame" (the canopy frame), "stick" and "collective"
(the game moves them), and "mount_*" empties for the live instruments: gauges (speed,
altitude, boost, heat, rpm, vsi, torque, heading), radar, kills, health, item,
lamp_missile / _overheat / _service / _lock, beacon, sight (the reticle, dead ahead of
the eye), hud, and displays mfd_<page>[_n] (pages: flight, radar, systems). Parts and
conventions: cockpit_parts.py.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import choppa_shared as shared  # noqa: E402
import cockpit_parts as cp  # noqa: E402
from cockpit_parts import Panel, box, cyl, tube, ball  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "choppa")
EYES = {"scout": shared.EYE, "gunship": Vector((0.0, 0.78, 0.82)), "heavy": Vector((0.0, 1.75, 0.68)),
        "striker": Vector((-0.36, 2.0, 0.62)), "mule": Vector((0.42, 3.55, 0.45))}  # The exteriors' "eye" empties.


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cp.MATS.clear()


def lamps_row(panel, x0, y, dx=0.05, out=0.012):
    """The four warning lamps the game lights (missile, overheat, service, lock)."""
    parts = []
    for k, name in enumerate(["missile", "overheat", "service", "lock"]):
        x = x0 + k * dx
        parts.append(panel.disc(x, y, out, 0.017, 0.012, "brass", 16))
        panel.mount("lamp_" + name, x, y, out + 0.013)
    return parts


def ordnance(panel, x, y, out=0.012):
    """The health lamp bar and the loadout plate, one above the other."""
    parts = [panel.box(x, y + 0.035, out, (0.17, 0.012, 0.045), "dark", bevel_width=0.004),
             panel.box(x, y - 0.03, out, (0.17, 0.012, 0.05), "dark", bevel_width=0.004)]
    panel.mount("health", x, y + 0.035, out + 0.014)
    panel.mount("item", x, y - 0.03, out + 0.014)
    return parts


def nixies(panel, x, y, out=0.012):
    parts = [panel.box(x, y, out, (0.11, 0.025, 0.08), "dark", bevel_width=0.006)]
    panel.mount("kills", x, y, out + 0.026)
    return parts


def floor_box(y0, y1, x0, x1, z):
    parts = [box(((x0 + x1) / 2, (y0 + y1) / 2, z - 0.015), (x1 - x0, y1 - y0, 0.03), "dark")]
    for k in range(int((y1 - y0) / 0.12)):  # Anti-slip strips.
        parts.append(box(((x0 + x1) / 2, y0 + 0.06 + k * 0.12, z + 0.002), (x1 - x0 - 0.1, 0.02, 0.004), "rubber"))
    return parts


def wall(x, y0, y1, z0, z1, ribs=4):
    """A side wall of the tub with stringers and a wiring loom along it."""
    parts = [box((x, (y0 + y1) / 2, (z0 + z1) / 2), (0.02, y1 - y0, z1 - z0), "paint")]
    inward = -1 if x > 0 else 1
    for k in range(ribs):
        y = y0 + (k + 0.5) * (y1 - y0) / ribs
        parts.append(box((x + inward * 0.015, y, (z0 + z1) / 2), (0.012, 0.025, z1 - z0), "paint"))
    parts += cp.wiring([(x + inward * 0.03, y0 + 0.05, z0 + 0.12), (x + inward * 0.03, y1 - 0.05, z0 + 0.14)], 3)
    return parts


def reflex_sight(top, arm_x):
    """The gunsight every class flies with: a round glass in a hood ring dead ahead of the
    eye, on a squat lamp housing, held by a bracket arm bolted to the coaming at arm_x.
    It stands just beyond the coaming's top edge `top` and is sized by its distance so it
    looks the same from every seat: the HUD draws the reticle to fit its glass (Hud.SIGHT_ANGLE).
    Places mount_sight at the glass."""
    dist = top.y + 0.03
    ring = 0.077 * dist
    k = ring / 0.046
    house_z = -ring - 0.032 * k
    parts = [cyl((0, dist, top.z - 0.02), (0, dist, house_z), 0.012 * k, "metal", 10)]
    parts.append(cp.prim("cylinder", "dark", location=(0, dist, house_z), vertices=28, radius=0.036 * k,
                         depth=0.03 * k, bevel_width=0.006 * k))
    parts.append(cp.prim("cylinder", "screen", location=(0, dist, house_z + 0.016 * k), vertices=28, radius=0.024 * k,
                         depth=0.003))
    parts.append(cyl((0.03 * k, dist, house_z), (0.046 * k, dist, house_z), 0.009 * k, "metal", 12))  # Brightness knob.
    parts.append(cp.prim("torus", "dark", location=(0, dist, 0.0), rotation=(math.pi / 2, 0, 0), major_radius=ring,
                         minor_radius=0.0045 * k, major_segments=40, minor_segments=8, scale=(1, 1, 2.6)))
    parts.append(cp.prim("cylinder", "glass", location=(0, dist, 0.0), rotation=(math.pi / 2 - 0.3, 0, 0),
                         vertices=32, radius=ring - 0.003, depth=0.002))
    for side in (-1, 1):  # The hood's feet on the housing.
        parts.append(box((side * 0.03 * k, dist, (house_z - ring) / 2 + 0.006), (0.008 * k, 0.02 * k, ring - house_z - 0.03 * k),
                         "dark", rotation=(0, side * -0.6, 0)))
    side = 1 if arm_x > 0 else -1
    parts.append(box((arm_x / 2 + side * 0.02, dist, house_z), (abs(arm_x), 0.018, 0.014), "metal", bevel_width=0.003))
    parts.append(box((arm_x, dist, (house_z + top.z) / 2), (0.03, 0.03, house_z - top.z + 0.03), "dark", bevel_width=0.004))
    for f in (0.25, 0.6, 0.95):  # Bolts along the arm.
        parts.append(cyl((arm_x * f, dist - 0.012, house_z), (arm_x * f, dist - 0.018, house_z), 0.006, "metal", 8))
    cp.empty("mount_sight", (0, dist, 0.0))
    return parts


def roof_cap(c, r, e_top, material="paint"):
    """The solid roof of a canopy: the cap of its ellipsoid above elevation e_top, seen
    from inside, so the frame has something to end in."""
    import bmesh
    bm = bmesh.new()
    sides, rings = 36, 6
    grid = []
    for i in range(rings):
        e = e_top + (math.pi / 2 - e_top) * i / rings
        grid.append([bm.verts.new(cp.ell(c, r, 2 * math.pi * k / sides, e)) for k in range(sides)])
    top = bm.verts.new(cp.ell(c, r, 0.0, math.pi / 2))
    for r0, r1 in zip(grid, grid[1:]):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((r0[k], r0[j], r1[j], r1[k]))
    for k in range(sides):
        bm.faces.new((grid[-1][k], grid[-1][(k + 1) % sides], top))
    roof = cp.mesh_object(bm, "roof", material)
    roof.data.flip_normals()  # mesh_object points them out; the pilot looks at it from inside.
    return roof


def cabin(c, r, e_top, posts, sill=-0.38, sill_from=0.25, bar=0.013, screen=None):
    """A closed canopy frame on the ellipsoid (c, r): a solid roof above e_top with a rail
    round its edge, posts at the azimuths `posts` running from the sill up into that rail
    (none stop in mid-air), and a sill rail down each side from `sill_from` back. With
    `screen`, the windscreen has its own bottom rail at that elevation (just over the
    glare shield) across the front, and the front posts stand on it rather than diving
    into the instrument panel."""
    parts = [roof_cap(c, r, e_top)]
    ring = [cp.ell(c, r, 2 * math.pi * k / 48, e_top) for k in range(49)]
    parts.append(tube(ring, bar * 1.2))
    if screen is not None:
        parts.append(cp.frame_member(c, r, -sill_from, screen, sill_from, screen, bar, 20))
    for a in posts:
        foot = sill + (0.06 if abs(a) < 1.0 else 0.0)
        if screen is not None and abs(a) < sill_from:
            foot = screen
        parts.append(cp.frame_member(c, r, a, foot, a, e_top, bar, 14))
    for side in (-1, 1):
        parts.append(cp.frame_member(c, r, side * sill_from, sill, side * 2.9, sill, bar, 18))
    return parts


def kick_wall(panel, half_w, half_h, floor_z, inset=0.04):
    """Closes the tub under the panel: a wall from the panel's bottom edge down to the
    floor, the panel's width (the exterior is hidden from the seat, so any gap there
    looks straight out at the ground)."""
    edge = panel.at(0, -half_h, -inset)
    top = edge.z + 0.02
    parts = [box((edge.x, edge.y, (top + floor_z) / 2), (half_w * 2 + 0.04, 0.04, top - floor_z), "paint")]
    for k in range(3):  # Stiffening ribs and a wiring duct.
        parts.append(box((edge.x, edge.y - 0.03, floor_z + (k + 1) * (top - floor_z) / 4), (half_w * 2, 0.02, 0.03),
                         "paint"))
    parts.append(box((edge.x, edge.y - 0.05, top - 0.06), (half_w * 1.6, 0.06, 0.06), "dark"))
    return parts


def bulkhead(y, x0, x1, z0, z1):
    parts = [box(((x0 + x1) / 2, y, (z0 + z1) / 2), (x1 - x0, 0.02, z1 - z0), "paint")]
    for k in range(3):
        parts.append(box(((x0 + x1) / 2, y + 0.015, z0 + (k + 1) * (z1 - z0) / 4), (x1 - x0, 0.012, 0.025), "paint"))
    return parts


# --- scout: Little Bird --------------------------------------------------------------

def build_scout():
    eye = EYES["scout"]
    shell, frame = [], []
    panel = Panel((0.0, 0.64, -0.26), tilt=-30.0)
    hw, hh = 0.44, 0.12
    shell.append(panel.box(0, 0, -0.012, (hw * 2, 0.024, hh * 2), "paint", bevel_width=0.008))
    shell += cp.screws(panel, 0, 0, 0.012, hw - 0.015, hh - 0.012, 0.07)
    shell += cp.hood(panel, 0, hh + 0.012, hw * 2 + 0.02, 0.06, 0.0)
    for (x, y), name in zip([(-0.33, 0.052), (-0.2, 0.052), (-0.33, -0.058), (-0.2, -0.058)],
                            ["speed", "altitude", "boost", "heat"]):
        shell += cp.gauge(panel, name, x, y, 0.05)
    # Centre: the radar scope in its hooded case.
    shell.append(panel.box(0, -0.012, 0.0, (0.22, 0.08, 0.22), "dark", bevel_width=0.02))
    shell.append(panel.ring(0, -0.012, 0.082, 0.092, 0.009, "metal", 40))
    panel.mount("radar", 0, -0.012, 0.086)
    # Right: kill counter, hull bar and loadout, warning lamps, a small clock.
    shell += nixies(panel, 0.2, 0.07)
    shell += ordnance(panel, 0.215, -0.045)
    for k, name in enumerate(["missile", "overheat", "service", "lock"]):
        y = 0.08 - k * 0.05
        shell.append(panel.disc(0.375, y, 0.012, 0.018, 0.012, "brass", 16))
        panel.mount("lamp_" + name, 0.375, y, 0.025)
    panel.mount("beacon", 0.36, hh + 0.04, 0.03)
    # Lower panel angled down to the floor: rotor gauge, vertical speed, torque, the
    # radio stack, two switch rows, breakers.
    low = Panel(panel.at(0, -hh - 0.15, -0.005), tilt=-52.0)
    shell += cp.subpanel(low, 0, 0, hw * 2 - 0.06, 0.3, -0.012)
    shell += cp.gauge(low, "rpm", -0.3, 0.06, 0.045)
    shell += cp.gauge(low, "vsi", -0.3, -0.06, 0.04)
    shell += cp.gauge(low, "torque", -0.19, 0.06, 0.04)
    shell += cp.dummy_gauge(low, -0.19, -0.06, 0.032)
    for k in range(3):  # Radio stack: frequency windows and knobs.
        y = 0.09 - k * 0.06
        shell.append(low.box(0.0, y, 0.0, (0.15, 0.02, 0.045), "dark", bevel_width=0.003))
        shell.append(low.box(-0.025, y, 0.02, (0.07, 0.002, 0.018), "screen"))
        shell += cp.knob(low, 0.05, y, 0.02, 0.009)
    shell += cp.switch_field(low, 0.24, 0.06, 5, 2, 0.032, 0.06, guards={(0, 4)})
    shell += cp.breakers(low, 0.24, -0.1, 7, 2)
    shell += reflex_sight(panel.at(0, hh, 0.0), 0.34)
    # Side consoles with switch fields and breakers.
    for side in (-1, 1):
        shell.append(box((side * 0.56, 0.1, -0.73), (0.22, 0.76, 0.26), "paint", rotation=(0, side * 0.2, 0),
                         bevel_width=0.02))
        top_panel = Panel((side * 0.555, 0.1, -0.598), tilt=-90.0, roll=-side * 11.5)
        shell += cp.switch_field(top_panel, 0, 0.17, 3, 2, 0.04, 0.06)
        shell += cp.breakers(top_panel, 0, -0.06, 4, 3)
        shell += cp.knob(top_panel, -0.05, -0.22, 0.012, 0.016)
        shell += cp.knob(top_panel, 0.05, -0.22, 0.012, 0.016)
    # The tub, floor and seat; the pedestal holding up the panel, the pedals.
    outline = shared.floor_outline(shared.EYE.z - 1.0, 0.06, y_max=1.9)
    xs = [p.x for p in outline]
    shell += floor_box(-0.45, 0.75, min(xs) + 0.1, max(xs) - 0.1, -1.0)
    shell.append(box((0, 0.56, -0.71), (0.2, 0.14, 0.6), "paint", bevel_width=0.015))
    shell += cp.wiring([(0.06, 0.6, -0.42), (0.1, 0.62, -0.7), (0.12, 0.5, -0.98)], 4)
    shell += cp.pedals(0, 0.78, -0.92, 0.17)
    shell += cp.seat(0, -0.05, -0.72, 0.5, 0.62)
    shell += bulkhead(-0.42, -0.62, 0.62, -1.0, 0.22)
    shell += cp.extinguisher(-0.5, -0.25, -0.98, (0, 0, 1))
    shell += cp.compass((-0.36, 0.6, -0.07), hanging=False)  # On the coaming, clear of the view ahead.
    # The canopy frame (the inside of the exterior's members) and the tub walls.
    off = lambda pts: [p - eye for p in pts]  # noqa: E731
    frame.append(tube(off(shared.sill_points(-0.03, 30)), 0.03))
    frame.append(tube(off(shared.roof_points(-0.025, 24)), 0.024))
    frame.append(tube(off(shared.rear_hoop_points(-0.03, 16)), 0.035))
    frame.append(tube(off(shared.chin_points(-0.025, 12)), 0.02))
    for side in (-1, 1):
        frame.append(tube(off(shared.pillar_points(side, -0.025, 8)), 0.024))
    # A strip of breakers along the roof, overhead behind the frame.
    roof = Panel((0, 0.15, 0.42), tilt=70.0)
    shell += cp.breakers(roof, 0, 0, 10, 2)
    shell.append(roof.box(0, 0, -0.012, (0.24, 0.012, 0.07), "paint"))
    shell.append(cyl((0, 0.15, 0.43), (0, 0.55, 0.36), 0.008, "dark", 6))
    finish(shell, frame)
    cp.stick((0, 0.25, -0.98))
    cp.collective((-0.45, -0.25, -0.72))


# --- gunship: tandem, the pilot behind --------------------------------------------------

def build_gunship():
    eye = EYES["gunship"]
    c_pilot, r = Vector((0, 0.75, 0.68)) - eye, (0.36 - 0.03, 0.95 - 0.03, 0.42 - 0.03)
    c_gunner = Vector((0, 1.75, 0.42)) - eye
    shell, frame = [], []
    # Instrument panel under the glare hood: two MFDs, standby gauges below.
    panel = Panel((0.0, 0.46, -0.27), tilt=-30.0)
    shell += cp.subpanel(panel, 0, 0, 0.6, 0.36, -0.012)
    shell += kick_wall(panel, 0.3, 0.18, -1.05)
    shell += cp.hood(panel, 0, 0.19, 0.62, 0.12, 0.0)
    shell += cp.mfd(panel, "flight", -0.15, 0.04, 0.15)
    shell += cp.mfd(panel, "radar", 0.15, 0.04, 0.15)
    shell += cp.gauge(panel, "speed", -0.22, -0.135, 0.03)
    shell += cp.gauge(panel, "altitude", -0.145, -0.135, 0.03)
    shell += cp.gauge(panel, "rpm", 0.145, -0.135, 0.03)
    shell += cp.gauge(panel, "heat", 0.22, -0.135, 0.03)
    shell += ordnance(panel, 0.0, -0.13)
    shell += lamps_row(panel, -0.075, 0.2, 0.05, 0.075)
    panel.mount("beacon", 0.25, 0.2, 0.09)
    shell += nixies(Panel(panel.at(0.2, 0.225, 0.04), tilt=-55.0), 0.0, 0.0)
    shell += cp.wiring([(0.2, 0.5, -0.5), (0.25, 0.45, -0.75), (0.28, 0.2, -0.95)], 4)
    shell += reflex_sight(panel.at(0, 0.18, 0.0), 0.3)
    cp.empty("mount_hud", (0, 0.9, 0.0))  # The helmet symbology floats further out.
    # Ahead and below: the gunner's blast shield, his seat back and helmet rest.
    shell += cp.seat(0, 0.95, -0.98, 0.42, 0.62, armoured=True, harness=False)
    # The gunner up front: the top of his helmet and its sight mount over the glare shield.
    shell.append(ball((0, 0.98, -0.1), 0.14, "dark", scale=(1.0, 1.1, 0.85), segments=16, rings=8))
    shell.append(box((0.1, 1.04, -0.07), (0.05, 0.08, 0.06), "metal", bevel_width=0.01))
    shell.append(cyl((0.1, 1.08, -0.07), (0.1, 1.14, -0.1), 0.012, "dark", 8))
    # Narrow tub: walls, consoles on both sides, floor, seat, pedals.
    for side in (-1, 1):
        shell += wall(side * 0.31, -0.55, 0.45, -1.05, -0.24, 5)
        shell.append(box((side * 0.25, -0.05, -0.58), (0.1, 0.7, 0.18), "paint", bevel_width=0.012))
        top = Panel((side * 0.25, -0.05, -0.488), tilt=-90.0, roll=-side * 18.0)
        shell += cp.switch_field(top, 0, 0.22, 2, 3, 0.035, 0.05, guards={(0, 1)})
        shell += cp.breakers(top, 0, -0.1, 3, 4)
        shell += cp.knob(top, 0, -0.28, 0.012, 0.014)
    shell += cp.keypad(Panel((0.245, 0.15, -0.475), tilt=-75.0, roll=-18.0), 0, 0)
    shell += floor_box(-0.55, 0.45, -0.3, 0.3, -1.05)
    shell += bulkhead(-0.6, -0.31, 0.31, -1.05, 0.22)
    shell += cp.seat(0, -0.08, -0.74, 0.44, 0.7, armoured=True)
    shell += cp.pedals(0, 0.42, -0.95, 0.12)
    shell += cp.extinguisher(-0.24, -0.45, -1.03, (0, 0, 1))
    # The canopy: frame bars on the inside of the pilot's glass and the gunner's.
    # A closed cabin: a solid roof strip, the windscreen corners and door bows running into
    # its rail, a side rail at shoulder height, the gunner's sill ahead.
    frame += cabin(c_pilot, r, 1.1, [-0.9, 0.9, -1.35, 1.35, -2.2, 2.2], sill=-0.18, sill_from=0.2, bar=0.011)
    for side in (-1, 1):
        frame.append(cp.frame_member(c_pilot, r, side * 0.9, 0.45, side * 2.6, 0.45, 0.01))  # Side rail.
        frame.append(cp.frame_member(c_gunner, r, side * 0.2, -0.1, side * 2.4, -0.1, 0.011))
    finish(shell, frame)
    cp.stick((0, 0.18, -1.0))
    cp.collective((-0.27, -0.3, -0.62), 0.38)


# --- heavy: the Hind pilot's bubble ------------------------------------------------------

def build_heavy():
    eye = EYES["heavy"]
    c_pilot, r = Vector((0, 1.75, 0.65)) - eye, (0.6 - 0.03, 0.85 - 0.03, 0.5 - 0.03)
    c_gunner, rg = Vector((0, 2.85, 0.05)) - eye, (0.55 - 0.03, 0.85 - 0.03, 0.5 - 0.03)
    shell, frame = [], []
    panel = Panel((0.0, 0.62, -0.33), tilt=-18.0)
    shell += cp.subpanel(panel, 0, 0, 1.0, 0.42, -0.012)
    shell += kick_wall(panel, 0.5, 0.21, -1.05)
    shell += cp.hood(panel, 0, 0.22, 1.02, 0.1, 0.0)
    # Three rows of round instruments: the six-pack in the middle, engines either side.
    live = {(-0.12, 0.1): "speed", (0.0, 0.1): "heading", (0.12, 0.1): "altitude",
            (-0.12, -0.02): "vsi", (0.12, -0.02): "torque", (-0.36, 0.1): "rpm", (-0.26, 0.1): "boost",
            (0.26, 0.1): "heat"}
    for x in (-0.36, -0.26, -0.12, 0.0, 0.12, 0.26, 0.36):
        for y in (0.1, -0.02, -0.13):
            if (x, y) == (0.0, -0.02):
                continue
            name = live.get((x, y))
            if name:
                shell += cp.gauge(panel, name, x, y, 0.044 if abs(x) < 0.2 else 0.04)
            elif not (abs(x) < 0.05 and y < 0):
                shell += cp.dummy_gauge(panel, x, y, 0.036 if abs(x) < 0.2 else 0.032)
    # A small radar scope in the middle, the kill counter, bar and loadout on the right.
    shell.append(panel.box(0, -0.075, 0.0, (0.11, 0.05, 0.11), "dark", bevel_width=0.01))
    panel.mount("radar", 0, -0.075, 0.052, 0.55)
    shell += nixies(panel, 0.44, 0.1)
    shell += ordnance(panel, 0.44, -0.07)
    shell += cp.annunciators(panel, -0.44, 0.0, 2, 6)
    shell += lamps_row(panel, -0.2, 0.235, 0.06, 0.06)
    panel.mount("beacon", 0.38, 0.235, 0.07)
    shell += reflex_sight(panel.at(0, 0.21, 0.0), 0.36)
    # Overhead panel facing down at the pilot, side consoles crowded with switches.
    over = Panel((0, 0.05, 0.35), tilt=72.0)  # Under the roof.
    shell += cp.subpanel(over, 0, 0, 0.42, 0.26, -0.012)
    shell += cp.switch_field(over, -0.08, 0.05, 6, 2, 0.04, 0.07, guards={(0, 0), (1, 5)})
    shell += cp.breakers(over, 0.0, -0.08, 14, 2)
    shell += cp.dummy_gauge(over, 0.16, 0.06, 0.028)
    for side in (-1, 1):
        shell.append(box((side * 0.48, 0.15, -0.6), (0.2, 0.9, 0.3), "paint", rotation=(0, side * 0.12, 0),
                         bevel_width=0.015))
        top = Panel((side * 0.475, 0.15, -0.448), tilt=-90.0, roll=-side * 7.0)
        shell += cp.switch_field(top, 0, 0.3, 3, 2, 0.045, 0.06)
        shell += cp.breakers(top, 0, 0.08, 5, 3)
        shell += cp.dummy_gauge(top, -0.05, -0.1, 0.03)
        shell += cp.knob(top, 0.05, -0.1, 0.012, 0.016)
        shell += cp.switch_field(top, 0, -0.27, 4, 1, 0.035, 0.05, guards={(0, 3)})
        shell += wall(side * 0.6, -0.7, 0.75, -1.05, -0.3, 6)
    shell += floor_box(-0.7, 0.75, -0.58, 0.58, -1.05)
    shell += bulkhead(-0.72, -0.62, 0.62, -1.05, 0.48)
    shell += cp.seat(0, -0.12, -0.72, 0.52, 0.72, armoured=True)
    shell += cp.pedals(0, 0.62, -0.96, 0.16)
    shell += cp.extinguisher(0.5, -0.55, -1.03, (0, 0, 1))
    shell += cp.wiring([(-0.45, 0.6, -0.5), (-0.5, 0.2, -0.32), (-0.55, -0.6, -0.32)], 5)
    shell += cp.compass((-0.44, 0.6, -0.06), hanging=False)  # On the coaming, clear of the view.
    # A crew's lucky charm on a string from the windscreen frame.
    knot = cp.ell(c_pilot, r, -0.62, 0.6) + Vector((0.01, -0.02, 0))  # On the left windscreen post.
    shell.append(cyl(knot, knot + Vector((0, -0.01, -0.15)), 0.003, "rubber", 4))
    shell.append(box(knot + Vector((0, -0.01, -0.18)), (0.05, 0.012, 0.07), "brass", bevel_width=0.008))
    shell.append(ball(knot + Vector((0, -0.01, -0.13)), 0.012, "hazard", segments=8, rings=4))
    # Ahead and below: the gunner's glazed nose, his headrest and sight.
    shell += cp.seat(0, 1.05, -1.25, 0.46, 0.6, armoured=True, harness=False)
    shell.append(box((0, 1.45, -0.72), (0.12, 0.18, 0.12), "dark", bevel_width=0.01))
    shell.append(cyl((0, 1.45, -0.66), (0, 1.38, -0.52), 0.03, "dark", 12))
    # The pilot's canopy: flat windscreen panes, a post, side blisters, the rear ring.
    # A closed cabin: a solid roof, every post running from the sill into its rail.
    # No centre post: it would stand right in front of the sight. The windscreen sits on
    # its own rail over the glare shield; the side sills start behind the panel.
    frame += cabin(c_pilot, r, 0.95, [-0.62, 0.62, -1.35, 1.35, -2.1, 2.1], sill=-0.38, sill_from=1.0, bar=0.013,
                   screen=-0.15)
    for side in (-1, 1):
        frame.append(cp.frame_member(c_pilot, r, side * 0.18, -0.15, side * 0.32, 0.05, 0.006, 4))  # Wipers.
        frame.append(cp.frame_member(c_gunner, rg, side * 0.5, -0.2, side * 0.4, 1.3, 0.011, 10))
    frame.append(cp.frame_member(c_gunner, rg, 0.0, 0.0, 0.0, 1.4, 0.011, 10))
    frame.append(cp.frame_member(c_gunner, rg, -1.3, 0.1, 1.3, 0.1, 0.011, 16))
    finish(shell, frame)
    cp.stick((0, 0.2, -1.03))
    cp.collective((-0.42, -0.25, -0.66), 0.42)


# --- striker: side by side, glass cockpit -------------------------------------------------

def build_striker():
    eye = EYES["striker"]
    c, r = Vector((0, 2.15, 0.42)) - eye, (0.7 - 0.03, 1.05 - 0.03, 0.5 - 0.03)
    mid = c.x  # The cockpit's centre line, right of the pilot.
    shell, frame = [], []
    panel = Panel((mid, 0.6, -0.3), tilt=-24.0)
    shell += cp.subpanel(panel, 0, 0, 1.24, 0.34, -0.012)
    shell += kick_wall(panel, 0.62, 0.17, -1.05)
    shell += cp.hood(panel, 0, 0.2, 1.26, 0.13, 0.0)
    pilot = -mid  # The pilot's centre line in panel coordinates.
    shell += cp.mfd(panel, "flight", pilot - 0.125, 0.02, 0.16)
    shell += cp.mfd(panel, "radar", pilot + 0.125, 0.02, 0.16)
    shell += cp.mfd(panel, "systems", -pilot - 0.125, 0.02, 0.16)
    shell += cp.mfd(panel, "flight_2", -pilot + 0.125, 0.02, 0.16)
    shell += cp.gauge(panel, "speed", -0.03, 0.08, 0.026)
    shell += cp.gauge(panel, "altitude", -0.03, 0.01, 0.026)
    shell += cp.gauge(panel, "rpm", 0.03, 0.08, 0.026)
    shell += cp.gauge(panel, "heat", 0.03, 0.01, 0.026)
    shell += ordnance(Panel(panel.at(0, -0.1, 0.0), tilt=-24.0), 0, 0)
    # Warning lamps and the beacon off to the left on the glare shield, clear of the sight.
    shell += lamps_row(panel, pilot - 0.36, 0.215, 0.045, 0.06)
    panel.mount("beacon", pilot + 0.32, 0.215, 0.07)
    shell += nixies(Panel(panel.at(-pilot, 0.235, 0.04), tilt=-55.0), 0.0, 0.0)
    shell += cp.annunciators(panel, -0.03, -0.13, 4, 2, 0.022, 0.012)
    shell += reflex_sight(panel.at(pilot, 0.17, 0.0), 0.3)
    cp.empty("mount_hud", (0, 0.62, 0.0))
    # Centre console between the seats: a keypad, throttle levers, switches.
    console = Panel((mid, 0.25, -0.55), tilt=-70.0)
    shell.append(box((mid, 0.22, -0.72), (0.24, 0.6, 0.36), "paint", bevel_width=0.015))
    shell += cp.keypad(console, 0, 0.09)
    shell += cp.switch_field(console, 0, -0.12, 4, 2, 0.04, 0.06, guards={(0, 0)})
    for side in (-1, 1):
        shell.append(cyl(console.at(side * 0.06, -0.24, 0.0), console.at(side * 0.06, -0.2, 0.09), 0.008, "metal", 8))
        shell.append(ball(console.at(side * 0.06, -0.2, 0.095), 0.016, "dark", segments=10, rings=5))
    # Two seats (ejection seats with tall head boxes), walls, floor, side consoles.
    for x in (0.0, 2 * mid):
        shell += cp.seat(x, -0.1, -0.74, 0.46, 0.78, armoured=True)
        shell.append(box((x, -0.37, -0.0), (0.3, 0.12, 0.14), "dark", bevel_width=0.01))
        shell += cp.pedals(x, 0.62, -0.96, 0.13)
    for x, side in ((-0.4, -1), (2 * mid + 0.4, 1)):
        shell += wall(x, -0.65, 0.8, -1.05, -0.28, 6)
        shell.append(box((x - side * 0.08, -0.05, -0.6), (0.12, 0.7, 0.2), "paint", bevel_width=0.012))
        top = Panel((x - side * 0.08, -0.05, -0.497), tilt=-90.0, roll=-side * 15.0)
        shell += cp.switch_field(top, 0, 0.2, 2, 2, 0.04, 0.06)
        shell += cp.breakers(top, 0, -0.07, 3, 4)
    shell += floor_box(-0.65, 0.8, -0.4, 2 * mid + 0.4, -1.05)
    shell += bulkhead(-0.66, -0.4, 2 * mid + 0.4, -1.05, 0.34)
    shell += cp.extinguisher(-0.33, -0.55, -1.03, (0, 0, 1))
    shell += cp.wiring([(mid, 0.55, -0.5), (mid + 0.05, 0.4, -0.85), (mid, 0.0, -1.0)], 5)
    # The cabin: a solid roof over both seats, thin posts (windscreen centre and corners,
    # the door bows, the rear posts) each running from the sill into the roof rail.
    frame += cabin(c, r, 1.0, [0.0, -0.95, 0.95, -1.6, 1.6, -2.45, 2.45])
    finish(shell, frame)
    cp.stick((0, 0.2, -1.03))
    cp.stick((2 * mid, 0.2, -1.03), "stick_copilot")
    cp.collective((-0.32, -0.3, -0.66), 0.4)


def finish(shell, frame):
    cp.join(shell, "shell")
    cp.join(frame, "frame")


# --- mule: tandem-rotor transport, side by side ------------------------------------------

def build_mule():
    mid = -0.42  # The cockpit's centre line, left of the pilot.
    co = 2 * mid  # The copilot.
    shell, frame = [], []
    panel = Panel((mid, 0.62, -0.32), tilt=-22.0)
    shell += cp.subpanel(panel, 0, 0, 1.5, 0.34, -0.012)
    shell += kick_wall(panel, 0.75, 0.17, -1.05)
    shell += cp.hood(panel, 0, 0.2, 1.52, 0.14, 0.0)
    pilot = -mid
    shell += cp.mfd(panel, "flight", pilot - 0.12, 0.02, 0.15)
    shell += cp.mfd(panel, "radar", pilot + 0.12, 0.02, 0.15)
    shell += cp.mfd(panel, "systems", 0.0, 0.02, 0.15)
    shell += cp.mfd(panel, "flight_2", -pilot - 0.12, 0.02, 0.15)
    shell += cp.mfd(panel, "radar_2", -pilot + 0.12, 0.02, 0.15)
    for k, name in enumerate(["speed", "altitude", "rpm", "heat"]):
        shell += cp.gauge(panel, name, -0.09 + k * 0.06, -0.135, 0.024)
    shell += cp.annunciators(panel, pilot, -0.14, 6, 1, 0.024, 0.012)
    shell += cp.annunciators(panel, -pilot, -0.14, 6, 1, 0.024, 0.012)
    shell += lamps_row(panel, pilot - 0.075, 0.215, 0.05, 0.085)
    panel.mount("beacon", pilot + 0.2, 0.215, 0.095)
    shell += nixies(Panel(panel.at(0.0, 0.235, 0.05), tilt=-55.0), 0.0, 0.0)
    shell += ordnance(Panel(panel.at(-0.3, 0.235, 0.05), tilt=-55.0), 0.0, 0.0)
    shell += reflex_sight(panel.at(pilot, 0.17, 0.0), -0.3)
    cp.empty("mount_hud", (0, 0.9, 0.0))
    # The overhead console: switch fields and breakers across the roof.
    over = Panel((mid, 0.05, 0.47), tilt=74.0)
    shell += cp.subpanel(over, 0, 0, 0.9, 0.36, -0.012)
    shell += cp.switch_field(over, -0.25, 0.08, 6, 2, 0.04, 0.07, guards={(0, 0), (0, 5)})
    shell += cp.switch_field(over, 0.25, 0.08, 6, 2, 0.04, 0.07, guards={(1, 2)})
    shell += cp.breakers(over, 0, -0.1, 30, 2)
    for x in (-0.38, 0.38):
        shell += cp.dummy_gauge(over, x, 0.1, 0.028)
    shell.append(box((mid, 0.0, 0.56), (1.5 - 2 * mid, 1.4, 0.04), "paint"))  # Ceiling, wall to wall.
    # Centre console with the thrust levers and a keypad.
    console = Panel((mid, 0.25, -0.56), tilt=-70.0)
    shell.append(box((mid, 0.2, -0.75), (0.28, 0.65, 0.4), "paint", bevel_width=0.015))
    shell += cp.keypad(console, 0, 0.1)
    shell += cp.switch_field(console, 0, -0.12, 5, 2, 0.04, 0.06)
    for side in (-1, 1):
        shell.append(cyl(console.at(side * 0.07, -0.25, 0.0), console.at(side * 0.07, -0.21, 0.1), 0.009, "metal", 8))
        shell.append(box(console.at(side * 0.07, -0.21, 0.105), (0.05, 0.03, 0.025), "dark", bevel_width=0.006))
    # Seats, pedals, walls with side consoles, floor, the bulkhead with a door behind.
    for x in (0.0, co):
        shell += cp.seat(x, -0.1, -0.74, 0.5, 0.72)
        shell += cp.pedals(x, 0.72, -0.96, 0.14)
    for x, side in ((co - 0.73, -1), (0.73, 1)):
        shell += wall(x, -0.7, 0.85, -1.05, -0.33, 6)
        shell.append(box((x - side * 0.09, -0.05, -0.62), (0.14, 0.75, 0.22), "paint", bevel_width=0.012))
        top = Panel((x - side * 0.09, -0.05, -0.507), tilt=-90.0, roll=-side * 12.0)
        shell += cp.switch_field(top, 0, 0.2, 2, 2, 0.045, 0.06)
        shell += cp.breakers(top, 0, -0.08, 3, 5)
    shell += floor_box(-0.7, 0.85, co - 0.73, 0.73, -1.05)
    for x0, x1 in ((co - 0.73, mid - 0.32), (mid + 0.32, 0.73)):
        shell += bulkhead(-0.72, x0, x1, -1.05, 0.55)
    shell.append(box((mid, -0.72, 0.42), (0.64, 0.03, 0.26), "paint"))  # Over the door.
    shell.append(box((mid, -0.76, -0.25), (0.62, 0.03, 1.6), "dark", bevel_width=0.01))  # The door to the cabin, shut.
    for z in (-0.6, 0.1):
        shell.append(box((mid, -0.74, z), (0.5, 0.02, 0.02), "metal"))
    shell.append(box((mid + 0.22, -0.735, -0.2), (0.03, 0.04, 0.14), "metal"))  # Handle.
    shell += cp.extinguisher(0.62, -0.6, -1.03, (0, 0, 1))
    shell += cp.wiring([(mid, 0.6, -0.48), (mid + 0.05, 0.45, -0.85), (mid, 0.0, -1.0)], 5)
    shell += cp.compass((mid, 0.62, 0.3))  # Hung from the windscreen header.
    # The windscreen: two flat panes, three posts, rails top and bottom (on the edges of
    # the exterior's panes, so nothing pokes out of the nose); side windows.
    top_y, top_z, low_y, low_z = 0.64, 0.2, 1.0, -0.19
    for x in (co - 0.21, mid, 0.21):
        frame.append(tube([(x, low_y, low_z), (x, top_y, top_z)], 0.018 if x == mid else 0.015))
    for y, z in ((top_y, top_z), (low_y, low_z)):
        frame.append(tube([(co - 0.22, y, z), (0.22, y, z)], 0.015))
    for x in (co - 0.71, 0.71):
        for y0, z0, y1, z1 in ((-0.3, -0.33, 0.7, -0.33), (-0.3, 0.2, 0.7, 0.2), (-0.3, -0.33, -0.3, 0.2),
                               (0.7, -0.33, 0.7, 0.2)):
            frame.append(tube([(x, y0, z0), (x, y1, z1)], 0.014))
    # Close the cabin round the ceiling: a header over the windscreen, the walls above
    # and behind the side windows (no sky between the glass and the roof).
    shell.append(box((mid, (top_y + 0.7) / 2 + 0.01, (top_z + 0.56) / 2), (1.5 - 2 * mid, 0.04, 0.56 - top_z + 0.02), "paint"))
    for x in (co - 0.73, 0.73):
        shell.append(box((x, 0.0, (0.2 + 0.56) / 2), (0.02, 1.4, 0.38), "paint"))  # Over the window.
        shell.append(box((x, -0.5, (-0.33 + 0.2) / 2), (0.02, 0.4, 0.55), "paint"))  # Behind it.
        shell.append(box((x, 0.78, (-0.33 + 0.2) / 2), (0.02, 0.16, 0.55), "paint"))  # Ahead of it.
    finish(shell, frame)
    cp.stick((0, 0.2, -1.03))
    cp.stick((co, 0.2, -1.03), "stick_copilot")
    cp.collective((0.55, -0.3, -0.66), 0.4)


BUILDS = {"scout": build_scout, "gunship": build_gunship, "heavy": build_heavy, "striker": build_striker,
          "mule": build_mule}


def export(name):
    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.abspath(os.path.join(OUT_DIR, "cockpit_%s.glb" % name))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print(f"exported {path} ({tris} triangles)", flush=True)


def preview(directory, name):
    """Cycles stills from the pilot's eye: ahead, down at the panel, round to each side."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    colours = {"paint": (0.25, 0.3, 0.3), "metal": (0.6, 0.6, 0.6), "dark": (0.05, 0.05, 0.05), "brass": (0.7, 0.5, 0.2),
               "rubber": (0.02, 0.02, 0.02), "glass": (0.6, 0.7, 0.8), "fabric": (0.2, 0.2, 0.17),
               "screen": (0.01, 0.02, 0.02), "placard": (0.8, 0.78, 0.7), "lamp_off": (0.3, 0.2, 0.1),
               "hazard": (0.7, 0.1, 0.05)}
    for m in cp.MATS.values():
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colours.get(m.name, (0.5, 0.5, 0.5)), 1)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.75, 1)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.rotation_euler = (0.6, 0.2, 0.8)
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens_unit = "FOV"
    cam.data.angle = math.radians(80)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for view, rot in {"ahead": (90, 0, 0), "down": (62, 0, 0), "left": (75, 0, 55), "right": (75, 0, -55),
                      "up": (130, 0, 0)}.items():
        cam.location = (0, 0, 0)
        cam.rotation_euler = tuple(math.radians(v) for v in rot)
        scene.render.filepath = os.path.join(directory, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath, flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args and args[0] == "--preview":
        for name in args[2:] or list(BUILDS):
            fresh()
            BUILDS[name]()
            preview(args[1], name)
    else:
        for name in args or list(BUILDS):
            fresh()
            BUILDS[name]()
            export(name)
