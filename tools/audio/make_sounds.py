"""Builds the game's sound effects, assets/sounds/*.wav, from noise and oscillators.

Run:  python3 tools/audio/make_sounds.py [names...]     (needs numpy)

Everything is synthesized, so it can be retuned here and regenerated. Loops (rotor,
engine, boost, missile, warning) are made seamless: their pulse patterns repeat exactly
over the loop length, and filters run over two copies so the seam carries their state.
Mono 16-bit at 22050 Hz keeps the files small; the game positions them in 3D.
"""
import math
import os
import sys
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sounds")
rng = np.random.default_rng(7)
LOOP = None  # While building a loop: its length in samples, so noise repeats with it.


# --- building blocks ---------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    n = int(seconds * RATE)
    if LOOP is None:
        return rng.uniform(-1.0, 1.0, n)
    return np.resize(rng.uniform(-1.0, 1.0, LOOP), n)  # Periodic, so the loop seam matches.


def lowpass(x, cutoff):
    """Two-pole low-pass (two one-pole stages, 12 dB/octave); cutoff may be a number
    or an array (a sweep)."""
    return _one_pole(_one_pole(x, cutoff), cutoff)


def _one_pole(x, cutoff):
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2.0 * math.pi * cutoff / RATE)
    y = np.empty_like(x)
    state = 0.0
    for k in range(len(x)):
        state += a[k] * (x[k] - state)
        y[k] = state
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return lowpass(highpass(x, low), high)


def env(seconds, attack, decay):
    """Fast attack, exponential decay (decay = time constant in seconds)."""
    t = t_axis(seconds)
    rise = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return rise * np.exp(-np.maximum(t - attack, 0.0) / decay)


