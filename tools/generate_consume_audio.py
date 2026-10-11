#!/usr/bin/env python3
"""Procedural sound design for the creature + death sequence ("consumption") of 404: Alive.
Writes 16-bit mono 22.05 kHz WAVs into assets/sounds/ (same format as tools/generate_audio.py). Requires numpy.

  con_catch    the claw lands: sub drop, bone-rattle transient, a shriek of the creature's own voice
  con_grab     leathery clamp: creaking joints, a low squeeze
  con_lantern  the lantern is flung: clatter, glass, a flame guttering out
  con_wings    wings flaring: a membrane whoosh with a leathery flutter
  con_suck     the pull toward the jaws: a rising inhale that ends in a drop
  con_gulp     the swallow: a hollow low thud, wet glugs, then a hush
  con_roar     the furnace flares: the crow's shriek, an octave-and-a-half down and a lot bigger
  con_glitch   the game falling apart: stutter, bit-crush, a rising whine
  con_cut      the CRT collapsing: a falling whine, a pop, nothing
  con_step     one heavy footfall (used while it chases you)
  con_breath   a wet rasp on your neck (used when it is right behind you)

Run from anywhere:  python3 tools/generate_consume_audio.py
"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds"))
rng = np.random.default_rng(404)

def T(d): return np.arange(int(SR * d)) / SR
def sine(f, d): return np.sin(2 * np.pi * f * T(d))
def sweep(f0, f1, d):
    t = T(d); f = f0 * (f1 / f0) ** (t / d); return np.sin(2 * np.pi * np.cumsum(f) / SR)
def saw_sweep(f0, f1, d):
    t = T(d); f = f0 * (f1 / f0) ** (t / d); return 2 * ((np.cumsum(f) / SR) % 1) - 1
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def env(d, a=0.004, k=8.0):
    t = T(d); return np.minimum(t / a, 1) * np.exp(-k * t)
def bpg(x, fc, bw=0.5):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR) + 1e-3
    return np.fft.irfft(X * np.exp(-0.5 * ((np.log(f) - np.log(fc)) / bw) ** 2), len(x))
def lp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / fc) ** 4), len(x))
def hp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * (1 - 1 / (1 + (f / fc) ** 4)), len(x))
def add(*xs):
    out = np.zeros(max(len(x) for x in xs))
    for x in xs: out[:len(x)] += x
    return out
def norm(x, peak=0.85): return x / max(np.abs(x).max(), 1e-9) * peak
def mix(parts, d):
    out = np.zeros(int(SR * d))
    for off, x in parts:
        i = int(SR * off); n = min(len(x), len(out) - i)
        if n > 0: out[i:i + n] += x[:n]
    return out
def bell(f, d, k=9.0):
    return (sine(f, d) + 0.5 * sine(f * 2.76, d) * np.exp(-3 * T(d)) + 0.25 * sine(f * 5.4, d) * np.exp(-6 * T(d))) * env(d, 0.002, k)
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def sweep_band(x, f0, f1, bw=0.45, frame=1024):
    """Band-pass whose centre frequency glides f0 -> f1 over the clip (overlap-add, Hann)."""
    n = len(x); hop = frame // 2
    win = np.hanning(frame); out = np.zeros(n + frame); fr = np.fft.rfftfreq(frame, 1 / SR) + 1e-3
    for i in range(0, n, hop):
        seg = np.zeros(frame); m = min(frame, n - i); seg[:m] = x[i:i + m]
        fc = f0 * (f1 / f0) ** (min(i / max(n, 1), 1.0))
        S = np.fft.rfft(seg * win) * np.exp(-0.5 * ((np.log(fr) - np.log(fc)) / bw) ** 2)
        out[i:i + frame] += np.fft.irfft(S, frame) * win
    return out[:n]

def bitcrush(x, bits=5, hold=3):
    q = 2 ** bits; y = np.round(x * q) / q
    return np.repeat(y[::hold], hold)[:len(x)]

def save(name, x, peak=0.85):
    x = norm(x, peak)
    n = min(int(SR * 0.004), len(x) // 2); x[-n:] *= np.linspace(1, 0, n)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("  %-12s %.2fs" % (name, len(x) / SR))

def formant_voice(f0_curve, d, formants, drive=3.0):
    """A saw 'throat' pushed through vocal-tract resonances: the creature's voice."""
    t = T(d); ph = np.cumsum(f0_curve) / SR
    src = 2 * (ph % 1) - 1
    src = src + 0.35 * (2 * ((ph * 2) % 1) - 1)
    out = np.zeros_like(src)
    for fc, bw, g in formants: out += g * bpg(src, fc, bw)
    return np.tanh(out * drive)

