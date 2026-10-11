class_name TutorialDraw
extends RefCounted
## First-session button tutorial, drawn over the HUD while the run is frozen waiting for the player to
## try a button. Pure drawing: the HUD owns the layout of the buttons and passes the highlighted one in.
##   veil()    - dims the whole screen (the HUD then redraws the target button on top of it)
##   callout() - pulsing ring around the button + a speech bubble that explains it
##   skip_rect() / draw_skip() - the "skip tutorial" pill, bottom centre (clear of both thumbs)

const STEPS := [
	{"title": "JUMP", "lines": ["Tap to leap over graves,", "spikes and gaps.", "Hold for a higher jump."]},
	{"title": "SLIDE", "lines": ["Hold to slide under", "hanging traps and crows."]},
	{"title": "DASH", "lines": ["Tap to burst through", "thorn walls. It needs a", "moment to recharge."]},
	{"title": "LOOK BACK", "lines": ["Hold to see behind you", "and spot hidden glints.", "Don't stare - it creeps closer."]},
]


static func _ease(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


static func skip_rect(view: Vector2) -> Rect2:
	return Rect2(view.x * 0.5 - 100.0, view.y - 62.0, 200.0, 40.0)


static func veil(ci: CanvasItem, view: Vector2, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, view.x, view.y), Color(0.01, 0.0, 0.03, 0.62 * _ease(t / 0.25)))


static func draw_skip(ci: CanvasItem, view: Vector2, t: float) -> void:
	var a := _ease((t - 0.3) / 0.3)
	var r := skip_rect(view)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.09, 0.7 * a)
	sb.border_color = Color(1, 1, 1, 0.28 * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(20)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
	Gfx.text(ci, GameState.spaced(GameState.f_bold, 3.0), "SKIP TUTORIAL", Vector2(r.position.x + r.size.x * 0.5 + 1.5, r.position.y + 26.0), 13, Color(1, 1, 1, 0.65 * a), 1, 0.4)


## `c`/`r` = centre and radius of the highlighted button; `step` indexes STEPS.
static func callout(ci: CanvasItem, step: int, t: float, c: Vector2, r: float, accent: Color, view: Vector2) -> void:
	var a := _ease(t / 0.25)
	# pulsing ring + an expanding echo, so the target is unmistakable
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	ci.draw_arc(c, r + 12.0 + 4.0 * pulse, 0.0, TAU, 56, Color(accent.r, accent.g, accent.b, (0.55 + 0.4 * pulse) * a), 4.0, true)
	var k := fposmod(t * 1.1, 1.0)
	ci.draw_arc(c, r + 10.0 + 34.0 * k, 0.0, TAU, 56, Color(accent.r, accent.g, accent.b, (1.0 - k) * 0.6 * a), 3.0, true)
	Gfx.glow(ci, c, r * 2.2, Color(accent.r, accent.g, accent.b, 0.22 * a * (0.7 + 0.3 * pulse)))
	# bubble
	var info: Dictionary = STEPS[step]
	var lines: Array = info["lines"]
	var bw := 342.0
	var bh := 100.0 + 25.0 * float(lines.size())
	var left_side := c.x < view.x * 0.5
	var bx := clampf(c.x - r if left_side else c.x + r - bw, 18.0, view.x - bw - 18.0)
	var slide := (1.0 - _ease(t / 0.35)) * 14.0
	var by := c.y - r - 34.0 - bh + slide
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.025, 0.08, 0.94 * a)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.9 * a)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(bx, by, bw, bh))
	# pointer toward the button
	var px := clampf(c.x, bx + 30.0, bx + bw - 30.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 12.0, by + bh - 1.0), Vector2(px + 12.0, by + bh - 1.0), Vector2(clampf(c.x, px - 10.0, px + 10.0), by + bh + 17.0)]), Color(accent.r, accent.g, accent.b, 0.9 * a))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 10.0, by + bh - 3.0), Vector2(px + 10.0, by + bh - 3.0), Vector2(clampf(c.x, px - 8.0, px + 8.0), by + bh + 12.0)]), Color(0.04, 0.025, 0.08, 0.94 * a))
	Gfx.text(ci, GameState.f_display, String(info["title"]), Vector2(bx + 22.0, by + 44.0), 30, Color(accent.r, accent.g, accent.b, a), 0, 0.6)
	for i in lines.size():
		Gfx.text(ci, GameState.f_ui, String(lines[i]), Vector2(bx + 22.0, by + 74.0 + 25.0 * float(i)), 19, Color(0.95, 0.92, 0.9, 0.92 * a), 0, 0.5)
	# progress dots (which of the four buttons this is)
	for i in STEPS.size():
		var dc := Vector2(bx + bw - 24.0 - float(STEPS.size() - 1 - i) * 16.0, by + 30.0)
		if i == step:
			ci.draw_circle(dc, 5.0, Color(accent.r, accent.g, accent.b, a))
		else:
			ci.draw_circle(dc, 4.0, Color(1, 1, 1, 0.22 * a))
	Gfx.text(ci, GameState.spaced(GameState.f_bold, 3.0), "TRY IT NOW", Vector2(bx + bw - 22.0, by + bh - 14.0), 12, Color(accent.r, accent.g, accent.b, (0.55 + 0.45 * pulse) * a), 2, 0.4)
