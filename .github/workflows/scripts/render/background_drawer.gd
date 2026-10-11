class_name BackgroundDrawer
extends RefCounted
## Layered parallax world with atmospheric perspective. Far layers are hazier and bluer, near
## layers are darker; everything drifts from dusk-violet to blood-black with `dark` (0..1).
## `draw()` paints the world layer (darkened by the lighting shader); `draw_lights()` paints the
## emissive bits (moonlight haze, windows, candles, ground cracks) on the additive glow layer.

const G := Cfg.GROUND_Y
const TREE_STEP := 230.0
const MOON := Vector2(1010.0, 150.0)
const MOON_FAN_W := 128        ## procedural moonlight texture size (it is stretched and smoothly filtered)
const MOON_FAN_H := 96
const MOON_FAN_LEN := 1500.0   ## how far the moonlight reaches from the moon, in design pixels

static var _fan_tex: Texture2D

## Per-index random constants (stars, pebbles, roots, ...). They never change, but used to be recomputed with
## hash1() (a sin + floor each) several hundred times per frame. Built once; the values are identical.
static var _star := PackedFloat64Array()   # 4 per star: x fraction, y fraction, radius, twinkle rate
static var _h0 := PackedFloat64Array()     # hash1(i)      for i < 40 (pebbles, grass blades)
static var _h3 := PackedFloat64Array()     # hash1(i + 3)  for i < 24 (pebbles)
static var _h8 := PackedFloat64Array()     # hash1(i + 8)  for i < 10 (roots)
static var _h5 := PackedFloat64Array()     # hash1(i + 5)  for i < 5  (bones)
static var _h2 := PackedFloat64Array()     # hash1(i + 2)  for i < 6  (puddles)
static var _h6 := PackedFloat64Array()     # hash1(i + 6)  for i < 9  (ground cracks)


static func _init_cache() -> void:
	if _star.size() > 0:
		return
	_star.resize(70 * 4)
	for i in 70:
		var fi := float(i)
		_star[i * 4] = Gfx.hash1(fi)
		_star[i * 4 + 1] = Gfx.hash1(fi + 100.0)
		_star[i * 4 + 2] = 0.8 + Gfx.hash1(fi + 9.0) * 1.2
		_star[i * 4 + 3] = 1.0 + Gfx.hash1(fi + 5.0) * 2.5
	_h0.resize(40)
	for i in 40:
		_h0[i] = Gfx.hash1(float(i))
	_h3.resize(24)
	for i in 24:
		_h3[i] = Gfx.hash1(float(i) + 3.0)
	_h8.resize(10)
	for i in 10:
		_h8[i] = Gfx.hash1(float(i) + 8.0)
	_h5.resize(5)
	for i in 5:
		_h5[i] = Gfx.hash1(float(i) + 5.0)
	_h2.resize(6)
	for i in 6:
		_h2[i] = Gfx.hash1(float(i) + 2.0)
	_h6.resize(9)
	for i in 9:
		_h6[i] = Gfx.hash1(float(i) + 6.0)


static func _l() -> float:
	return -Cfg.ox - 560.0


static func _r() -> float:
	return Cfg.view_w - Cfg.ox + 560.0


static func _t() -> float:
	return -Cfg.oy - 360.0


static func haze(dark: float) -> Color:
	return Color(0.30, 0.22, 0.40).lerp(Color(0.36, 0.04, 0.09), dark)


