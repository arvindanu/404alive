extends Node
## First-boot cinematic. Plays ONCE, on the very first launch (see GameState.intro_seen), and is skipped on
## every launch after that. The picture is CineArt (procedural, low-poly); the sound is the `cine_*` files
## from tools/generate_cinematic_audio.py, cut to the same timeline.
##
## Rendering: CineView (opaque scene) + a second additively-blended CineView (lights) under the game's own
## grade shader (bloom / chromatic aberration / glitch tearing / grain), then letterbox bars + a SKIP button.
## Flow: cinematic -> whites out -> Transition.cut_through() -> the game fades in from that same white and the
## runner drops out of the screen into the world, with a short settling glitch (see Game._ready).
## Completing OR skipping it saves `intro_seen`, so it can never replay.

const GAME_SCENE := "res://scenes/game.tscn"
const SND := "res://assets/sounds/"
const STREAMS := ["cine_music", "cine_night", "cine_room", "cine_keys", "cine_owl", "cine_cut", "cine_chair", "cine_gasp",
		"cine_pcwake", "cine_blips", "cine_logo", "cine_glitch", "cine_riser", "cine_pull"]
const LOOPS := ["cine_night", "cine_room", "cine_keys"]

## [time, cue]: one-shots, fired once as the timeline passes them.
const CUES := [
	[5.2, "owl"], [8.7, "owl2"],
	[11.0, "room_on"], [12.0, "keys_on"],
	[20.4, "cut"], [21.0, "silence"], [21.15, "chair"], [21.2, "gasp"], [22.0, "flame"],
	[23.95, "wake"], [24.6, "blips"], [25.9, "logo"],   # cine_logo's sub-drop is 1.5 s into the file: it lands as the title appears (27.4)
	[30.0, "glitch"], [30.4, "whisper_a"], [30.6, "riser"], [31.2, "glitch2"], [31.8, "pull"], [32.0, "whisper_b"],
	[32.3, "glitch3"], [33.4, "glitch"], [34.0, "whisper_c"], [35.1, "sting"], [35.2, "glitch2"],
	[39.55, "impact"],
]

## Volume envelopes (dB) of the three looping beds: [[time, dB], ...]
const ENV_NIGHT := [[0.0, -80.0], [0.15, -45.0], [2.2, -17.0], [10.2, -17.0], [12.4, -80.0]]
const ENV_ROOM := [[0.0, -80.0], [11.0, -80.0], [13.0, -19.0], [20.85, -19.0], [20.97, -80.0]]
const ENV_KEYS := [[0.0, -80.0], [12.0, -80.0], [12.9, -15.0], [20.8, -15.0], [20.9, -80.0]]


## One of the two full-screen drawing surfaces. `glow` = the additively blended light pass.
class CineView extends Control:
	var t := 0.0
	var glow := false

	func _init(is_glow: bool = false) -> void:
		glow = is_glow
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_glow:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = m

	func _draw() -> void:
		if size.x < 1.0 or size.y < 1.0:
			return
		if glow:
			CineArt.draw_light(self, t, size)
		else:
			CineArt.draw(self, t, size)


## Cinematic letterbox: black bars slide in during the first seconds.
class CineBars extends Control:
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func bar_h() -> float:
		var k := clampf(t / 1.8, 0.0, 1.0)
		return size.y * 0.072 * (k * k * (3.0 - 2.0 * k))

	func _draw() -> void:
		var h := bar_h()
		draw_rect(Rect2(0.0, 0.0, size.x, h), Color.BLACK)
		draw_rect(Rect2(0.0, size.y - h, size.x, h), Color.BLACK)


var t := 0.0
var _view: CineView
var _glow: CineView
var _bars: CineBars
var _mat: ShaderMaterial
var _skip: FancyButton
var _streams := {}
var _players := {}
var _cue := 0
var _ending := false
var _beats: Array[float] = []
var _paused_playlist := false


