extends Node
## Main menu. The live game runs behind it ("attract" mode, runner shifted to the right third,
## and every so often it glances back). UI is a left-aligned column of custom controls with
## three pages: main, settings, dress / accessories. Everything is laid out from the real viewport size,
## so it fills any 16:9..21:9 (or taller) screen and is rebuilt if the window changes.

const GAME_SCENE := "res://scenes/game.tscn"
const CINEMATIC_SCENE := "res://scenes/cinematic.tscn"
const VERSION := "v1.0.0"

var _layer: CanvasLayer
var _root: Control
var _pages := {}
var _page: StringName = &"main"
var _info: Label
var _cards: Array = [[], []]   ## CosmeticCards per kind (0 = dresses, 1 = accessories)
var _tab_btns: Array[FancyButton] = []
var _tab := 0
var _rebuild_queued := false


class LeftShade extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.66, 0), Vector2(w * 0.66, h), Vector2(0, h)]),
			PackedColorArray([Color(0.01, 0, 0.02, 0.82), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.01, 0, 0.02, 0.82)]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))


class StatsBar extends Control:
	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var u := Cfg.ui_scale()
		var items := [
			["BEST SCORE", str(GameState.best_score), &"star"],
			["FARTHEST", "%d M" % GameState.best_meters, &"dash"],
			["SHARDS", str(GameState.total_shards), &"gem"],
		]
		for i in 3:
			var x := float(i) * 200.0 * u
			draw_line(Vector2(x, 6.0 * u), Vector2(x, 76.0 * u), Color(1, 1, 1, 0.12), 1.0)
			UIDraw.icon(self, items[i][2], Vector2(x + 24.0 * u, 20.0 * u), 15.0 * u, Color(Cfg.COL_BONE.r, Cfg.COL_BONE.g, Cfg.COL_BONE.b, 0.5))
			Gfx.text(self, GameState.spaced(GameState.f_bold, 3.0), items[i][0], Vector2(x + 42.0 * u, 26.0 * u), int(12.0 * u), Color(1, 1, 1, 0.5), 0, 0.4)
			Gfx.text(self, GameState.f_num, items[i][1], Vector2(x + 16.0 * u, 70.0 * u), int(42.0 * u), Cfg.COL_BONE, 0, 0.8)


func _ready() -> void:
	# The very first launch of a fresh install opens with the cinematic instead of the menu. It records
	# itself as seen when it ends or is skipped, so every later launch comes straight here. If it cannot be
	# loaded for any reason, never trap the player on a first boot: mark it seen and carry on.
	if not GameState.intro_seen:
		var cine := load(CINEMATIC_SCENE) as PackedScene
		if cine != null:
			get_tree().change_scene_to_packed.call_deferred(cine)
			return
		GameState.intro_seen = true
		GameState.save_data()
	var bg = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	bg.attract = true
	add_child(bg)
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	get_viewport().size_changed.connect(_queue_rebuild)
	_build()
	Transition.boot_fade()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_do_rebuild")


func _do_rebuild() -> void:
	_rebuild_queued = false
	_build()


