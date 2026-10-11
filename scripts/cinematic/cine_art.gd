class_name CineArt
extends RefCounted
## All the drawing for the first-boot cinematic. Everything is procedural low-poly, like the game.
## Pure functions of time `t` (seconds since the cinematic started): `draw()` paints the scene, `draw_light()`
## paints the additive glow pass (lamps, monitor light, moonlight) onto a second, additively blended item.
##
## Timeline (the score in tools/generate_cinematic_audio.py is cut to the same beats):
##    0.0  night forest, slow push toward the cabin       |  24.0  the PC wakes by itself
##   11.7  inside: he is working at his PC                |  24.6  text types itself, 27.4 the logo appears
##   20.4  the lamp flickers                              |  30.0  the screen glitches and distorts
##   21.0  POWER CUT, he panics and grabs his lantern     |  31.6  he is pulled into the screen
##   33.0  camera pushes into the monitor                 |  38.3  white-out, 40.0 cut into the game world
##
## Coordinates: a 1280x720 "design" space. `vs`/`vo` = cover-scale and offset that map it onto the real
## screen, so the picture fills any aspect ratio (the important action stays in the central 16:9 area).

const T_INT := 11.7
const T_FLICKER := 20.4
const T_CUT := 21.0
const T_WAKE := 24.0
const T_TEXT := 24.6
const T_LOGO := 27.4
const T_GLITCH := 30.0
const T_PULL := 31.6
const T_SUCK := 35.2
const T_ZOOM := 33.0
const T_FLASH := 38.3
const T_END := 40.0

const MONITOR := Rect2(925.0, 250.0, 231.0, 130.0)   ## the screen glass, in room coordinates
const END_COL := Color(0.80, 0.92, 1.0)              ## the colour the cinematic ends on (the game fades in from it)

static var _logo: Texture2D


# ======================================================================================== helpers
static func _e(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _io(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(x, 0.0, 1.0))


static func _h(n: float) -> float:
	return Gfx.hash1(n)


## Layer transform: design-space points of a parallax layer (scaled by `s` about world anchor `aw`)
## land so that `aw` appears at screen anchor `an`.
static func _layer(ci: CanvasItem, vs: float, vo: Vector2, s: float, aw: Vector2, an: Vector2) -> void:
	ci.draw_set_transform(vo + (an - aw * s) * vs, 0.0, Vector2(vs * s, vs * s))


## Intensity of the screen distortion (also drives the grade shader's tearing in the controller).
static func glitch(t: float) -> float:
	if t < T_GLITCH:
		return 0.0
	return clampf(0.3 + 0.7 * _e((t - T_GLITCH) / 4.5), 0.0, 1.0)


## 0..1 white-out at the very end.
static func whiteout(t: float) -> float:
	return _e((t - T_FLASH) / 1.2)


# ======================================================================================== frame entry
static func draw(ci: CanvasItem, t: float, view: Vector2) -> void:
	var vs := maxf(view.x / 1280.0, view.y / 720.0)
	var vo := (view - Vector2(1280.0, 720.0) * vs) * 0.5
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))
	ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(0.008, 0.006, 0.016))
	if t < T_INT:
		exterior(ci, t, vs, vo)
	else:
		interior(ci, t, vs, vo)
	# screen-space overlays
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))
	var fa := _e((t - 10.5) / 1.1) * (1.0 - _e((t - T_INT) / 1.6))   # the window's warm light swallows the lens, then lets go
	if fa > 0.0:
		ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(1.0, 0.84, 0.52, 0.96 * fa))
	var wa := whiteout(t)
	if wa > 0.0:
		ci.draw_rect(Rect2(-1500.0, -1000.0, 4300.0, 2700.0), Color(END_COL.r, END_COL.g, END_COL.b, wa))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_light(ci: CanvasItem, t: float, view: Vector2) -> void:
	var vs := maxf(view.x / 1280.0, view.y / 720.0)
	var vo := (view - Vector2(1280.0, 720.0) * vs) * 0.5
	if t < T_INT:
		exterior_light(ci, t, vs, vo)
	else:
		interior_light(ci, t, vs, vo)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ======================================================================================== EXTERIOR
