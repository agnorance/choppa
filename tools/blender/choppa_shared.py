"""Geometry shared by the helicopter exterior (make_choppa.py) and the cockpit interior
(make_cockpit.py), so the canopy frame you see from inside is the one you see outside.

Blender coordinates, model space: +Y is the nose, +Z up, origin at the choppa's centre
(the Godot model origin). The cockpit interior is built relative to EYE.

The cabin is an egg (an ellipsoid). Its glass is the part in front of REAR_Y and above
the sill, a plane that slopes down toward the nose so the windscreen wraps under the
pilot's feet, Little Bird style. Frame members: the sill, two A-pillars, a chin bar
between them, a roof ring and the rear hoop behind the pilot's head. Frame curves are
lists of points `offset` metres off the egg (positive = outside).
"""
import math

from mathutils import Vector

# Pilot's eye in model space (Godot: (0, 0.55, -1.15)).
EYE = Vector((0.0, 1.15, 0.55))

EGG_CENTER = Vector((0.0, 0.9, 0.15))
EGG_RADII = Vector((0.88, 1.5, 1.05))
REAR_Y = 0.72  # The glass ends here, just behind the pilot's head.
SILL_REAR_Z = 0.22  # Sill height at REAR_Y...
SILL_SLOPE = -0.55  # ...dropping this much per metre toward the nose.

PILLAR_AZIMUTH = math.radians(38.0)  # Where the A-pillars stand on the sill (0 = dead ahead).
PILLAR_TOP_AZIMUTH = math.radians(52.0)  # ...and where they meet the roof ring.
ROOF = 0.72  # Roof ring height, as a fraction from the sill (0) to the top of the egg (1).
CHIN = 0.2  # Chin bar between the pillars, same measure.


def sill_z(y):
    return SILL_REAR_Z + (y - REAR_Y) * SILL_SLOPE


def egg_point(azimuth, elevation, offset=0.0):
    """azimuth 0 = forward, + = right; elevation 0 = the egg's equator."""
    d = Vector((math.cos(elevation) * math.sin(azimuth), math.cos(elevation) * math.cos(azimuth),
                math.sin(elevation)))
    p = EGG_CENTER + Vector((d.x * EGG_RADII.x, d.y * EGG_RADII.y, d.z * EGG_RADII.z))
    return p + egg_normal(p) * offset


def egg_normal(p):
    q = p - EGG_CENTER
    return Vector((q.x / EGG_RADII.x ** 2, q.y / EGG_RADII.y ** 2, q.z / EGG_RADII.z ** 2)).normalized()


def is_glass(p):
    return p.y > REAR_Y and p.z > sill_z(p.y)


def _sill_elevation(azimuth):
    """Elevation where this azimuth crosses the sill plane (bisection)."""
    lo, hi = -math.pi / 2, math.pi / 2
    for _ in range(40):
        mid = (lo + hi) / 2
        p = egg_point(azimuth, mid)
        if p.z > sill_z(p.y):
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


def canopy_point(azimuth, height, offset=0.0):
    """Point on the glass: height 0 = on the sill, 1 = the top of the egg."""
    e0 = _sill_elevation(azimuth)
    return egg_point(azimuth, e0 + (math.pi / 2 - e0) * height, offset)


def _rear_azimuth(height):
    """Azimuth (right side) where the curve at this height reaches REAR_Y."""
    lo, hi = 0.0, math.pi
    for _ in range(40):
        mid = (lo + hi) / 2
        if canopy_point(mid, height).y > REAR_Y:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def _band(height, offset, steps, end=None):
    end = _rear_azimuth(height) if end is None else end
    return [canopy_point(-end + 2.0 * end * k / steps, height, offset) for k in range(steps + 1)]


def sill_points(offset=0.0, steps=48):
    """Sill from the rear hoop on the left, under the nose, to the rear hoop on the right."""
    return _band(0.0, offset, steps)


def roof_points(offset=0.0, steps=32):
    """Roof ring: overhead rail in front, running back along the top to the rear hoop."""
    return _band(ROOF, offset, steps)


def chin_points(offset=0.0, steps=16):
    """Chin bar across the lower windscreen, pillar to pillar."""
    end = PILLAR_AZIMUTH + (PILLAR_TOP_AZIMUTH - PILLAR_AZIMUTH) * CHIN / ROOF
    return _band(CHIN, offset, steps, end)


def pillar_points(side, offset=0.0, steps=12):
    """A-pillar from the sill up to the roof ring (side = -1 left, 1 right)."""
    pts = []
    for k in range(steps + 1):
        t = k / steps
        azimuth = side * (PILLAR_AZIMUTH + (PILLAR_TOP_AZIMUTH - PILLAR_AZIMUTH) * t)
        pts.append(canopy_point(azimuth, ROOF * t, offset))
    return pts


def rear_hoop_points(offset=0.0, steps=24):
    """Hoop where the glass ends behind the pilot, sill to sill over the top."""
    s = math.sqrt(1.0 - ((REAR_Y - EGG_CENTER.y) / EGG_RADII.y) ** 2)
    rx, rz = EGG_RADII.x * s, EGG_RADII.z * s
    start = math.asin((SILL_REAR_Z - EGG_CENTER.z) / rz)
    pts = []
    for k in range(steps + 1):
        a = start + (math.pi - 2.0 * start) * k / steps
        x, z = rx * math.cos(a), rz * math.sin(a)
        out = Vector((x / rx ** 2, 0.0, z / rz ** 2)).normalized()
        pts.append(Vector((x, REAR_Y, EGG_CENTER.z + z)) + out * offset)
    return pts


def floor_outline(z, inset=0.04, y_max=1.95, steps=32):
    """Cabin floor at height z: the egg's cross-section there, inset, cut off at y_max."""
    k = 1.0 - ((z - EGG_CENTER.z) / EGG_RADII.z) ** 2
    rx, ry = EGG_RADII.x * math.sqrt(k) - inset, EGG_RADII.y * math.sqrt(k) - inset
    pts = []
    for i in range(steps):
        a = 2 * math.pi * i / steps
        p = Vector((rx * math.cos(a), EGG_CENTER.y + ry * math.sin(a), z))
        p.y = min(p.y, y_max)
        pts.append(p)
    return pts
