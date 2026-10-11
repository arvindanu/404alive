extends Control
## In-game HUD + touch controls. Minimal, high-contrast, edge-anchored (respects notches).
## Uses raw InputEventScreenTouch indices so several fingers work at once (hold LOOK with the
## left thumb while jumping/sliding with the right). On desktop the mouse acts as one touch.
##
##   left thumb : LOOK (hold)  DASH        right thumb : SLIDE (hold)  JUMP (hold = higher)

const PAUSE_MENU := preload("res://scenes/pause_menu.tscn")
const BONE := Cfg.COL_BONE

var game = null
var paused := false
var _pause_ui: Node = null
var _touches := {}   # pointer index -> action
var _down := {&"look": false, &"dash": false, &"slide": false, &"jump": false}
var _labels_alpha := 1.0


func setup(g) -> void:
	game = g


func on_pause_changed(p: bool) -> void:
	paused = p
	if p:
		_release_all()
		_pause_ui = PAUSE_MENU.instantiate()
		_pause_ui.setup(game)
		game.add_child(_pause_ui)
	elif _pause_ui != null:
		_pause_ui.queue_free()
		_pause_ui = null


func _release_all() -> void:
	for idx in _touches.keys():
		var a: StringName = _touches[idx]
		_down[a] = false
		game.on_action(a, false)
	_touches.clear()


func _process(_dt: float) -> void:
	queue_redraw()


# ------------------------------------------------------------------ layout
## Button centres/radii follow the real screen edges, so they sit under the thumbs on any aspect.
func _btns() -> Dictionary:
	var lx := Cfg.CONTROL_EDGE + 84.0   # centre x of the big buttons, measured from the nearest screen edge
	var by := Cfg.view_h - 126.0        # big buttons: 42 px above the bottom edge
	var sy := Cfg.view_h - 82.0         # small buttons: 24 px above the bottom edge
	return {
		&"look": [Vector2(lx, by), 84.0],
		&"dash": [Vector2(lx + 178.0, sy), 58.0],
		&"slide": [Vector2(Cfg.view_w - lx - 178.0, sy), 58.0],
		&"jump": [Vector2(Cfg.view_w - lx, by), 84.0],
	}


func _pause_pos() -> Vector2:
	var hr := Cfg.hud_rect()
	return Vector2(hr.end.x - 27.0, hr.position.y + 27.0)


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if game == null or not game.hud_layer.visible:
		return
	if event.is_action_pressed(&"pause"):
		game.toggle_pause()
		return
	if paused:
		return
	var idx := -1
	var pos := Vector2.ZERO
	var pressed := false
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if touch != null:
		idx = touch.index
		pos = touch.position
		pressed = touch.pressed
	elif mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		idx = 99
		pos = mouse.position
		pressed = mouse.pressed
	else:
		return
	if pressed:
		_pointer_down(idx, pos)
	else:
		_pointer_up(idx)


func _pointer_down(idx: int, pos: Vector2) -> void:
	if not game.is_playing():
		return
	if pos.distance_to(_pause_pos()) < 44.0:
		game.toggle_pause()
		return
	if game.tut_hold and TutorialDraw.skip_rect(Vector2(Cfg.view_w, Cfg.view_h)).grow(14.0).has_point(pos):
		game.tut_skip()
		return
	var best: StringName = &""
	var best_d := 1.0e9
	var defs := _btns()
	for a in defs:
		var d := pos.distance_to(defs[a][0] as Vector2)
		if d < (defs[a][1] as float) + 28.0 and d < best_d:
			best = a
			best_d = d
	if best != &"" and game.tut_hold and best != game.TUT_ACTIONS[game.tut_step]:
		best = &""   # the run is frozen on a prompt: only the highlighted button responds
	if best != &"":
		_touches[idx] = best
		_down[best] = true
		game.on_action(best, true)


