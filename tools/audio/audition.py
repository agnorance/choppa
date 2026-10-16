"""Finds candidate recordings for a game sound and renders them to listen to.

    python tools/audio/audition.py gun machine gun --exclude silenced --length 0.4
    python tools/audio/audition.py rotor_loop helicopter --loop --length 4

Searches the library (--library or CHOPPA_SFX) for WAV files whose folder and file
names contain all the words, and writes up to --count of them, cut and levelled the
way the game would use them, to build/audition/<sound>/a.wav, b.wav ... with a
list.txt naming the source of each. Listen in Explorer, then put the ones you like
into recipes.json (list.txt gives the exact path and start).
"""

import argparse
import os
import string
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import library  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def find(root, words, exclude):
    words = [w.lower() for w in words]
    exclude = [w.lower() for w in exclude]
    hits = []
    for folder, _, files in os.walk(root):
        for name in files:
            if not name.lower().endswith(".wav"):
                continue
            rel = os.path.relpath(os.path.join(folder, name), root)
            text = rel.lower().replace("_", " ").replace("-", " ")
            if all(w in text for w in words) and not any(w in text for w in exclude):
                # Words in the file name count more than words only in the folder.
                score = sum(name.lower().count(w) for w in words)
                hits.append((-score, rel))
    return [rel for _, rel in sorted(hits)]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sound", help="the game sound these are for (output folder name)")
    parser.add_argument("words", nargs="+", help="words that must all appear in the path")
    parser.add_argument("--exclude", nargs="*", default=[], help="skip paths with these words")
    parser.add_argument("--library", default=os.environ.get("CHOPPA_SFX", ""))
    parser.add_argument("--count", type=int, default=8)
    parser.add_argument("--length", type=float, default=None, help="seconds to keep (default: all)")
    parser.add_argument("--loop", action="store_true", help="render as a seamless loop")
    parser.add_argument("--loudness", type=float, default=-16.0)
    args = parser.parse_args()
    if not args.library or not os.path.isdir(args.library):
        sys.exit("Set --library or CHOPPA_SFX to the sound library folder.")
    paths = find(args.library, args.words, args.exclude)
    print("%d matches" % len(paths))
    out = os.path.join(ROOT, "build", "audition", args.sound)
    os.makedirs(out, exist_ok=True)
    for old in os.listdir(out):
        os.remove(os.path.join(out, old))
    lines = []
    for letter, rel in zip(string.ascii_lowercase, paths[: args.count]):
        spec = {"takes": [{"file": rel, "start": 0.0 if args.loop else "auto", "length": args.length}],
                "loudness": args.loudness, "loop": args.loop, "crossfade": 0.4}
        try:
            take = library.render(spec, args.library)[0]
        except ValueError as e:
            print("  skip %s (%s)" % (rel, e))
            continue
        library.write_wav(os.path.join(out, letter + ".wav"), take)
        lines.append("%s  %s" % (letter, rel))
        print("  %s  %s" % (letter, rel))
    with open(os.path.join(out, "list.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("Listen: %s" % out)


if __name__ == "__main__":
    main()
