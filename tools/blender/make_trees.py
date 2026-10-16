"""Builds the conifers, assets/models/trees/trees.glb, and their needle texture,
assets/textures/needles_albedo.png.

Run:     python3 tools/blender/make_trees.py
Preview: python3 tools/blender/make_trees.py --preview DIR

Three pines ("pine_1".."pine_3", about 9-11 m tall at scale 1), each one mesh with two
materials: "bark" (tapered trunk and branches, UVs for the tiling bark texture) and
"needles" (crossed alpha cards of needle sprays along every branch). Card normals
point out of the crown so the foliage shades as one soft volume, not as flat cards.
"""
import math
import os
import random
import sys

import bpy
import bmesh  # Only importable after bpy.
from mathutils import Matrix, Vector

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "models", "trees", "trees.glb")
NEEDLES = os.path.join(ROOT, "assets", "textures", "needles_albedo.png")


def needle_texture(path, size=512):
    """A spray of needles on a twig: stem up the middle, side twigs, needles off them."""
    from PIL import Image, ImageDraw, ImageFilter
    big = size * 2
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rng = random.Random(4)

    def needle_color(t):
        dark, light = (28, 46, 22), (78, 98, 40)
        return tuple(int(d + (l - d) * t) for d, l in zip(dark, light)) + (255,)

    def twig(x0, y0, angle, length, width, depth, fill):
        """Draws one twig with its needles; with fill, only the dark mass behind them."""
        steps = 24
        x, y = x0, y0
        for k in range(steps):
            t = k / steps
            nx = x + math.cos(angle) * length / steps
            ny = y - math.sin(angle) * length / steps
            reach = big * 0.075 * (1.0 - 0.45 * t)
            if fill:
                r = reach * 0.45
                draw.ellipse((x - r, y - r, x + r, y + r), fill=(22, 36, 18, 255))
            else:
                draw.line((x, y, nx, ny), fill=(70, 52, 34, 255), width=max(1, int(width * (1 - t * 0.6))))
            # Needles in pairs, swept toward the tip, shorter near the end.
            for side in (-1, 1):
                for _ in range(2):
                    a = angle + side * math.radians(rng.uniform(40, 75))
                    n = reach * rng.uniform(0.7, 1.0)
                    if not fill:
                        draw.line((x, y, x + math.cos(a) * n, y - math.sin(a) * n),
                                  fill=needle_color(rng.uniform(0.15, 1.0)), width=4)
            x, y = nx, ny
            if depth > 0 and k % 4 == 3:
                side = 1 if (k // 4) % 2 else -1
                twig(x, y, angle + side * math.radians(rng.uniform(30, 45)), length * rng.uniform(0.3, 0.42) * (1 - t * 0.5),
                     width * 0.6, depth - 1, fill)
        for _ in range(8):  # A tuft at the tip.
            a = angle + math.radians(rng.uniform(-40, 40))
            n = big * rng.uniform(0.03, 0.05)
            if not fill:
                draw.line((x, y, x + math.cos(a) * n, y - math.sin(a) * n), fill=needle_color(1.0), width=4)

    for fill in (True, False):  # Same random sequence twice: mass first, needles on top.
        rng.seed(4)
        twig(big / 2, big * 0.98, math.radians(90), big * 0.7, 9, 2, fill)
    image = image.filter(ImageFilter.SMOOTH).resize((size, size), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)


# --- geometry ----------------------------------------------------------------------

class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.normals = {}  # Loop custom normals for the cards, by face index.

    def face(self, verts, uvs, material, normal=None):
        f = self.bm.faces.new([self.bm.verts.new(v) for v in verts])
        f.material_index = material
        f.smooth = True
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        if normal is not None:
            self.normals[len(self.bm.faces) - 1] = normal
        return f

    def tube(self, spine, radii, sides, v_scale=1.5, u_repeat=2.0):
        """Tapered bark tube along spine points; UVs wrap u_repeat times around."""
        rings = []
        normal = None
        for k, p in enumerate(spine):
            t = (spine[min(k + 1, len(spine) - 1)] - spine[max(k - 1, 0)]).normalized()
            normal = t.orthogonal().normalized() if normal is None else (normal - t * normal.dot(t)).normalized()
            b = t.cross(normal)
            rings.append([p + (normal * math.cos(a) + b * math.sin(a)) * radii[k]
                          for a in (2 * math.pi * i / sides for i in range(sides + 1))])
        length = 0.0
        vs = [0.0]
        for a, b in zip(spine, spine[1:]):
            length += (b - a).length
            vs.append(length / v_scale)
        for k in range(len(rings) - 1):
            for i in range(sides):
                u0, u1 = i / sides * u_repeat, (i + 1) / sides * u_repeat
                self.face([rings[k][i], rings[k][i + 1], rings[k + 1][i + 1], rings[k + 1][i]],
                          [(u0, vs[k]), (u1, vs[k]), (u1, vs[k + 1]), (u0, vs[k + 1])], 0)

    def card(self, base, along, across, length, width, normal):
        """Needle card: stem at base, spray growing along `along`."""
        a = along.normalized() * length
        c = across.normalized() * width * 0.5
        self.face([base - c, base + c, base + c + a, base - c + a], [(0, 0), (1, 0), (1, 1), (0, 1)], 1, normal)


def pine(name, seed, height):
    rng = random.Random(seed)
    b = Builder()
    # Trunk: a gently wandering spine, flared at the foot.
    spine, radii = [], []
    steps = 14
    drift = Vector((0, 0, 0))
    for k in range(steps + 1):
        t = k / steps
        drift += Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0))
        spine.append(Vector((drift.x, drift.y, height * t)))
        radii.append(0.3 * (1 - t) ** 1.2 + 0.02 + 0.12 * max(0.0, 0.15 - t) / 0.15)
    b.tube(spine, radii, 10)

    def axis(z):
        k = min(steps, max(0, int(z / height * steps)))
        return Vector((spine[k].x, spine[k].y, z))

    def crown_normal(p, z):
        out = p - axis(z)
        out.z = 0
        return (out.normalized() * 0.8 + Vector((0, 0, 0.6))).normalized()

    # Whorls of branches, long and drooping low, short and lifted near the top.
    z = 1.6 + rng.uniform(0, 0.3)
    yaw0 = rng.uniform(0, math.tau)
    while z < height - 0.7:
        t = z / height
        count = rng.randint(5, 7)
        yaw0 += rng.uniform(0.4, 0.9)
        for k in range(count):
            yaw = yaw0 + math.tau * k / count + rng.uniform(-0.2, 0.2)
            length = (1.0 - t) ** 0.9 * height * 0.33 * rng.uniform(0.8, 1.1) + 0.35
            out = Vector((math.cos(yaw), math.sin(yaw), 0))
            lift = math.radians(-12 + 40 * t)  # Droop low down, reach up near the top.
            start = axis(z)
            pts = []
            for s in range(5):
                f = s / 4
                sag = -0.25 * length * f * f * (1 - t)
                pts.append(start + out * length * f * math.cos(lift) + Vector((0, 0, length * f * math.sin(lift) + sag)))
            b.tube(pts, [0.05 * (1 - f / 1.2) * (0.5 + length / 4) for f in (0, 0.25, 0.5, 0.75, 1)], 5, 0.8, 1.0)
            # Needle cards along the branch: one lying flat, one crossed, both spraying outward.
            cards = max(2, int(length / 0.32))
            side = out.cross(Vector((0, 0, 1)))
            for c in range(cards):
                f = (c + 0.6) / cards
                i = min(3, int(f * 4))
                p = pts[i].lerp(pts[i + 1], f * 4 - i)
                direction = (pts[i + 1] - pts[i]).normalized()
                direction = (direction + side * rng.uniform(-0.5, 0.5) + Vector((0, 0, rng.uniform(-0.1, 0.2)))).normalized()
                size = (0.75 + 0.55 * (1 - t)) * rng.uniform(0.85, 1.15)
                n = crown_normal(p, z)
                flat = direction.cross(Vector((0, 0, 1))).normalized()
                b.card(p - direction * 0.1, direction, flat, size * 0.9, size * 0.8, n)
                upright = (flat * 0.4 + Vector((0, 0, 1))).normalized()
                b.card(p - direction * 0.1, direction, upright, size * 0.8, size * 0.6, n)
        z += rng.uniform(0.38, 0.5)
    # Leader: a few upright sprays on the top.
    top = spine[-1]
    for k in range(4):
        yaw = math.tau * k / 4 + rng.uniform(0, 0.5)
        across = Vector((math.cos(yaw), math.sin(yaw), 0))
        b.card(top - Vector((0, 0, 0.9)), Vector((0, 0, 1)), across, 1.3, 0.55, Vector((0, 0, 1)))

    mesh = bpy.data.meshes.new(name)
    b.bm.to_mesh(mesh)
    b.bm.free()
    for m in ("bark", "needles"):
        mesh.materials.append(material(m))
    # Card normals point out of the crown; the bark keeps its own.
    loop_normals = []
    for poly in mesh.polygons:
        n = b.normals.get(poly.index)
        for _ in poly.loop_indices:
            loop_normals.append(n if n is not None else (0.0, 0.0, 0.0))
    mesh.normals_split_custom_set(loop_normals)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