static func _ext_z(t: float) -> float:
	return pow(16.0, _io(t / 11.6))


static func _ext_anchor(t: float) -> Vector2:
	return Vector2(628.0, 468.0).lerp(Vector2(640.0, 360.0), _e(t / 9.5)) + Vector2(sin(t * 0.8) * 2.0, cos(t * 0.6) * 1.5)


const HOUSE := Vector2(628.0, 468.0)   ## the lit window: where the camera is heading


static func exterior(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	var z := _ext_z(t)
	var an := _ext_anchor(t)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.03, HOUSE, an)
	_sky(ci, t)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.10, HOUSE, an)
	_hills(ci)
	Gfx.glow_ellipse(ci, Vector2(640.0, 505.0), 1100.0, 90.0, Color(0.30, 0.36, 0.66, 0.16))
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.26, HOUSE, an)
	_trees(ci, 1.0, 46, -760.0, 62.0, 506.0, 150.0, 250.0, Color(0.032, 0.046, 0.10), 150.0, false)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 0.50, HOUSE, an)
	Gfx.glow_ellipse(ci, Vector2(640.0, 520.0), 1000.0, 60.0, Color(0.34, 0.42, 0.75, 0.13))
	_trees(ci, 5.0, 26, -680.0, 112.0, 516.0, 230.0, 380.0, Color(0.018, 0.028, 0.068), 170.0, true)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 1.0, HOUSE, an)
	_house(ci, t, z)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 1.55, HOUSE, an)
	_foreground(ci, t)


static func exterior_light(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	var z := _ext_z(t)
	var an := _ext_anchor(t)
	_layer(ci, vs, vo, 1.0 + (z - 1.0) * 1.0, HOUSE, an)
	var fl := 0.9 + 0.1 * sin(t * 7.0) * sin(t * 3.1)
	Gfx.glow(ci, HOUSE, 170.0, Color(1.0, 0.70, 0.30, 0.42 * fl))
	Gfx.glow_ellipse(ci, Vector2(628.0, 505.0), 190.0, 28.0, Color(1.0, 0.66, 0.28, 0.20 * fl))
	for i in 12:
		var h1 := _h(float(i) * 2.3 + 40.0)
		var h2 := _h(float(i) * 5.1 + 41.0)
		var fp := Vector2(330.0 + h1 * 640.0 + sin(t * 0.6 + h1 * 9.0) * 22.0, 430.0 + h2 * 85.0 + cos(t * 0.5 + h2 * 7.0) * 12.0)
		var pu := 0.5 + 0.5 * sin(t * (1.2 + h1) + h2 * 30.0)
		Gfx.glow(ci, fp, 9.0 + 5.0 * pu, Color(0.8, 1.0, 0.4, 0.25 + 0.5 * pu))


static func _sky(ci: CanvasItem, t: float) -> void:
	Gfx.vquad(ci, -1600.0, 2900.0, -1400.0, 330.0, Color(0.008, 0.012, 0.045), Color(0.04, 0.05, 0.13))
	Gfx.vquad(ci, -1600.0, 2900.0, 330.0, 560.0, Color(0.04, 0.05, 0.13), Color(0.13, 0.15, 0.30))
	for i in 110:
		var h1 := _h(float(i) * 3.1)
		var h2 := _h(float(i) * 7.7 + 1.0)
		var sp := Vector2(-250.0 + h1 * 1780.0, -300.0 + h2 * 700.0)
		var tw := 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (1.0 + 2.0 * h1) + h2 * 40.0))
		ci.draw_circle(sp, 0.7 + 1.1 * h2 * h2, Color(0.8, 0.86, 1.0, tw * (1.0 - clampf((sp.y - 150.0) / 300.0, 0.0, 0.8))))
	var mp := Vector2(930.0, 150.0)
	Gfx.glow(ci, mp, 380.0, Color(0.35, 0.45, 0.9, 0.35))
	Gfx.glow(ci, mp, 150.0, Color(0.7, 0.8, 1.0, 0.35))
	ci.draw_circle(mp, 46.0, Color(0.86, 0.9, 1.0))
	ci.draw_circle(mp + Vector2(-14.0, -10.0), 9.0, Color(0.74, 0.8, 0.94))
	ci.draw_circle(mp + Vector2(16.0, 12.0), 12.0, Color(0.78, 0.84, 0.96))
	ci.draw_circle(mp + Vector2(8.0, -22.0), 5.0, Color(0.74, 0.8, 0.94))
	for i in 3:
		var cx := fposmod(t * (6.0 + 3.0 * float(i)) + float(i) * 400.0, 1700.0) - 300.0
		Gfx.glow_ellipse(ci, Vector2(cx, 120.0 + float(i) * 55.0), 210.0, 14.0, Color(0.35, 0.42, 0.7, 0.16))


