extends CanvasLayer
## Full-screen cinematic ending. The frozen world is still faintly visible behind everything (the
## creature looming, eyes burning) but the screen is almost black; the screen itself is the layout:
##   letterbox bars close in -> faint blood vignette -> "CONSUMED" slams across ~78% of the width with
##   glitch bursts (the ONLY place screen tearing is allowed) -> score counts up -> stats spread edge
##   to edge -> buttons fade in.
## The stage always covers the whole viewport (anchored full-rect, re-laid-out on resize). Text and
## buttons live in a centred layout box that is at least 16:9 wide, so the composition is the same
## on 4:3, 16:9, 20:9 and ultra-wide screens.
## Tap anywhere during the reveal to skip to the end (keeps "one more run" fast).

const LINES: Array[String] = [
	"It was right behind you the whole time.",
	"You looked. Of course you looked.",
	"Almost.",
	"It remembers your face.",
	"One more run. You know you want to.",
]
const READY_T := 1.9   ## seconds before the buttons are live

var _meters := 0.0
var _score := 0.0
var _shards := 0
var _result := {}
var _game = null
var _stage: Stage


class Stage extends Control:
	const LIVE_T := 1.9   ## seconds before the buttons accept taps
	const NUM_CAP := 0.81   ## digit height / font size for the Big Shoulders numerals (so the SCORE label can sit exactly above them)
	var meters := 0.0
	var score := 0.0
	var shards := 0
	var best := 0
	var new_best := false
	var unlocked: Array = []
	var line := ""
	var buttons: Array = []
	var t := 0.0
	var _pulse := 0.0
	var _tick := 0.0
	var _slammed := false
	var _counted := false
	var _scan := PackedVector2Array()
	var _scan_h := 0.0
	var _box := Rect2()          ## centred layout box inside the full-screen stage (>= 16:9 wide)
	var _u := 1.0                ## layout scale: box height / 720
	var _laid_for := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Everything on this screen is laid out inside a centred box that is at least 16:9 wide: on wider
	## screens it is the full height, on taller screens (4:3, square windows) it is a 16:9 band in the
	## middle. Backgrounds, vignette, letterbox and grain always use the full screen.
	func _measure() -> void:
		var bh := minf(size.y, size.x * 9.0 / 16.0)
		_box = Rect2(0.0, (size.y - bh) * 0.5, size.x, bh)
		_u = bh / 720.0

	## Re-position the two buttons from the current size. Called when they are added and whenever the
	## window / device resolution changes.
	func relayout() -> void:
		_measure()
		_laid_for = size
		if buttons.size() < 2:
			return
		var u := _u
		var bh := 62.0 * u
		var w1 := 330.0 * u
		var w2 := 190.0 * u
		var gap := 20.0 * u
		var x0 := (size.x - (w1 + w2 + gap)) * 0.5
		var by := _box.position.y + _box.size.y * 0.828
		buttons[0].font_size = int(roundf(26.0 * u))
		buttons[0].position = Vector2(x0, by)
		buttons[0].size = Vector2(w1, bh)
		buttons[1].font_size = int(roundf(18.0 * u))
		buttons[1].position = Vector2(x0 + w1 + gap, by)
		buttons[1].size = Vector2(w2, bh)

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and t < 2.4:
			t = 2.4   # skip the reveal

	func _process(dt: float) -> void:
		if size != _laid_for:
			relayout()
		t += dt
		_pulse = pow(maxf(0.0, sin(t * 4.4)), 8.0)   # a slow heartbeat the whole screen throbs to
		if not _slammed and t >= 0.3:
			_slammed = true
			Audio.play(&"sting", -7.0, 0.7)
		_tick -= dt
		if t > 1.1 and t < 2.35 and _tick <= 0.0:
			_tick = 0.055
			Audio.play(&"ui_click", -24.0, 0.7 + (t - 1.1) * 0.8)
		if not _counted and t >= 2.35:
			_counted = true
			if new_best:
				Audio.play(&"powerup", -9.0, 1.0)
		var reveal := clampf((t - 1.8) / 0.4, 0.0, 1.0)
		for b in buttons:
			b.modulate.a = reveal
			b.mouse_filter = Control.MOUSE_FILTER_STOP if t > LIVE_T else Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _e(k: float) -> float:
		return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)

	func _draw() -> void:
		if size.x < 1.0 or size.y < 1.0:
			return
		_measure()
		var W := size.x
		var H := size.y
		var u := _u
		var by0 := _box.position.y   # top of the layout box
		var bh := _box.size.y        # height of the layout box
		var red := Cfg.COL_CRIMSON
		var bone := Cfg.COL_BONE
		var wash := _e(t / 0.9)

		# ---- grade the whole frame: an almost-black wash (just enough translucency that the frozen
		# world ghosts through) plus a faint blood vignette on all four edges
		draw_rect(Rect2(0.0, 0.0, W, H), Color(0.004, 0.0, 0.008, 0.93 * wash))
		var edge := Color(0.20, 0.0, 0.03, 0.40 * wash * (0.85 + 0.15 * _pulse))
		var clear := Color(0.20, 0.0, 0.03, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W * 0.30, 0), Vector2(W * 0.30, H), Vector2(0, H)]), PackedColorArray([edge, clear, clear, edge]))
		draw_polygon(PackedVector2Array([Vector2(W * 0.70, 0), Vector2(W, 0), Vector2(W, H), Vector2(W * 0.70, H)]), PackedColorArray([clear, edge, edge, clear]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H * 0.32), Vector2(0, H * 0.32)]), PackedColorArray([edge, edge, clear, clear]))
		draw_polygon(PackedVector2Array([Vector2(0, H * 0.68), Vector2(W, H * 0.68), Vector2(W, H), Vector2(0, H)]), PackedColorArray([clear, clear, edge, edge]))
		Gfx.glow_ellipse(self, Vector2(W * 0.5, by0 + bh * 0.27), W * 0.52, bh * 0.17, Color(0, 0, 0, 0.5 * wash))
		Gfx.glow_ellipse(self, Vector2(W * 0.5, by0 + bh * 0.52), W * 0.42, bh * 0.14, Color(0, 0, 0, 0.42 * wash))

		# ---- title: letters slam in, whole word breathes with the heartbeat
		var f := GameState.spaced(GameState.f_display, 8.0 * u)
		var word := "CONSUMED"
		var base := 160
		var wb := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
		var fs := int(float(base) * clampf(W * 0.78 / maxf(wb, 1.0), 0.3, 1.5))
		fs = mini(fs, int(bh * 0.27))   # ultra-wide screens: never so tall that the word runs into the letterbox
		var tw := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := (W - tw) * 0.5
		var ty := by0 + bh * 0.285
		var zoom := 1.0 + 0.04 * _e(t / 6.0) + 0.012 * _pulse
		var piv := Vector2(W * 0.5, ty - float(fs) * 0.3)
		Gfx.glow_ellipse(self, piv, tw * 0.62, float(fs) * 0.75, Color(red.r, red.g, red.b, 0.32 * wash * (0.8 + 0.2 * _pulse)))
		draw_set_transform(piv * (1.0 - zoom), 0.0, Vector2(zoom, zoom))
		var glitch := (t > 0.25 and t < 0.9 and fmod(t, 0.22) < 0.07) or (t > 1.0 and fmod(t, 2.4) < 0.16)
		var jx := (sin(t * 93.0) * 16.0 + 6.0) * u if glitch else 0.0
		for pass_i in 3:   # 0 red ghost, 1 cyan ghost (only while glitching), 2 the word itself
			if pass_i < 2 and not glitch:
				continue
			for i in word.length():
				var k := _e((t - 0.30 - float(i) * 0.06) / 0.30)
				if k <= 0.0:
					continue
				var px := tx + f.get_string_size(word.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var py := ty + (1.0 - k) * -50.0 * u
				var ch := word.substr(i, 1)
				if pass_i == 0:
					draw_string(f, Vector2(px + jx, py), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.1, 0.2, 0.55 * k))
				elif pass_i == 1:
					draw_string(f, Vector2(px - jx * 0.8, py + 3.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.40 * k))
				else:
					var heat := _e((t - 0.40 - float(i) * 0.06) / 0.5)
					var col := Color.WHITE.lerp(red.lightened(0.18), heat)
					col.a = k
					draw_string(f, Vector2(px + 3.0, py + 5.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7 * k))
					draw_string(f, Vector2(px, py), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)

		# ---- flavour line
		var fa := _e((t - 1.2) / 0.5)
		Gfx.text(self, GameState.spaced(GameState.f_ui, 2.0), line, Vector2(W * 0.5, by0 + bh * 0.345), int(23.0 * u), Color(1, 1, 1, 0.66 * fa), 1, 0.6)

		# ---- score. The label is positioned FROM the top of the digits (not from a fixed fraction), so it
		# can never be clipped by / overlap the number at any resolution; the count-up is unchanged.
		var sa := _e((t - 1.0) / 0.4)
		var sfs := int(132.0 * u)
		var num_base := by0 + bh * 0.576                         # baseline of the numerals
		var num_h := float(sfs) * NUM_CAP                        # their cap height
		var lab_base := num_base - num_h - 18.0 * u              # baseline of "SCORE": a clear 18px gap above the digit tops
		Gfx.text(self, GameState.spaced(GameState.f_bold, 5.0), "SCORE", Vector2(W * 0.5 + 2.5 * u, lab_base), int(16.0 * u), Color(1, 1, 1, 0.55 * sa), 1, 0.4)   # +2.5u: the tracking adds trailing space
		var ce := _e((t - 1.1) / 1.25)
		if ce >= 1.0:
			Gfx.glow_ellipse(self, Vector2(W * 0.5, num_base - num_h * 0.5), W * 0.2, bh * 0.08, Color(bone.r, bone.g, bone.b, 0.05 + 0.06 * _pulse))
		Gfx.text(self, GameState.f_num, str(int(score * ce)), Vector2(W * 0.5, num_base), sfs, Color(bone.r, bone.g, bone.b, sa), 1, 0.9)

		# ---- NEW BEST / unlocks
		var ba := _e((t - 2.0) / 0.4)
		if new_best and ba > 0.0:
			var bw := 190.0 * u
			var ph := 34.0 * u
			var bx := W * 0.5 - bw * 0.5
			var by := num_base + 12.0 * u
			var pill := StyleBoxFlat.new()
			pill.bg_color = Color(1.0, 0.8, 0.3, 0.16 * ba)
			pill.border_color = Color(1.0, 0.82, 0.32, 0.9 * ba)
			pill.set_border_width_all(1)
			pill.set_corner_radius_all(int(ph * 0.5))
			pill.anti_aliasing = true
			draw_style_box(pill, Rect2(bx, by, bw, ph))
			UIDraw.icon(self, &"star", Vector2(bx + 24.0 * u, by + ph * 0.5), 17.0 * u, Color(UIDraw.GOLD.r, UIDraw.GOLD.g, UIDraw.GOLD.b, ba))
			Gfx.text(self, GameState.spaced(GameState.f_bold, 4.0), "NEW BEST", Vector2(bx + bw * 0.58, by + ph * 0.5 + 6.0 * u), int(16.0 * u), Color(UIDraw.GOLD.r, UIDraw.GOLD.g, UIDraw.GOLD.b, ba), 1, 0.4)
			var sh := fposmod(t * 0.7, 1.6) - 0.3   # shimmer sweep
			draw_line(Vector2(bx + bw * sh, by + 2.0), Vector2(bx + bw * sh - 14.0 * u, by + ph - 2.0), Color(1, 1, 1, 0.26 * ba), 6.0 * u)
		if unlocked.size() > 0 and ba > 0.0:
			var skin: Dictionary = GameState.find_cosmetic(String(unlocked[0]))
			var uy := num_base + 12.0 * u + (44.0 * u if new_best else 0.0)
			var msg := "New cosmetic unlocked: %s" % unlocked[0]
			var mw := GameState.f_ui.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * u)).x
			if not skin.is_empty():
				var sc: Color = skin["color"]
				Gfx.glow(self, Vector2(W * 0.5 - mw * 0.5 - 22.0 * u, uy + 14.0 * u), 30.0 * u, Color(sc.r, sc.g, sc.b, 0.5 * ba))
				draw_circle(Vector2(W * 0.5 - mw * 0.5 - 22.0 * u, uy + 14.0 * u), 11.0 * u, Color(sc.r, sc.g, sc.b, ba))
			Gfx.text(self, GameState.f_ui, msg, Vector2(W * 0.5, uy + 20.0 * u), int(19.0 * u), Color(UIDraw.CYAN.r, UIDraw.CYAN.g, UIDraw.CYAN.b, ba), 1, 0.5)

		# ---- stats: hairline across the full width, three columns
		var ta := _e((t - 1.6) / 0.5)
		if ta > 0.0:
			var ly := by0 + bh * 0.70
			draw_line(Vector2(0.0, ly), Vector2(W, ly), Color(1, 1, 1, 0.10 * ta), 1.0)
			var se := _e((t - 1.7) / 1.0)
			var cols := [
				["DISTANCE", str(int(meters * se)) + " M"],
				["SHARDS", str(int(float(shards) * se))],
				["BEST SCORE", str(best)],
			]
			for i in 3:
				var x: float = W * (0.2 + 0.3 * float(i))
				Gfx.text(self, GameState.spaced(GameState.f_bold, 4.0), cols[i][0], Vector2(x, by0 + bh * 0.727), int(14.0 * u), Color(1, 1, 1, 0.5 * ta), 1, 0.4)
				Gfx.text(self, GameState.f_num, cols[i][1], Vector2(x, by0 + bh * 0.803), int(56.0 * u), Color(bone.r, bone.g, bone.b, ta), 1, 0.8)
			for x2 in [W * 0.35, W * 0.65]:
				draw_line(Vector2(x2, by0 + bh * 0.715), Vector2(x2, by0 + bh * 0.81), Color(1, 1, 1, 0.12 * ta), 1.0)

		# ---- cinematic letterbox
		var bar := H * 0.07 * _e(t / 0.7)
		draw_rect(Rect2(0.0, 0.0, W, bar), Color.BLACK)
		draw_rect(Rect2(0.0, H - bar, W, bar), Color.BLACK)
		draw_line(Vector2(0.0, bar), Vector2(W, bar), Color(red.r, red.g, red.b, 0.5 * wash), 1.5)
		draw_line(Vector2(0.0, H - bar), Vector2(W, H - bar), Color(red.r, red.g, red.b, 0.5 * wash), 1.5)

		# ---- film grain lines + glitch tears (this screen is the only place tearing is allowed)
		if absf(_scan_h - H) > 0.5:
			_scan_h = H
			_scan = PackedVector2Array()
			var yy := 0.0
			while yy < H:
				_scan.append(Vector2(0.0, yy))
				_scan.append(Vector2(W, yy))
				yy += 5.0
		draw_multiline(_scan, Color(0, 0, 0, 0.07 * wash), 1.0)
		if glitch:
			var q := int(t * 30.0)
			for n in 5:
				var gy := Gfx.hash1(float(q * 7 + n)) * H
				var gh := 3.0 + Gfx.hash1(float(q * 3 + n)) * 18.0
				draw_rect(Rect2(0.0, gy, W, gh), Color(1.0, 0.15, 0.25, 0.10))
				var gx := Gfx.hash1(float(q * 5 + n)) * W * 0.5
				draw_rect(Rect2(gx, gy + gh * 0.5, W * 0.5, 2.0), Color(1, 1, 1, 0.22))
		if t < 0.35:   # we arrive from the death sequence's blackout (CRT collapse): a soft crimson pulse, not a white flash
			draw_rect(Rect2(0.0, 0.0, W, H), Color(1.0, 0.22, 0.28, 0.20 * (1.0 - t / 0.35)))


