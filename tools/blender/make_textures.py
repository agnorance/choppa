"""Bakes the tileable PBR textures in assets/textures with Blender's Cycles.

Run:  python3 tools/blender/make_textures.py [name ...] [--size 1024]

Every material is a procedural node tree. To make it tile seamlessly, the plane's UV
(u, v) is wrapped onto a torus in 4D, (cos 2πu, sin 2πu, cos 2πv, sin 2πv), and all
noise/voronoi nodes sample that 4D point. Baked outputs: <name>_albedo.png,
<name>_normal.png (OpenGL tangent space), <name>_rough.png.
"""
import math
import os
import sys

import bpy

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures")


class Tree:
    """Small helper to build a node tree in code."""

    def __init__(self, material):
        self.nt = material.node_tree
        self.nt.nodes.clear()
        self.n = self.nt.nodes
        self.l = self.nt.links
        self._torus()

    def node(self, kind, **props):
        nd = self.n.new(kind)
        for key, value in props.items():
            if key.startswith("in_"):
                nd.inputs[key[3:].replace("_", " ")].default_value = value
            else:
                setattr(nd, key, value)
        return nd

    def link(self, a, b):
        self.l.new(a, b)

    def _torus(self):
        """Builds the 4D torus coordinate: self.p (vector xyz) and self.w (float)."""
        uv = self.node("ShaderNodeTexCoord")
        sep = self.node("ShaderNodeSeparateXYZ")
        self.link(uv.outputs["UV"], sep.inputs[0])

        def trig(src, op, scale=1.0):
            m = self.node("ShaderNodeMath", operation="MULTIPLY", in_Value=0.0)
            m.inputs[1].default_value = 2 * math.pi
            self.link(src, m.inputs[0])
            t = self.node("ShaderNodeMath", operation=op)
            self.link(m.outputs[0], t.inputs[0])
            return t.outputs[0]

        cu, su = trig(sep.outputs["X"], "COSINE"), trig(sep.outputs["X"], "SINE")
        cv, sv = trig(sep.outputs["Y"], "COSINE"), trig(sep.outputs["Y"], "SINE")
        comb = self.node("ShaderNodeCombineXYZ")
        self.link(cu, comb.inputs[0])
        self.link(su, comb.inputs[1])
        self.link(cv, comb.inputs[2])
        self.p = comb.outputs[0]
        self.w = sv
        # A torus with a fatter u-circle: features come out squeezed along u, i.e.
        # long streaks running along v (fibres, grass blades).
        scaled = self.node("ShaderNodeVectorMath", operation="MULTIPLY")
        scaled.inputs[1].default_value = (5.0, 5.0, 1.0)
        self.link(comb.outputs[0], scaled.inputs[0])
        self.p_streak = scaled.outputs[0]
        # Plain v (0..1) too, for straight horizontal bands such as rock strata.
        self.v = sep.outputs["Y"]
        self.u = sep.outputs["X"]

    def noise(self, scale, detail=8.0, rough=0.55, distortion=0.0, offset=0.0, kind="FBM", streak=False):
        """4D noise; scale is in whole-tile periods (approx features per tile / 2)."""
        nd = self.node("ShaderNodeTexNoise", noise_dimensions="4D", noise_type=kind)
        nd.inputs["Scale"].default_value = scale
        nd.inputs["Detail"].default_value = detail
        nd.inputs["Roughness"].default_value = rough
        nd.inputs["Distortion"].default_value = distortion
        self.link(self.p_streak if streak else self.p, nd.inputs["Vector"])
        if offset:
            add = self.node("ShaderNodeMath", operation="ADD")
            add.inputs[1].default_value = offset
            self.link(self.w, add.inputs[0])
            self.link(add.outputs[0], nd.inputs["W"])
        else:
            self.link(self.w, nd.inputs["W"])
        return nd

    def voronoi(self, scale, feature="F1", metric="EUCLIDEAN", rand=1.0, streak=False):
        nd = self.node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", feature=feature, distance=metric)
        nd.inputs["Scale"].default_value = scale
        nd.inputs["Randomness"].default_value = rand
        self.link(self.p_streak if streak else self.p, nd.inputs["Vector"])
        self.link(self.w, nd.inputs["W"])
        return nd

    def ramp(self, src, stops):
        """stops: [(pos, (r, g, b))...]"""
        r = self.node("ShaderNodeValToRGB")
        cr = r.color_ramp
        while len(cr.elements) > 1:
            cr.elements.remove(cr.elements[-1])
        cr.elements[0].position = stops[0][0]
        cr.elements[0].color = (*stops[0][1], 1.0)
        for pos, col in stops[1:]:
            e = cr.elements.new(pos)
            e.color = (*col, 1.0)
        self.link(src, r.inputs[0])
        return r.outputs[0]

    def math(self, op, a, b=None, clamp=False):
        m = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        for idx, val in enumerate([a, b]):
            if val is None:
                continue
            if isinstance(val, (int, float)):
                m.inputs[idx].default_value = val
            else:
                self.link(val, m.inputs[idx])
        return m.outputs[0]

    def mix(self, a, b, fac, mode="MIX"):
        m = self.node("ShaderNodeMix", data_type="RGBA", blend_type=mode)
        if isinstance(fac, (int, float)):
            m.inputs["Factor"].default_value = fac
        else:
            self.link(fac, m.inputs["Factor"])
        for slot, val in (("A", a), ("B", b)):
            if isinstance(val, tuple):
                m.inputs[slot].default_value = (*val, 1.0)
            else:
                self.link(val, m.inputs[slot])
        return m.outputs["Result"]

    def output(self, color, rough, height, bump_strength=1.0, bump_distance=0.02):
        """Emission carries the albedo for baking; the BSDF carries bump and roughness."""
        bsdf = self.node("ShaderNodeBsdfPrincipled")
        bump = self.node("ShaderNodeBump")
        bump.inputs["Strength"].default_value = bump_strength
        bump.inputs["Distance"].default_value = bump_distance
        self.link(height, bump.inputs["Height"])
        self.link(bump.outputs["Normal"], bsdf.inputs["Normal"])
        self.link(color, bsdf.inputs["Base Color"])
        if isinstance(rough, (int, float)):
            bsdf.inputs["Roughness"].default_value = rough
        else:
            self.link(rough, bsdf.inputs["Roughness"])
        self.color, self.rough, self.bsdf = color, rough, bsdf
        out = self.node("ShaderNodeOutputMaterial")
        self.out = out
        self.link(bsdf.outputs[0], out.inputs["Surface"])


