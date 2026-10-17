"""Synthesized techno for the built-in radio station and the title screen.

    python tools/audio/make_music.py [techno] [menu]

numpy for the synthesis, ffmpeg for the OGG encoding (scoop install ffmpeg). Writes
assets/sounds/music_<name>_loop.ogg: stereo, 44.1 kHz, seamless (32 bars that end
where they began). The radio's other stations are royalty-free tracks the owner drops
into assets/music/library/<Station>/ (git-ignored, see scripts/radio.gd).

Techno is the one genre where synthesis is the real thing: an 808-style kick with its
pitch drop, offbeat hats, a clap, a rolling sidechained bass, a resonant acid line and
detuned pad stabs, arranged groove / build / breakdown / drop.
"""

import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import library  # noqa: E402

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sounds")
rng = np.random.default_rng(128)


def note_hz(name):
    """'A1', 'C#3' ... to Hz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2.0 ** ((names[pitch] + (octave - 4) * 12) / 12.0)


def saw(freq, n, phase=0.0):
    t = np.arange(n) / RATE
    return 2.0 * ((t * freq + phase) % 1.0) - 1.0


def decay(n, attack, tau):
    t = np.arange(n) / RATE
    return np.clip(t / max(attack, 1e-4), 0.0, 1.0) * np.exp(-np.maximum(t - attack, 0.0) / tau)


def resonant_lowpass(x, cutoff, q):
    """Low-pass with a resonant bump at the cutoff (the acid squelch), in the frequency
    domain: fine for one short note at a time."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    gain = 1.0 / np.sqrt(1.0 + (f / cutoff) ** 8)
    gain *= 1.0 + q * np.exp(-(((f - cutoff) / (0.12 * cutoff)) ** 2))
    return np.fft.irfft(np.fft.rfft(x) * gain, n)


def add(target, sound, at):
    start = int(at * RATE)
    end = min(len(target), start + len(sound))
    if start < len(target):
        target[start:end] += sound[: end - start]


