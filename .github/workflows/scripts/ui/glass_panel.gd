class_name GlassPanel
extends Control
## A titled glass card. Children are positioned by the owner.

var title := ""
var accent := Cfg.COL_CRIMSON


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	UIDraw.glass(self, Rect2(Vector2.ZERO, size), 16, accent)
	if title != "":
		var u := Cfg.ui_scale()
		Gfx.text(self, GameState.f_display, title, Vector2(30.0 * u, 62.0 * u), int(38.0 * u), Cfg.COL_BONE, 0, 0.6)
		draw_line(Vector2(30.0 * u, 76.0 * u), Vector2(30.0 * u + 54.0 * u, 76.0 * u), accent, 3.0)