static func draw(ci: CanvasItem, dist: float, t: float, dark: float, fog: float) -> void:
	_init_cache()
	var L := _l()
	var R := _r()
	var T := _t()
	var span := R - L
	var hz := haze(dark)
	var q := Cfg.quality

	# ---------------------------------------------------------------- sky
	var top := Color(0.035, 0.035, 0.12).lerp(Color(0.05, 0.0, 0.025), dark)
	var mid := Color(0.16, 0.11, 0.30).lerp(Color(0.20, 0.015, 0.06), dark)
	var hor := Color(0.66, 0.38, 0.44).lerp(Color(0.62, 0.07, 0.11), dark)
	Gfx.vquad(ci, L, R, T, G - 300.0, top, mid)
	Gfx.vquad(ci, L, R, G - 300.0, G, mid, hor)
	Gfx.glow_ellipse(ci, Vector2((L + R) * 0.5, G - 40.0), span * 0.6, 200.0, Color(hor.r, hor.g, hor.b, 0.32))
	var star_a := 1.0 - dark * 0.85
	for i in int(70.0 * q):
		var sx := L + fposmod(_star[i * 4] * span - dist * 0.008, span)
		var sy := T + _star[i * 4 + 1] * (G - 340.0 - T)
		var tw := 0.55 + 0.45 * sin(t * _star[i * 4 + 3] + float(i))
		ci.draw_circle(Vector2(sx, sy), _star[i * 4 + 2], Color(1.0, 0.96, 0.9, 0.55 * tw * star_a))

	# moon
	var mc := Color(0.93, 0.92, 0.85).lerp(Color(0.92, 0.16, 0.2), dark)
	var mr := 46.0 + dark * 30.0
	Gfx.glow(ci, MOON, 340.0 + dark * 120.0, Color(mc.r, mc.g, mc.b, 0.20))
	Gfx.glow(ci, MOON, mr * 2.4, Color(mc.r, mc.g, mc.b, 0.30))
	ci.draw_circle(MOON, mr, mc)
	var crater := Color(mc.r * 0.78, mc.g * 0.78, mc.b * 0.8, 0.5)
	ci.draw_circle(MOON + Vector2(-mr * 0.3, -mr * 0.2), mr * 0.2, crater)
	ci.draw_circle(MOON + Vector2(mr * 0.35, mr * 0.25), mr * 0.14, crater)
	ci.draw_circle(MOON + Vector2(-mr * 0.1, mr * 0.45), mr * 0.1, crater)

	# drifting clouds with a moonlit upper edge
	for i in 5:
		var fi := float(i)
		var cx := L + fposmod(fi * 610.0 - dist * 0.02 - t * 9.0, span)
		var cy := G - 330.0 - Gfx.hash1(fi) * 150.0
		Gfx.glow_ellipse(ci, Vector2(cx, cy), 420.0, 34.0 + Gfx.hash1(fi + 2.0) * 22.0, Color(0.05, 0.03, 0.10, 0.55))
		Gfx.glow_ellipse(ci, Vector2(cx + 60.0, cy - 16.0), 260.0, 18.0, Color(mc.r, mc.g, mc.b, 0.05))
	# birds circle overhead as the world sickens
	if dark > 0.25:
		var ba := clampf((dark - 0.25) * 2.0, 0.0, 1.0)
		for i in int(6.0 * q):
			var fi := float(i)
			var bx := L + fposmod(fi * 480.0 - t * 45.0 - dist * 0.02, span)
			var by := G - 380.0 - Gfx.hash1(fi + 3.0) * 120.0 + sin(t * 0.8 + fi) * 10.0
			var fl := sin(t * 9.0 + fi * 2.0) * 7.0
			ci.draw_polyline(PackedVector2Array([Vector2(bx - 12.0, by - fl), Vector2(bx, by), Vector2(bx + 12.0, by - fl)]), Color(0.02, 0.0, 0.03, 0.85 * ba), 2.5, true)

	# ---------------------------------------------------------------- distant silhouettes
	var c_far := Color(0.14, 0.10, 0.24).lerp(Color(0.16, 0.02, 0.06), dark).lerp(hz, 0.35)
	var c_mid := Color(0.09, 0.06, 0.16).lerp(Color(0.10, 0.01, 0.04), dark).lerp(hz, 0.2)
	var pts := PackedVector2Array()
	var off := dist * 0.03
	var x := L
	while x <= R:
		var wx := x + off
		pts.append(Vector2(x, G - 190.0 - absf(sin(wx * 0.004)) * 90.0 - sin(wx * 0.011) * 30.0))
		x += 48.0
	pts.append(Vector2(R, G))
	pts.append(Vector2(L, G))
	Gfx.vgrad(ci, pts, G - 320.0, G, c_far, c_far.lerp(hz, 0.5))
	# jagged dead-pine ridge
	pts = PackedVector2Array()
	off = dist * 0.08
	x = L
	var idx := 0
	while x <= R:
		var wi := floorf((x + off) / 22.0)
		pts.append(Vector2(x, G - 118.0 - Gfx.hash1(wi) * 64.0 - (14.0 if idx % 2 == 0 else 0.0)))
		x += 22.0
		idx += 1
	pts.append(Vector2(R, G))
	pts.append(Vector2(L, G))
	Gfx.vgrad(ci, pts, G - 230.0, G, c_mid, c_mid.lerp(hz, 0.4))

	# ruined chapels (parallax 0.14)
	var o14 := dist * 0.14
	var rc := c_mid.lerp(Color(0.02, 0.0, 0.03), 0.3)
	for i in range(int(floorf((o14 + L) / 1100.0)) - 1, int(ceilf((o14 + R) / 1100.0)) + 1):
		var fi := float(i)
		if Gfx.hash1(fi + 40.0) < 0.3:
			continue
		var rx := fi * 1100.0 - o14 + Gfx.hash1(fi) * 300.0
		var rh := 150.0 + Gfx.hash1(fi + 2.0) * 90.0
		ci.draw_rect(Rect2(rx, G - rh, 90.0, rh), rc)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(rx - 8.0, G - rh), Vector2(rx + 45.0, G - rh - 90.0), Vector2(rx + 98.0, G - rh)]), rc)
		ci.draw_rect(Rect2(rx + 90.0, G - rh * 0.55, 80.0, rh * 0.55), rc)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(rx + 170.0, G - rh * 0.55), Vector2(rx + 150.0, G - rh * 0.8), Vector2(rx + 130.0, G - rh * 0.55)]), rc)
		ci.draw_rect(Rect2(rx - 60.0, G - rh * 0.4, 50.0, rh * 0.4), rc)

	# ---------------------------------------------------------------- dead trees (parallax 0.3)
	var tc := Color(0.075, 0.055, 0.14).lerp(Color(0.035, 0.0, 0.02), dark).lerp(hz, 0.12)
	var o3 := dist * 0.3
	for i in range(int(floorf((o3 + L) / TREE_STEP)) - 1, int(ceilf((o3 + R) / TREE_STEP)) + 1):
		var fi := float(i)
		_tree(ci, fi * TREE_STEP - o3 + Gfx.hash1(fi) * 110.0, 190.0 + Gfx.hash1(fi + 7.0) * 190.0, fi, tc, hz, q)

	# low mist between the tree line and the graveyard
	var fa := 0.08 + fog * 0.16
	for i in 4:
		var fx := L + fposmod(float(i) * 830.0 - dist * 0.2 + t * 18.0, span)
		Gfx.glow_ellipse(ci, Vector2(fx, G - 30.0 - float(i) * 26.0), 430.0, 66.0, Color(hz.r * 1.6, hz.g * 1.5, hz.b * 1.6, fa))

	# ---------------------------------------------------------------- graveyard (parallax 0.7)
	var nc := Color(0.06, 0.045, 0.105).lerp(Color(0.025, 0.0, 0.015), dark).lerp(hz, 0.28)
	var nl := nc.lerp(Color(0.5, 0.5, 0.8), 0.25)
	var o7 := dist * 0.7
	for i in range(int(floorf((o7 + L) / 440.0)) - 1, int(ceilf((o7 + R) / 440.0)) + 1):
		var fi := float(i)
		var nx := fi * 440.0 - o7 + Gfx.hash1(fi + 4.0) * 160.0
		var nh := 28.0 + Gfx.hash1(fi) * 32.0
		var kind := Gfx.hash1(fi + 9.0)
		if kind < 0.30:
			continue   # leave gaps: the foreground hazards must be the only graves that matter
		if kind > 0.80:   # rounded headstone
			ci.draw_rect(Rect2(nx, G - nh, 32.0, nh), nc)
			ci.draw_circle(Vector2(nx + 16.0, G - nh), 16.0, nc)
			ci.draw_line(Vector2(nx + 32.0, G - nh), Vector2(nx + 32.0, G), nl, 2.0)
		elif kind > 0.52:   # cross
			ci.draw_rect(Rect2(nx + 12.0, G - nh - 20.0, 9.0, nh + 20.0), nc)
			ci.draw_rect(Rect2(nx, G - nh + 4.0, 33.0, 8.0), nc)
		else:   # iron fence
			for k in 4:
				var ph := 62.0 + Gfx.hash1(fi + float(k)) * 18.0
				ci.draw_rect(Rect2(nx + float(k) * 34.0, G - ph, 8.0, ph), nc)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(nx + float(k) * 34.0 - 2.0, G - ph), Vector2(nx + float(k) * 34.0 + 10.0, G - ph), Vector2(nx + float(k) * 34.0 + 4.0, G - ph - 14.0)]), nc)
			ci.draw_line(Vector2(nx, G - 46.0), Vector2(nx + 112.0, G - 42.0), nc, 5.0)

	# ---------------------------------------------------------------- ground
	var gc := Color(0.21, 0.165, 0.29).lerp(Color(0.17, 0.04, 0.08), dark)
	var gb := Color(0.05, 0.035, 0.09).lerp(Color(0.03, 0.0, 0.02), dark)
	Gfx.vquad(ci, L, R, G, 900.0, gc, gb)
	var path_a := Color(0.36, 0.29, 0.41).lerp(Color(0.30, 0.07, 0.11), dark)
	var path_b := Color(0.23, 0.18, 0.30).lerp(Color(0.18, 0.04, 0.08), dark)
	Gfx.vquad(ci, L, R, G, G + 60.0, path_a, path_b)                      # worn path
	Gfx.vquad(ci, L, R, G, G + 22.0, Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.0))   # ambient occlusion under the horizon
	ci.draw_line(Vector2(L, G), Vector2(R, G), Color(0.68, 0.58, 0.85, 0.32), 2.5)
	for i in int(24.0 * q):   # cobbles / pebbles
		var fi := float(i)
		var px := L + fposmod(fi * 131.0 - dist, span)
		var py := G + 10.0 + _h0[i] * 120.0
		var pr := 3.0 + _h3[i] * 6.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(px - pr * 1.4, py), Vector2(px, py - pr * 0.6), Vector2(px + pr * 1.4, py), Vector2(px, py + pr * 0.6)]), Color(0, 0, 0, 0.26))
	for i in int(10.0 * q):   # roots
		var fi := float(i)
		var rx2 := L + fposmod(fi * 311.0 - dist, span)
		var ry := G + 24.0 + _h8[i] * 90.0
		ci.draw_polyline(PackedVector2Array([Vector2(rx2, ry), Vector2(rx2 + 40.0, ry - 8.0), Vector2(rx2 + 70.0, ry + 4.0), Vector2(rx2 + 120.0, ry - 4.0)]), Color(0.03, 0.02, 0.05, 0.6), 4.0, true)
	for i in int(5.0 * q):   # scattered bones
		var fi := float(i)
		var bx2 := L + fposmod(fi * 617.0 - dist, span)
		var by2 := G + 30.0 + _h5[i] * 80.0
		Gfx.capsule(ci, Vector2(bx2, by2), Vector2(bx2 + 22.0, by2 - 4.0), 5.0, 5.0, Color(0.55, 0.5, 0.46, 0.7))
	for i in int(6.0 * q):   # puddles
		var fi := float(i)
		var wx2 := L + fposmod(fi * 503.0 - dist, span)
		Gfx.glow_ellipse(ci, Vector2(wx2, G + 44.0 + _h2[i] * 60.0), 70.0, 8.0, Color(0.02, 0.03, 0.09, 0.7))