func setup(meters: float, score: float, shards: int, result: Dictionary, game) -> void:
	_meters = meters
	_score = score
	_shards = shards
	_result = result
	_game = game


func _ready() -> void:
	_stage = Stage.new()
	_stage.meters = _meters
	_stage.score = _score
	_stage.shards = _shards
	_stage.best = GameState.best_score
	_stage.new_best = _result.get("new_best", false)
	_stage.unlocked = _result.get("unlocked", [])
	_stage.line = LINES.pick_random()
	add_child(_stage)
	# Cover the WHOLE viewport whatever its aspect ratio (a CanvasLayer child's anchors resolve against
	# the viewport). The stage re-lays itself out if the window / device resolution changes.
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var again := FancyButton.new()
	again.label = "RUN AGAIN"
	again.icon = &"retry"
	again.style = FancyButton.Style.PRIMARY
	again.pressed.connect(_on_again)
	_stage.add_child(again)
	var menu := FancyButton.new()
	menu.label = "MENU"
	menu.icon = &"home"
	menu.style = FancyButton.Style.GHOST
	menu.pressed.connect(_on_menu)
	_stage.add_child(menu)
	for b in [again, menu]:
		b.modulate.a = 0.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.buttons = [again, menu]
	_stage.relayout()   # sizes + positions come from the stage's layout box


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and _stage != null and _stage.t > READY_T:
		if k.keycode == KEY_ENTER or k.keycode == KEY_SPACE:
			_on_again()


func _on_again() -> void:
	_game.restart()


func _on_menu() -> void:
	_game.to_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _game != null:
		_game.to_menu()
