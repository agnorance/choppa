"""Records the demo video: short clips from the game itself (Godot's Movie Maker, game
sound included), cut together with captions, a title and an end card, the CHOPPA FM
techno underneath. Output: build/demo/choppa_demo.mp4 (1920x1080, 60 fps, H.264).

Run:  python tools/make_demo.py            (records every clip, then cuts)
      python tools/make_demo.py --cut      (only cuts, from clips already recorded)
      python tools/make_demo.py takeoff    (records only the named clips, then cuts)

Needs Godot 4.7.2 (GODOT or C:\\Tools\\Godot) and ffmpeg on the PATH. Clips are taken
with `--clean` (no key overlay, no in-game music; nothing is saved) and the cameras
in ChaseCamera.cinematic. Edit CLIPS to change the cut.
"""
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "build", "demo")
GODOT = os.environ.get("GODOT") or shutil.which("godot") or r"C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
FFMPEG = shutil.which("ffmpeg") or os.path.expanduser(r"~\scoop\shims\ffmpeg.exe")
FONT = os.path.join(ROOT, "assets", "fonts", "BarlowCondensed-SemiBold.ttf")
MUSIC = os.path.join(ROOT, "assets", "sounds", "music_techno_loop.ogg")
LOGO = os.path.join(ROOT, "assets", "brand", "logo_wordmark.png")  # Used on the cards if present.
W, H, FPS = 1920, 1080, 60

# name, caption, seconds kept, seconds skipped at the start, game arguments.
CLIPS = [
    ("menu", "", 4.0, 1.0, "--menu --map=basin"),
    ("takeoff", "Cold start: engine on, rotor spools up, lift-off", 6.5, 0.5,
     "--mode=free --map=basin --autopilot=takeoff --cam=low --dummies=0"),
    ("lake", "Downwash on the water", 5.0, 1.0,
     "--mode=free --map=basin --spawn=150,3,150,225 --autopilot=hover --cam=orbit --dummies=0"),
    ("grass", "Wind in the grass, pines, a lake that moves", 5.0, 0.5,
     "--mode=free --map=basin --spawn=-60,6,140,200 --autopilot=forward --cam=side --dummies=0"),
    ("rockets", "Rocket salvos", 4.0, 0.3, "--mode=free --map=basin --autopilot=weapon:rockets --cam=showcase"),
    ("missile", "Homing missiles", 4.5, 0.3, "--mode=free --map=basin --autopilot=weapon:missile --cam=side"),
    ("flares", "Flares, one after another", 4.0, 0.3,
     "--mode=free --map=basin --spawn=0,60,120,0 --autopilot=weapon:flares --cam=showcase"),
    ("explode", "Explosions", 4.0, 0.6, "--mode=free --map=basin --autopilot=hover --explode=70 --cam=showcase"),
    ("damage", "Damage model: smoke, cracks, a dead tail rotor spins you", 5.0, 0.5,
     "--mode=free --map=basin --spawn=150,6,150,225 --health=25 --wear=tail --autopilot=hover --cam=orbit --dummies=0"),
    ("battle", "Battles against bots that fight back", 9.0, 6.0, "--mode=battle --map=basin --autopilot=bot"),
    ("canyon", "Slot Canyon", 6.0, 6.0, "--mode=battle --map=canyon --autopilot=bot --cam=side"),
    ("harbor", "Rust Harbor: containers, cranes, ships", 7.0, 6.0, "--mode=battle --map=harbor --autopilot=bot"),
    ("striker", "Striker: coaxial rotors, no tail rotor to lose", 5.0, 0.5,
     "--mode=free --map=harbor --airframe=striker --autopilot=forward --spawn=40,14,230,0 --cam=side --dummies=0"),
    ("heavy", "Five classes that fly differently", 4.0, 0.5,
     "--mode=free --map=basin --airframe=heavy --spawn=150,6,150,225 --autopilot=hover --cam=orbit --dummies=0"),
    ("mule", "Mule: tandem rotors, a flying fortress", 5.0, 3.5,
     "--mode=free --map=harbor --airframe=mule --spawn=-15,12,110,0 --autopilot=hover --cam=orbit --dummies=0"),
    ("shark", "Shark mouth and new camos", 4.0, 0.5,
     "--mode=free --map=basin --airframe=gunship --camo=shark --spawn=150,6,150,45 --autopilot=hover --cam=orbit --dummies=0"),
    ("dam", "Iron Dam: a new arena", 6.0, 6.0, "--mode=battle --map=dam --autopilot=bot --cam=side"),
    ("dusk", "Dusk", 4.0, 3.0, "--mode=free --map=dam --time=dusk --spawn=30,30,120,0 --autopilot=hover --cam=orbit --dummies=0"),
    ("night", "Night: searchlights and stars", 6.0, 8.0, "--mode=battle --map=harbor --time=night --autopilot=bot"),
    ("wreck", "Wrecks that burn where they fall", 5.0, 3.0,
     "--mode=free --map=basin --autopilot=flip --health=1 --cam=low --dummies=0"),
    ("cp_scout", "Cockpits: Little Bird", 4.0, 0.5,
     "--mode=free --map=basin --spawn=150,4,150,225 --autopilot=hover --cam=fp_look --dummies=0"),
    ("cp_gunship", "Apache style glass cockpit", 4.0, 0.5,
     "--mode=free --map=basin --airframe=gunship --spawn=150,4,150,225 --autopilot=hover --cam=fp_look --dummies=0"),
    ("cp_heavy", "Hind style analog bubble", 4.0, 0.5,
     "--mode=free --map=basin --airframe=heavy --spawn=150,4,150,225 --autopilot=hover --cam=fp_look --dummies=0"),
    ("cp_striker", "Ka-52 style side by side", 4.0, 0.5,
     "--mode=free --map=harbor --airframe=striker --spawn=-60,16,150,0 --autopilot=hover --cam=fp_look --dummies=0"),
    ("cp_mule", "Chinook style, five displays", 4.0, 0.5,
     "--mode=free --map=harbor --airframe=mule --spawn=-60,16,150,0 --autopilot=hover --cam=fp_look --dummies=0"),
    ("race", "Races", 5.0, 4.0, "--mode=race --autopilot=bot"),
    ("hangar", "Hangar: classes, camos, progression", 4.0, 1.0, "--menu --hangar --map=basin"),
]