static func _tree(ci: CanvasItem, x: float, h: float, sd: float, col: Color, hz: Color, q: float) -> void:
	var lean := (Gfx.hash1(sd) - 0.5) * 30.0
	var trunk := PackedVector2Array([Vector2(x - 17.0, G), Vector2(x + 17.0, G), Vector2(x + lean + 5.0, G - h), Vector2(x + lean - 5.0, G - h)])
	Gfx.vgrad(ci, trunk, G - h, G, col, col.lerp(hz, 0.25))
	ci.draw_line(Vector2(x + 16.0, G - 4.0), Vector2(x + lean + 5.0, G - h), Color(0.6, 0.62, 0.9, 0.16), 2.0)   # moon-side rim
	for k in 5:
		var y := G - h * (0.30 + 0.14 * float(k))
		var dir := 1.0 if Gfx.hash1(sd * 9.0 + float(k)) > 0.5 else -1.0
		var l := 50.0 + Gfx.hash1(sd * 3.0 + float(k)) * 76.0
		var a := Vector2(x + lean * (0.3 + 0.14 * float(k)), y)
		var b := a + Vector2(dir * l, -l * 0.6)
		ci.draw_line(a, b, col, 7.0 - float(k) * 0.9, true)
		ci.draw_line(b, b + Vector2(dir * l * 0.4, -l * 0.5), col, 3.5, true)
		if q > 0.7:
			ci.draw_line(b, b + Vector2(dir * l * 0.5, l * 0.1), col, 2.5, true)
	if Gfx.hash1(sd + 11.0) > 0.8:   # a noose
		var r := Vector2(x + 44.0, G - h * 0.55)
		ci.draw_line(r, r + Vector2(0.0, 110.0), col, 3.0)
		ci.draw_arc(r + Vector2(0.0, 124.0), 13.0, 0.0, TAU, 14, col, 3.0)