static func _hills(ci: CanvasItem) -> void:
	for r in 2:
		var pts := PackedVector2Array()
		var base := 462.0 + float(r) * 26.0
		pts.append(Vector2(-1600.0, 900.0))
		for i in range(0, 53):
			var x := -1600.0 + float(i) * 80.0
			pts.append(Vector2(x, base - 22.0 * sin(x * 0.0045 + float(r) * 2.0) - 12.0 * sin(x * 0.012 + 1.0 + float(r))))
		pts.append(Vector2(2700.0, 900.0))
		ci.draw_colored_polygon(pts, Color(0.05, 0.06, 0.14).lerp(Color(0.02, 0.025, 0.07), float(r) * 0.6))


## A row of low-poly pines. `clear` leaves a gap around the cabin; `facets` adds the moonlit side of each tier.
static func _trees(ci: CanvasItem, sd: float, count: int, x0: float, step: float, base: float, h0: float, h1: float, col: Color, clear: float, facets: bool) -> void:
	for i in count:
		var hh := _h(sd + float(i) * 1.7)
		var x := x0 + float(i) * step + (_h(sd * 3.0 + float(i)) - 0.5) * step * 0.6
		if absf(x - 640.0) < clear:
			continue
		var h := lerpf(h0, h1, hh)
		var w := h * 0.32
		ci.draw_rect(Rect2(x - w * 0.06, base - h * 0.14, w * 0.12, h * 0.16), col)
		for k in 3:
			var top := base - h * (1.0 - 0.22 * float(k))
			var bot := base - h * (0.52 - 0.22 * float(k))
			var half := w * (0.50 + 0.22 * float(k))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bot), Vector2(x - half, bot)]), col)
			if facets:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bot), Vector2(x + half * 0.15, bot)]), col.lightened(0.16))


