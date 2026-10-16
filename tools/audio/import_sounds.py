"""Builds the game's sounds from recorded libraries, as described in recipes.json.

    python tools/audio/import_sounds.py [names...] [--library DIR]

The library folder (e.g. the Sonniss GDC bundles) comes from --library or the
CHOPPA_SFX environment variable; recipe paths are relative to it. Each recipe entry:

    "gun": {
        "takes": [{"file": "Weapons/MG42_close_01.wav", "start": "auto", "length": 0.35}, ...],
        "loudness": -14, "fade_out": 0.03, "highpass": 60
    }

Per take: file, start (seconds, or "auto" for the loudest hit), length (seconds, or
leave out for the rest), pitch, gain_db. Per sound: loudness (gated RMS dBFS),
peak, fade_in, fade_out, highpass, lowpass, loop + crossfade (seamless loops),
channels (1, or 2 for music). One take writes name.wav; several write name_1.wav ..
name_N.wav and the game picks one per play (Sounds.stream). Output goes to
assets/sounds/library/, which git ignores while the repo is public; the game prefers
it over the synthesized stand-ins in assets/sounds/ (make_sounds.py).
"""

import argparse
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import library  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Out of git while the repo is public (the library licence forbids sharing the files);
# the game prefers these over the synthesized stand-ins in assets/sounds.
OUT = os.path.join(ROOT, "assets", "sounds", "library")
RECIPES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "recipes.json")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help="only these sounds (default: every recipe)")
    parser.add_argument("--library", default=os.environ.get("CHOPPA_SFX", ""), help="the sound library folder")
    parser.add_argument("--recipes", default=RECIPES, help="recipe file (default tools/audio/recipes.json)")
    parser.add_argument("--out", default=OUT, help="output folder (default assets/sounds/library)")
    args = parser.parse_args()
    if not args.library or not os.path.isdir(args.library):
        sys.exit("Set --library or CHOPPA_SFX to the sound library folder.")
    with open(args.recipes, encoding="utf-8") as f:
        recipes = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
    names = args.names or sorted(recipes)
    for name in names:
        if name not in recipes:
            sys.exit("no recipe for %s" % name)
        takes = library.render(recipes[name], args.library)
        os.makedirs(args.out, exist_ok=True)
        # Clear the old files first: a sound can go from one take to several and back.
        for old in glob.glob(os.path.join(args.out, name + "*.wav")):
            if re.fullmatch(re.escape(name) + r"(_\d+)?\.wav", os.path.basename(old)):
                os.remove(old)
        if len(takes) == 1:
            library.write_wav(os.path.join(args.out, name + ".wav"), takes[0])
        else:
            for k, take in enumerate(takes):
                library.write_wav(os.path.join(args.out, "%s_%d.wav" % (name, k + 1)), take)
        length = sum(len(t) for t in takes) / library.RATE / len(takes)
        print("%s: %d take(s), %.2f s, %.1f dBFS" % (name, len(takes), length, library.rms_db(takes[0], library.RATE)))
    print("Now re-import in Godot (tools/test.ps1 does it) and listen in the game.")


if __name__ == "__main__":
    main()