func _pointer_up(idx: int) -> void:
	if _touches.has(idx):
		var a: StringName = _touches[idx]
		_touches.erase(idx)
		_down[a] = false
		game.on_action(a, false)


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if game == null or game.mode != 1:   # 1 == Mode.PLAY
		return
	var g = game
	var hr := Cfg.hud_rect()
	var cx := Cfg.view_w * 0.5
	var f_num: Font = GameState.f_num
	var f_lbl: Font = GameState.spaced(GameState.f_bold, 3.0)

	# ---- top-left: distance + score
	draw_line(Vector2(hr.position.x - 14.0, hr.position.y + 8.0), Vector2(hr.position.x - 14.0, hr.position.y + 86.0), Cfg.COL_CRIMSON, 3.0)
	var ms := str(int(g.meters))
	Gfx.text(self, f_num, ms, Vector2(hr.position.x, hr.position.y + 58.0), 66, BONE, 0, 0.8)
	var mw := f_num.get_string_size(ms, HORIZONTAL_ALIGNMENT_LEFT, -1, 66).x
	Gfx.text(self, f_lbl, "M", Vector2(hr.position.x + mw + 8.0, hr.position.y + 58.0), 20, Color(BONE.r, BONE.g, BONE.b, 0.55), 0, 0.5)
	Gfx.text(self, f_lbl, "SCORE", Vector2(hr.position.x, hr.position.y + 86.0), 13, Color(BONE.r, BONE.g, BONE.b, 0.5), 0, 0.5)
	Gfx.text(self, f_num, str(int(g.score)), Vector2(hr.position.x + 62.0, hr.position.y + 88.0), 28, Color(BONE.r, BONE.g, BONE.b, 0.85), 0, 0.6)

	# ---- top-centre: how close is it?
	_threat_meter(g, cx, hr.position.y)

	# ---- top-right: pause, shards, multiplier
	var pp := _pause_pos()
	draw_circle(pp, 27.0, Color(0.05, 0.03, 0.09, 0.6))
	draw_arc(pp, 26.0, 0.0, TAU, 36, Color(1, 1, 1, 0.25), 1.5, true)
	UIDraw.icon(self, &"pause", pp, 24.0, Color(BONE.r, BONE.g, BONE.b, 0.9))
	var sx := pp.x - 46.0
	var shards_s := str(g.run_shards)
	Gfx.text(self, f_num, shards_s, Vector2(sx, hr.position.y + 44.0), 46, UIDraw.GOLD, 2, 0.8)
	var sw := f_num.get_string_size(shards_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	UIDraw.icon(self, &"gem", Vector2(sx - sw - 18.0, hr.position.y + 28.0), 24.0, UIDraw.GOLD)
	var mu: float = g.multiplier()
	if mu > 1.0:
		var txt := "x%.1f" % mu
		var tw := f_num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.45, 0.3, 0.8, 0.35)
		pill.border_color = Color(UIDraw.VIOLET.r, UIDraw.VIOLET.g, UIDraw.VIOLET.b, 0.8)
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(14)
		pill.anti_aliasing = true
		draw_style_box(pill, Rect2(sx - tw - 22.0, hr.position.y + 58.0, tw + 22.0, 30.0))
		Gfx.text(self, f_num, txt, Vector2(sx - 11.0, hr.position.y + 82.0), 28, UIDraw.VIOLET, 2, 0.6)

	# ---- active power-ups
	var ch: Array = []
	if g.lantern_t > 0.0:
		ch.append([&"flame", Color(1.0, 0.68, 0.24), g.lantern_t / 9.0, str(int(ceilf(g.lantern_t)))])
	if g.relic_t > 0.0:
		ch.append([&"diamond", UIDraw.VIOLET, g.relic_t / 12.0, str(int(ceilf(g.relic_t)))])
	if g.shield:
		ch.append([&"ward", UIDraw.CYAN, 1.0, ""])
	for i in ch.size():
		var cc := Vector2(cx - float(ch.size() - 1) * 52.0 + float(i) * 104.0, hr.position.y + 112.0)
		var col: Color = ch[i][1]
		draw_circle(cc, 21.0, Color(0.05, 0.03, 0.09, 0.6))
		draw_arc(cc, 21.0, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.25), 3.0, true)
		draw_arc(cc, 21.0, -PI * 0.5, -PI * 0.5 + TAU * float(ch[i][2]), 32, col, 3.5, true)
		UIDraw.icon(self, ch[i][0], cc, 22.0, col)
		if ch[i][3] != "":
			Gfx.text(self, f_num, ch[i][3], cc + Vector2(30.0, 9.0), 26, col, 0, 0.6)

	# ---- message line
	if g.msg_t > 0.0 and g.msg != "":
		var since: float = g.msg_dur - g.msg_t
		var a := clampf(since / 0.18, 0.0, 1.0) * clampf(g.msg_t / 0.45, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - clampf(since / 0.3, 0.0, 1.0), 3.0)
		var my := hr.position.y + 190.0 - (1.0 - e) * 12.0
		var f_msg: Font = GameState.spaced(GameState.f_display, 2.0)
		Gfx.text(self, f_msg, g.msg, Vector2(cx, my), 44, Color(BONE.r, BONE.g, BONE.b, a), 1, 0.8)
		var lw := 40.0 + 150.0 * e
		draw_line(Vector2(cx - lw, my + 18.0), Vector2(cx + lw, my + 18.0), Color(Cfg.COL_CRIMSON.r, Cfg.COL_CRIMSON.g, Cfg.COL_CRIMSON.b, 0.8 * a), 2.0)

	# ---- floating popups (+score, multipliers)
	for p in g.popups:
		var k: float = p["t"] / p["life"]
		var sp: Vector2 = g.cam * (p["pos"] as Vector2)
		var col2: Color = p["col"]
		col2.a = 1.0 - k * k
		Gfx.text(self, f_num, p["text"], sp + Vector2(0.0, -60.0 * (1.0 - pow(1.0 - k, 2.0))), 34, col2, 1, 0.8)

	# ---- something glints behind you: edge hint while you are NOT looking
	var pk = g.pickup
	if pk != null and g.look_a < 0.4:
		var c: Color = pk.color()
		var pa := 0.5 + 0.4 * sin(g.t * 8.0)
		var ex := Cfg.safe.x + 38.0
		var ey := Cfg.view_h * 0.46
		Gfx.glow(self, Vector2(ex, ey), 52.0, Color(c.r, c.g, c.b, 0.55 * pa))
		draw_circle(Vector2(ex, ey), 7.0, Color(c.r, c.g, c.b, pa))
		for k2 in 2:
			var off := fposmod(g.t * 1.6 + float(k2) * 0.5, 1.0)
			UIDraw.icon(self, &"back", Vector2(ex + 20.0 + off * 22.0, ey), 18.0, Color(c.r, c.g, c.b, (1.0 - off) * 0.8))
		Gfx.text(self, f_lbl, "LOOK", Vector2(ex, ey + 44.0), 14, Color(c.r, c.g, c.b, pa), 1, 0.5)

	# ---- touch controls
	_labels_alpha = 1.0 if GameState.runs < 3 else 0.0
	_button(g, &"look", _action_color(&"look"))
	_button(g, &"dash", Cfg.COL_DASH)
	_button(g, &"slide", Cfg.COL_SLIDE)
	_button(g, &"jump", Cfg.COL_JUMP)

	# ---- first-session tutorial: dim everything, re-draw the target button on top, explain it
	if g.tut_hold and g.tut_step >= 0 and g.tut_step < TutorialDraw.STEPS.size():
		var tid: StringName = g.TUT_ACTIONS[g.tut_step]
		var tcol := _action_color(tid)
		var view := Vector2(Cfg.view_w, Cfg.view_h)
		TutorialDraw.veil(self, view, g.tut_t)
		_button(g, tid, tcol)
		var td: Array = _btns()[tid]
		TutorialDraw.callout(self, g.tut_step, g.tut_t, td[0], td[1], tcol, view)
		TutorialDraw.draw_skip(self, view, g.tut_t)


