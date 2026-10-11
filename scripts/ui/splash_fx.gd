class_name SplashFx
extends RefCounted
## The glitch on the second launch splash, as pure functions of `tb` (seconds since splash 2 appeared).
## Nothing here draws or keeps state, so the picture and the sound are always in step:
## tools/generate_splash_audio.py reads BURSTS / DROPS / FLICKER_IN / LENGTH straight from this file.
##
## The idea is "subtle": a whisper of instability is always there (a 1-pixel colour fringe, an occasional
## one-frame slipped row, a slow push-in), and a few short, escalating bursts break through it.

const LENGTH := 3.9          ## how long splash 2 is on screen (the SFX is exactly this long)
const FLICKER_IN := 0.55     ## the picture stutters on instead of fading in
## [start, length, strength 0..1]: the bursts (the last one is the glitch-out as it fades to black)
const BURSTS: Array[Vector3] = [Vector3(1.05, 0.22, 0.45), Vector3(1.78, 0.14, 0.30), Vector3(2.10, 0.34, 0.85), Vector3(2.85, 0.12, 0.30), Vector3(3.25, 0.30, 1.00)]
## one-to-three-frame blinks where the picture drops out, hidden inside the bursts
const DROPS: Array[float] = [1.13, 2.18, 3.30]
const DROP_LEN := 0.05


static func hash1(n: float) -> float:
	return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)


## 0..1: how hard the picture is glitching right now.
static func strength(tb: float) -> float:
	var g := 0.07 + 0.03 * sin(tb * 3.1)
	for b in BURSTS:
		var u := (tb - b.x) / b.y
		if u >= 0.0 and u <= 1.0:
			g = maxf(g, b.z * (1.0 - u * 0.6))
	if tb < FLICKER_IN:
		g = maxf(g, 0.2 + 0.7 * (1.0 - tb / FLICKER_IN))
	return clampf(g, 0.0, 1.0)


## 0..1: picture brightness. Stutters on at the start, blinks out for a few frames inside the big bursts, and
## otherwise breathes very slightly (a slow sag, a little flicker that grows with the glitch).
static func brightness(tb: float) -> float:
	if tb < FLICKER_IN:
		var p := smoothstep(0.0, FLICKER_IN, tb)
		return 1.0 if hash1(floorf(tb * 24.0)) < 0.22 + 0.78 * p else 0.0
	for d in DROPS:
		if tb >= d and tb < d + DROP_LEN:
			return 0.12
	var g := strength(tb)
	var l := 0.965 + 0.035 * sin(tb * 5.65) - 0.07 * g * hash1(floorf(tb * 30.0))
	return clampf(l, 0.0, 1.0)


## Slow creeping push-in (uniform scale) over the whole splash.
static func zoom(tb: float) -> float:
	return 1.0 + 0.045 * smoothstep(0.0, LENGTH, tb)


## Camera-shake offset in design units; only really there during a burst.
static func shake(tb: float) -> Vector2:
	var g := strength(tb)
	var k := floorf(tb * 30.0)
	var amp := 5.0 * g * g
	return Vector2(hash1(k * 1.7) - 0.5, hash1(k * 2.9 + 4.0) - 0.5) * 2.0 * amp


## Colour-fringe distance in design units (red one way, cyan the other).
static func chroma(tb: float) -> float:
	return 0.9 + 6.5 * strength(tb)


## Strength of the red/cyan ghost copies.
static func ghost_alpha(tb: float) -> float:
	return 0.10 + 0.42 * strength(tb)


## The slipped rows for this instant: each is Vector3(y, height, shift) as fractions of the picture
## (height / width). Rows are re-rolled 20 times a second so a tear lives for a few frames, like a real one.
static func tears(tb: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var g := strength(tb)
	var bucket := floorf(tb * 20.0)
	var n := int(roundf(g * 6.0))
	if n == 0 and hash1(bucket * 3.3) > 0.9:
		n = 1   # the idle glitch: every so often a single row slips
	for i in n:
		var h := 0.012 + 0.07 * hash1(bucket * 5.3 + float(i) * 3.1) * (0.4 + g)
		var y := 0.04 + hash1(bucket * 13.1 + float(i) * 7.7) * (0.86 - h)   # aimed at where the picture has content
		var sign := 1.0 if hash1(bucket * 9.7 + float(i) * 1.9) < 0.5 else -1.0
		var amp := (0.004 + 0.03 * g) * (0.45 + 0.55 * hash1(bucket * 2.3 + float(i) * 6.1))   # always a decisive slip, never ~0
		out.append(Vector3(y, h, sign * amp))
	return out