func _ready() -> void:
	DisplayServer.screen_set_keep_on(true)
	# --- sound
	for n in STREAMS:
		var path: String = SND + String(n) + ".wav"
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for n in LOOPS:
		var st := _streams.get(n) as AudioStreamWAV
		if st != null:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = st.data.size() >> 1
	_make_player("cine_music", "Music", 2.0)
	_make_player("cine_night", "Ambience", -80.0)
	_make_player("cine_room", "Ambience", -80.0)
	_make_player("cine_keys", "Ambience", -80.0)
	if Audio._music != null:   # a dropped-in playlist must not talk over the score
		Audio._music.stream_paused = true
		_paused_playlist = true
	_play("cine_music")
	_play("cine_night")
	# the heartbeats baked into the score (same schedule as the generator), to pulse the screen with
	for k in 4:
		_beats.append(15.0 + 1.7 * float(k))
	var tb := 22.2
	var gap := 1.05
	while tb < 31.4:
		_beats.append(tb)
		tb += gap
		gap = maxf(0.46, gap - 0.045)
	# --- picture
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_view = CineView.new(false)
	layer.add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow = CineView.new(true)
	layer.add_child(_glow)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gl := CanvasLayer.new()
	gl.layer = 12
	add_child(gl)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/grade.gdshader")
	var rect := ColorRect.new()
	rect.material = _mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gl.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_bars = CineBars.new()
	ui.add_child(_bars)
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skip = FancyButton.new()
	_skip.label = "SKIP"
	_skip.style = FancyButton.Style.GHOST
	_skip.font_size = 15
	_skip.size = Vector2(130.0, 42.0)
	_skip.modulate.a = 0.0
	_skip.pressed.connect(skip)
	ui.add_child(_skip)
	_update_grade()
	Transition.boot_fade(1.6)


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)
	if _paused_playlist and Audio._music != null:
		Audio._music.stream_paused = false