# ---- materials ------------------------------------------------------------------

def sandstone(t):
    # Wavy horizontal strata: distort v with low-frequency noise, then band it.
    warp = t.noise(1.5, detail=3, rough=0.5)
    wv = t.math("ADD", t.v, t.math("MULTIPLY", warp.outputs["Fac"], 0.12))
    bands = t.math("SINE", t.math("MULTIPLY", wv, 2 * math.pi * 7))
    fine = t.math("SINE", t.math("MULTIPLY", wv, 2 * math.pi * 29))
    layered = t.math("ADD", t.math("MULTIPLY", bands, 0.6), t.math("MULTIPLY", fine, 0.25))
    grain = t.noise(40, detail=10, rough=0.7)
    blotch = t.noise(3, detail=6, rough=0.6, offset=3.0)
    cracks = t.voronoi(2.2, feature="DISTANCE_TO_EDGE")
    crack = t.math("LESS_THAN", cracks.outputs["Distance"], 0.012)
    tone = t.math("ADD", t.math("MULTIPLY", layered, 0.25), t.math("MULTIPLY", blotch.outputs["Fac"], 0.8))
    col = t.ramp(tone, [
        (0.15, (0.42, 0.18, 0.09)), (0.4, (0.62, 0.32, 0.17)), (0.6, (0.74, 0.45, 0.26)),
        (0.85, (0.86, 0.62, 0.42)),
    ])
    col = t.mix(col, t.ramp(grain.outputs["Fac"], [(0.3, (0.25, 0.12, 0.06)), (0.7, (1.0, 0.9, 0.8))]), 0.18, "OVERLAY")
    col = t.mix(col, (0.18, 0.08, 0.04), t.math("MULTIPLY", crack, 0.85))
    height = t.math("ADD", t.math("MULTIPLY", layered, 0.5), t.math("MULTIPLY", grain.outputs["Fac"], 0.08))
    height = t.math("SUBTRACT", height, t.math("MULTIPLY", crack, 0.4))
    rough = t.math("ADD", 0.82, t.math("MULTIPLY", grain.outputs["Fac"], 0.15))
    t.output(col, rough, height, 1.0, 0.012)