static func _house(ci: CanvasItem, t: float, z: float) -> void:
	# ground, a moonlit rim of grass, and the path to the door
	ci.draw_rect(Rect2(-2500.0, 500.0, 6000.0, 1800.0), Color(0.02, 0.03, 0.055))
	Gfx.vquad(ci, -2500.0, 3700.0, 500.0, 548.0, Color(0.06, 0.075, 0.14), Color(0.02, 0.03, 0.055))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(662.0, 500.0), Vector2(684.0, 500.0), Vector2(860.0, 900.0), Vector2(500.0, 900.0)]), Color(0.10, 0.11, 0.18))
	for i in 14:
		var gx := 330.0 + float(i) * 44.0
		ci.draw_line(Vector2(gx, 502.0), Vector2(gx + sin(t * 1.3 + float(i)) * 3.0, 490.0 - _h(float(i)) * 8.0), Color(0.05, 0.08, 0.12), 1.6)
	# the cabin
	Gfx.vquad(ci, 565.0, 715.0, 438.0, 500.0, Color(0.15, 0.11, 0.11), Color(0.07, 0.055, 0.06))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(640.0, 438.0), Vector2(715.0, 438.0), Vector2(715.0, 500.0), Vector2(640.0, 500.0)]), Color(0.18, 0.14, 0.17, 0.35))
	for i in 10:
		ci.draw_line(Vector2(565.0 + 15.0 * float(i), 438.0), Vector2(565.0 + 15.0 * float(i), 500.0), Color(0, 0, 0, 0.28), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(544.0, 442.0), Vector2(640.0, 388.0), Vector2(736.0, 442.0)]), Color(0.05, 0.04, 0.07))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(640.0, 388.0), Vector2(736.0, 442.0), Vector2(640.0, 442.0)]), Color(0.09, 0.08, 0.14))
	ci.draw_line(Vector2(640.0, 388.0), Vector2(736.0, 442.0), Color(0.55, 0.62, 0.9, 0.55), 1.6)
	ci.draw_rect(Rect2(684.0, 396.0, 16.0, 34.0), Color(0.06, 0.05, 0.08))
	ci.draw_rect(Rect2(681.0, 392.0, 22.0, 6.0), Color(0.09, 0.08, 0.12))
	for i in 7:   # chimney smoke
		var f := float(i) / 7.0
		var sp := Vector2(692.0 + sin(t * 0.7 + float(i)) * 6.0 + float(i) * 3.5, 388.0 - float(i) * 14.0 - fposmod(t * 9.0, 14.0))
		ci.draw_circle(sp, 5.0 + float(i) * 1.8, Color(0.5, 0.55, 0.75, 0.20 * (1.0 - f)))
	ci.draw_rect(Rect2(660.0, 456.0, 24.0, 44.0), Color(0.04, 0.03, 0.05))
	ci.draw_circle(Vector2(678.0, 480.0), 1.6, Color(0.85, 0.7, 0.4))
	# the window: warm, a figure at a desk just visible inside it
	var fl := 0.9 + 0.1 * sin(t * 7.0) * sin(t * 3.1)
	ci.draw_rect(Rect2(605.0, 449.0, 46.0, 38.0), Color(0.05, 0.04, 0.05))
	Gfx.vquad(ci, 610.0, 646.0, 454.0, 482.0, Color(1.0, 0.82, 0.45).darkened(1.0 - fl), Color(0.85, 0.55, 0.25).darkened(1.0 - fl))
	ci.draw_rect(Rect2(610.0, 474.0, 36.0, 3.0), Color(0.2, 0.12, 0.08))                                  # desk
	ci.draw_rect(Rect2(636.0, 464.0, 8.0, 10.0), Color(0.28, 0.58, 0.92))                                    # monitor glow
	ci.draw_circle(Vector2(623.0, 466.0), 4.2, Color(0.08, 0.05, 0.08))                                    # head
	ci.draw_colored_polygon(PackedVector2Array([Vector2(616.0, 482.0), Vector2(618.0, 470.0), Vector2(628.0, 470.0), Vector2(631.0, 482.0)]), Color(0.1, 0.07, 0.12))
	ci.draw_line(Vector2(628.0, 454.0), Vector2(628.0, 482.0), Color(0.05, 0.04, 0.05), 2.0)
	ci.draw_line(Vector2(610.0, 468.0), Vector2(646.0, 468.0), Color(0.05, 0.04, 0.05), 2.0)
	# a fence
	for i in 8:
		var fx := 520.0 + float(i) * 12.0
		ci.draw_rect(Rect2(fx, 484.0, 3.0, 16.0), Color(0.05, 0.04, 0.06))
		ci.draw_rect(Rect2(740.0 + float(i) * 12.0, 484.0, 3.0, 16.0), Color(0.05, 0.04, 0.06))
	ci.draw_line(Vector2(520.0, 490.0), Vector2(610.0, 490.0), Color(0.05, 0.04, 0.06), 1.4)
	ci.draw_line(Vector2(740.0, 490.0), Vector2(830.0, 490.0), Color(0.05, 0.04, 0.06), 1.4)


