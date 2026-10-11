class_name CosmeticArt
extends RefCounted
## Small vector icons for the DRESS / ACCESSORIES page: a coat silhouette in each dress's palette, and a
## hooded head wearing each accessory. Drawn from the same palette the runner uses, so they always match.


## kind 0 = dress, 1 = accessory. `c` is the centre, `sz` the icon's box size, `a` overall alpha.
static func icon(ci: CanvasItem, kind: int, i: int, c: Vector2, sz: float, a: float = 1.0) -> void:
	if kind == 0:
		_dress(ci, i, c, sz, a)
	else:
		_accessory(ci, i, c, sz, a)


static func _tint(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a)


static func _dress(ci: CanvasItem, i: int, c: Vector2, sz: float, a: float) -> void:
	var pal := CharacterDrawer.palette(i)
	var coat: Color = pal["coat"]
	var coat_d: Color = pal["coat_d"]
	var trim: Color = pal["trim"]
	var trail: Color = pal["trail"]
	var edge: Color = pal["edge"]
	var s := sz * 0.5
	# trailing cloth (the old scarf), streaming to the left
	var tp := PackedVector2Array()
	for k in 6:
		tp.append(c + Vector2(-s * 0.18 - float(k) * s * 0.16, -s * 0.30 + sin(float(k) * 0.9) * s * 0.07 + float(k) * s * 0.025))
	ci.draw_polyline(tp, _tint(trail.darkened(0.4), a), sz * 0.11, true)
	ci.draw_polyline(tp, _tint(trail, a), sz * 0.085, true)
	if edge.a > 0.0:
		ci.draw_polyline(tp, _tint(edge, a), sz * 0.02, true)
	# coat body + hood
	var body := PackedVector2Array([c + Vector2(-s * 0.30, -s * 0.30), c + Vector2(s * 0.30, -s * 0.30), c + Vector2(s * 0.46, s * 0.62), c + Vector2(-s * 0.46, s * 0.62)])
	Gfx.vgrad(ci, body, c.y - s * 0.30, c.y + s * 0.62, _tint(coat.lightened(0.12), a), _tint(coat_d, a))
	ci.draw_circle(c + Vector2(0.0, -s * 0.50), s * 0.30, _tint(coat.lightened(0.05), a))
	ci.draw_circle(c + Vector2(s * 0.08, -s * 0.48), s * 0.20, Color(0.035, 0.025, 0.06, a))
	ci.draw_circle(c + Vector2(s * 0.14, -s * 0.52), s * 0.045, Color(0.96, 0.93, 1.0, a))
	ci.draw_line(c + Vector2(-s * 0.36, s * 0.12), c + Vector2(s * 0.38, s * 0.12), _tint(trim, a), sz * 0.045, true)   # belt
	ci.draw_line(c + Vector2(s * 0.12, -s * 0.28), c + Vector2(s * 0.2, s * 0.6), _tint(trim.lerp(coat, 0.4), a * 0.8), sz * 0.025, true)
	match i:
		1:   # patches + strap
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y + s * 0.26, s * 0.2, s * 0.17), Color(0.47, 0.38, 0.24, a))
			ci.draw_rect(Rect2(c.x + s * 0.08, c.y - s * 0.12, s * 0.15, s * 0.15), Color(0.21, 0.16, 0.11, a))
			ci.draw_line(c + Vector2(-s * 0.08, -s * 0.28), c + Vector2(-s * 0.04, s * 0.12), _tint(trim, a), sz * 0.04, true)
		2:   # bone buttons
			for k in 3:
				ci.draw_circle(c + Vector2(s * 0.14, -s * 0.12 + float(k) * s * 0.2), sz * 0.022, _tint(trim, a))
		3:   # claw marks + drips
			for k in 3:
				var a0 := c + Vector2(-s * 0.22, -s * 0.14 + float(k) * s * 0.14)
				ci.draw_line(a0, a0 + Vector2(s * 0.42, s * 0.16), Color(1.0, 0.2, 0.28, a), sz * 0.03, true)
			for k in 3:
				var bx := c.x - s * 0.28 + float(k) * s * 0.28
				ci.draw_line(Vector2(bx, c.y + s * 0.62), Vector2(bx, c.y + s * 0.62 + s * (0.12 + 0.05 * float(k))), Color(0.85, 0.06, 0.13, a), sz * 0.03, true)
		4:   # constellation
			var st := PackedVector2Array([Vector2(-0.18, 0.02), Vector2(0.02, 0.14), Vector2(-0.08, 0.30), Vector2(0.18, 0.40), Vector2(-0.12, 0.50)])
			for k in range(1, st.size()):
				ci.draw_line(c + st[k - 1] * s * 1.0, c + st[k] * s * 1.0, Color(trim.r, trim.g, trim.b, 0.5 * a), 1.0, true)
			for k in st.size():
				ci.draw_circle(c + st[k] * s * 1.0, sz * 0.024, _tint(trim, a))


