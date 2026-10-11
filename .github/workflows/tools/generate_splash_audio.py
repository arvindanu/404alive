#!/usr/bin/env python3
"""Generates assets/sounds/splash_glitch.wav: the unsettling sound under the second launch splash.
16-bit mono 22.05 kHz, same format as the rest of the game's sounds. Requires numpy.

It is built to sit exactly under the picture. The timing is NOT hard-coded: it is read from
scripts/ui/splash_fx.gd (BURSTS, DROPS, FLICKER_IN, LENGTH, and the very same hash that decides which frames of the
stutter-on are lit), so edit the glitch there, re-run this, and the sound follows.

What you hear:
  * a low, slowly sagging minor-second drone (two detuned saws) that swells toward the big hit
  * a thin, wavering high whine, like blood in your ears
  * a digital zap for every frame that flickers on at the start
  * each burst: a gritty noise tear, a falling bit-crushed chirp, a low thump; the big one gets a rising reverse
    swell into it and a cold metallic ring
  * the picture's one-frame blinks are one-frame dropouts in the sound
  * the glitch-out: a power-down sweep, then nothing

Run from anywhere:  python3 tools/generate_splash_audio.py
"""
import os, re, wave
import numpy as np

SR = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FX = os.path.join(ROOT, "scripts", "ui", "splash_fx.gd")
OUT = os.path.join(ROOT, "assets", "sounds", "splash_glitch.wav")
rng = np.random.default_rng(404)

# ------------------------------------------------------------------ the schedule, straight from splash_fx.gd
src = open(FX, encoding="utf-8").read()
def const(name, default):
    m = re.search(r"const\s+%s\s*(?::[^=]+)?=\s*([0-9.]+)" % name, src)
    return float(m.group(1)) if m else default
LENGTH = const("LENGTH", 3.9)
FLICKER_IN = const("FLICKER_IN", 0.55)
DROP_LEN = const("DROP_LEN", 0.05)
bm = re.search(r"const\s+BURSTS[^=]*=\s*\[(.*?)\]\s*\n", src, re.S)
BURSTS = [tuple(float(x) for x in m) for m in re.findall(r"Vector3\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)", bm.group(1))] if bm else [(1.05, 0.22, 0.45), (1.78, 0.14, 0.30), (2.10, 0.34, 0.85), (2.85, 0.12, 0.30), (3.25, 0.30, 1.00)]
dm = re.search(r"const\s+DROPS[^=]*=\s*\[(.*?)\]", src, re.S)
DROPS = [float(x) for x in re.findall(r"[0-9]+\.[0-9]+", dm.group(1))] if dm else [1.13, 2.18, 3.30]

def hash1(n):   # the same hash as SplashFx.hash1
    x = np.sin(n * 127.1 + 311.7) * 43758.5453
    return x - np.floor(x)

# ------------------------------------------------------------------ small synth kit
def T(d): return np.arange(int(SR * d)) / SR
def sine(f, d): return np.sin(2 * np.pi * f * T(d))
def sweep(f0, f1, d):
    t = T(d); f = f0 * (f1 / f0) ** (t / d); return np.sin(2 * np.pi * np.cumsum(f) / SR)
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def env(d, a=0.004, k=8.0):
    t = T(d); return np.minimum(t / a, 1) * np.exp(-k * t)
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def bpg(x, fc, bw=0.5):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR) + 1e-3
    return np.fft.irfft(X * np.exp(-0.5 * ((np.log(f) - np.log(fc)) / bw) ** 2), len(x))
def lp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / fc) ** 4), len(x))
def sweep_band(x, f0, f1, bw=0.6, frame=1024):
    n = len(x); hop = frame // 2; win = np.hanning(frame); out = np.zeros(n + frame); fr = np.fft.rfftfreq(frame, 1 / SR) + 1e-3
    for i in range(0, n, hop):
        seg = np.zeros(frame); m = min(frame, n - i); seg[:m] = x[i:i + m]
        fc = f0 * (f1 / f0) ** min(i / max(n, 1), 1.0)
        out[i:i + frame] += np.fft.irfft(np.fft.rfft(seg * win) * np.exp(-0.5 * ((np.log(fr) - np.log(fc)) / bw) ** 2), frame) * win
    return out[:n]
def bitcrush(x, bits=4, hold=4):
    q = 2 ** bits; y = np.round(x * q) / q
    return np.repeat(y[::hold], hold)[:len(x)]
def put(buf, at, x, gain=1.0):
    i = int(SR * at)
    if i >= len(buf): return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n] * gain

# ------------------------------------------------------------------ build
L = LENGTH
t = T(L)
out = np.zeros(len(t))
final_t = BURSTS[-1][0]                                          # the last burst IS the glitch-out
pre = BURSTS[:-1]                                                # the ones before it
main_k = max(b[2] for b in pre)                                  # the biggest of those is the hit everything builds to
big_t = [b for b in pre if b[2] == main_k][0][0]