MATS = {}


def material(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nodes = m.node_tree.nodes
        bsdf = nodes["Principled BSDF"]
        if name == "needles":
            tex = nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(os.path.abspath(NEEDLES))
            m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
        else:
            bsdf.inputs["Base Color"].default_value = (0.25, 0.18, 0.12, 1)
        bsdf.inputs["Roughness"].default_value = 0.8
        MATS[name] = m
    return MATS[name]


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    needle_texture(NEEDLES)
    trees = [pine("pine_1", 1, 10.0), pine("pine_2", 2, 9.0), pine("pine_3", 3, 11.0)]
    for k, t in enumerate(trees):
        t.location.x = (k - 1) * 9.0  # Spread out for previews; reset on export.
    return trees


def export(trees):
    for t in trees:
        t.location = (0, 0, 0)
    path = os.path.abspath(OUT)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_image_format="NONE")
    tris = 0
    for t in trees:
        t.data.calc_loop_triangles()
        tris += len(t.data.loop_triangles)
    print(f"exported {path} ({tris} triangles in {len(trees)} trees)", flush=True)


def preview(directory):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 500
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.7, 1)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(55), 0, math.radians(30))
    bpy.context.collection.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=80)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 35
    cam.location = (0, -26, 6)
    cam.rotation_euler = (Vector((0, 0, 4.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(directory, exist_ok=True)
    scene.render.filepath = os.path.join(directory, "trees.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath, flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    trees = build()
    if args and args[0] == "--preview":
        preview(args[1])
    else:
        export(trees)