def rock(t):
    big = t.voronoi(4, feature="F1", rand=1.0)
    edges = t.voronoi(4, feature="DISTANCE_TO_EDGE")
    grain = t.noise(30, detail=12, rough=0.7)
    stain = t.noise(2.5, detail=5, rough=0.6, offset=7.0)
    facets = t.math("MULTIPLY", edges.outputs["Distance"], 4.0, clamp=True)
    tone = t.math("ADD", t.math("MULTIPLY", stain.outputs["Fac"], 0.7), t.math("MULTIPLY", big.outputs["Distance"], 0.4))
    col = t.ramp(tone, [(0.25, (0.22, 0.2, 0.19)), (0.55, (0.4, 0.36, 0.33)), (0.8, (0.55, 0.5, 0.45))])
    col = t.mix(col, t.ramp(grain.outputs["Fac"], [(0.35, (0.2, 0.2, 0.2)), (0.65, (1, 1, 1))]), 0.25, "OVERLAY")
    crack = t.math("LESS_THAN", edges.outputs["Distance"], 0.02)
    col = t.mix(col, (0.08, 0.07, 0.07), t.math("MULTIPLY", crack, 0.9))
    height = t.math("ADD", t.math("MULTIPLY", facets, 0.6), t.math("MULTIPLY", grain.outputs["Fac"], 0.1))
    rough = t.math("ADD", 0.75, t.math("MULTIPLY", grain.outputs["Fac"], 0.2))
    t.output(col, rough, height, 1.0, 0.015)


def grass(t):
    # Clumps of slightly different greens, each made of fine blade streaks, with soil
    # showing through in places.
    patch = t.noise(3, detail=4, rough=0.6)
    clumps = t.voronoi(18, feature="F1", rand=1.0)
    blades = t.noise(14, detail=8, rough=0.75, streak=True)
    blades2 = t.noise(22, detail=8, rough=0.75, offset=9.0, streak=True)
    base = t.ramp(patch.outputs["Fac"], [
        (0.3, (0.13, 0.21, 0.05)), (0.5, (0.2, 0.3, 0.08)), (0.72, (0.33, 0.36, 0.13)),
    ])
    clump_tint = t.ramp(clumps.outputs["Color"], [(0.0, (0.75, 0.8, 0.7)), (1.0, (1.15, 1.1, 0.95))])
    col = t.mix(base, clump_tint, 1.0, "MULTIPLY")
    streaks = t.math("MULTIPLY", blades.outputs["Fac"], blades2.outputs["Fac"])
    col = t.mix(col, t.ramp(streaks, [(0.15, (0.25, 0.25, 0.25)), (0.45, (1.0, 1.0, 1.0))]), 0.45, "OVERLAY")
    soil = t.noise(10, detail=6, rough=0.6, offset=5.0)
    bare = t.math("GREATER_THAN", t.math("ADD", soil.outputs["Fac"], t.math("MULTIPLY", streaks, -0.3)), 0.58)
    col = t.mix(col, (0.25, 0.18, 0.11), t.math("MULTIPLY", bare, 0.85))
    height = t.math("ADD", t.math("MULTIPLY", streaks, 1.2), t.math("MULTIPLY", clumps.outputs["Distance"], -0.3))
    t.output(col, 0.9, height, 1.0, 0.02)


def dirt(t):
    pebbles = t.voronoi(12, feature="F1", rand=0.9)
    pebble_mask = t.math("LESS_THAN", pebbles.outputs["Distance"], 0.45)
    pebble_tone = t.ramp(pebbles.outputs["Color"], [(0.0, (0.3, 0.26, 0.22)), (1.0, (0.6, 0.55, 0.48))])
    grain = t.noise(45, detail=10, rough=0.7)
    clump = t.noise(5, detail=6, rough=0.6, offset=4.0)
    col = t.ramp(clump.outputs["Fac"], [(0.3, (0.27, 0.19, 0.12)), (0.55, (0.42, 0.31, 0.2)), (0.8, (0.55, 0.43, 0.3))])
    col = t.mix(col, t.ramp(grain.outputs["Fac"], [(0.3, (0.3, 0.3, 0.3)), (0.7, (1, 1, 1))]), 0.22, "OVERLAY")
    col = t.mix(col, pebble_tone, t.math("MULTIPLY", pebble_mask, 0.9))
    dome = t.math("SUBTRACT", 0.45, pebbles.outputs["Distance"])
    height = t.math("ADD", t.math("MULTIPLY", t.math("MAXIMUM", dome, 0.0), 2.5), t.math("MULTIPLY", grain.outputs["Fac"], 0.3))
    t.output(col, 0.92, height, 1.0, 0.03)