# ------------------------------------------------------------------ moonlight
## Builds the moonlight "light fan" once: a white texture whose ALPHA is the light. The apex is the top
## centre (the moon), +y is the direction of travel. Alpha = a wide Gaussian spread around the axis
## x a few very low, very wide density undulations (hazy air, never distinct shafts) x a long radial fade
## (soft start at the moon, gone well before the far end), windowed to exactly 0 at the sides.
static func _fan_texture() -> Texture2D:
	if _fan_tex != null:
		return _fan_tex
	var w := MOON_FAN_W
	var h := MOON_FAN_H
	var half_w := float(w) * 0.5 / float(h)
	var sig := deg_to_rad(17.0)
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for y in h:
		var dy := (float(y) + 0.5) / float(h)
		for x in w:
			var dx := (float(x) + 0.5 - float(w) * 0.5) / float(h)
			var r := sqrt(dx * dx + dy * dy)
			var th := atan2(dx, dy)
			var ang := exp(-0.5 * (th / sig) * (th / sig))
			var dens := 1.0 + 0.12 * cos(9.0 * th + 0.6) + 0.07 * cos(17.0 * th + 2.1) + 0.035 * cos(27.0 * th + 4.0)
			var rad := pow(clampf(1.0 - r, 0.0, 1.0), 1.9) * smoothstep(0.0, 0.10, r)
			var win := 1.0 - smoothstep(0.8, 1.0, absf(dx) / half_w)
			var a := clampf(ang * dens * rad * win, 0.0, 1.0)
			var i := (y * w + x) * 4
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
			data[i + 3] = int(a * 255.0 + 0.5)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	_fan_tex = ImageTexture.create_from_image(img)
	return _fan_tex