## Big dark trunks at the frame edges. They scale fastest, so they sweep past as the camera moves in.
static func _foreground(ci: CanvasItem, t: float) -> void:
	for side in 2:
		var sx := 80.0 if side == 0 else 1200.0
		var d := 1.0 if side == 0 else -1.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 34.0, 800.0), Vector2(sx - 24.0, 100.0), Vector2(sx + 20.0, 90.0), Vector2(sx + 40.0, 800.0)]), Color(0.006, 0.008, 0.02))
		for b in 3:
			var by := 230.0 + float(b) * 120.0
			var tip := Vector2(sx + d * (150.0 + float(b) * 20.0), by - 70.0 + sin(t * 0.5 + float(b)) * 4.0)
			Gfx.capsule(ci, Vector2(sx, by), tip, 20.0, 5.0, Color(0.006, 0.008, 0.02))
	var bxs := [-70.0, 70.0, 200.0, 1090.0, 1210.0, 1350.0]   # only at the frame edges, never in front of the cabin
	for i in bxs.size():
		ci.draw_circle(Vector2(bxs[i], 610.0), 55.0 + _h(float(i) + 9.0) * 35.0, Color(0.005, 0.008, 0.018))
	Gfx.glow_ellipse(ci, Vector2(640.0, 540.0), 900.0, 50.0, Color(0.4, 0.5, 0.8, 0.12))


# ======================================================================================== INTERIOR
## Camera shake: a jolt at the power cut, then a growing tremor with the glitch.
static func _shake(t: float) -> Vector2:
	var g := glitch(t)
	var n := floorf(t * 22.0)
	var s := Vector2(_h(n) - 0.5, _h(n + 7.0) - 0.5) * 9.0 * g * g
	if t > T_CUT:
		s += Vector2(sin(t * 71.0), cos(t * 53.0)) * 5.0 * exp(-(t - T_CUT) * 6.0)
	return s


## 1 = the lamp is on. It stutters for the last 0.6 s and dies exactly at T_CUT.
static func _lamp(t: float) -> float:
	if t < T_FLICKER:
		return 1.0
	if t >= T_CUT:
		return 0.0
	var u := (t - T_FLICKER) / (T_CUT - T_FLICKER)
	var f := 1.0 - u * 0.45
	if sin(u * 47.0) * sin(u * 29.0 + 1.0) > 0.25:
		f *= 0.15
	if u > 0.93:
		f = 0.0
	return f


static func interior(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	CineRoom.draw(ci, t, vs, vo)   # the 3D cabin: orbiting camera, runner at his PC (see cine_room.gd)


# ======================================================================================== THE SCREEN
const CODE_COLS := [Color(0.40, 0.92, 0.62), Color(0.42, 0.72, 1.0), Color(1.0, 0.72, 0.42), Color(0.82, 0.62, 1.0)]
const TERM_LINES := ["> connection lost", "> searching for user...", "> user found."]


static func screen(ci: CanvasItem, t: float) -> void:
	var r := MONITOR
	var g := glitch(t)
	if t < T_WAKE:
		ci.draw_rect(r, Color(0.02, 0.035, 0.07))
		_code(ci, r, minf(t, T_CUT))
		if t >= T_CUT:   # the display quivers but does not die
			ci.draw_rect(r, Color(0.0, 0.0, 0.02, 0.30 + 0.25 * sin(t * 40.0) * sin(t * 13.0)))
	elif t < T_TEXT:
		ci.draw_rect(r, Color(0.0, 0.0, 0.0))
		var nb := 1.0 - _e((t - T_WAKE) / 0.5)   # one burst of static as it comes up
		for i in 14:
			var ny := r.position.y + _h(float(i) + floorf(t * 30.0)) * r.size.y
			ci.draw_rect(Rect2(r.position.x, ny, r.size.x, 2.0 + 4.0 * _h(float(i) * 3.0)), Color(0.8, 0.9, 1.0, 0.5 * nb))
		if fposmod(t, 0.8) < 0.45:
			ci.draw_rect(Rect2(r.position.x + 12.0, r.position.y + 14.0, 7.0, 11.0), Color(0.5, 1.0, 0.7))
	elif t < T_ZOOM + 3.2:
		ci.draw_rect(r, Color(0.0, 0.01, 0.02))
		_terminal(ci, r, t, g)
	else:
		ci.draw_rect(r, Color(0.0, 0.01, 0.02))
		_tunnel(ci, r, t)
	# scanlines + a faint glass sheen
	for i in range(0, 33):
		ci.draw_line(r.position + Vector2(0.0, float(i) * 4.0), r.position + Vector2(r.size.x, float(i) * 4.0), Color(0, 0, 0, 0.16), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.5, 0.0), r.position + Vector2(r.size.x * 0.25, r.size.y), r.position + Vector2(0.0, r.size.y)]), Color(1, 1, 1, 0.035))


