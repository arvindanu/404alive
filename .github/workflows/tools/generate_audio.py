#!/usr/bin/env python3
"""Procedural sound design for 404: Alive.
Writes 16-bit mono 22.05 kHz WAVs into assets/sounds/. Requires numpy.
Loops (drone, growl, wind) are built from whole-cycle partials / circular FFT noise so they loop seamlessly."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds"))
rng = np.random.default_rng(1313)

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

def save(name, x, loop=False, peak=0.85):
    x = norm(x, peak)
    if not loop:
        n = min(int(SR * 0.004), len(x) // 2); x[-n:] *= np.linspace(1, 0, n)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())

def whisper(seed, syl, lo, hi):
    r = np.random.default_rng(seed); parts = []; t = 0.0
    for _ in range(syl):
        d = r.uniform(0.12, 0.26); n = noise(d)
        s = bpg(n, r.uniform(lo, hi), 0.35) + 0.6 * bpg(n, r.uniform(lo, hi) * 1.7, 0.3)
        parts.append((t, s * np.sin(np.pi * T(d) / d) ** 1.5)); t += d + r.uniform(0.04, 0.12)
    return mix(parts, t + 0.05)

# ---------------- one-shots ----------------
save("jump", add(sweep(190, 460, .16) * env(.16, .004, 14) * .7, bpg(noise(.16), 1200, .6) * env(.16, .002, 30) * .25))
save("land", add(sweep(110, 45, .22) * env(.22, .002, 12), lp(noise(.12), 700) * env(.12, .001, 30) * .8))
n = noise(.5); w = np.linspace(0, 1, len(n))
save("slide", (bpg(n, 1500, .5) * (1 - w) + bpg(n, 450, .5) * w) * np.sin(np.pi * T(.5) / .5) ** 1.5)
save("dash", add(lp(saw_sweep(700, 110, .36), 3000) * env(.36, .005, 7) * .5, bpg(noise(.36), 2500, .7) * env(.36, .01, 6) * .6))
save("hit", np.tanh(2.2 * add(sweep(120, 32, .45) * env(.45, .001, 6), lp(noise(.35), 500) * env(.35, .001, 9) * 1.2)))
save("shard", add(bell(988, .3), .6 * bell(1319, .3)))
save("powerup", mix([(i * .09, bell(f, .5, 6)) for i, f in enumerate([523, 659, 784, 1047])], .9))
save("shield_break", add(hp(noise(.25), 2000) * env(.25, .001, 14), saw_sweep(900, 120, .3) * env(.3, .001, 10) * .4))
n = noise(.45); w = np.linspace(0, 1, len(n))
save("look_in", (bpg(n, 300, .5) * (1 - w) + bpg(n, 1800, .5) * w) * w ** 1.2 + sweep(50, 90, .45) * w * .8)
save("look_out", (bpg(n, 1800, .5) * (1 - w) + bpg(n, 300, .5) * w) * (1 - w) ** 1.2)
save("lunge", np.tanh(3 * add(saw_sweep(70, 28, .8) * env(.8, .01, 2.5), bpg(noise(.8), 300, 1.0) * env(.8, .005, 2.5), sweep(900, 200, .8) * env(.8, .001, 8) * .3)))
save("die", np.tanh(2 * add(saw_sweep(110, 20, 1.8) * env(1.8, .01, 1.6) * .7, lp(noise(1.8), 400) * env(1.8, .01, 2.2) * .8, sweep(60, 25, 1.8) * env(1.8, .005, 1.2))))
save("ui_click", add(sine(1500, .05) * env(.05, .001, 60), hp(noise(.05), 3000) * env(.05, .001, 80) * .4))
save("warn", (sine(1760, .6) + .6 * sine(2637, .6)) * env(.6, .02, 4) * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * T(.6))), peak=.5)
save("thorn_break", add(hp(noise(.3), 1200) * env(.3, .001, 16), lp(noise(.35), 900) * env(.35, .001, 10) * .9, sweep(200, 60, .3) * env(.3, .001, 12) * .8))
t = T(.4); f = 800 + 700 * np.sin(np.pi * t / .4)
save("crow", (np.sin(2 * np.pi * np.cumsum(f) / SR + 3 * np.sin(2 * np.pi * 90 * t)) + .5 * bpg(noise(.4), 2500, .5)) * env(.4, .02, 5) * (0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 30 * t))))
save("step_a", add(lp(noise(.08), 350) * env(.08, .001, 45), sweep(120, 70, .08) * env(.08, .001, 40) * .5))
save("step_b", add(lp(noise(.08), 480) * env(.08, .001, 45), sweep(140, 80, .08) * env(.08, .001, 40) * .5))
save("heartbeat", mix([(0, sweep(70, 42, .16) * env(.16, .002, 18)), (.22, .75 * sweep(62, 40, .18) * env(.18, .002, 16)), (0, lp(noise(.4), 200) * env(.4, .002, 25) * .15)], .6))
save("whisper_a", whisper(1, 4, 1500, 3500), peak=.5)
save("whisper_b", whisper(2, 5, 2000, 4200), peak=.5)
save("whisper_c", whisper(3, 3, 1200, 3000), peak=.5)
chord = sum(saw_sweep(f, f * .98, .9) for f in (220, 233, 311, 330))
save("sting", np.tanh(1.6 * add(chord * env(.9, .005, 3.5) * .5, bpg(noise(.9), 1500, .8) * env(.9, .002, 8))))

# ---------------- seamless loops ----------------
d = 8; t = T(d)
drone = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((27.5, .9), (55, 1), (55.125, .8), (82.5, .5), (110.25, .35)))
drone = drone * (0.75 + 0.25 * np.sin(2 * np.pi * t / d)) + lp(noise(d), 250) * .6
save("drone", np.tanh(1.4 * norm(drone, 1)), loop=True, peak=.7)
d = 4; t = T(d)
am = 0.6 + 0.4 * np.sin(2 * np.pi * 6 * t)
gr = sum(np.sin(2 * np.pi * 41 * k * t) / k for k in range(1, 9)) * am + bpg(noise(d), 350, .6) * am * 3
save("growl", np.tanh(1.8 * norm(gr, 1)), loop=True, peak=.7)
d = 6; t = T(d)
save("wind", (bpg(noise(d), 600, 1.0) + .5 * bpg(noise(d), 180, .6)) * (0.6 + 0.4 * np.sin(2 * np.pi * 2 * t / d)), loop=True, peak=.6)
print("sounds ->", OUT)
print(sorted(os.listdir(OUT)))
