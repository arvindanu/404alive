extends CanvasLayer
## Autoload "Transition": fade-through-black scene changes so nothing ever hard-cuts.

var _rect: ColorRect
var _busy := false
var _booted := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.012, 0.004, 0.024, 1.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 1.0
	add_child(_rect)


## First launch: fade in from black once.
func boot_fade(duration: float = 1.0) -> void:
	if _booted:
		return
	_booted = true
	_rect.modulate.a = 1.0
	create_tween().tween_property(_rect, "modulate:a", 0.0, duration)


func go(path: String) -> void:
	await _swap(func() -> void: get_tree().change_scene_to_file(path))


## Scene change with NO dip to black: the outgoing scene has already filled the screen with `col` (the first-boot
## cinematic ends on a white-out), so the cover is set to that exact colour first and then faded away over the
## new scene. Used once, from the cinematic into the first run.
func cut_through(path: String, col: Color, reveal: float = 1.2) -> void:
	if _busy:
		return
	_busy = true
	_booted = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.color = col
	_rect.modulate.a = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_rect, "modulate:a", 0.0, reveal).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	_rect.color = Color(0.012, 0.004, 0.024, 1.0)   # back to the normal fade colour
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func reload() -> void:
	await _swap(func() -> void: get_tree().reload_current_scene())


func _swap(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	_booted = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow taps during the fade
	var out := create_tween()
	out.tween_property(_rect, "modulate:a", 1.0, 0.28)
	await out.finished
	get_tree().paused = false
	action.call()
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_rect, "modulate:a", 0.0, 0.5)
	await back.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
