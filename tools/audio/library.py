"""Shared audio helpers for turning recorded library files into game sounds.

numpy only: read any common WAV (16/24/32-bit PCM, 32/64-bit float, extensible
headers), resample, filter, match loudness, cut seamless loops, write 16-bit WAV.
Used by import_sounds.py (the recipes) and audition.py (candidates to listen to).
"""

import os
import struct

import numpy as np

RATE = 44100


def read_wav(path):
    """Returns (samples as float32 array [frames, channels], sample rate)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("not a WAV file: %s" % path)
    pos = 12
    fmt = None
    pcm = None
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            tag, channels, rate, _, _, bits = struct.unpack("<HHIIHH", body[:16])
            if tag == 0xFFFE and len(body) >= 26:
                tag = struct.unpack("<H", body[24:26])[0]  # The sub-format GUID starts with the tag.
            fmt = (tag, channels, rate, bits)
        elif cid == b"data":
            pcm = body
        pos += 8 + size + (size & 1)
    if fmt is None or pcm is None:
        raise ValueError("no fmt or data chunk: %s" % path)
    tag, channels, rate, bits = fmt
    if tag == 3:
        x = np.frombuffer(pcm[: len(pcm) // (bits // 8) * (bits // 8)], dtype="<f4" if bits == 32 else "<f8").astype(np.float32)
    elif tag == 1 and bits == 16:
        x = np.frombuffer(pcm[: len(pcm) // 2 * 2], dtype="<i2").astype(np.float32) / 32768.0
    elif tag == 1 and bits == 24:
        b = np.frombuffer(pcm[: len(pcm) // 3 * 3], dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v & 0x800000, v - 0x1000000, v)
        x = v.astype(np.float32) / 8388608.0
    elif tag == 1 and bits == 32:
        x = np.frombuffer(pcm[: len(pcm) // 4 * 4], dtype="<i4").astype(np.float32) / 2147483648.0
    elif tag == 1 and bits == 8:
        x = (np.frombuffer(pcm, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        raise ValueError("unsupported WAV format %d / %d bit: %s" % (tag, bits, path))
    frames = len(x) // channels
    return x[: frames * channels].reshape(frames, channels), rate


def write_wav(path, x, rate=RATE):
    """Writes 16-bit PCM; `x` is [frames] (mono) or [frames, channels]."""
    if x.ndim == 1:
        x = x[:, None]
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2")
    channels = x.shape[1]
    body = pcm.tobytes()
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(body)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, channels, rate, rate * channels * 2, channels * 2, 16))
        f.write(b"data" + struct.pack("<I", len(body)) + body)


def to_channels(x, channels):
    if channels == 1:
        return x.mean(axis=1)
    if x.shape[1] == 1:
        return np.repeat(x, channels, axis=1)
    return x[:, :channels]


def resample(x, rate_in, rate_out):
    """FFT resampling (band-limited); fine for clips up to a few minutes."""
    if rate_in == rate_out or len(x) == 0:
        return x
    n_out = int(round(len(x) * rate_out / rate_in))
    spectrum = np.fft.rfft(x, axis=0)
    keep = n_out // 2 + 1
    if spectrum.shape[0] >= keep:
        spectrum = spectrum[:keep]
    else:
        pad = np.zeros((keep - spectrum.shape[0],) + spectrum.shape[1:], dtype=spectrum.dtype)
        spectrum = np.concatenate([spectrum, pad])
    return (np.fft.irfft(spectrum, n_out, axis=0) * (n_out / len(x))).astype(np.float32)


def filtered(x, rate, highpass=None, lowpass=None, order=2):
    """Zero-phase Butterworth-shaped high and low pass in the frequency domain."""
    if not highpass and not lowpass:
        return x
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / rate)
    gain = np.ones_like(f)
    if highpass:
        gain *= 1.0 / np.sqrt(1.0 + (highpass / np.maximum(f, 1e-6)) ** (2 * order))
    if lowpass:
        gain *= 1.0 / np.sqrt(1.0 + (f / lowpass) ** (2 * order))
    spectrum = np.fft.rfft(x, axis=0)
    spectrum *= gain[:, None] if x.ndim > 1 else gain
    return np.fft.irfft(spectrum, n, axis=0).astype(np.float32)


def rms_db(x, rate, gate_db=-50.0):
    """Loudness as gated RMS in dBFS over 50 ms windows (quiet tails don't count)."""
    mono = x if x.ndim == 1 else x.mean(axis=1)
    w = max(1, int(rate * 0.05))
    frames = len(mono) // w
    if frames == 0:
        return 20.0 * np.log10(np.sqrt(np.mean(mono ** 2)) + 1e-9)
    blocks = mono[: frames * w].reshape(frames, w)
    levels = np.sqrt(np.mean(blocks ** 2, axis=1))
    loud = levels[20.0 * np.log10(levels + 1e-9) > gate_db]
    if len(loud) == 0:
        loud = levels
    return 20.0 * np.log10(np.sqrt(np.mean(loud ** 2)) + 1e-9)


def normalized(x, rate, target_db, peak_db=-1.0):
    """Matches loudness, then pulls the peak under `peak_db` with a soft knee."""
    x = x * (10.0 ** ((target_db - rms_db(x, rate)) / 20.0))
    ceiling = 10.0 ** (peak_db / 20.0)
    peak = np.max(np.abs(x)) if len(x) else 0.0
    if peak > ceiling:
        # Soft saturation above the knee keeps transients punchy instead of just quieter.
        knee = ceiling * 0.7
        mag = np.abs(x)
        over = mag > knee
        squeezed = knee + (ceiling - knee) * np.tanh((mag - knee) / (ceiling - knee))
        x = np.where(over, np.sign(x) * squeezed, x)
    return x.astype(np.float32)


def onset(x, rate, before=0.01):
    """Seconds where the loudest hit starts (for one-shots cut from long takes)."""
    mono = np.abs(x if x.ndim == 1 else x.mean(axis=1))
    w = max(1, int(rate * 0.005))
    frames = len(mono) // w
    if frames < 2:
        return 0.0
    env = mono[: frames * w].reshape(frames, w).max(axis=1)
    loudest = int(np.argmax(env))
    threshold = env[loudest] * 0.15
    k = loudest
    while k > 0 and env[k - 1] > threshold:
        k -= 1
    return max(0.0, k * w / rate - before)


def faded(x, rate, fade_in=0.0, fade_out=0.0):
    x = x.copy()
    n_in = min(len(x), int(rate * fade_in))
    n_out = min(len(x), int(rate * fade_out))
    if n_in:
        ramp = np.linspace(0.0, 1.0, n_in) ** 2
        x[:n_in] *= ramp[:, None] if x.ndim > 1 else ramp
    if n_out:
        ramp = np.linspace(1.0, 0.0, n_out) ** 2
        x[-n_out:] *= ramp[:, None] if x.ndim > 1 else ramp
    return x


def seamless(x, rate, crossfade):
    """A loop: the last `crossfade` seconds are blended into the start (equal power), and
    the result is that much shorter, so the end runs straight into the beginning."""
    n = int(rate * crossfade)
    if n <= 0 or len(x) <= 2 * n:
        return x
    body = x[:-n].copy()
    t = np.linspace(0.0, 1.0, n)
    fade_in = np.sin(t * np.pi / 2.0)
    fade_out = np.cos(t * np.pi / 2.0)
    if x.ndim > 1:
        fade_in = fade_in[:, None]
        fade_out = fade_out[:, None]
    body[:n] = x[:n] * fade_in + x[-n:] * fade_out
    return body


def render(spec, library, rate=RATE):
    """One finished sound from a recipe entry: a list of takes, each a float array."""
    channels = int(spec.get("channels", 1))
    takes = []
    for take in spec["takes"]:
        x, src_rate = read_wav(os.path.join(library, take["file"]))
        x = to_channels(x, channels) if channels > 1 else to_channels(x, 1)
        start = take.get("start", 0.0)
        if start == "auto":
            start = onset(x, src_rate)
        a = int(float(start) * src_rate)
        length = take.get("length")
        b = len(x) if length is None else min(len(x), a + int(float(length) * src_rate))
        if spec.get("loop"):
            b = min(len(x), b + int(spec.get("crossfade", 0.3) * src_rate))
        clip = x[a:b]
        # Pitch by resampling: a higher pitch is a shorter, brighter sound.
        pitch = float(take.get("pitch", spec.get("pitch", 1.0)))
        clip = resample(clip, src_rate * pitch, rate)
        clip = filtered(clip, rate, spec.get("highpass"), spec.get("lowpass"))
        clip *= 10.0 ** (float(take.get("gain_db", 0.0)) / 20.0)
        if spec.get("loop"):
            clip = seamless(clip, rate, float(spec.get("crossfade", 0.3)))
        else:
            clip = faded(clip, rate, float(spec.get("fade_in", 0.0)), float(spec.get("fade_out", 0.02)))
        clip = normalized(clip, rate, float(spec.get("loudness", -16.0)), float(spec.get("peak", -1.0)))
        takes.append(clip)
    return takes