## Two overlapping, mirrored copies of the fan that sway very slightly out of phase: the density
## undulations interfere and drift like light moving through haze. A wide halo and a faint pool of
## light on the ground tie it into the scene. (Low-effects mode draws just the main layer.)
static func _moon_haze(ci: CanvasItem, t: float, dark: float, col: Color) -> void:
	var tex := _fan_texture()
	var axis := PI * 0.70   # down and to the left, across the playfield
	var wpx := MOON_FAN_LEN * float(MOON_FAN_W) / float(MOON_FAN_H)
	var fade := 1.0 - dark * 0.3
	var rect := Rect2(-wpx * 0.5, 0.0, wpx, MOON_FAN_LEN)
	var a1 := 0.17 * (0.92 + 0.08 * sin(t * 0.6)) * fade
	ci.draw_set_transform(MOON, axis - PI * 0.5 + 0.018 * sin(t * 0.21), Vector2.ONE)
	ci.draw_texture_rect(tex, rect, false, Color(col.r, col.g, col.b, a1))
	if Cfg.quality >= 1.0:
		var a2 := 0.10 * (0.9 + 0.1 * sin(t * 0.5 + 2.0)) * fade
		ci.draw_set_transform(MOON, axis + 0.04 - PI * 0.5 + 0.025 * sin(t * 0.31 + 1.0), Vector2(-1.25, 0.85))
		ci.draw_texture_rect(tex, rect, false, Color(col.r, col.g, col.b, a2))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	Gfx.glow(ci, MOON, 560.0, Color(col.r, col.g, col.b, 0.05 * fade))
	var gx := MOON.x + cos(axis) * (G - MOON.y) / sin(axis)
	Gfx.glow_ellipse(ci, Vector2(gx, G - 8.0), 460.0, 50.0, Color(col.r, col.g, col.b, 0.04 * fade))


