"""Builds the choppa brand set into assets/brand/ (owner 2026-10-17: "the logo is quite
shitty currently"):

- logo_wordmark.svg: CHOPPA in chamfered block letters leaning forward, a rotor blade
  over the top on a mast rising out of the O. Orange; _light and _ink variants.
- logo_mark.svg: the monogram, the same C under the same rotor, on a dark rounded
  square: the app icon. icon.svg (the Godot project icon) is a copy.
- logo_lockup.svg: mark and wordmark side by side.
- PNGs of each in the usual sizes, a Windows icon (icon.ico, 16 to 256 px), a social
  banner (1280x640) and the boot splash, rendered by Godot (tools/brand/raster.gd).

Run:  python tools/brand/make_brand.py
"""
import math
import os
import struct
import subprocess
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "brand")
GODOT = os.environ.get("GODOT") or shutil.which("godot") or r"C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"

ORANGE = "#FF9E33"
ORANGE_DEEP = "#D9731A"
INK = "#121418"
STEEL = "#2A2F36"
LIGHT = "#F0F2F5"

# Letters on a 60 x 100 grid, stroke 22, corners chamfered by 14. Outer outline first,
# then holes (drawn even-odd).
GLYPHS = {
    "C": [[(14, 0), (60, 0), (60, 22), (22, 22), (22, 78), (60, 78), (60, 100), (14, 100), (0, 86), (0, 14)]],
    "H": [[(0, 0), (22, 0), (22, 39), (38, 39), (38, 0), (60, 0), (60, 100), (38, 100), (38, 61), (22, 61), (22, 100),
           (0, 100)]],
    "O": [[(14, 0), (46, 0), (60, 14), (60, 86), (46, 100), (14, 100), (0, 86), (0, 14)],
          [(22, 22), (38, 22), (38, 78), (22, 78)]],
    "P": [[(0, 0), (46, 0), (60, 14), (60, 52), (46, 66), (22, 66), (22, 100), (0, 100)],
          [(22, 22), (38, 22), (38, 44), (22, 44)]],
    "A": [[(0, 100), (0, 14), (14, 0), (46, 0), (60, 14), (60, 100), (38, 100), (38, 66), (22, 66), (22, 100)],
          [(22, 22), (38, 22), (38, 44), (22, 44)]],
}
ADVANCE = 72
LEAN = math.tan(math.radians(12))  # Forward lean: x shifts right as y goes up.


def lean(x, y, base=100.0):
    return x + (base - y) * LEAN, y


def path(polys, dx=0.0, dy=0.0, scale=1.0, base=100.0):
    out = []
    for poly in polys:
        pts = [lean(x, y, base) for x, y in poly]
        out.append("M" + " L".join("%.2f,%.2f" % (dx + px * scale, dy + py * scale) for px, py in pts) + " Z")
    return " ".join(out)


def blade(x0, x1, y, thick, dx=0.0, dy=0.0, scale=1.0):
    """A rotor blade: tapered tips, a little thicker toward the hub."""
    pts = [(x0, y + thick * 0.5), (x0 + 10, y), (x1 - 10, y), (x1, y + thick * 0.5), (x1 - 10, y + thick),
           (x0 + 10, y + thick)]
    return path([pts], dx, dy, scale, y + thick)  # Level: the lean is for the letters.


def wordmark(fill, rotor=None):
    """CHOPPA under its rotor. Returns (svg body, width, height) in a 0..W x 0..H box."""
    rotor = rotor or fill
    top = 38.0  # Room for the rotor above the letters.
    parts = []
    for k, ch in enumerate("CHOPPA"):
        parts.append('<path fill="%s" fill-rule="evenodd" d="%s"/>' % (fill, path(GLYPHS[ch], 8 + k * ADVANCE, top)))
    hub = 8 + 2 * ADVANCE + 30 + (100 - 0) * LEAN  # Over the top of the O.
    parts.append('<path fill="%s" d="%s"/>' % (rotor, path([[(hub - 7, 8), (hub + 7, 8), (hub + 7, 38), (hub - 7, 38)]],
                                                              0, 0, 1.0, 38.0)))
    parts.append('<path fill="%s" d="%s"/>' % (rotor, blade(14, 8 + 5 * ADVANCE + 60 + 100 * LEAN - 6, 0, 12, 0, 0)))
    parts.append('<circle cx="%.2f" cy="6" r="9" fill="%s"/>' % (hub + 8 * LEAN, rotor))
    width = 8 + 6 * ADVANCE + 100 * LEAN + 8
    return "\n  ".join(parts), width, top + 100 + 4


def svg(body, w, h, view=None):
    view = view or "0 0 %.2f %.2f" % (w, h)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s">\n  %s\n</svg>\n'
            % (round(w), round(h), view, body))


