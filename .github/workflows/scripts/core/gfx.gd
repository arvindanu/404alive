class_name Gfx
extends RefCounted
## Small drawing helpers shared by all renderers.

static var _glow_tex: GradientTexture2D


static func hash1(n: float) -> float:
	var s := sin(n * 127.1) * 43758.5453
	return s - floorf(s)


static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex


static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	if color.a <= 0.004:
		return
	ci.draw_texture_rect(glow_tex(), Rect2(pos.x - radius, pos.y - radius, radius * 2.0, radius * 2.0), false, color)


static func glow_ellipse(ci: CanvasItem, pos: Vector2, rx: float, ry: float, color: Color) -> void:
	if color.a <= 0.004:
		return
	ci.draw_texture_rect(glow_tex(), Rect2(pos.x - rx, pos.y - ry, rx * 2.0, ry * 2.0), false, color)


## Two-bone IK. Returns the middle joint (elbow/knee). bend = +1 / -1 picks the side.
static func ik(a: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := target - a
	var dist := clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var base := atan2(d.y, d.x)
	var c := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var ang := base + bend * acos(c)
	return a + Vector2(cos(ang), sin(ang)) * l1


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## Polygon with a vertical colour gradient (c0 at y0 -> c1 at y1). Gives every prop volume.
static func vgrad(ci: CanvasItem, pts: PackedVector2Array, y0: float, y1: float, c0: Color, c1: Color) -> void:
	var cols := PackedColorArray()
	var span := maxf(absf(y1 - y0), 0.001) * signf(y1 - y0 if y1 != y0 else 1.0)
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p.y - y0) / span, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)


## Axis-aligned quad with a vertical gradient.
static func vquad(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), PackedColorArray([c0, c0, c1, c1]))


## Tapered capsule between two points (rounded ends).
static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		ci.draw_circle(a, wa * 0.5, col)
		return
	var n := Vector2(-d.y, d.x).normalized()
	ci.draw_colored_polygon(PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), col)
	ci.draw_circle(a, wa * 0.5, col)
	ci.draw_circle(b, wb * 0.5, col)


static func text(ci: CanvasItem, font: Font, s: String, pos: Vector2, size: int, col: Color, align: int = 0, shadow: float = 0.7) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == 1:
		p.x -= w * 0.5
	elif align == 2:
		p.x -= w
	if shadow > 0.0:
		ci.draw_string(font, p + Vector2(0.0, size * 0.06 + 1.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * shadow))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