static func _code(ci: CanvasItem, r: Rect2, t: float) -> void:
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 12.0), Color(0.06, 0.08, 0.14))
	for i in 3:
		ci.draw_circle(r.position + Vector2(8.0 + float(i) * 8.0, 6.0), 2.0, Color(0.9 - 0.3 * float(i), 0.3 + 0.3 * float(i), 0.3))
	ci.draw_rect(Rect2(r.position.x, r.position.y + 12.0, 30.0, r.size.y - 12.0), Color(0.03, 0.045, 0.09))
	var off := fposmod(t * 14.0, 10.0)
	var base := floori(t * 1.4)
	var last_end := r.position
	for i in 12:
		var idx := float(base + i)
		var hh := _h(idx * 1.37)
		var ind := floorf(_h(idx * 2.11) * 4.0) * 12.0
		var ln := 22.0 + hh * 130.0
		var y := r.position.y + 18.0 + float(i) * 10.0 - off
		if y < r.position.y + 13.0 or y > r.end.y - 4.0:
			continue
		ci.draw_rect(Rect2(r.position.x + 4.0, y, 18.0, 3.0), Color(0.25, 0.3, 0.45, 0.6))
		var col: Color = CODE_COLS[int(floorf(_h(idx * 3.7) * 4.0)) % 4]
		ci.draw_rect(Rect2(r.position.x + 36.0 + ind, y, minf(ln, r.size.x - 44.0 - ind), 3.0), Color(col.r, col.g, col.b, 0.85))
		if hh > 0.45:
			ci.draw_rect(Rect2(r.position.x + 36.0 + ind + minf(ln, r.size.x - 44.0 - ind) + 5.0, y, 24.0 + 30.0 * hh, 3.0), Color(0.85, 0.85, 0.95, 0.55))
		last_end = Vector2(r.position.x + 36.0 + ind + minf(ln, r.size.x - 44.0 - ind) + 4.0, y)
	if fposmod(t, 0.9) < 0.55:
		ci.draw_rect(Rect2(last_end.x, last_end.y - 3.0, 4.0, 9.0), Color(0.9, 0.95, 1.0, 0.9))