class Track:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.bars = bars
        self.n = int(bars * 4 * self.beat * RATE)
        self.left = np.zeros(self.n)
        self.right = np.zeros(self.n)
        self.duck = np.ones(self.n)  # The kick's sidechain: pads and bass dip under it.

    def at(self, bar, beat=0.0):
        return (bar * 4 + beat) * self.beat

    def put(self, sound, when, pan=0.0, gain=1.0):
        """Mono sound at `when` seconds, panned -1 (left) .. 1 (right). Wraps past the end,
        so tails spill into the start and the loop is seamless."""
        l = sound * gain * np.sqrt(0.5 * (1.0 - pan))
        r = sound * gain * np.sqrt(0.5 * (1.0 + pan))
        start = int(when * RATE) % self.n
        for buf, s in ((self.left, l), (self.right, r)):
            first = min(len(s), self.n - start)
            buf[start:start + first] += s[:first]
            if first < len(s):
                buf[: len(s) - first] += s[first:]

    def kick(self, when, gain=1.0):
        n = int(0.5 * RATE)
        t = np.arange(n) / RATE
        freq = 45.0 + 110.0 * np.exp(-t / 0.035)
        body = np.sin(2.0 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.28)
        click = library.filtered(rng.uniform(-1, 1, n), RATE, highpass=2500) * np.exp(-t / 0.004) * 0.3
        self.put(np.tanh((body + click) * 1.6) * 0.42, when, 0.0, gain)
        # Duck everything else for a moment.
        start = int(when * RATE) % self.n
        dip = 1.0 - 0.75 * np.exp(-t / 0.12)
        for k in range(n):
            self.duck[(start + k) % self.n] = min(self.duck[(start + k) % self.n], dip[k])

    def hat(self, when, open_hat=False, gain=1.0, pan=0.0):
        n = int((0.35 if open_hat else 0.06) * RATE)
        sound = library.filtered(rng.uniform(-1, 1, n), RATE, highpass=7500, order=3)
        sound *= decay(n, 0.001, 0.09 if open_hat else 0.015)
        self.put(sound * 0.62, when, pan, gain)

    def clap(self, when, gain=1.0):
        n = int(0.4 * RATE)
        noise = library.filtered(rng.uniform(-1, 1, n), RATE, highpass=900, lowpass=5000)
        t = np.arange(n) / RATE
        shape = np.zeros(n)
        for k, start in enumerate([0.0, 0.011, 0.022]):  # The three hands of a clap.
            shape += np.where(t >= start, np.exp(-(t - start) / (0.008 if k < 2 else 0.12)), 0.0)
        self.put(noise * shape * 0.8, when, -0.1, gain)
        self.put(noise * shape * 0.8, when + 0.012, 0.15, gain * 0.7)

    def bass(self, when, hz, length, gain=1.0):
        n = int(length * RATE)
        tone = saw(hz, n) * 0.6 + np.sin(2 * np.pi * hz * np.arange(n) / RATE) * 0.7
        tone = library.filtered(tone, RATE, lowpass=380)
        self.put(tone * decay(n, 0.003, length * 0.6) * 0.55, when, 0.0, gain)

    def acid(self, when, hz, length, cutoff, accent=False, gain=1.0):
        n = int(length * RATE)
        tone = saw(hz, n) * 0.5 + np.sign(np.sin(2 * np.pi * hz * np.arange(n) / RATE)) * 0.25
        # The filter opens on each note and closes again: the squelch.
        sound = np.zeros(n)
        steps = 6
        for k in range(steps):
            a, b = n * k // steps, n * (k + 1) // steps
            c = cutoff * (2.6 if accent else 1.8) * np.exp(-k / 2.2) + 120.0
            sound[a:b] = resonant_lowpass(tone, min(c, 9000.0), 3.5 if accent else 2.2)[a:b]
        sound = np.tanh(sound * 2.2) * 0.9
        self.put(sound * decay(n, 0.002, length * (0.9 if accent else 0.55)), when, 0.25, gain)

    def pad(self, when, chord, length, gain=1.0, cutoff=1400.0):
        n = int(length * RATE)
        for k, name in enumerate(chord):
            hz = note_hz(name)
            for detune, pan in ((-0.12, -0.6), (0.0, 0.0), (0.12, 0.6)):
                tone = saw(hz * 2.0 ** (detune / 12.0), n, rng.uniform())
                tone = library.filtered(tone, RATE, lowpass=cutoff)
                shape = np.minimum(1.0, np.arange(n) / (0.25 * RATE)) * np.minimum(1.0, (n - np.arange(n)) / (0.4 * RATE))
                self.put(tone * shape * 0.16, when, pan, gain)

    def riser(self, start, length, gain=1.0):
        n = int(length * RATE)
        sweep = np.geomspace(300.0, 9000.0, n)
        noise = rng.uniform(-1, 1, n)
        out = np.zeros(n)
        block = 2048
        for k in range(0, n, block):  # A rising band of noise.
            seg = noise[k:k + block]
            out[k:k + block] = library.filtered(seg, RATE, highpass=sweep[k] * 0.7, lowpass=sweep[k] * 1.4)
        self.put(out * np.linspace(0.0, 0.7, n), start, 0.0, gain)

    def mix(self, duck_parts):
        """duck_parts: (left, right) of everything the kick should push down."""
        left = self.left + duck_parts[0] * self.duck
        right = self.right + duck_parts[1] * self.duck
        stereo = np.stack([left, right], axis=1)
        stereo = np.tanh(stereo * 1.25) / np.tanh(1.25)  # Glue.
        return stereo / max(1e-9, np.max(np.abs(stereo))) * 0.89