static func _accessory(ci: CanvasItem, i: int, c: Vector2, sz: float, a: float) -> void:
	var s := sz * 0.5
	var hc := c + Vector2(0.0, s * 0.12)
	# the bare hooded head every accessory sits on
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-s * 0.42, s * 0.8), hc + Vector2(-s * 0.3, s * 0.3), hc + Vector2(s * 0.3, s * 0.3), hc + Vector2(s * 0.42, s * 0.8)]), Color(0.18, 0.15, 0.30, a))
	ci.draw_circle(hc, s * 0.40, Color(0.28, 0.23, 0.42, a))
	ci.draw_circle(hc + Vector2(s * 0.10, 0.0), s * 0.27, Color(0.035, 0.025, 0.06, a))
	ci.draw_circle(hc + Vector2(s * 0.22, -s * 0.03), s * 0.06, Color(0.96, 0.93, 1.0, a))
	match i:
		1:   # raven (looking back)
			var rc := hc + Vector2(-s * 0.46, -s * 0.34)
			ci.draw_colored_polygon(PackedVector2Array([rc + Vector2(-s * 0.2, s * 0.18), rc + Vector2(-s * 0.08, -s * 0.14), rc + Vector2(s * 0.24, -s * 0.12), rc + Vector2(s * 0.32, s * 0.12), rc + Vector2(s * 0.0, s * 0.26)]), Color(0.06, 0.06, 0.12, a))
			ci.draw_circle(rc + Vector2(-s * 0.24, -s * 0.12), s * 0.12, Color(0.06, 0.06, 0.12, a))
			ci.draw_colored_polygon(PackedVector2Array([rc + Vector2(-s * 0.32, -s * 0.2), rc + Vector2(-s * 0.58, -s * 0.1), rc + Vector2(-s * 0.32, -s * 0.04)]), Color(0.2, 0.18, 0.2, a))
			ci.draw_line(rc + Vector2(-s * 0.08, -s * 0.14), rc + Vector2(s * 0.24, -s * 0.12), Color(0.55, 0.65, 1.0, 0.85 * a), 1.5, true)
			ci.draw_circle(rc + Vector2(-s * 0.26, -s * 0.15), s * 0.035, Color(1.0, 0.3, 0.32, a))
		2:   # antlers
			for sd in 2:
				var m := 1.0 if sd == 1 else -1.0
				var col := Color(0.90, 0.86, 0.74, a) if sd == 1 else Color(0.5, 0.47, 0.4, a)
				var r0 := hc + Vector2(m * s * 0.16, -s * 0.34)
				var pts := PackedVector2Array([r0, r0 + Vector2(m * s * 0.08, -s * 0.28), r0 + Vector2(m * s * 0.26, -s * 0.5), r0 + Vector2(m * s * 0.28, -s * 0.78)])
				ci.draw_polyline(pts, col, sz * 0.05, true)
				ci.draw_line(pts[1], pts[1] + Vector2(m * s * 0.26, -s * 0.2), col, sz * 0.035, true)
				ci.draw_line(pts[2], pts[2] + Vector2(m * s * 0.26, -s * 0.12), col, sz * 0.035, true)
		3:   # plague mask
			var fc := hc + Vector2(s * 0.10, s * 0.02)
			ci.draw_circle(fc, s * 0.30, Color(0.80, 0.73, 0.60, a))
			ci.draw_colored_polygon(PackedVector2Array([fc + Vector2(s * 0.14, -s * 0.14), fc + Vector2(s * 0.74, s * 0.2), fc + Vector2(s * 0.16, s * 0.2)]), Color(0.86, 0.79, 0.64, a))
			ci.draw_circle(fc + Vector2(s * 0.14, -s * 0.06), s * 0.13, Color(0.16, 0.11, 0.07, a))
			ci.draw_circle(fc + Vector2(s * 0.14, -s * 0.06), s * 0.095, Color(1.0, 0.72, 0.26, a))
		4:   # halo
			var ring := PackedVector2Array()
			for k in range(0, 17):
				var an := 0.9 + float(k) / 16.0 * (TAU - 0.9)
				ring.append(hc + Vector2(cos(an) * s * 0.46, -s * 0.74 + sin(an) * s * 0.15))
			Gfx.glow(ci, hc + Vector2(0.0, -s * 0.74), s * 0.9, Color(1.0, 0.82, 0.4, 0.3 * a))
			ci.draw_polyline(ring, Color(0.35, 0.22, 0.05, 0.9 * a), sz * 0.075, true)
			ci.draw_polyline(ring, Color(1.0, 0.88, 0.45, a), sz * 0.045, true)