static func _terminal(ci: CanvasItem, r: Rect2, t: float, g: float) -> void:
	var f: Font = GameState.f_ui
	var starts := [T_TEXT, T_TEXT + 1.2, T_TEXT + 2.3]
	for i in TERM_LINES.size():
		var s: String = TERM_LINES[i]
		var n := clampi(int((t - starts[i]) * 26.0), 0, s.length())
		if n <= 0:
			continue
		var jx := 0.0
		if g > 0.0 and _h(float(i) + floorf(t * 14.0)) > 0.6:
			jx = (_h(float(i) * 3.0 + floorf(t * 14.0)) - 0.5) * 22.0 * g
		ci.draw_string(f, r.position + Vector2(12.0 + jx + 1.0, 24.0 + float(i) * 14.0 + 1.0), s.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.0, 0.3, 0.2, 0.7))
		ci.draw_string(f, r.position + Vector2(12.0 + jx, 24.0 + float(i) * 14.0), s.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 1.0, 0.75))
	# the title card
	var la := _e((t - T_LOGO) / 0.9)
	if la <= 0.0:
		return
	if _logo == null:
		_logo = load("res://assets/images/logo.png") as Texture2D
	if _logo == null:
		return
	var w := r.size.x * 0.86
	var h := w * float(_logo.get_height()) / float(_logo.get_width())
	var c := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.66)
	var flick := 0.8 + 0.2 * sin(t * 45.0) * sin(t * 11.0)
	if g <= 0.0:
		ci.draw_texture_rect(_logo, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), false, Color(1, 1, 1, la * flick))
		return
	# glitching: the title is cut into strips that slide apart, with colour-split ghosts behind it
	var n := 12
	var tw := float(_logo.get_width())
	var th := float(_logo.get_height())
	for k in 2:
		var ghost := Color(1.0, 0.1, 0.3, 0.45 * g) if k == 0 else Color(0.1, 0.9, 1.0, 0.45 * g)
		var dx := (3.0 + 5.0 * g) * (1.0 if k == 0 else -1.0)
		ci.draw_texture_rect(_logo, Rect2(c.x - w * 0.5 + dx, c.y - h * 0.5, w, h), false, ghost)
	for i in n:
		var sy := th * float(i) / float(n)
		var hs := _h(float(i) + floorf(t * 13.0) * 1.7)
		var sl := (hs - 0.5) * 34.0 * g * (1.0 if hs > 0.35 else 0.0)
		ci.draw_texture_rect_region(_logo, Rect2(c.x - w * 0.5 + sl, c.y - h * 0.5 + h * float(i) / float(n), w, h / float(n)), Rect2(0.0, sy, tw, th / float(n)), Color(1, 1, 1, la * flick))
	for i in 5:   # blocks of corruption
		var bx := r.position.x + _h(float(i) + floorf(t * 17.0)) * r.size.x
		var by := r.position.y + _h(float(i) * 4.0 + floorf(t * 17.0)) * r.size.y
		ci.draw_rect(Rect2(bx, by, 10.0 + 40.0 * _h(float(i) * 9.0), 2.0 + 5.0 * _h(float(i) * 6.0)), Color(0.9, 0.95, 1.0, 0.7 * g))


## What lies beyond the glass: a tunnel of rectangles rushing toward you.
static func _tunnel(ci: CanvasItem, r: Rect2, t: float) -> void:
	var c := r.position + r.size * 0.5
	var sp := (t - T_ZOOM) * 0.7
	for i in 14:
		var f := fposmod(float(i) / 14.0 + sp, 1.0)
		var k := pow(f, 2.2)
		var hw := r.size.x * 0.5 * (0.06 + 1.4 * k)
		var hh := r.size.y * 0.5 * (0.06 + 1.4 * k)
		var col := Color(0.3, 0.9, 1.0, 1.0 * (1.0 - f)) if i % 2 == 0 else Color(1.0, 0.3, 0.7, 0.9 * (1.0 - f))
		ci.draw_rect(Rect2(c.x - hw + (_h(float(i) + floorf(t * 20.0)) - 0.5) * 6.0, c.y - hh, hw * 2.0, hh * 2.0), col, false, 2.4 + 4.0 * k)
	for i in 30:
		var ang := _h(float(i) * 1.9) * TAU
		var d := fposmod(_h(float(i) * 4.4) + sp * 1.7, 1.0)
		ci.draw_line(c + Vector2(cos(ang), sin(ang)) * d * 120.0, c + Vector2(cos(ang), sin(ang)) * (d * 120.0 + 18.0 * d), Color(0.8, 0.95, 1.0, 0.8 * d), 1.2)


# ======================================================================================== LIGHT PASS (additive)
static func _mon_i(t: float) -> float:
	var v := 0.22
	if t >= T_CUT and t < T_WAKE:
		v = 0.22 + 0.06 * sin(t * 30.0)
	if t >= T_WAKE:
		v = 0.55 - 0.2 * _e((t - T_WAKE) / 2.0)
	if t >= T_GLITCH:
		v = 0.4 + 0.5 * glitch(t) * (0.5 + 0.5 * sin(t * 37.0 + _h(floorf(t * 18.0)) * 9.0))
	return v


static func interior_light(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	CineRoom.draw_light(ci, t, vs, vo)
