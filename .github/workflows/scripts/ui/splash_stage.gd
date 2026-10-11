class_name SplashStage
extends Control
## Draws the launch splashes. Two instances are stacked by splash.gd: the normal one draws the pictures
## (and the slipped rows, scanlines and creeping vignette on splash 2); the `ghost` one has additive blending
## and only draws the red / cyan colour-fringe copies and the faint red wash during a burst.
## With the glitch at rest the picture is drawn exactly as supplied.

var tex_a: Texture2D
var tex_b: Texture2D
var a_alpha := 0.0           ## splash 1 opacity
var b_alpha := 0.0           ## splash 2 opacity (only used for the final fade to black)
var tb := -1.0               ## seconds since splash 2 appeared (-1 = not on screen)
var ghost := false           ## true: the additive pass
## splash 2's own background (its edge colour is a very dark red, not black), so the letterbox is invisible
var bg_b := Color(0.013, 0.001, 0.001)


## The picture scaled to fit the screen with its aspect kept (any screen shape), then scaled by `zoom`.
func fit(tex: Texture2D, zoom: float) -> Rect2:
	var iw := float(tex.get_width())
	var ih := float(tex.get_height())
	var k := minf(size.x / iw, size.y / ih) * zoom
	var s := Vector2(iw, ih) * k
	return Rect2((size - s) * 0.5, s)


func _draw() -> void:
	if ghost:
		_draw_ghost()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if tex_a != null and a_alpha > 0.002:
		draw_texture_rect(tex_a, fit(tex_a, 1.0), false, Color(1.0, 1.0, 1.0, a_alpha))
	if tex_b != null and tb >= 0.0 and b_alpha > 0.002:
		_draw_b()


func _draw_b() -> void:
	var g := SplashFx.strength(tb)
	var lum := SplashFx.brightness(tb)
	var r := fit(tex_b, SplashFx.zoom(tb))
	r.position += SplashFx.shake(tb)
	var a := b_alpha
	draw_rect(Rect2(Vector2.ZERO, size), Color(bg_b.r, bg_b.g, bg_b.b, a))
	var col := Color(lum, lum, lum, a)
	draw_texture_rect(tex_b, r, false, col)
	# slipped rows: wipe the row, then draw it again shifted sideways
	var iw := float(tex_b.get_width())
	var ih := float(tex_b.get_height())
	for s in SplashFx.tears(tb):
		var dst := Rect2(r.position.x + s.z * r.size.x, r.position.y + s.x * r.size.y, r.size.x, s.y * r.size.y)
		var src := Rect2(0.0, s.x * ih, iw, s.y * ih)
		draw_rect(Rect2(0.0, dst.position.y, size.x, dst.size.y), Color(bg_b.r, bg_b.g, bg_b.b, a))
		draw_texture_rect_region(tex_b, dst, src, col)
	# faint scanlines that crawl, a little stronger inside a burst
	var pts := PackedVector2Array()
	var y := fposmod(tb * 24.0, 3.0)
	while y < size.y:
		pts.append(Vector2(0.0, y))
		pts.append(Vector2(size.x, y))
		y += 3.0
	draw_multiline(pts, Color(0.0, 0.0, 0.0, (0.10 + 0.10 * g) * a), 1.0)
	# the edges close in, slowly, over the whole splash
	var v := 0.38 * smoothstep(0.0, SplashFx.LENGTH, tb) * a
	var e := minf(size.x, size.y) * 0.22
	var dark := Color(0.0, 0.0, 0.0, v)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, e), Vector2(0, e)]), PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y - e), Vector2(size.x, size.y - e), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([clear, clear, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, size.y), Vector2(0, size.y)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(size.x - e, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x - e, size.y)]), PackedColorArray([clear, dark, dark, clear]))


func _draw_ghost() -> void:
	if tex_b == null or tb < 0.0 or b_alpha < 0.002:
		return
	var g := SplashFx.strength(tb)
	var lum := SplashFx.brightness(tb)
	if lum < 0.05:
		return
	var r := fit(tex_b, SplashFx.zoom(tb))
	r.position += SplashFx.shake(tb)
	var d := SplashFx.chroma(tb)
	var ga := SplashFx.ghost_alpha(tb) * b_alpha * lum
	draw_texture_rect(tex_b, Rect2(r.position + Vector2(d, 0.0), r.size), false, Color(1.0, 0.10, 0.10, ga))
	draw_texture_rect(tex_b, Rect2(r.position - Vector2(d, 0.0), r.size), false, Color(0.10, 0.90, 1.0, ga))
	if g > 0.5:   # a breath of blood-red across the whole frame at the hardest moments
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.30, 0.0, 0.02, 0.07 * (g - 0.5) * 2.0 * b_alpha))