os.makedirs(OUT, exist_ok=True)
print("writing to", OUT)

# ---------------------------------------------------------------- catch: the claw lands
d = 1.5; t = T(d)
shriek = formant_voice(300 * (1 + 0.04 * np.sin(2 * np.pi * 9 * t)) * np.exp(-0.6 * t), d, [(1400, 0.30, 1.0), (2600, 0.35, 0.7)], 4.0) * env(d, 0.01, 4.5)
save("con_catch", np.tanh(1.6 * add(
    sweep(105, 24, d) * env(d, 0.002, 2.8) * 1.4,
    bpg(noise(0.5), 2600, 0.7) * env(0.5, 0.001, 10) * 0.6,
    hp(noise(0.14), 4500) * env(0.14, 0.001, 28) * 0.5,
    saw_sweep(180, 48, 0.9) * env(0.9, 0.01, 4.5) * 0.45,
    shriek * 0.45)))

# ---------------------------------------------------------------- grab: leathery clamp
d = 0.8
creak = lambda f0, f1, dur: bpg(saw_sweep(f0, f1, dur) * (1 + 0.5 * sine(31, dur)), (f0 + f1) / 2, 0.6) * env(dur, 0.02, 5)
save("con_grab", np.tanh(1.8 * mix([
    (0.00, sweep(80, 36, 0.5) * env(0.5, 0.002, 7) * 1.1),
    (0.00, bpg(noise(0.35), 900, 0.7) * env(0.35, 0.001, 9) * 0.8),
    (0.04, creak(420, 190, 0.35) * 0.5),
    (0.14, creak(340, 150, 0.4) * 0.4),
    (0.22, hp(noise(0.05), 3000) * env(0.05, 0.001, 40) * 0.5),
    (0.30, sweep(60, 30, 0.5) * env(0.5, 0.01, 6) * 0.7),
], d)))

# ---------------------------------------------------------------- lantern: flung, clatters, dies
d = 1.3
clink = lambda f, dur=0.35: bell(f, dur, 14.0) * 0.8
flame = hp(noise(0.7), 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(np.linspace(26, 7, int(SR * 0.7))) / SR)) * np.exp(-3.2 * T(0.7))
save("con_lantern", mix([
    (0.00, hp(noise(0.08), 2500) * env(0.08, 0.001, 30) * 0.7),
    (0.05, clink(1650)), (0.16, clink(2380) * 0.8), (0.27, clink(1960) * 0.6), (0.36, clink(3050) * 0.45), (0.44, clink(2250) * 0.3),
    (0.05, bpg(noise(0.6), 1200, 0.9) * env(0.6, 0.002, 8) * 0.35),
    (0.20, sweep(150, 60, 0.3) * env(0.3, 0.001, 18) * 0.5),
    (0.50, flame * 0.45),
], d))

# ---------------------------------------------------------------- wings flare: a leathery whoosh
d = 1.7; t = T(d)
body = sweep_band(noise(d), 180, 1100, 0.9) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
flutter = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(np.linspace(9, 22, len(t))) / SR)
save("con_wings", np.tanh(1.5 * add(body * flutter * 1.4, sweep(70, 40, d) * env(d, 0.08, 2.2) * 0.8, hp(noise(d), 3500) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 3 * 0.12)))

# ---------------------------------------------------------------- suck: the inhale toward the jaws
d = 1.75; t = T(d); u = t / d
inhale = sweep_band(noise(d), 140, 3800, 0.7) * (u ** 2.2)
tone = sweep(55, 260, d) * (u ** 2.6) + 0.5 * sweep(110, 520, d) * (u ** 3.0)
x = add(inhale * 1.4, tone * 0.7, sweep(44, 36, d) * 0.5 * smooth(0.0, 0.5, u))
x[int(SR * (d - 0.06)):] *= np.linspace(1, 0, len(x[int(SR * (d - 0.06)):]))   # snaps shut on the gulp
save("con_suck", np.tanh(1.4 * x))

# ---------------------------------------------------------------- gulp: the swallow
d = 2.0
glug = lambda f0, dur: bpg(noise(dur), 340, 0.45) * env(dur, 0.01, 9) * (0.5 + 0.5 * sine(f0, dur))
save("con_gulp", np.tanh(1.7 * mix([
    (0.00, sweep(125, 32, 1.6) * env(1.6, 0.004, 2.4) * 1.5),
    (0.00, lp(noise(0.3), 400) * env(0.3, 0.002, 12) * 1.0),
    (0.06, glug(38, 0.4) * 0.9), (0.30, glug(30, 0.35) * 0.7),
    (0.12, bpg(noise(1.2), 160, 0.5) * env(1.2, 0.05, 2.4) * 0.8),
    (0.60, sweep(60, 28, 1.3) * env(1.3, 0.1, 2.5) * 0.5),
], d)))