def record(name, keep, skip, args):
    path = os.path.join(OUT, "clip_%s.avi" % name)
    frames = int((keep + skip) * FPS) + 10
    cmd = [GODOT, "--path", ROOT, "--resolution", "%dx%d" % (W, H), "--write-movie", path, "--quit-after", str(frames),
           "--", "--clean"] + args.split()
    print("recording", name, flush=True)
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def text_filter(text, size, y, start=0.25, color="white"):
    font = FONT.replace("\\", "/").replace(":", "\\:")
    text = text.replace(":", "\\:").replace("'", "\u2019")
    return ("drawtext=fontfile='%s':text='%s':fontsize=%d:fontcolor=%s:x=90:y=%s:"
            "shadowcolor=black@0.6:shadowx=2:shadowy=2:alpha='min(1,max(0,(t-%.2f)*4))'" % (font, text, size, color, y, start))


def cut():
    parts = []
    for k, (name, caption, keep, skip, _) in enumerate(CLIPS):
        src = os.path.join(OUT, "clip_%s.avi" % name)
        if not os.path.exists(src):
            print("missing", src)
            continue
        dst = os.path.join(OUT, "part_%02d.mp4" % k)
        vf = ["trim=start=%.2f:duration=%.2f" % (skip, keep), "setpts=PTS-STARTPTS", "scale=%d:%d" % (W, H)]
        if caption:
            vf.append("drawbox=x=60:y=ih-170:w=12:h=64:color=0xFF9E33@1:t=fill:enable='gte(t,0.25)'")
            vf.append(text_filter(caption.upper(), 58, "h-175"))
        vf.append("fade=t=in:st=0:d=0.25,fade=t=out:st=%.2f:d=0.25" % (keep - 0.25))
        af = "atrim=start=%.2f:duration=%.2f,asetpts=PTS-STARTPTS,afade=t=in:d=0.2,afade=t=out:st=%.2f:d=0.25" % (
            skip, keep, keep - 0.25)
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", src, "-vf", ",".join(vf), "-af", af,
                        "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", dst], check=True)
        parts.append(dst)
    parts.insert(0, card("title", "HELICOPTER ARENA COMBAT", 3.0))
    parts.append(card("end", "IN DEVELOPMENT  ·  PC", 3.5))
    listing = os.path.join(OUT, "parts.txt")
    with open(listing, "w", encoding="utf-8") as f:
        for p in parts:
            f.write("file '%s'\n" % p.replace("\\", "/"))
    joined = os.path.join(OUT, "joined.mp4")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", joined],
                   check=True)
    length = float(subprocess.run([FFMPEG.replace("ffmpeg", "ffprobe"), "-v", "error", "-show_entries", "format=duration",
                                   "-of", "csv=p=0", joined], capture_output=True, text=True).stdout.strip() or 0)
    final = os.path.join(OUT, "choppa_demo.mp4")
    # Game sound on top, the techno looped underneath and faded out at the end.
    mix = ("[1:a]volume=0.45,afade=t=in:d=1,afade=t=out:st=%.2f:d=2.5[m];[0:a]volume=1.0[g];"
           "[g][m]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]" % max(0.0, length - 2.5))
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", joined, "-stream_loop", "-1", "-i", MUSIC,
                    "-filter_complex", mix, "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "22",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
                    "-shortest", "-movflags", "+faststart", final], check=True)
    print("wrote", final, "(%.0f s)" % length)