func _action_color(id: StringName) -> Color:
	match id:
		&"jump":
			return Cfg.COL_JUMP
		&"slide":
			return Cfg.COL_SLIDE
		&"dash":
			return Cfg.COL_DASH
	return Cfg.COL_LOOK


func _threat_meter(g, cx: float, top: float) -> void:
	var thr: float = g.creature.threat()
	var beat: float = g.pulse
	var danger := clampf((thr - 0.6) / 0.4, 0.0, 1.0)
	var eye_col := BONE.lerp(Cfg.COL_CRIMSON, clampf(thr * 1.3, 0.0, 1.0))
	var ey := top + 20.0
	Gfx.glow(self, Vector2(cx, ey), 36.0 + beat * 14.0 * danger, Color(Cfg.COL_CRIMSON.r, Cfg.COL_CRIMSON.g, Cfg.COL_CRIMSON.b, 0.35 * thr))
	UIDraw.icon(self, &"eye", Vector2(cx, ey), 40.0, eye_col, lerpf(0.4, 1.0, thr))
	var n := 24
	var seg_w := 8.0
	var gap := 3.0
	var x0 := cx - (float(n) * (seg_w + gap) - gap) * 0.5
	var filled := thr * float(n)
	for i in n:
		var fi := float(i)
		var on := fi < filled
		var u := fi / float(n - 1)
		var col := Color(BONE.r, BONE.g, BONE.b, 0.55).lerp(Color(1.0, 0.6, 0.25), clampf(u * 2.0, 0.0, 1.0))
		col = col.lerp(Cfg.COL_CRIMSON, clampf(u * 2.0 - 1.0, 0.0, 1.0))
		if on:
			col.a = 0.95 * (1.0 + beat * 0.3 * danger)
		else:
			col = Color(1, 1, 1, 0.12)
		draw_rect(Rect2(x0 + fi * (seg_w + gap), top + 50.0, seg_w, 8.0 + (3.0 * beat * danger if on else 0.0)), col)


