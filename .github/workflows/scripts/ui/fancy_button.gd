class_name FancyButton
extends Control
## Animated custom button. Styles: PRIMARY (crimson, glowing), GHOST (outlined glass),
## ICON (round glass), SWATCH (colour chip, optionally locked).

signal pressed

enum Style { PRIMARY, GHOST, ICON, SWATCH }

var label := ""
var icon: StringName = &""
var style: int = Style.GHOST
var accent := Cfg.COL_CRIMSON
var swatch := Color.WHITE
var locked := false
var selected := false
var sub_label := ""       ## small text (e.g. unlock cost)
var font_size := 26
var _hover := 0.0
var _press := 0.0
var _down := false
var _hovering := false
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(dt: float) -> void:
	_t += dt
	_hover = lerpf(_hover, 1.0 if _hovering else 0.0, 1.0 - exp(-14.0 * dt))
	_press = lerpf(_press, 1.0 if _down else 0.0, 1.0 - exp(-28.0 * dt))
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
		Audio.play(&"ui_click", -8.0, 1.15)
	else:
		if _down and Rect2(Vector2.ZERO, size).has_point(mb.position):
			pressed.emit()
		_down = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovering = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false
		_down = false


func _draw() -> void:
	var sc := 1.0 - 0.05 * _press
	draw_set_transform(size * 0.5 * (1.0 - sc), 0.0, Vector2(sc, sc))
	match style:
		Style.PRIMARY:
			_draw_primary()
		Style.ICON:
			_draw_icon()
		Style.SWATCH:
			_draw_swatch()
		_:
			_draw_ghost()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _sb(fill: Color, border: Color, radius: int, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _draw_primary() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pulse := 0.5 + 0.5 * sin(_t * 2.6)
	Gfx.glow_ellipse(self, size * 0.5, size.x * 0.72, size.y * 1.0, Color(accent.r, accent.g, accent.b, 0.22 + 0.10 * pulse + 0.15 * _hover))
	var fill := accent.darkened(0.30).lerp(accent, 0.25 * _hover + 0.4 * _press)
	draw_style_box(_sb(fill, Color(1, 1, 1, 0.28 + 0.2 * _hover), int(size.y * 0.22), 2), r)
	draw_line(Vector2(size.y * 0.22, 3.0), Vector2(size.x - size.y * 0.22, 3.0), Color(1, 1, 1, 0.22), 2.0)   # sheen
	var f := GameState.spaced(GameState.f_bold, 4.0)
	var fs := int(font_size)
	var has_label := label != ""
	var has_icon := icon != &""
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if has_label else 0.0
	# an icon-only button gets a bigger icon, centred exactly (no gap reserved for a missing label)
	var ic := size.y * (0.36 if has_label else 0.50) if has_icon else 0.0
	var gap := 16.0 if (has_label and has_icon) else 0.0
	var total := tw + ic + gap
	var x0 := (size.x - total) * 0.5
	if has_icon:
		var ic_c := Vector2(x0 + ic * 0.5, size.y * 0.5)
		if not has_label and icon == &"play":
			ic_c.x -= ic * 0.03   # a play triangle is heavy on its flat side: balance bounding box vs. centre of mass
		UIDraw.icon(self, icon, ic_c, ic, Color(1, 1, 1, 0.95))
		x0 += ic + gap
	if has_label:
		Gfx.text(self, f, label, Vector2(x0, size.y * 0.5 + fs * 0.34), fs, Color.WHITE, 0, 0.6)


func _draw_ghost() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var b := 0.22 + 0.35 * _hover + 0.3 * _press
	var fill := Color(0.05, 0.03, 0.09, 0.62 + 0.15 * _hover)
	if selected:   # an active tab
		b = 0.85
		fill = Color(0.30, 0.05, 0.11, 0.80)
	draw_style_box(_sb(fill, Color(1, 1, 1, b), int(size.y * 0.22), 1), r)
	var f := GameState.spaced(GameState.f_bold, 3.0)
	var fs := int(font_size)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ic := minf(size.y * 0.40, size.x * 0.16) if icon != &"" else 0.0   # tall + narrow buttons keep a sensible icon size
	var total := tw + (ic + 14.0 if icon != &"" else 0.0)
	var x0 := (size.x - total) * 0.5
	var col := Cfg.COL_BONE.lerp(Color.WHITE, _hover)
	if icon != &"":
		UIDraw.icon(self, icon, Vector2(x0 + ic * 0.5, size.y * 0.5), ic, col)
		x0 += ic + 14.0
	Gfx.text(self, f, label, Vector2(x0, size.y * 0.5 + fs * 0.34), fs, col, 0, 0.5)


func _draw_icon() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5
	draw_circle(c, rad, Color(0.05, 0.03, 0.09, 0.62 + 0.2 * _hover))
	draw_arc(c, rad - 1.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22 + 0.4 * _hover), 1.5, true)
	UIDraw.icon(self, icon, c, rad * 0.95, Cfg.COL_BONE.lerp(Color.WHITE, _hover))


func _draw_swatch() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5 - 4.0
	if selected:
		Gfx.glow(self, c, rad * 2.0, Color(swatch.r, swatch.g, swatch.b, 0.35))
		draw_arc(c, rad + 4.0, 0.0, TAU, 40, Color(1, 1, 1, 0.95), 3.0, true)
	else:
		draw_arc(c, rad + 3.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12 + 0.3 * _hover), 1.5, true)
	var col := swatch.darkened(0.78) if locked else swatch
	draw_circle(c, rad, col)
	draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.3, Color(1, 1, 1, 0.12 if locked else 0.22))
	if locked:
		UIDraw.icon(self, &"lock", c + Vector2(0.0, -rad * 0.12), rad * 0.8, Color(1, 1, 1, 0.75))
		if sub_label != "":
			Gfx.text(self, GameState.f_bold, sub_label, c + Vector2(0.0, rad * 0.72), int(rad * 0.46), Color(1, 1, 1, 0.8), 1, 0.4)
	elif selected:
		UIDraw.icon(self, &"check", c, rad * 0.8, Color(0, 0, 0, 0.55))
