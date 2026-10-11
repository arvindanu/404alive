class_name UIDraw
extends RefCounted
## Shared UI drawing: resolution-independent vector icons and the "glass" panel style.
## Design language: near-black indigo glass, bone-white text, a single crimson accent, thin strokes.

const BONE := Cfg.COL_BONE
const CRIMSON := Cfg.COL_CRIMSON
const GOLD := Color(1.0, 0.82, 0.32)
const VIOLET := Color(0.72, 0.55, 1.0)
const CYAN := Color(0.40, 0.90, 1.0)


static func glass(ci: CanvasItem, r: Rect2, radius: int = 14, accent: Color = CRIMSON, fill_a: float = 0.80) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.022, 0.065, fill_a)
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.10)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 6)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
	# top sheen
	ci.draw_line(r.position + Vector2(radius, 1.5), Vector2(r.end.x - radius, r.position.y + 1.5), Color(1, 1, 1, 0.09), 1.5)
	# accent corner brackets
	var b := 16.0
	var c := Color(accent.r, accent.g, accent.b, 0.85)
	var p0 := r.position + Vector2(9.0, 9.0)
	ci.draw_polyline(PackedVector2Array([p0 + Vector2(0, b), p0, p0 + Vector2(b, 0)]), c, 2.0, true)
	var p1 := r.end - Vector2(9.0, 9.0)
	ci.draw_polyline(PackedVector2Array([p1 - Vector2(0, b), p1, p1 - Vector2(b, 0)]), c, 2.0, true)