# ---------------------------------------------------------------- roar: the crow's shriek, enormous
d = 3.3; t = T(d)
vib = 1 + 0.03 * np.sin(2 * np.pi * 6.5 * t) + 0.015 * np.sin(2 * np.pi * 47 * t)
f0 = (92 - 22 * smooth(0.5, 3.2, t)) * vib
big = formant_voice(f0, d, [(520, 0.35, 1.0), (1100, 0.35, 0.9), (2300, 0.40, 0.55)], 3.5)
scream_f = 560 + 340 * smooth(0.15, 1.2, t) - 120 * smooth(1.8, 3.3, t)
scream = formant_voice(scream_f * (1 + 0.025 * np.sin(2 * np.pi * 11 * t)), d, [(1600, 0.28, 1.0), (3200, 0.32, 0.8)], 3.0)
amp = np.minimum(t / 0.04, 1) * (0.35 + 0.65 * smooth(0.0, 0.35, t)) * np.exp(-0.38 * np.maximum(t - 1.6, 0) ** 1.3)
grit = noise(d) * (0.5 + 0.5 * np.sin(2 * np.pi * 70 * t)) * 0.25
tail = 1 - smooth(2.2, 3.3, t)   # let it die away instead of ending mid-roar
save("con_roar", np.tanh(1.3 * add(
    big * amp * 1.1,
    scream * amp * smooth(0.12, 0.5, t) * 0.6,
    grit * amp,
    sweep(70, 26, d) * env(d, 0.002, 1.7) * 1.3)) * tail, 0.8)

# ---------------------------------------------------------------- glitch: the game coming apart
d = 0.8; t = T(d)
seed = bpg(noise(0.16), 900, 0.8) + 0.6 * sine(220, 0.16)
parts = []; off = 0.0
for i, ln in enumerate([0.16, 0.12, 0.09, 0.06, 0.04, 0.03, 0.02, 0.02, 0.015]):
    k = int(SR * ln); chunk = seed[:k] * np.hanning(k) * 0.9
    for rep in range(2 + i % 2):
        parts.append((off, chunk)); off += ln
    off += 0.01
stutter = bitcrush(mix(parts, d), 4, 4)
whine = sweep(500, 6000, d) * (T(d) / d) ** 2 * (0.5 + 0.5 * sine(33, d)) * 0.5
save("con_glitch", np.tanh(1.8 * add(stutter, whine, hp(noise(d), 4000) * (0.4 + 0.6 * np.sign(sine(41, d))) * 0.18)) * (1 - smooth(0.62, 0.8, T(d))))

# ---------------------------------------------------------------- cut: the CRT dying
d = 1.3
fall = sweep(9000, 380, 0.28) * np.minimum(T(0.28) / 0.005, 1) * (1 - T(0.28) / 0.28) ** 0.5
pop = sweep(140, 45, 0.18) * env(0.18, 0.001, 22)
save("con_cut", mix([
    (0.00, fall * 0.9), (0.00, hp(noise(0.28), 5000) * np.exp(-9 * T(0.28)) * 0.45),
    (0.27, pop * 1.1), (0.27, hp(noise(0.02), 2000) * env(0.02, 0.0005, 80) * 0.8),
    (0.55, bell(5200, 0.12, 40) * 0.12),
], d))

# ---------------------------------------------------------------- step: one heavy footfall
d = 0.5
save("con_step", np.tanh(1.5 * add(
    sweep(76, 31, d) * env(d, 0.002, 9) * 1.3,
    lp(noise(0.12), 420) * env(0.12, 0.001, 24) * 0.9,
    bpg(noise(0.2), 1500, 0.6) * env(0.2, 0.001, 20) * 0.25)))

# ---------------------------------------------------------------- breath: wet, close
d = 1.9; t = T(d)
cyc = np.sin(np.pi * np.clip(t / 1.1, 0, 1)) ** 1.6 * (t < 1.1) + 0.7 * np.sin(np.pi * np.clip((t - 1.0) / 0.9, 0, 1)) ** 1.4 * (t >= 1.0)
rasp = sweep_band(noise(d), 600, 1900, 0.9) * cyc
growl = (0.5 + 0.5 * np.sin(2 * np.pi * 31 * t)) * lp(noise(d), 260) * cyc
save("con_breath", add(rasp * 0.9, growl * 1.2, sweep(60, 52, d) * cyc * 0.4), 0.6)