func _button(g, id: StringName, accent: Color) -> void:
	var d: Array = _btns()[id]
	var c: Vector2 = d[0]
	var r: float = d[1]
	var down: bool = _down[id]
	if down:
		r *= 0.95
		Gfx.glow(self, c, r * 1.9, Color(accent.r, accent.g, accent.b, 0.30))
	var usable := true
	if id == &"dash":
		usable = g.player.dash_cd <= 0.0
	var al := 1.0 if usable else 0.5
	draw_circle(c, r, Color(0.05, 0.03, 0.09, 0.78 if down else 0.52))
	if down:
		draw_circle(c, r, Color(accent.r, accent.g, accent.b, 0.20))
	draw_arc(c, r - 1.5, 0.0, TAU, 56, Color(accent.r, accent.g, accent.b, (0.95 if down else 0.55) * al), 2.5, true)
	draw_arc(c, r * 0.8, 0.0, TAU, 48, Color(1, 1, 1, 0.07), 1.5, true)
	var ic := Color(accent.r, accent.g, accent.b, al).lerp(Color.WHITE, 0.45 if down else 0.15)
	var isz := r * 0.92
	match id:
		&"jump":
			UIDraw.icon(self, &"up", c, isz, ic)
		&"slide":
			UIDraw.icon(self, &"down", c + Vector2(0.0, 4.0), isz, ic)
		&"dash":
			UIDraw.icon(self, &"dash", c, isz, ic)
			var frac: float = g.player.dash_ready_frac()
			if frac < 1.0:
				draw_arc(c, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(accent.r, accent.g, accent.b, 0.95), 4.0, true)
			else:
				draw_arc(c, r + 6.0, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.18 + 0.15 * sin(g.t * 5.0)), 2.0, true)
		&"look":
			UIDraw.icon(self, &"eye", c, isz, ic, 0.35 + 0.65 * g.look_a)
			var lt: float = clampf(g.creature.look_time / 2.0, 0.0, 1.0)
			if lt > 0.01:   # how long you have been staring: it fills red, then it lunges
				draw_arc(c, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * lt, 56, Color(1.0, 0.7, 0.3).lerp(Cfg.COL_CRIMSON, lt), 5.0, true)
	if _labels_alpha > 0.0:
		var names := {&"jump": "JUMP", &"slide": "SLIDE", &"dash": "DASH", &"look": "LOOK"}
		Gfx.text(self, GameState.spaced(GameState.f_bold, 2.0), names[id], c + Vector2(0.0, r + 24.0), 13, Color(1, 1, 1, 0.55), 1, 0.5)
