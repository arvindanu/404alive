class_name SwitchRow
extends Control
## A settings row: icon, label, animated toggle switch.

signal toggled(on: bool)

var label := ""
var icon: StringName = &""
var on := true : set = _set_on
var _k := 1.0
var _down := false
var _hover := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _set_on(v: bool) -> void:
	on = v
	queue_redraw()


func _process(dt: float) -> void:
	_k = lerpf(_k, 1.0 if on else 0.0, 1.0 - exp(-16.0 * dt))
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
	else:
		if _down and Rect2(Vector2.ZERO, size).has_point(mb.position):
			on = not on
			Audio.play(&"ui_click", -6.0, 1.0 if on else 0.85)
			toggled.emit(on)
		_down = false


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.04 + (0.05 if _down else 0.0))
	bg.set_corner_radius_all(int(size.y * 0.25))
	draw_style_box(bg, r)
	var cy := size.y * 0.5
	UIDraw.icon(self, icon, Vector2(size.y * 0.55, cy), size.y * 0.42, Cfg.COL_BONE.lerp(Cfg.COL_CRIMSON, _k * 0.0), 1.0 if on else 0.0)
	Gfx.text(self, GameState.f_ui, label, Vector2(size.y * 1.05, cy + size.y * 0.13), int(size.y * 0.36), Cfg.COL_BONE, 0, 0.5)
	# switch
	var tw := size.y * 0.95
	var th := size.y * 0.5
	var tx := size.x - tw - size.y * 0.35
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.25, 0.22, 0.32, 0.9).lerp(Cfg.COL_CRIMSON, _k)
	track.set_corner_radius_all(int(th * 0.5))
	track.anti_aliasing = true
	draw_style_box(track, Rect2(tx, cy - th * 0.5, tw, th))
	var kx := lerpf(tx + th * 0.5, tx + tw - th * 0.5, _k)
	if _k > 0.05:
		Gfx.glow(self, Vector2(kx, cy), th, Color(Cfg.COL_CRIMSON.r, Cfg.COL_CRIMSON.g, Cfg.COL_CRIMSON.b, 0.4 * _k))
	draw_circle(Vector2(kx, cy), th * 0.36, Color.WHITE)