# ------------------------------------------------------------------ construction
func _page_ctl() -> Control:
	var c := Control.new()
	c.size = Vector2(Cfg.view_w, Cfg.view_h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _label(text: String, font: Font, size: int, col: Color, pos: Vector2, sz: Vector2, align: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align as HorizontalAlignment
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(parent: Control, text: String, ic: StringName, style: int, pos: Vector2, sz: Vector2, fs: int) -> FancyButton:
	var b := FancyButton.new()
	b.label = text
	b.icon = ic
	b.style = style
	b.font_size = fs
	b.position = pos
	b.size = sz
	parent.add_child(b)
	return b


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_cards = [[], []]
	_tab_btns.clear()
	var u := Cfg.ui_scale()
	_root = Control.new()
	_root.size = Vector2(Cfg.view_w, Cfg.view_h)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	var shade := LeftShade.new()
	shade.size = _root.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var x0 := Cfg.hud_rect().position.x + 38.0 * u
	_pages = {}
	_pages[&"main"] = _build_main(x0, u)
	_pages[&"settings"] = _build_settings(x0, u)
	_pages[&"dress"] = _build_dress(x0, u)
	for k in _pages:
		_root.add_child(_pages[k])
	_show_page(_page, false)


func _build_main(x0: float, u: float) -> Control:
	var p := _page_ctl()
	var tex := load("res://assets/images/logo.png") as Texture2D
	var lw := 600.0 * u
	var lh := 160.0 * u
	if tex != null:
		lh = lw * float(tex.get_height()) / float(tex.get_width())
		var logo := TextureRect.new()
		logo.texture = tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.position = Vector2(x0 - 22.0 * u, 52.0 * u)
		logo.size = Vector2(lw, lh)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(logo)
	else:
		p.add_child(_label("404: Alive", GameState.f_display, int(64.0 * u), Cfg.COL_BONE, Vector2(x0, 70.0 * u), Vector2(lw, 90.0 * u)))
	var ty := 52.0 * u + lh + 4.0 * u
	p.add_child(_label("It has been following you for a long time.", GameState.f_display, int(21.0 * u), Color(0.82, 0.58, 0.66, 0.9), Vector2(x0, ty), Vector2(lw, 32.0 * u)))
	var by := ty + 66.0 * u
	var hr := Cfg.hud_rect()
	# The RUN button is icon-only and tall; DRESS / SETTINGS sit under it. Together they fill the empty
	# band between the tagline and the stats bar. If a big bottom inset squeezes that band, shrink to fit
	# (never below ~75%, i.e. never smaller than the old sizes).
	var fit := clampf((hr.end.y - 96.0 * u - 16.0 * u - by) / (236.0 * u), 0.75, 1.0)
	var run_h := 132.0 * u * fit
	var row_h := 84.0 * u * fit
	var run := _button(p, "", &"play", FancyButton.Style.PRIMARY, Vector2(x0, by), Vector2(372.0 * u, run_h), 36)
	run.pressed.connect(_on_play)
	by += run_h + 20.0 * u
	var sc := _button(p, "DRESS", &"dress", FancyButton.Style.GHOST, Vector2(x0, by), Vector2(178.0 * u, row_h), 18)
	sc.pressed.connect(_show_page.bind(&"dress", true))
	var st := _button(p, "SETTINGS", &"gear", FancyButton.Style.GHOST, Vector2(x0 + 194.0 * u, by), Vector2(178.0 * u, row_h), 18)
	st.pressed.connect(_show_page.bind(&"settings", true))
	var bar := StatsBar.new()
	bar.position = Vector2(x0 - 16.0 * u, hr.end.y - 96.0 * u)
	bar.size = Vector2(620.0 * u, 90.0 * u)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bar)
	p.add_child(_label(VERSION, GameState.f_ui, int(13.0 * u), Color(1, 1, 1, 0.35), Vector2(hr.end.x - 120.0 * u, hr.end.y - 18.0 * u), Vector2(120.0 * u, 20.0 * u), 2))
	return p


func _build_settings(x0: float, u: float) -> Control:
	var p := _page_ctl()
	var panel := GlassPanel.new()
	panel.title = "SETTINGS"
	panel.position = Vector2(x0 - 10.0 * u, 48.0 * u)
	panel.size = Vector2(540.0 * u, 624.0 * u)
	p.add_child(panel)
	var rows := [
		["Sound", &"sound", &"sound_on"],
		["Haptics", &"haptic", &"haptics_on"],
		["Screen shake", &"shake", &"shake_on"],
		["Low effects mode", &"fx", &"low_fx"],
		["Battery saver (30 FPS)", &"battery", &"fps30"],
		["Show FPS counter", &"fps", &"show_fps"],
	]
	var y := 104.0 * u
	for r in rows:
		var s := SwitchRow.new()
		s.label = r[0]
		s.icon = r[1]
		s.on = GameState.get(r[2])
		s.position = Vector2(26.0 * u, y)
		s.size = Vector2(panel.size.x - 52.0 * u, 58.0 * u)
		s.toggled.connect(_on_setting.bind(r[2]))
		panel.add_child(s)
		y += 64.0 * u
	panel.add_child(_label("Fonts: Gloock, Big Shoulders, Instrument Sans (SIL Open Font License 1.1).  Made with the Godot Engine.", GameState.f_ui, int(13.0 * u), Color(1, 1, 1, 0.38), Vector2(30.0 * u, y + 8.0 * u), Vector2(panel.size.x - 60.0 * u, 40.0 * u)))
	var back := _button(panel, "BACK", &"back", FancyButton.Style.GHOST, Vector2(26.0 * u, panel.size.y - 82.0 * u), Vector2(panel.size.x - 52.0 * u, 60.0 * u), 18)
	back.pressed.connect(_show_page.bind(&"main", true))
	return p


func _build_dress(x0: float, u: float) -> Control:
	var p := _page_ctl()
	var panel := GlassPanel.new()
	panel.title = "DRESS / ACCESSORIES"
	panel.position = Vector2(x0 - 10.0 * u, 36.0 * u)
	panel.size = Vector2(540.0 * u, 640.0 * u)
	p.add_child(panel)
	var inner := panel.size.x - 52.0 * u
	# two tabs
	var tw := (inner - 12.0 * u) * 0.5
	for k in 2:
		var tb := _button(panel, "DRESS" if k == 0 else "ACCESSORIES", &"", FancyButton.Style.GHOST, Vector2(26.0 * u + float(k) * (tw + 12.0 * u), 98.0 * u), Vector2(tw, 48.0 * u), 15)
		tb.pressed.connect(_on_tab.bind(k))
		_tab_btns.append(tb)
	# 3-column grids of tiles, one grid per tab (only the active one is visible)
	var gap := 14.0 * u
	var cw := (inner - 2.0 * gap) / 3.0
	var ch := 142.0 * u
	for kind in 2:
		var list := GameState.cosmetic_list(kind)
		for i in list.size():
			var card := CosmeticCard.new()
			card.kind = kind
			card.index = i
			card.position = Vector2(26.0 * u + float(i % 3) * (cw + gap), 164.0 * u + float(floori(float(i) / 3.0)) * (ch + gap))
			card.size = Vector2(cw, ch)
			card.pressed.connect(_on_card.bind(kind, i))
			panel.add_child(card)
			_cards[kind].append(card)
	_info = _label("", GameState.f_ui, int(17.0 * u), Color(1, 1, 1, 0.75), Vector2(30.0 * u, 480.0 * u), Vector2(panel.size.x - 60.0 * u, 70.0 * u), 1)
	panel.add_child(_info)
	var back := _button(panel, "BACK", &"back", FancyButton.Style.GHOST, Vector2(26.0 * u, panel.size.y - 78.0 * u), Vector2(inner, 58.0 * u), 18)
	back.pressed.connect(_show_page.bind(&"main", true))
	_refresh_dress()
	return p


func _refresh_dress(msg: String = "") -> void:
	for kind in 2:
		var tried_i := GameState.preview_dress if kind == 0 else GameState.preview_accessory
		var eq := GameState.equipped(kind)
		for i in _cards[kind].size():
			var card: CosmeticCard = _cards[kind][i]
			card.visible = (kind == _tab)
			card.locked = not GameState.cosmetic_unlocked(kind, i)
			card.equipped = (i == eq)
			card.tried = card.locked and i == tried_i
	for k in _tab_btns.size():
		_tab_btns[k].selected = (k == _tab)
	if _info == null:
		return
	if msg != "":
		_info.text = msg
		return
	var list := GameState.cosmetic_list(_tab)
	var cur: Dictionary = list[GameState.equipped(_tab)]
	var line := "%s equipped.  %s" % [String(cur["name"]).to_upper(), String(cur["blurb"])]
	for i in list.size():
		if not GameState.cosmetic_unlocked(_tab, i):
			line += "\nNext: %s at %d shards  (you have %d)" % [String(list[i]["name"]).to_upper(), int(list[i]["cost"]), GameState.total_shards]
			break
	_info.text = line


# ------------------------------------------------------------------ behaviour
func _show_page(p: StringName, animate: bool = true) -> void:
	_page = p
	if p != &"dress":
		GameState.clear_preview()   # a try-on never outlives the page
	else:
		_refresh_dress()
	for k in _pages:
		var pg: Control = _pages[k]
		if k == p:
			pg.visible = true
			if animate:
				pg.modulate.a = 0.0
				pg.position.x = -28.0
				var tw := create_tween().set_parallel(true)
				tw.tween_property(pg, "modulate:a", 1.0, 0.22)
				tw.tween_property(pg, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			else:
				pg.modulate.a = 1.0
				pg.position.x = 0.0
		else:
			pg.visible = false


func _on_setting(on: bool, prop: StringName) -> void:
	GameState.set(prop, on)
	GameState.apply_settings()
	GameState.save_data()


func _on_tab(k: int) -> void:
	_tab = k
	_refresh_dress()


## Owned: equip it. Locked: try it on the runner (shown live behind the menu) and say what it costs.
func _on_card(kind: int, i: int) -> void:
	var item: Dictionary = GameState.cosmetic_list(kind)[i]
	if GameState.cosmetic_unlocked(kind, i):
		if kind == 0:
			GameState.dress = i
			GameState.preview_dress = -1
		else:
			GameState.accessory = i
			GameState.preview_accessory = -1
		GameState.save_data()
		Audio.play(&"powerup", -10.0, 1.3)
		_refresh_dress()
	else:
		if kind == 0:
			GameState.preview_dress = i
		else:
			GameState.preview_accessory = i
		Audio.play(&"hit", -16.0, 1.6)
		_refresh_dress("Trying on %s.  Collect %d more shards to unlock it." % [String(item["name"]).to_upper(), int(item["cost"]) - GameState.total_shards])


func _on_play() -> void:
	Audio.play(&"ui_click")
	Transition.go(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ENTER and _page == &"main":
		_on_play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _page != &"main":
			_show_page(&"main", true)
		else:
			get_tree().quit()