# ------------------------------------------------------------------ emissive layer
static func draw_lights(ci: CanvasItem, dist: float, t: float, dark: float) -> void:
	_init_cache()
	var L := _l()
	var R := _r()
	var span := R - L
	var mc := Color(0.93, 0.92, 0.85).lerp(Color(0.92, 0.16, 0.2), dark)
	# a faint wash of cool moonlight over the whole playfield: keeps every hazard readable
	Gfx.glow_ellipse(ci, Vector2(Cfg.VIEW_W * 0.5, G - 70.0), Cfg.VIEW_W * 0.95 + Cfg.ox, 200.0, Color(0.42, 0.52, 0.95, 0.07 * (1.0 - dark * 0.35)))
	# soft volumetric moonlight spilling from the moon: one smooth haze, not separate beams
	_moon_haze(ci, t, dark, mc.lerp(Color(0.62, 0.72, 1.0), 0.35 * (1.0 - dark)))
	# lit chapel windows (parallax 0.14)
	var o14 := dist * 0.14
	for i in range(int(floorf((o14 + L) / 1100.0)) - 1, int(ceilf((o14 + R) / 1100.0)) + 1):
		var fi := float(i)
		if Gfx.hash1(fi + 40.0) < 0.3:
			continue
		var rx := fi * 1100.0 - o14 + Gfx.hash1(fi) * 300.0
		var rh := 150.0 + Gfx.hash1(fi + 2.0) * 90.0
		var fl := 0.75 + 0.25 * sin(t * 7.0 + fi * 3.0)
		var wc := Color(1.0, 0.62, 0.25).lerp(Color(1.0, 0.15, 0.18), dark)
		Gfx.glow(ci, Vector2(rx + 45.0, G - rh * 0.55), 46.0, Color(wc.r, wc.g, wc.b, 0.4 * fl))
		ci.draw_rect(Rect2(rx + 36.0, G - rh * 0.55 - 20.0, 18.0, 34.0), Color(wc.r, wc.g, wc.b, 0.8 * fl))
	# graveyard candles (parallax 0.7)
	var o7 := dist * 0.7
	for i in range(int(floorf((o7 + L) / 440.0)) - 1, int(ceilf((o7 + R) / 440.0)) + 1):
		var fi := float(i)
		if Gfx.hash1(fi + 21.0) < 0.72 or Gfx.hash1(fi + 9.0) < 0.30:
			continue
		var cx := fi * 440.0 - o7 + Gfx.hash1(fi + 4.0) * 160.0 + 56.0
		var fl := 0.7 + 0.3 * sin(t * 11.0 + fi * 5.0) * sin(t * 6.3 + fi)
		Gfx.glow(ci, Vector2(cx, G - 12.0), 34.0, Color(1.0, 0.6, 0.22, 0.5 * fl))
		ci.draw_rect(Rect2(cx - 1.5, G - 16.0, 3.0, 12.0), Color(1.0, 0.85, 0.5, 0.9 * fl))
	# moon shimmer on puddles
	for i in int(6.0 * Cfg.quality):
		var fi := float(i)
		var wx := L + fposmod(fi * 503.0 - dist, span)
		Gfx.glow_ellipse(ci, Vector2(wx, G + 44.0 + _h2[i] * 60.0), 44.0, 5.0, Color(mc.r, mc.g, mc.b, 0.16))
	# the ground itself starts to bleed
	if dark > 0.4:
		var ca := clampf((dark - 0.4) * 1.8, 0.0, 1.0)
		for i in int(9.0 * Cfg.quality):
			var fi := float(i)
			var kx := L + fposmod(fi * 377.0 - dist, span)
			var ky := G + 18.0 + _h6[i] * 100.0
			var pulse := 0.6 + 0.4 * sin(t * 2.0 + fi)
			ci.draw_polyline(PackedVector2Array([Vector2(kx, ky), Vector2(kx + 30.0, ky + 8.0), Vector2(kx + 44.0, ky - 4.0), Vector2(kx + 80.0, ky + 6.0)]), Color(1.0, 0.12, 0.14, 0.75 * ca * pulse), 2.5, true)
			Gfx.glow_ellipse(ci, Vector2(kx + 40.0, ky), 60.0, 12.0, Color(1.0, 0.08, 0.1, 0.18 * ca * pulse))