def card(name, line, seconds):
    """A dark card with the logo (or the name) and one line under it."""
    dst = os.path.join(OUT, "card_%s.mp4" % name)
    inputs = ["-f", "lavfi", "-i", "color=c=0x0E1114:s=%dx%d:r=%d:d=%.2f" % (W, H, FPS, seconds),
              "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"]
    font = FONT.replace("\\", "/").replace(":", "\\:")
    sub = ("drawtext=fontfile='%s':text='%s':fontsize=44:fontcolor=0xC9CED4:x=(w-tw)/2:y=h*0.66" % (font, line))
    if os.path.exists(LOGO):
        inputs += ["-i", LOGO]
        graph = ("[2:v]scale=900:-1[l];[0:v][l]overlay=(W-w)/2:(H-h)/2-60,%s,"
                 "fade=t=in:d=0.5,fade=t=out:st=%.2f:d=0.5[v]" % (sub, seconds - 0.5))
    else:
        graph = ("[0:v]drawtext=fontfile='%s':text='CHOPPA':fontsize=220:fontcolor=0xFF9E33:x=(w-tw)/2:y=h*0.3,%s,"
                 "fade=t=in:d=0.5,fade=t=out:st=%.2f:d=0.5[v]" % (font, sub, seconds - 0.5))
    subprocess.run([FFMPEG, "-y", "-loglevel", "error"] + inputs + ["-filter_complex", graph, "-map", "[v]", "-map", "1:a",
                    "-t", "%.2f" % seconds, "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac",
                    "-b:a", "192k", "-ar", "48000", "-ac", "2", dst], check=True)
    return dst


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--cut" not in sys.argv:
        for name, _, keep, skip, args in CLIPS:
            if not names or name in names:
                record(name, keep, skip, args)
    cut()
    for leftover in glob.glob(os.path.join(OUT, "part_*.mp4")) + [os.path.join(OUT, "joined.mp4")]:
        os.remove(leftover)