# 1) the drone: two saws a minor second apart (they beat against each other), sagging ~2.5 semitones
sag = 2 ** (-2.5 / 12 * smooth(0, L, t))
def saw(f): return 2 * ((np.cumsum(f) / SR) % 1) - 1
drone = lp(saw(55.0 * sag) + 0.8 * saw(55.0 * 1.0595 * sag), 240)
swell = (0.18 + 0.82 * smooth(0.15, big_t + 0.05, t)) * (1 - smooth(final_t - 0.05, final_t + 0.2, t))
out += drone * swell * 0.55
out += lp(noise(L), 160) * smooth(0.4, big_t, t) * (1 - smooth(final_t, final_t + 0.2, t)) * 0.30   # a rumble under it

# 2) the whine in your ears: thin, wavering, only present once the room has gone wrong
trem = (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * t)) ** 2
whine = (np.sin(2 * np.pi * np.cumsum(2350 * (1 + 0.004 * np.sin(2 * np.pi * 5.3 * t))) / SR)) * trem
out += whine * smooth(0.8, big_t, t) * (1 - smooth(final_t - 0.05, final_t + 0.15, t)) * 0.05

# 3) every lit frame of the stutter-on gets a digital zap (same hash, same 24 Hz buckets as the picture)
for b in range(int(FLICKER_IN * 24) + 1):
    tb = b / 24.0
    if tb >= FLICKER_IN: break
    p = float(smooth(0.0, FLICKER_IN, tb))
    if hash1(float(b)) < 0.22 + 0.78 * p:
        z = bitcrush(bpg(noise(0.04), 2600 + 2000 * hash1(b * 1.3), 0.7), 3, 3) * env(0.04, 0.001, 55)
        put(out, tb, z, 0.5 + 0.4 * p)

# 4) the bursts
for (t0, dur, k) in BURSTS:
    d = max(dur, 0.12)
    if t0 >= final_t:
        continue   # the glitch-out is built separately below
    put(out, t0, bpg(noise(d), 1500, 0.9) * env(d, 0.002, 5.0 / d) * 0.55, k)                      # a gritty tear
    put(out, t0, bitcrush(sweep(1100, 180, d), 3, 5) * env(d, 0.002, 4.0 / d) * 0.28, k)           # a falling, crushed chirp
    put(out, t0, sweep(115, 38, 0.32) * env(0.32, 0.002, 8.0) * (0.95 if k >= main_k else 0.5), k)  # the low thump
    if k >= main_k:
        riser = sweep_band(noise(0.55), 260, 3600, 0.7) * np.linspace(0, 1, int(SR * 0.55)) ** 2.2   # a reverse swell into the hit
        put(out, t0 - 0.55, riser, 0.9)
        for ratio, g in [(1.0, 1.0), (1.51, 0.7), (2.19, 0.5), (3.07, 0.35)]:                       # a cold, inharmonic ring
            put(out, t0, sine(233.0 * ratio, 1.3) * env(1.3, 0.002, 3.2 + 2 * ratio), 0.16 * g)

# 5) the glitch-out: a stutter, a power-down, then silence
seed = bpg(noise(0.1), 800, 0.8) + 0.6 * np.sin(2 * np.pi * 180 * T(0.1))
for i in range(4):
    chunk = seed[:int(SR * (0.07 - 0.012 * i))] * np.hanning(int(SR * (0.07 - 0.012 * i)))
    put(out, final_t + 0.0 + i * 0.075, bitcrush(chunk, 3, 4), 0.55)
pd = sweep(900, 45, 0.5) * env(0.5, 0.004, 3.5)
put(out, final_t + 0.05, pd, 0.55)
put(out, final_t, sweep(110, 32, 0.3) * env(0.3, 0.002, 9.0), 0.9)

# 6) the picture blinks out for a few frames: so does the sound
for d0 in DROPS:
    i0, i1 = int(SR * d0), int(SR * (d0 + DROP_LEN))
    gate = np.ones(len(out)); gate[i0:i1] = 0.12
    gate = np.convolve(gate, np.ones(40) / 40, mode="same")   # a few ms of slope so the cut doesn't click
    out *= gate

# a hair of fade-in (no click), and everything is gone by the last frame
out *= smooth(0.0, 0.025, t)
out *= 1 - smooth(L - 0.4, L - 0.02, t)
out = np.tanh(1.5 * out)
out = out / np.abs(out).max() * 0.75
out[-int(SR * 0.004):] *= np.linspace(1, 0, int(SR * 0.004))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(out, -1, 1) * 32767).astype("<i2").tobytes())
print("wrote %s  (%.2fs, bursts %s, drops %s)" % (OUT, len(out) / SR, [b[0] for b in BURSTS], DROPS))
