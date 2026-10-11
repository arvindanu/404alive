extends CanvasLayer
## Pause overlay: dimmed world, centred glass card with RESUME / RESTART / MENU and quick toggles.

var _game = null
var _panel: GlassPanel


func setup(g) -> void:
	_game = g


func _ready() -> void:
	var u := Cfg.ui_scale()
	var root := Control.new()
	root.size = Vector2(Cfg.view_w, Cfg.view_h)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.02, 0.66)
	dim.size = root.size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var w := 500.0 * u
	var h := 560.0 * u
	_panel = GlassPanel.new()
	_panel.title = "PAUSED"
	_panel.size = Vector2(w, h)
	_panel.position = (root.size - _panel.size) * 0.5
	_panel.pivot_offset = _panel.size * 0.5
	root.add_child(_panel)

	var bx := 34.0 * u
	var bw := w - 68.0 * u
	var y := 112.0 * u
	var resume := _button("RESUME", &"play", FancyButton.Style.PRIMARY, Vector2(bx, y), Vector2(bw, 78.0 * u), 26)
	resume.pressed.connect(_on_resume)
	y += 96.0 * u
	var restart := _button("RESTART", &"retry", FancyButton.Style.GHOST, Vector2(bx, y), Vector2(bw, 60.0 * u), 20)
	restart.pressed.connect(_on_restart)
	y += 74.0 * u
	var menu := _button("MAIN MENU", &"home", FancyButton.Style.GHOST, Vector2(bx, y), Vector2(bw, 60.0 * u), 20)
	menu.pressed.connect(_on_menu)
	y += 84.0 * u
	_switch("Sound", &"sound", &"sound_on", Vector2(bx, y), Vector2(bw, 56.0 * u))
	y += 60.0 * u
	_switch("Haptics", &"haptic", &"haptics_on", Vector2(bx, y), Vector2(bw, 56.0 * u))

	root.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.16)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _button(text: String, ic: StringName, style: int, pos: Vector2, sz: Vector2, fs: int) -> FancyButton:
	var b := FancyButton.new()
	b.label = text
	b.icon = ic
	b.style = style
	b.font_size = fs
	b.position = pos
	b.size = sz
	_panel.add_child(b)
	return b


func _switch(text: String, ic: StringName, prop: StringName, pos: Vector2, sz: Vector2) -> void:
	var s := SwitchRow.new()
	s.label = text
	s.icon = ic
	s.on = GameState.get(prop)
	s.position = pos
	s.size = sz
	s.toggled.connect(_on_setting.bind(prop))
	_panel.add_child(s)


func _on_setting(on: bool, prop: StringName) -> void:
	GameState.set(prop, on)
	GameState.apply_settings()
	GameState.save_data()


func _on_resume() -> void:
	_game.toggle_pause()


func _on_restart() -> void:
	_game.restart()


func _on_menu() -> void:
	_game.to_menu()