def techno():
    """CHOPPA FM: 128 BPM, 32 bars. 1-8 groove, 9-16 acid comes in, 17-24 full, 25-28
    breakdown with a riser, 29-32 the drop (which leads straight back into bar 1)."""
    song = Track(128, 32)
    soft = Track(128, 32)  # The ducked layer: bass and pads.
    roots = ["A1", "A1", "F1", "G1"]  # Two bars each.
    acid_line = [0, 0, 12, 0, 3, 0, 15, 0, 7, 0, 12, 10, 0, 3, 0, 5]  # Semitones over the root.
    accents = {2, 6, 9, 13}
    for bar in range(32):
        breakdown = 24 <= bar < 28
        root = note_hz(roots[(bar // 2) % 4])
        for beat in range(4):
            if not breakdown:
                song.kick(song.at(bar, beat))
            if bar >= 2 or breakdown:
                song.hat(song.at(bar, beat + 0.5), open_hat=bar >= 4, pan=0.2)
            if (bar >= 8 and beat in (1, 3)) and not breakdown:
                song.clap(song.at(bar, beat))
        for six in range(16):
            if bar >= 1 and not breakdown and six % 2 == 1:
                song.hat(song.at(bar, six / 4.0), gain=0.55 if six % 4 == 3 else 0.35, pan=-0.3)
            # Rolling bass: three of every four sixteenths, never on the beat.
            if not breakdown and six % 4 != 0:
                soft.bass(soft.at(bar, six / 4.0), root, song.beat / 4.0 * 0.9)
            if 8 <= bar < 24 or bar >= 28:
                opening = 600.0 + 2400.0 * (0.5 - 0.5 * np.cos(np.pi * ((bar - 8) % 16) / 15.0))
                hz = root * 4.0 * 2.0 ** (acid_line[six] / 12.0)
                song.acid(song.at(bar, six / 4.0), hz, song.beat / 4.0 * 0.95, opening, six in accents,
                          gain=0.7 if bar < 12 else 1.0)
        chord = {"A1": ["A3", "C4", "E4"], "F1": ["F3", "A3", "C4"], "G1": ["G3", "B3", "D4"]}[roots[(bar // 2) % 4]]
        if breakdown:
            soft.pad(soft.at(bar), chord, song.beat * 4.0, gain=1.0, cutoff=900.0 + 500.0 * (bar - 24))
        elif bar % 2 == 0:
            for stab in (0.5, 2.5):  # Offbeat chord stabs.
                soft.pad(soft.at(bar, stab), chord, song.beat * 0.7, gain=0.8, cutoff=2200.0)
    song.riser(song.at(26), song.beat * 8.0, gain=0.9)
    return song.mix((soft.left, soft.right))


def menu():
    """Title screen: deep and minimal, 120 BPM, 16 bars. A soft kick, shakers, a sub
    and slow pads; no acid."""
    song = Track(120, 16)
    soft = Track(120, 16)
    chords = [["A3", "C4", "E4", "G4"], ["F3", "A3", "C4", "E4"], ["D3", "F3", "A3", "C4"], ["E3", "G3", "B3", "D4"]]
    for bar in range(16):
        for beat in range(4):
            song.kick(song.at(bar, beat), gain=0.55)
            song.hat(song.at(bar, beat + 0.5), gain=1.0, pan=0.3)
            song.hat(song.at(bar, beat + 0.75), gain=0.5, pan=-0.3)
            song.hat(song.at(bar, beat + 0.25), gain=0.3, pan=0.1)
        chord = chords[(bar // 4) % 4]
        if bar % 4 == 0:
            soft.pad(soft.at(bar), chord, song.beat * 16.0, gain=1.4, cutoff=1100.0)
        root = note_hz(chord[0][:-1] + "1")
        for beat in range(4):
            soft.bass(soft.at(bar, beat + 0.5), root, song.beat * 0.45, gain=0.8)
    return song.mix((soft.left, soft.right))


TRACKS = {"techno": techno, "menu": menu}


def encode(name, stereo):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        sys.exit("ffmpeg is needed for the OGG encoding (scoop install ffmpeg)")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        library.write_wav(wav, stereo.astype(np.float32), RATE)
        out = os.path.abspath(os.path.join(OUT, "music_%s_loop.ogg" % name))
        subprocess.run([ffmpeg, "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    old = os.path.abspath(os.path.join(OUT, "music_%s_loop.wav" % name))
    if os.path.exists(old):
        os.remove(old)  # The OGG replaces the synthesized WAV of make_sounds.py.
        if os.path.exists(old + ".import"):
            os.remove(old + ".import")
    print("music_%s_loop.ogg: %.1f s, %d KB" % (name, len(stereo) / RATE, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    for name in sys.argv[1:] or list(TRACKS):
        encode(name, TRACKS[name]())