def sine(seconds, freq, phase=0.0):
    """Sine with a fixed or swept frequency (array)."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (int(seconds * RATE),))
    return np.sin(phase + 2.0 * math.pi * np.cumsum(freq) / RATE)


def place(target, sound, at_seconds, gain=1.0):
    start = int(at_seconds * RATE)
    end = min(len(target), start + len(sound))
    if start < len(target):
        target[start:end] += sound[: end - start] * gain


def seamless(build, seconds):
    """Builds two loop lengths of a periodic signal and returns the second, so filter
    state at the loop seam matches."""
    global LOOP
    LOOP = int(seconds * RATE)
    try:
        twice = build(seconds * 2.0)
    finally:
        LOOP = None
    return twice[len(twice) // 2:]


def save(name, x, peak=0.9):
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.abspath(os.path.join(OUT, name + ".wav"))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"{name}: {len(x) / RATE:.2f} s", flush=True)


# --- sounds ------------------------------------------------------------------------

def rotor_loop():
    """Blade slap: 'wop-wop' pulses at 12 per second (the game bends the pitch)."""
    def build(seconds):
        x = np.zeros(int(seconds * RATE))
        # Mid-range 'wop' so it carries on laptop speakers, plus a little low thump.
        slap = bandpass(noise(0.09), 180.0, 1100.0) * env(0.09, 0.004, 0.025) * 3.0
        slap += sine(0.09, 85.0) * env(0.09, 0.003, 0.03) * 0.5
        for k in range(int(seconds * 12)):
            place(x, slap, k / 12.0, 0.75 + 0.25 * ((k * 7) % 5) / 4.0)
        hum = lowpass(noise(seconds), 140.0) * 0.3
        return lowpass(x + hum, 2400.0)
    return seamless(build, 2.0)


def engine_loop():
    """Seven-cylinder radial: lumpy firing pulses and a rough exhaust note."""
    def build(seconds):
        x = np.zeros(int(seconds * RATE))
        rate = 49.0  # Firing pulses per second at cruise.
        lumps = [1.0, 0.7, 0.9, 0.6, 1.0, 0.75, 0.85]  # Uneven, one per cylinder.
        pulse = bandpass(noise(0.03), 150.0, 1600.0) * env(0.03, 0.001, 0.008) * 2.5
        pulse += sine(0.03, 98.0) * env(0.03, 0.001, 0.01) * 0.6
        for k in range(int(seconds * rate)):
            place(x, pulse, k / rate, lumps[k % 7])
        x += sine(seconds, rate / 2.0) * 0.12 + sine(seconds, rate) * 0.1
        return lowpass(x, 2200.0)
    return seamless(build, 1.0)  # 49 pulses: 7 full engine cycles per loop.


def boost_loop():
    """Afterburner roar for boost and turbo."""
    def build(seconds):
        roar = bandpass(noise(seconds), 200.0, 1800.0)
        flutter = 1.0 + 0.3 * sine(seconds, 18.0)
        return roar * flutter + lowpass(noise(seconds), 120.0) * 1.5
    return seamless(build, 1.5)


def missile_loop():
    """Rocket motor of a missile in flight."""
    def build(seconds):
        return bandpass(noise(seconds), 400.0, 3000.0) * (1.0 + 0.2 * sine(seconds, 30.0))
    return seamless(build, 1.0)


def warning_loop():
    """Missile lock warning: two fast beeps, then a pause."""
    x = np.zeros(int(0.5 * RATE))
    beep = np.sign(sine(0.07, 1250.0)) * 0.6 + sine(0.07, 1250.0) * 0.4
    beep *= np.clip(t_axis(0.07) / 0.004, 0.0, 1.0) * np.clip((0.07 - t_axis(0.07)) / 0.01, 0.0, 1.0)
    place(x, lowpass(beep, 5000.0), 0.0)
    place(x, lowpass(beep, 5000.0), 0.11)
    return x


def gun():
    """One heavy machine gun round: sharp crack, a chesty punch, the bolt cycling and a
    short air tail, so a burst sounds like a big gun rather than a rattle."""
    s = 0.32
    n = int(s * RATE)
    crack = highpass(noise(s), 1800.0) * env(s, 0.0004, 0.004) * 0.55
    body = lowpass(noise(s), 1100.0) * env(s, 0.001, 0.04) * 2.0
    punch = bandpass(noise(s), 180.0, 700.0) * env(s, 0.001, 0.06) * 2.2
    thump = sine(s, np.linspace(125.0, 55.0, n)) * env(s, 0.001, 0.06) * 1.7
    clack = np.zeros(n)
    place(clack, highpass(noise(0.03), 2500.0) * env(0.03, 0.0005, 0.006), 0.035, 0.22)
    tail = lowpass(noise(s), 650.0) * env(s, 0.01, 0.11) * 0.4
    return lowpass(crack + body + punch + thump + clack + tail, 7000.0)


def gun_tail():
    """What rolls on after a burst stops: a low boom echoing off the terrain."""
    s = 1.6
    n = int(s * RATE)
    echo = np.zeros(n)
    for at, gain in [(0.0, 1.0), (0.12, 0.5), (0.31, 0.3), (0.55, 0.18)]:
        place(echo, lowpass(noise(0.5), 700.0) * env(0.5, 0.004, 0.18), at, gain)
    rumble = sine(s, np.geomspace(90.0, 45.0, n)) * env(s, 0.01, 0.35) * 0.5
    return lowpass(echo + rumble, 2500.0) * 0.8


def explosion():
    """A big boom: crack, roaring fireball, sub-bass thump, debris crackle."""
    s = 3.0
    n = int(s * RATE)
    sweep = np.geomspace(1800.0, 120.0, n)
    roar = lowpass(noise(s), sweep) * env(s, 0.004, 0.75) * 2.6
    crack = highpass(noise(s), 900.0) * env(s, 0.0005, 0.015) * 0.5
    sub = sine(s, np.geomspace(55.0, 28.0, n)) * env(s, 0.006, 0.6) * 1.4
    crackle = np.zeros(n)
    for k in range(40):
        at = 0.25 + rng.uniform(0.0, 1.8)
        click = highpass(noise(0.02), 2000.0) * env(0.02, 0.0005, 0.004)
        place(crackle, click, at, rng.uniform(0.1, 0.35) * math.exp(-at))
    return lowpass(roar + crack + sub + crackle, 4000.0)


def impact_metal():
    """A round striking armour: click and inharmonic clang."""
    s = 0.35
    clang = sum(sine(s, f) * env(s, 0.0008, d) * a
                for f, d, a in [(1240.0, 0.09, 0.5), (2930.0, 0.05, 0.35), (4710.0, 0.03, 0.25), (690.0, 0.12, 0.3)])
    click = highpass(noise(s), 2500.0) * env(s, 0.0003, 0.004)
    return clang + click


def impact_dirt():
    """A round thumping into the ground: dull thud and a spray of grit."""
    s = 0.3
    thud = lowpass(noise(s), 500.0) * env(s, 0.001, 0.035) * 2.0 + sine(s, 110.0) * env(s, 0.001, 0.03)
    grit = bandpass(noise(s), 1500.0, 6000.0) * env(s, 0.01, 0.06) * 0.3
    return thud + grit


def splash():
    """A round or blast hitting water."""
    s = 0.6
    hiss = bandpass(noise(s), 800.0, 7000.0) * env(s, 0.005, 0.15)
    plop = sine(s, np.geomspace(500.0, 180.0, int(s * RATE))) * env(s, 0.002, 0.05) * 0.6
    return hiss + plop


def missile_launch():
    """Fwoosh of a missile leaving the rail."""
    s = 0.9
    sweep = np.geomspace(500.0, 4000.0, int(s * RATE))
    thump = sine(s, np.geomspace(90.0, 50.0, int(s * RATE))) * env(s, 0.002, 0.06)
    return lowpass(noise(s), sweep) * env(s, 0.02, 0.3) * 1.5 + thump


def pickup():
    """Item box: a quick rising arpeggio."""
    s = 0.55
    x = np.zeros(int(s * RATE))
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        note = (sine(0.18, f) + 0.3 * sine(0.18, f * 2.0)) * env(0.18, 0.003, 0.08)
        place(x, note, k * 0.07)
    return x


def rocket_launch():
    """Unguided rocket leaving the pod: a hard crack and a short tearing whoosh."""
    s = 0.6
    crack = bandpass(noise(0.05), 600.0, 3000.0) * env(0.05, 0.001, 0.012) * 2.0
    sweep = np.geomspace(2500.0, 700.0, int(s * RATE))
    whoosh = lowpass(noise(s), sweep) * env(s, 0.01, 0.18)
    x = whoosh.copy()
    place(x, crack, 0.0)
    return x


def flares():
    """Flare dispenser: a string of dull pops, then a fizz as they burn."""
    s = 1.4
    x = np.zeros(int(s * RATE))
    pop = bandpass(noise(0.06), 250.0, 1500.0) * env(0.06, 0.001, 0.015) * 2.0
    for k in range(6):
        place(x, pop, k * 0.07, 1.0 - k * 0.08)
    fizz = bandpass(noise(s), 1200.0, 5000.0) * env(s, 0.15, 0.5) * 0.35
    return x + fizz


def station_service():
    """Service station at work: a ratcheting impact wrench and a hydraulic hum."""
    s = 4.0
    x = lowpass(noise(s), 300.0) * 0.25 + sine(s, 120.0) * 0.08
    rattle = bandpass(noise(0.025), 800.0, 3200.0) * env(0.025, 0.001, 0.006) * 1.5
    for burst in (0.2, 1.3, 2.5):
        for k in range(14):
            place(x, rattle, burst + k * 0.035, 0.8)
    return x * np.minimum(1.0, t_axis(s) * 6.0)


def station_done():
    """Service finished: two clean bell tones, up a fifth."""
    s = 0.7
    x = np.zeros(int(s * RATE))
    for k, f in enumerate([659.25, 987.77]):
        note = (sine(0.5, f) + 0.25 * sine(0.5, f * 2.76)) * env(0.5, 0.002, 0.18)
        place(x, note, k * 0.12)
    return x


def cable_strike():
    """Rotor blades hitting a power cable: a metallic twang and an electric crackle."""
    s = 0.9
    twang = sine(s, np.geomspace(420.0, 300.0, int(s * RATE))) * env(s, 0.001, 0.25)
    twang += sine(s, np.geomspace(1150.0, 900.0, int(s * RATE))) * env(s, 0.001, 0.12) * 0.4
    crackle = bandpass(noise(s), 1500.0, 6000.0) * (np.random.default_rng(3).random(int(s * RATE)) > 0.985) * 3.0
    return twang + lowpass(crackle, 7000.0) * env(s, 0.0, 0.3)


def wind_loop():
    """Gusting canyon wind: band-limited noise that swells and fades."""
    def build(seconds):
        t = t_axis(seconds)
        gust = 0.6 + 0.4 * np.sin(2.0 * math.pi * t / 4.0) * np.sin(2.0 * math.pi * t / 2.0 + 1.0)
        sweep = 500.0 + 400.0 * gust
        return bandpass(noise(seconds), 150.0, 900.0) * 0.6 * gust + lowpass(noise(seconds), sweep) * 0.3
    return seamless(build, 8.0)


def hit_marker():
    """Your round connected: a short dry tick (non-positional)."""
    s = 0.08
    return (bandpass(noise(s), 1500.0, 4000.0) * 0.6 + sine(s, 1800.0) * 0.5) * env(s, 0.0005, 0.012)


def part_hit():
    """You wrecked part of a rival: a heavy metallic clank."""
    s = 0.5
    clank = sine(s, 310.0) * env(s, 0.001, 0.09) + sine(s, 760.0) * env(s, 0.001, 0.05) * 0.6
    return clank + bandpass(noise(s), 300.0, 2500.0) * env(s, 0.001, 0.04) * 1.2


# --- music: a dieselpunk march (drums, bass, a brass-ish lead), 96 bpm, D minor ------

BPM = 96.0
BEAT = 60.0 / BPM


def _kick():
    s = 0.35
    return sine(s, np.geomspace(140.0, 45.0, int(s * RATE))) * env(s, 0.002, 0.09) * 1.4


def _snare():
    s = 0.25
    return bandpass(noise(s), 400.0, 5000.0) * env(s, 0.001, 0.06) + sine(s, 190.0) * env(s, 0.001, 0.04) * 0.5


def _hat():
    s = 0.06
    return highpass(noise(s), 6000.0) * env(s, 0.0005, 0.015) * 0.5


def _tone(freq, seconds, bright=0.6):
    """A brass-ish note: a few harmonics, a soft attack, a gentle fall."""
    x = sum(sine(seconds, freq * h) * (bright ** (h - 1)) / h for h in range(1, 6))
    return lowpass(x, 2500.0) * env(seconds, 0.03, seconds * 0.7)


NOTE = {"D2": 73.42, "F2": 87.31, "G2": 98.0, "A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81,
        "F3": 174.61, "G3": 196.0, "A3": 220.0, "Bb3": 233.08, "C4": 261.63, "D4": 293.66, "E4": 329.63,
        "F4": 349.23, "G4": 392.0, "A4": 440.0}


def _song(bars, drums, bass, lead, lead_gain):
    seconds = bars * 4 * BEAT
    x = np.zeros(int(seconds * RATE))
    for bar in range(bars):
        for beat in range(4):
            at = (bar * 4 + beat) * BEAT
            if drums:
                if beat in (0, 2):
                    place(x, _kick(), at, 0.9)
                if beat in (1, 3):
                    place(x, _snare(), at, 0.55)
                for h in range(2):
                    place(x, _hat(), at + h * BEAT / 2, 0.5)
        root = bass[bar % len(bass)]
        for k, step in enumerate([0, 0, 7, 0]):  # Root, root, fifth, root.
            f = NOTE[root] * (1.5 if step == 7 else 1.0)
            place(x, _tone(f, BEAT * 0.9, 0.4), (bar * 4 + k) * BEAT, 0.55)
    at = 0.0
    for name, beats in lead:
        if name != "-":
            place(x, _tone(NOTE[name], beats * BEAT, 0.7), at, lead_gain)
        at += beats * BEAT
    return lowpass(x, 6000.0)


def music_menu():
    """Title screen: slow and moody, no drums, the lead stated once."""
    lead = [("D4", 2), ("F4", 1), ("E4", 1), ("D4", 3), ("-", 1), ("A3", 2), ("C4", 2), ("D4", 4),
            ("F4", 2), ("G4", 1), ("F4", 1), ("E4", 3), ("-", 1), ("D4", 2), ("C4", 2), ("D4", 4)]
    return _song(8, False, ["D2", "D2", "F2", "C3", "G2", "G2", "A2", "A2"], lead, 0.45)


def music_battle():
    """Battle: the same theme as a march, drums driving it."""
    lead = [("D4", 1), ("D4", 0.5), ("F4", 0.5), ("A4", 1), ("G4", 1), ("F4", 1), ("E4", 1), ("D4", 2),
            ("C4", 1), ("D4", 0.5), ("E4", 0.5), ("F4", 1), ("E4", 1), ("D4", 1), ("C4", 1), ("A3", 2),
            ("D4", 1), ("D4", 0.5), ("F4", 0.5), ("A4", 1), ("G4", 1), ("F4", 1), ("G4", 1), ("A4", 2),
            ("G4", 1), ("F4", 1), ("E4", 1), ("C4", 1), ("D4", 4)]
    return _song(8, True, ["D2", "D2", "C3", "C3", "D2", "F2", "G2", "A2"], lead, 0.4)



SOUNDS = {
    "rotor_loop": rotor_loop, "engine_loop": engine_loop, "boost_loop": boost_loop,
    "missile_loop": missile_loop, "warning_loop": warning_loop, "gun": gun, "gun_tail": gun_tail, "explosion": explosion,
    "impact_metal": impact_metal, "impact_dirt": impact_dirt, "splash": splash,
    "missile_launch": missile_launch, "pickup": pickup, "rocket_launch": rocket_launch, "flares": flares,
    "station_service": station_service, "station_done": station_done, "cable_strike": cable_strike,
    "wind_loop": wind_loop, "hit_marker": hit_marker, "part_hit": part_hit,
    # Music: tools/audio/make_music.py (stereo OGG).
}

if __name__ == "__main__":
    for name in sys.argv[1:] or list(SOUNDS):
        save(name, SOUNDS[name]())