## Glowing eyes watching from the trees. Appear as the world darkens.
static func draw_eyes(ci: CanvasItem, dist: float, t: float, dark: float) -> void:
	if dark < 0.3:
		return
	var o3 := dist * 0.3
	for i in range(int(floorf((o3 + _l()) / TREE_STEP)) - 1, int(ceilf((o3 + _r()) / TREE_STEP)) + 1):
		var fi := float(i)
		if Gfx.hash1(fi + 3.0) < 0.55 or fmod(t * 0.7 + Gfx.hash1(fi) * 10.0, 4.0) > 3.6:
			continue
		var ex := fi * TREE_STEP - o3 + Gfx.hash1(fi) * 110.0
		var ey := G - 80.0 - Gfx.hash1(fi + 5.0) * 150.0
		var a := clampf((dark - 0.3) * 2.0, 0.0, 1.0)
		Gfx.glow(ci, Vector2(ex, ey), 20.0, Color(1.0, 0.1, 0.15, 0.5 * a))
		ci.draw_rect(Rect2(ex - 9.0, ey - 2.0, 6.0, 4.0), Color(1.0, 0.35, 0.35, a))
		ci.draw_rect(Rect2(ex + 3.0, ey - 2.0, 6.0, 4.0), Color(1.0, 0.35, 0.35, a))


## Fast, near-black foreground: grass blades below and gnarled branches sweeping in from the top.
static func draw_foreground(ci: CanvasItem, dist: float, t: float) -> void:
	_init_cache()
	var L := _l()
	var R := _r()
	var span := R - L
	var col := Color(0.008, 0.0, 0.018, 0.96)
	var o := dist * 1.35
	var base := 740.0
	for i in int(34.0 * Cfg.quality) + 6:
		var fi := float(i)
		var bx := L + fposmod(fi * 96.0 - o, span)
		var bh := 40.0 + _h0[i] * 62.0
		var sway := sin(t * 2.0 + fi) * 6.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, base), Vector2(bx + 14.0, base), Vector2(bx + sway - 3.0, base - bh)]), col)
	var ot := dist * 1.6
	var top := _t()
	for i in 5:
		var fi := float(i)
		var bx2 := L + fposmod(fi * 900.0 + 200.0 - ot, span)
		var blen := 160.0 + Gfx.hash1(fi + 30.0) * 120.0
		var sw := sin(t * 0.9 + fi) * 8.0
		var p0 := Vector2(bx2, top)
		var p1 := Vector2(bx2 + 30.0 + sw, top + blen * 0.6 + 20.0)
		ci.draw_line(p0, p1, col, 10.0, true)
		ci.draw_line(p1, p1 + Vector2(-60.0 + sw, 60.0), col, 5.0, true)
		ci.draw_line(p1 + Vector2(0.0, -40.0), p1 + Vector2(50.0 + sw, 20.0), col, 4.0, true)