def mark(size=512):
    """The monogram on its tile: a dark rounded square, the C under the rotor, a thin
    orange keyline."""
    s = size / 100.0
    body = ['<rect width="%d" height="%d" rx="%.1f" fill="%s"/>' % (size, size, 22 * s, INK),
            '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="none" stroke="%s" stroke-width="%.1f" '
            'stroke-opacity="1"/>' % (3.5 * s, 3.5 * s, 93 * s, 93 * s, 18.5 * s, ORANGE, 1.4 * s)]
    # The C, 60 x 100 scaled to 0.56, its top centre right under the hub in the middle.
    g = 0.56 * s
    hub_x = 50 * s
    cy = 36 * s
    cx = hub_x - 30 * g - 100 * LEAN * g
    body.append('<path fill="%s" d="%s"/>' % (ORANGE, path(GLYPHS["C"], cx, cy, g)))
    # Rotor: a blade across the tile, the mast down to the C.
    body.append('<path fill="%s" d="%s"/>' % (LIGHT, path([[(-6, 0), (6, 0), (6, 14), (-6, 14)]], hub_x, cy - 14 * g, g,
                                                            14)))
    body.append('<path fill="%s" d="%s"/>' % (LIGHT, blade(-70, 70, 0, 13, hub_x, cy - 24 * g, g)))
    body.append('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (hub_x + 3 * g, cy - 17.5 * g, 8 * g, LIGHT))
    return "\n  ".join(body)


def write(name, text):
    with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def ico(pngs, target):
    """A Windows .ico holding PNG images (Vista and later read PNG entries)."""
    data = [open(p, "rb").read() for _, p in pngs]
    header = struct.pack("<HHH", 0, 1, len(pngs))
    offset = 6 + 16 * len(pngs)
    entries = b""
    for (size, _), blob in zip(pngs, data):
        dim = 0 if size >= 256 else size
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    with open(target, "wb") as f:
        f.write(header + entries + b"".join(data))


def main():
    os.makedirs(OUT, exist_ok=True)
    for variant, fill, rotor in (("", ORANGE, LIGHT), ("_light", LIGHT, LIGHT), ("_ink", INK, INK),
                                 ("_orange", ORANGE, ORANGE)):
        body, w, h = wordmark(fill, rotor)
        write("logo_wordmark%s.svg" % variant, svg(body, w, h + 4, "0 -4 %.2f %.2f" % (w, h + 4)))
    write("logo_mark.svg", svg(mark(512), 512, 512))
    shutil.copyfile(os.path.join(OUT, "logo_mark.svg"), os.path.join(ROOT, "icon.svg"))
    # Lockup: the mark, then the wordmark beside it (for dark backgrounds).
    body, w, h = wordmark(ORANGE, LIGHT)
    lockup = ['<g transform="translate(0,4) scale(%.4f)">%s</g>' % (142 / 512, mark(512)),
              '<g transform="translate(170,4)">%s</g>' % body]
    write("logo_lockup.svg", svg("\n  ".join(lockup), 170 + w, h + 8))
    # Social banner and boot splash: dark field, the wordmark, a hairline and the tagline.
    for name, (bw, bh, scale) in {"banner": (1280, 640, 1.9), "splash": (1920, 1080, 2.4)}.items():
        body, w, h = wordmark(ORANGE, LIGHT)
        x, y = (bw - w * scale) / 2, (bh - h * scale) / 2 - 40
        parts = ['<rect width="%d" height="%d" fill="%s"/>' % (bw, bh, INK),
                 '<rect y="%d" width="%d" height="%d" fill="%s"/>' % (bh - 6, bw, 6, ORANGE),
                 '<g transform="translate(%.1f,%.1f) scale(%.2f)">%s</g>' % (x, y, scale, body),
                 '<rect x="%.1f" y="%.1f" width="%.1f" height="3" fill="%s"/>' % (bw / 2 - 160, y + h * scale + 28, 320,
                                                                                ORANGE)]
        write("%s.svg" % name, svg("\n  ".join(parts), bw, bh))
    # PNGs through Godot's SVG renderer.
    jobs = [("logo_mark.svg", "logo_mark_%d.png" % s, s / 512) for s in (16, 24, 32, 48, 64, 128, 256, 512, 1024)]
    jobs += [("logo_wordmark%s.svg" % v, "logo_wordmark%s.png" % v, 2048 / wordmark(ORANGE)[1])
             for v in ("", "_light", "_ink", "_orange")]
    jobs += [("logo_lockup.svg", "logo_lockup.png", 3.0), ("banner.svg", "banner.png", 1.0),
             ("splash.svg", "splash.png", 1.0)]
    listing = os.path.join(OUT, ".raster_jobs.txt")
    with open(listing, "w", encoding="utf-8") as f:
        for src, dst, scale in jobs:
            f.write("%s|%s|%.5f\n" % (os.path.join(OUT, src), os.path.join(OUT, dst), scale))
    subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://tools/brand/raster.gd", "--", listing],
                   check=True, stdout=subprocess.DEVNULL)
    os.remove(listing)
    # Taglines in Barlow (the SVG renderer has no fonts): drawn on with ffmpeg.
    ffmpeg = shutil.which("ffmpeg") or os.path.expanduser(r"~\scoop\shims\ffmpeg.exe")
    font = os.path.join(ROOT, "assets", "fonts", "BarlowCondensed-Medium.ttf").replace("\\", "/").replace(":", r"\:")
    for name, size, y in (("banner", 34, 0.73), ("splash", 44, 0.73)):
        png = os.path.join(OUT, name + ".png")
        tmp = os.path.join(OUT, name + "_tmp.png")
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", png, "-vf",
                        "drawtext=fontfile='%s':text='HELICOPTER ARENA COMBAT':fontsize=%d:fontcolor=0xC9CED4:"
                        "x=(w-tw)/2:y=h*%.2f" % (font, size, y), tmp], check=True)
        os.replace(tmp, png)
    ico([(s, os.path.join(OUT, "logo_mark_%d.png" % s)) for s in (16, 24, 32, 48, 64, 128, 256)],
        os.path.join(OUT, "icon.ico"))
    print("brand set written to", OUT)


if __name__ == "__main__":
    main()
