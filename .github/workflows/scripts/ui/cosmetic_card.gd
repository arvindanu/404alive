class_name CosmeticCard
extends Control
## One tile on the DRESS / ACCESSORIES page: icon, name, and either its price (locked), OWNED, or
## EQUIPPED. Tapping emits `pressed`; the menu decides whether that equips it or just tries it on.

signal pressed

var kind := 0            ## 0 = dress, 1 = accessory
var index := 0
var locked := false
var equipped := false
var tried := false       ## currently shown on the runner as a try-on (not yet owned)
var _hover := 0.0
var _down := false
var _hovering := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(dt: float) -> void:
	_hover = lerpf(_hover, 1.0 if _hovering else 0.0, 1.0 - exp(-14.0 * dt))
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
	var item: Dictionary = GameState.cosmetic_list(kind)[index]
	var accent: Color = item["color"]
	var hl := 1.0 if (equipped or tried) else 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.11, 0.80 + 0.1 * _hover)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.22 + 0.30 * _hover + 0.6 * hl)
	sb.set_border_width_all(2 if hl > 0.0 else 1)
	sb.set_corner_radius_all(int(size.y * 0.09))
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if equipped:
		Gfx.glow(self, Vector2(size.x * 0.5, size.y * 0.38), size.y * 0.62, Color(accent.r, accent.g, accent.b, 0.20))
	CosmeticArt.icon(self, kind, index, Vector2(size.x * 0.5, size.y * 0.39), size.y * 0.56, 0.38 if locked else 1.0)
	var fs := int(size.y * 0.088)
	Gfx.text(self, GameState.spaced(GameState.f_bold, 1.5), String(item["name"]).to_upper(), Vector2(size.x * 0.5, size.y * 0.74), fs, Color(1, 1, 1, 0.55 if locked else 0.92), 1, 0.4)
	var fy := size.y * 0.90
	if locked:
		var cost := str(int(item["cost"]))
		var f: Font = GameState.f_num
		var cs := int(size.y * 0.115)
		var tw := f.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		var gx := size.x * 0.5 - (tw + size.y * 0.13) * 0.5
		UIDraw.icon(self, &"gem", Vector2(gx + size.y * 0.05, fy - size.y * 0.04), size.y * 0.11, UIDraw.GOLD)
		Gfx.text(self, f, cost, Vector2(gx + size.y * 0.13, fy), cs, UIDraw.GOLD, 0, 0.5)
		UIDraw.icon(self, &"lock", Vector2(size.x - size.y * 0.11, size.y * 0.11), size.y * 0.12, Color(1, 1, 1, 0.65))
	elif equipped:
		Gfx.text(self, GameState.spaced(GameState.f_bold, 2.0), "EQUIPPED", Vector2(size.x * 0.5, fy), int(size.y * 0.085), UIDraw.CYAN, 1, 0.4)
		UIDraw.icon(self, &"check", Vector2(size.x - size.y * 0.11, size.y * 0.11), size.y * 0.12, UIDraw.CYAN)
	else:
		Gfx.text(self, GameState.spaced(GameState.f_bold, 2.0), "OWNED", Vector2(size.x * 0.5, fy), int(size.y * 0.085), Color(1, 1, 1, 0.45), 1, 0.4)