# ------------------------------------------------------------------ sound
func _make_player(n: String, bus: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _streams.get(n)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	_players[n] = p


func _play(n: String) -> void:
	var p := _players.get(n) as AudioStreamPlayer
	if p != null and p.stream != null:
		p.play()


func _stop(n: String) -> void:
	var p := _players.get(n) as AudioStreamPlayer
	if p != null:
		p.stop()


## One-shot on a throw-away player (freed when it ends).
func _shot(n: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var st: AudioStream = _streams.get(n)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _env(points: Array, at: float) -> float:
	if at <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var t1 := float(points[i][0])
		if at <= t1:
			var t0 := float(points[i - 1][0])
			return lerpf(float(points[i - 1][1]), float(points[i][1]), (at - t0) / maxf(t1 - t0, 0.0001))
	return float(points[points.size() - 1][1])


func _fire(id: String) -> void:
	match id:
		"owl":
			_shot("cine_owl", -13.0, 1.0)
		"owl2":
			_shot("cine_owl", -17.0, 0.88)
		"room_on":
			_play("cine_room")
		"keys_on":
			_play("cine_keys")
		"cut":
			_shot("cine_cut", -2.0)
		"silence":
			_stop("cine_room")
			_stop("cine_keys")
			GameState.haptic(90, 1.0, 1.0)
		"chair":
			_shot("cine_chair", -5.0)
		"gasp":
			_shot("cine_gasp", -3.0)
		"flame":
			Audio.play(&"look_in", -9.0, 0.8)
		"wake":
			_shot("cine_pcwake", -4.0)
			GameState.haptic(40, 0.6, 0.6)
		"blips":
			_shot("cine_blips", -12.0)
		"logo":
			_shot("cine_logo", -3.0)
		"glitch":
			_shot("cine_glitch", -6.0, 1.0)
		"glitch2":
			_shot("cine_glitch", -7.0, 0.8)
		"glitch3":
			_shot("cine_glitch", -6.0, 1.25)
		"whisper_a":
			Audio.play(&"whisper_a", -10.0, 0.9)
		"whisper_b":
			Audio.play(&"whisper_b", -9.0, 0.85)
		"whisper_c":
			Audio.play(&"whisper_c", -8.0, 0.8)
		"riser":
			_shot("cine_riser", -6.0)
		"pull":
			_shot("cine_pull", -3.0)
			GameState.haptic(70, 0.8, 0.8)
		"sting":
			Audio.play(&"sting", -10.0, 0.7)
		"impact":
			# through the Audio autoload's pool so the tail keeps ringing into the first seconds of the game
			if not Audio._sfx.has(&"cine_impact") and ResourceLoader.exists(SND + "cine_impact.wav"):
				Audio._sfx[&"cine_impact"] = load(SND + "cine_impact.wav")
			Audio.play(&"cine_impact", -1.0, 1.0)
			GameState.haptic(140, 1.0, 1.0)


# ------------------------------------------------------------------ per frame
func _process(dt: float) -> void:
	if _ending:
		return
	t += minf(dt, 0.05)
	# keep the picture locked to the score: gently nudge the clock toward the music's real position
	var mp := _players.get("cine_music") as AudioStreamPlayer
	if mp != null and mp.playing:
		var err := mp.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() - t
		if absf(err) > 0.04:
			t += clampf(err, -0.02, 0.02)
	while _cue < CUES.size() and t >= float(CUES[_cue][0]):
		_fire(String(CUES[_cue][1]))
		_cue += 1
	var pn := _players.get("cine_night") as AudioStreamPlayer
	if pn != null:
		pn.volume_db = _env(ENV_NIGHT, t)
		if t > 12.6 and pn.playing:
			pn.stop()
	var pr := _players.get("cine_room") as AudioStreamPlayer
	if pr != null:
		pr.volume_db = _env(ENV_ROOM, t)
	var pk := _players.get("cine_keys") as AudioStreamPlayer
	if pk != null:
		pk.volume_db = _env(ENV_KEYS, t)
	_view.t = t
	_glow.t = t
	_bars.t = t
	_view.queue_redraw()
	_glow.queue_redraw()
	_bars.queue_redraw()
	_update_grade()
	_update_skip()
	if t >= CineArt.T_END:
		_finish()


func _pulse() -> float:
	var p := 0.0
	for b in _beats:
		var d := t - b
		if d >= 0.0 and d < 0.6:
			p = maxf(p, exp(-d * 7.0))
	return p


func _update_grade() -> void:
	if _mat == null:
		return
	var g := CineArt.glitch(t)
	var low := GameState.low_fx
	var wa := CineArt.whiteout(t)
	var dread := clampf((t - CineArt.T_CUT) / 3.0, 0.0, 1.0) * (1.0 - clampf((t - CineArt.T_ZOOM) / 3.0, 0.0, 1.0))
	var vr := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vr.x / maxf(vr.y, 1.0))
	_mat.set_shader_parameter("threat", 0.0)
	_mat.set_shader_parameter("look", dread * 0.7)
	_mat.set_shader_parameter("pulse", _pulse())
	_mat.set_shader_parameter("glitch", g)
	_mat.set_shader_parameter("aberration", 0.0 if low else 0.0012 + g * 0.012 + wa * 0.01)
	_mat.set_shader_parameter("grain", 0.0 if low else 0.05 + 0.06 * g)
	_mat.set_shader_parameter("bloom", 0.0 if low else 0.55)
	# the white-out is applied by the grade pass itself (after its vignette), so the last frame is a flat colour
	_mat.set_shader_parameter("flash_col", Color(CineArt.END_COL.r, CineArt.END_COL.g, CineArt.END_COL.b, wa))


func _update_skip() -> void:
	var a := clampf((t - 2.0) / 0.8, 0.0, 1.0) * (1.0 - CineArt.whiteout(t))
	_skip.modulate.a = a
	_skip.visible = a > 0.01
	var bh := _bars.bar_h()
	_skip.position = Vector2(_bars.size.x - _skip.size.x - 28.0, _bars.size.y - bh + (bh - _skip.size.y) * 0.5)


# ------------------------------------------------------------------ ending
func _mark_seen() -> void:
	if not GameState.intro_seen:
		GameState.intro_seen = true
		GameState.save_data()


## The player skipped: save, fade the sound out and go to the first run the ordinary way.
func skip() -> void:
	if _ending:
		return
	_ending = true
	_mark_seen()
	for n in _players:
		var p := _players[n] as AudioStreamPlayer
		if p != null:
			create_tween().tween_property(p, "volume_db", -80.0, 0.35)
	Transition.go(GAME_SCENE)


## The cinematic ran to its end: it is already a flat white, so cut straight into the game from that colour.
func _finish() -> void:
	if _ending:
		return
	_ending = true
	_mark_seen()
	GameState.from_cinematic = true
	Transition.cut_through(GAME_SCENE, CineArt.END_COL, 1.3)


func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_ENTER or k.keycode == KEY_SPACE):
		skip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # Android back button
		skip()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:   # closing the window mid-way still counts as seen
		_mark_seen()