static func slash(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_line(c + Vector2(-s * 0.95, -s * 0.95), c + Vector2(s * 0.95, s * 0.95), Color(0.03, 0.02, 0.06, 0.9), w * 2.6, true)
	ci.draw_line(c + Vector2(-s * 0.95, -s * 0.95), c + Vector2(s * 0.95, s * 0.95), col, w, true)


## extra: for toggle icons 1 = on / 0 = off; for &"eye" it is the openness.
static func icon(ci: CanvasItem, id: StringName, c: Vector2, size: float, col: Color, extra: float = 1.0) -> void:
	var s := size * 0.5
	var w := maxf(size * 0.10, 2.0)
	match id:
		&"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.8), c + Vector2(s * 0.85, 0.0), c + Vector2(-s * 0.5, s * 0.8)]), col)
		&"pause":
			ci.draw_rect(Rect2(c.x - s * 0.55, c.y - s * 0.7, s * 0.42, s * 1.4), col)
			ci.draw_rect(Rect2(c.x + s * 0.13, c.y - s * 0.7, s * 0.42, s * 1.4), col)
		&"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.4, -s * 0.7), c + Vector2(-s * 0.4, 0.0), c + Vector2(s * 0.4, s * 0.7)]), col, w * 1.5, true)
		&"home":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.9, 0.0), c + Vector2(0.0, -s * 0.85), c + Vector2(s * 0.9, 0.0)]), col, w * 1.4, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.62, -s * 0.15), c + Vector2(-s * 0.62, s * 0.8), c + Vector2(s * 0.62, s * 0.8), c + Vector2(s * 0.62, -s * 0.15)]), col, w * 1.4, true)
		&"retry":
			ci.draw_arc(c, s * 0.72, -PI * 0.15, PI * 1.35, 28, col, w * 1.5, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.72
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.05, -s * 0.5), tip + Vector2(s * 0.5, s * 0.1), tip + Vector2(-s * 0.45, s * 0.22)]), col)
		&"gear":
			ci.draw_arc(c, s * 0.58, 0.0, TAU, 28, col, w * 1.6, true)
			for i in 8:
				var a := TAU * float(i) / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.74, c + Vector2(cos(a), sin(a)) * s * 1.0, col, w * 1.9, true)
			ci.draw_circle(c, s * 0.2, col)
		&"scarf":
			var pts := PackedVector2Array()
			for i in 8:
				pts.append(c + Vector2(-s + float(i) * s * 2.0 / 7.0, sin(float(i) * 0.95) * s * 0.36 + float(i) * s * 0.06 - s * 0.2))
			ci.draw_polyline(pts, col, w * 2.4, true)
			ci.draw_circle(pts[0], w * 1.8, col)
		&"dress":   # a clothes hanger
			ci.draw_arc(c + Vector2(0.0, -s * 0.62), s * 0.22, PI * 0.15, PI * 1.85 + 0.5, 12, col, w * 1.3, true)
			ci.draw_line(c + Vector2(0.0, -s * 0.42), c + Vector2(0.0, -s * 0.12), col, w * 1.3, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.0, -s * 0.12), c + Vector2(s * 1.0, s * 0.62), c + Vector2(-s * 1.0, s * 0.62), c + Vector2(0.0, -s * 0.12)]), col, w * 1.5, true)
		&"sound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.32), c + Vector2(-s * 0.5, -s * 0.32), c + Vector2(s * 0.05, -s * 0.8), c + Vector2(s * 0.05, s * 0.8), c + Vector2(-s * 0.5, s * 0.32), c + Vector2(-s, s * 0.32)]), col)
			if extra > 0.5:
				ci.draw_arc(c + Vector2(s * 0.05, 0.0), s * 0.55, -0.75, 0.75, 12, col, w, true)
				ci.draw_arc(c + Vector2(s * 0.05, 0.0), s * 0.95, -0.75, 0.75, 14, col, w, true)
			else:
				slash(ci, c, s, col, w)
		&"haptic":
			ci.draw_rect(Rect2(c.x - s * 0.34, c.y - s * 0.85, s * 0.68, s * 1.7), col, false, w)
			ci.draw_line(c + Vector2(-s * 0.12, s * 0.6), c + Vector2(s * 0.12, s * 0.6), col, w)
			if extra > 0.5:
				ci.draw_arc(c, s * 0.75, PI - 0.6, PI + 0.6, 8, col, w, true)
				ci.draw_arc(c, s * 0.75, -0.6, 0.6, 8, col, w, true)
				ci.draw_arc(c, s * 1.0, PI - 0.5, PI + 0.5, 8, col, w * 0.8, true)
				ci.draw_arc(c, s * 1.0, -0.5, 0.5, 8, col, w * 0.8, true)
			else:
				slash(ci, c, s, col, w)
		&"shake":
			ci.draw_rect(Rect2(c.x - s * 0.72, c.y - s * 0.6, s * 1.2, s * 1.2), Color(col.r, col.g, col.b, col.a * 0.45), false, w)
			ci.draw_rect(Rect2(c.x - s * 0.48, c.y - s * 0.6, s * 1.2, s * 1.2), col, false, w)
			if extra <= 0.5:
				slash(ci, c, s, col, w)
		&"fx":
			var st := PackedVector2Array()
			for i in 8:
				var rr := s if i % 2 == 0 else s * 0.3
				var a2 := -PI * 0.5 + TAU * float(i) / 8.0
				st.append(c + Vector2(cos(a2), sin(a2)) * rr)
			ci.draw_colored_polygon(st, col)
			if extra <= 0.5:
				slash(ci, c, s, col, w)
		&"fps":   # a little speedometer
			ci.draw_arc(c + Vector2(0.0, s * 0.45), s * 0.95, PI * 1.08, PI * 1.92, 18, col, w)
			ci.draw_line(c + Vector2(0.0, s * 0.45), c + Vector2(s * 0.55, -s * 0.30), col, w)
			ci.draw_circle(c + Vector2(0.0, s * 0.45), s * 0.15, col)
		&"battery":
			ci.draw_rect(Rect2(c.x - s * 0.9, c.y - s * 0.45, s * 1.65, s * 0.9), col, false, w)
			ci.draw_rect(Rect2(c.x + s * 0.76, c.y - s * 0.2, s * 0.2, s * 0.4), col)
			ci.draw_rect(Rect2(c.x - s * 0.76, c.y - s * 0.3, s * (0.55 if extra > 0.5 else 1.3), s * 0.6), col)
		&"gem":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(s * 0.75, -s * 0.1), c + Vector2(0.0, s), c + Vector2(-s * 0.75, -s * 0.1)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(0.0, -s * 0.1), c + Vector2(-s * 0.75, -s * 0.1)]), Color(1, 1, 1, 0.35))
		&"eye":
			var o := clampf(extra, 0.05, 1.0)
			ci.draw_arc(c + Vector2(0.0, s * 0.85 * o), s * 1.05, -PI * 0.5 - 0.95, -PI * 0.5 + 0.95, 18, col, w * 1.5, true)
			ci.draw_arc(c - Vector2(0.0, s * 0.85 * o), s * 1.05, PI * 0.5 - 0.95, PI * 0.5 + 0.95, 18, col, w * 1.5, true)
			ci.draw_circle(c + Vector2(-s * 0.22, 0.0), s * 0.36 * clampf(o * 1.4, 0.2, 1.0), col)
		&"lock":
			ci.draw_rect(Rect2(c.x - s * 0.6, c.y - s * 0.1, s * 1.2, s * 0.9), col)
			ci.draw_arc(c + Vector2(0.0, -s * 0.1), s * 0.42, PI, TAU, 14, col, w * 1.4, true)
		&"star":
			var sp := PackedVector2Array()
			for i in 10:
				var r2 := s if i % 2 == 0 else s * 0.42
				var a3 := -PI * 0.5 + TAU * float(i) / 10.0
				sp.append(c + Vector2(cos(a3), sin(a3)) * r2)
			ci.draw_colored_polygon(sp, col)
		&"flame":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(s * 0.62, s * 0.25), c + Vector2(s * 0.3, s * 0.85), c + Vector2(-s * 0.3, s * 0.85), c + Vector2(-s * 0.62, s * 0.25)]), col)
		&"diamond":
			ci.draw_polyline(Gfx.closed(PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(s * 0.7, 0.0), c + Vector2(0.0, s), c + Vector2(-s * 0.7, 0.0)])), col, w * 1.5, true)
			ci.draw_circle(c, s * 0.16, col)
		&"ward":
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 24, col, w * 1.5, true)
			ci.draw_arc(c, s * 0.42, 0.0, TAU, 16, col, w * 1.2, true)
		&"up":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, s * 0.15), c + Vector2(0.0, -s * 0.65), c + Vector2(s * 0.8, s * 0.15)]), col, w * 1.7, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, s * 0.8), c + Vector2(0.0, 0.0), c + Vector2(s * 0.8, s * 0.8)]), Color(col.r, col.g, col.b, col.a * 0.45), w * 1.7, true)
		&"down":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.35), c + Vector2(0.0, s * 0.45), c + Vector2(s * 0.8, -s * 0.35)]), col, w * 1.7, true)
		&"dash":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.85, -s * 0.6), c + Vector2(-s * 0.15, 0.0), c + Vector2(-s * 0.85, s * 0.6)]), col, w * 1.6, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.05, -s * 0.6), c + Vector2(s * 0.75, 0.0), c + Vector2(s * 0.05, s * 0.6)]), col, w * 1.6, true)
		&"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, 0.0), c + Vector2(-s * 0.2, s * 0.55), c + Vector2(s * 0.8, -s * 0.6)]), col, w * 1.6, true)