def sand(t):
    warp = t.noise(2, detail=3, rough=0.5)
    ripple = t.math("SINE", t.math("MULTIPLY", t.math("ADD", t.u, t.math("MULTIPLY", warp.outputs["Fac"], 0.25)), 2 * math.pi * 18))
    grain = t.noise(80, detail=8, rough=0.8)
    tone = t.noise(4, detail=5, rough=0.6, offset=1.0)
    col = t.ramp(tone.outputs["Fac"], [(0.3, (0.62, 0.5, 0.34)), (0.7, (0.8, 0.68, 0.5))])
    col = t.mix(col, t.ramp(grain.outputs["Fac"], [(0.3, (0.4, 0.4, 0.4)), (0.7, (1, 1, 1))]), 0.2, "OVERLAY")
    height = t.math("ADD", t.math("MULTIPLY", ripple, 0.25), t.math("MULTIPLY", grain.outputs["Fac"], 0.2))
    t.output(col, 0.95, height, 0.6, 0.008)


def bark(t):
    # Vertical fibres from streaked noise, broken into plates.
    fibres = t.noise(6, detail=10, rough=0.65, distortion=0.3, streak=True)
    plates = t.voronoi(0.8, feature="DISTANCE_TO_EDGE", streak=True)
    col = t.ramp(fibres.outputs["Fac"], [(0.3, (0.12, 0.08, 0.05)), (0.6, (0.28, 0.19, 0.12)), (0.8, (0.38, 0.28, 0.19))])
    crack = t.math("LESS_THAN", plates.outputs["Distance"], 0.04)
    col = t.mix(col, (0.05, 0.03, 0.02), t.math("MULTIPLY", crack, 0.9))
    height = t.math("SUBTRACT", t.math("MULTIPLY", fibres.outputs["Fac"], 0.5), t.math("MULTIPLY", crack, 0.7))
    t.output(col, 0.9, height, 1.0, 0.03)


MATERIALS = {
    "sandstone": sandstone, "rock": rock, "grass": grass, "dirt": dirt, "sand": sand, "bark": bark,
}


# ---- baking -------------------------------------------------------------------

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    scene.render.bake.margin = 0
    bpy.ops.mesh.primitive_plane_add(size=2.0)
    return bpy.context.active_object


def bake(obj, name, fn, size):
    mat = bpy.data.materials.new(name)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    t = Tree(mat)
    fn(t)
    results = {}
    for kind in ("albedo", "normal", "rough"):
        img = bpy.data.images.new(f"{name}_{kind}", size, size, float_buffer=False)
        if kind != "albedo":
            img.colorspace_settings.name = "Non-Color"
        tex = t.node("ShaderNodeTexImage", image=img)
        t.nt.nodes.active = tex
        scene = bpy.context.scene
        if kind == "albedo":
            # Bake the colour through an emission shader for exact values.
            em = t.node("ShaderNodeEmission")
            t.link(t.color, em.inputs["Color"])
            t.link(em.outputs[0], t.out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT")
        elif kind == "rough":
            em = t.node("ShaderNodeEmission")
            if isinstance(t.rough, (int, float)):
                em.inputs["Color"].default_value = (t.rough, t.rough, t.rough, 1.0)
            else:
                t.link(t.rough, em.inputs["Color"])
            t.link(em.outputs[0], t.out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT")
        else:
            t.link(t.bsdf.outputs[0], t.out.inputs["Surface"])
            scene.render.bake.normal_space = "TANGENT"
            bpy.ops.object.bake(type="NORMAL")
        path = os.path.abspath(os.path.join(OUT, f"{name}_{kind}.png"))
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        results[kind] = path
        print("baked", path, flush=True)
    return results


def main():
    args = sys.argv[1:]
    size = 1024
    if "--size" in args:
        i = args.index("--size")
        size = int(args[i + 1])
        del args[i:i + 2]
    names = args or list(MATERIALS)
    os.makedirs(OUT, exist_ok=True)
    obj = setup_scene()
    for name in names:
        bake(obj, name, MATERIALS[name], size)


if __name__ == "__main__":
    main()
