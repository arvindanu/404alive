extends Node
## Autoload "GameState": persistent progress, settings, input map, haptics.

signal settings_changed

const SAVE_PATH := "user://dont_look_back.cfg"
## Cosmetics (replace the old scarf colours). Costs are in lifetime shards and rise steeply; each
## list is ordered cheapest first and index 0 is always free (the default look).
##   kind 0 = DRESS (recolours the coat and changes its details + the trailing cloth)
##   kind 1 = ACCESSORY (worn on the head / shoulder)
const DRESSES := [
	{"id": "wanderer", "name": "Wanderer", "cost": 0, "color": Color(0.72, 0.69, 0.78), "blurb": "The coat you started in."},
	{"id": "gravedigger", "name": "Gravedigger", "cost": 500, "color": Color(0.78, 0.45, 0.18), "blurb": "Patched, muddy, still warm."},
	{"id": "mourner", "name": "Mourner", "cost": 1800, "color": Color(0.90, 0.88, 0.84), "blurb": "Black crepe, bone buttons."},
	{"id": "bloodbound", "name": "Bloodbound", "cost": 4800, "color": Color(0.86, 0.10, 0.18), "blurb": "It never quite dries."},
	{"id": "void", "name": "Void Regalia", "cost": 11000, "color": Color(0.48, 0.36, 1.0), "blurb": "Stars sewn into the dark."},
]
const ACCESSORIES := [
	{"id": "none", "name": "Bare", "cost": 0, "color": Color(0.72, 0.69, 0.78), "blurb": "Nothing extra."},
	{"id": "raven", "name": "Raven Omen", "cost": 1000, "color": Color(0.55, 0.62, 1.0), "blurb": "It watches the way you came."},
	{"id": "antlers", "name": "Hollow Stag", "cost": 3000, "color": Color(0.88, 0.84, 0.72), "blurb": "Bone antlers on the hood."},
	{"id": "plague", "name": "Plague Mask", "cost": 7500, "color": Color(1.0, 0.72, 0.26), "blurb": "Amber lenses, no face."},
	{"id": "halo", "name": "Fallen Halo", "cost": 16000, "color": Color(1.0, 0.86, 0.45), "blurb": "Cracked. Still burning."},
]

var best_score := 0
var best_meters := 0
var total_shards := 0
var runs := 0
var dress := 0          ## equipped DRESSES index
var accessory := 0      ## equipped ACCESSORIES index
var preview_dress := -1       ## menu "try on" override (never saved); -1 = none
var preview_accessory := -1
var intro_seen := false       ## first-boot cinematic already played / skipped
var tutorial_done := false    ## first-session button tutorial already seen
var from_cinematic := false   ## set for the very first run that follows the cinematic (not saved)
var sound_on := true
var haptics_on := true
var shake_on := true
var low_fx := false
var fps30 := false
var show_fps := false   ## the little frame-rate counter (Settings)
var auto_low := false   ## NOT saved: the device could not keep up this session, so effects dropped to Low
var hints_seen := {}   ## Obstacle.Kind -> true, tutorial prompts already shown
var font: Font          ## default UI font (kept for compatibility)
var f_display: Font     ## Gloock - titles
var f_num: Font         ## Big Shoulders Bold - score numerals
var f_ui: Font          ## Instrument Sans - labels
var f_bold: Font        ## Instrument Sans Bold - buttons
var _spaced := {}
var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_t := 0.0
var _pf_t := 0.0        ## frame-rate watchdog window
var _pf_n := 0
var _pf_slow := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	load_data()
	_load_fonts()
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()
	apply_settings()


func _setup_input_map() -> void:
	var map := {
		&"jump": [KEY_SPACE, KEY_UP, KEY_W],
		&"slide": [KEY_DOWN, KEY_S],
		&"dash": [KEY_SHIFT, KEY_D, KEY_RIGHT],
		&"look": [KEY_LEFT, KEY_A, KEY_L],
		&"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _load_font(path: String, fallback: PackedStringArray) -> Font:
	if ResourceLoader.exists(path):
		var f := load(path) as Font
		if f != null:
			return f
	var sf := SystemFont.new()   # fallback while a font is still importing / missing
	sf.font_names = fallback
	return sf


func _load_fonts() -> void:
	f_display = _load_font("res://assets/fonts/Gloock-Regular.ttf", PackedStringArray(["Georgia", "Noto Serif", "serif"]))
	f_num = _load_font("res://assets/fonts/BigShoulders-Bold.ttf", PackedStringArray(["Roboto Condensed", "sans-serif"]))
	f_ui = _load_font("res://assets/fonts/InstrumentSans-Regular.ttf", PackedStringArray(["Roboto", "sans-serif"]))
	f_bold = _load_font("res://assets/fonts/InstrumentSans-Bold.ttf", PackedStringArray(["Roboto", "sans-serif"]))
	font = f_ui


## Font with extra letter-spacing (tracking), cached. Used for the small-caps UI labels.
func spaced(base: Font, px: float) -> Font:
	var key := "%d_%d" % [base.get_instance_id(), int(px * 10.0)]
	if not _spaced.has(key):
		var fv := FontVariation.new()
		fv.base_font = base
		fv.spacing_glyph = int(px)
		_spaced[key] = fv
	return _spaced[key]


func _on_resize() -> void:
	Cfg.update_view(get_tree().root)


## Low effects, either because the player asked for it or because the watchdog had to step in.
func fx_low() -> bool:
	return low_fx or auto_low


## The frame rate to aim for. 0 = no cap: the display's own refresh (vsync) paces the game.
##   * battery saver: 30
##   * a panel slower than the target (60 Hz): 0, vsync already paces us exactly
##   * a faster panel that does not divide into the target (120 / 144 Hz): 0, run at its native rate; a 90 cap
##     there would present frames unevenly (a visible judder) and be worse than running faster
##   * 90 Hz (or 180 Hz) panels, and when the platform cannot say what the refresh is: the target
func target_fps() -> int:
	if fps30:
		return 30
	var hz := DisplayServer.screen_get_refresh_rate()   # -1.0 when unknown
	var tgt := float(Cfg.TARGET_FPS)
	if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED:
		# nothing else would pace us, so an explicit cap is needed (never leave an uncapped loop burning the battery)
		return int(minf(tgt, hz)) if hz > 0.0 else Cfg.TARGET_FPS
	if hz > 0.0:
		if hz < tgt - 1.0:
			return 0
		if hz > tgt + 1.0 and fposmod(hz, tgt) > 1.0:
			return 0
	return Cfg.TARGET_FPS


func apply_settings() -> void:
	Cfg.quality = 0.5 if fx_low() else 1.0
	Engine.max_fps = target_fps()
	_set_fps_overlay(show_fps)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)
	settings_changed.emit()


## Frame-rate watchdog. The game calls this every frame of a run. If the device cannot even hold ~60% of what
## its display can show, for two 2-second windows in a row, drop to Low effects for the rest of the session
## (the saved setting is untouched). The threshold is deliberately far below the target: a phone whose system
## keeps the app at 60 Hz must NOT be mistaken for a slow one.
func perf_sample(delta: float) -> void:
	_pf_t += delta
	_pf_n += 1
	if _pf_t < 2.0:
		return
	var fps := float(_pf_n) / _pf_t
	_pf_t = 0.0
	_pf_n = 0
	Engine.max_fps = target_fps()   # the panel's refresh can change while we run (adaptive refresh)
	if auto_low or low_fx:
		return
	var hz := DisplayServer.screen_get_refresh_rate()
	var want := minf(hz if hz > 0.0 else 60.0, float(Cfg.TARGET_FPS))   # never expect more than the game's own target
	if fps30:
		want = 30.0
	if fps < want * 0.6:
		_pf_slow += 1
		if _pf_slow >= 2:
			auto_low = true
			apply_settings()
	else:
		_pf_slow = 0


func perf_reset() -> void:
	_pf_t = 0.0
	_pf_n = 0
	_pf_slow = 0


func _set_fps_overlay(on: bool) -> void:
	if on and _fps_label == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 128
		_fps_label = Label.new()
		_fps_label.add_theme_font_override("font", f_ui)
		_fps_label.add_theme_font_size_override("font_size", 18)
		_fps_label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.72, 0.92))
		_fps_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		_fps_label.add_theme_constant_override("outline_size", 5)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	if _fps_layer != null:
		_fps_layer.visible = on
	set_process(on)


func _process(delta: float) -> void:
	_fps_t -= delta
	if _fps_t > 0.0 or _fps_label == null:
		return
	_fps_t = 0.25
	_fps_label.text = "%d FPS%s" % [Engine.get_frames_per_second(), "  (auto-low)" if auto_low else ""]
	_fps_label.position = Vector2(Cfg.view_w * 0.5 - 60.0, Cfg.safe.y + 6.0)


func cosmetic_list(kind: int) -> Array:
	return DRESSES if kind == 0 else ACCESSORIES


func cosmetic_unlocked(kind: int, i: int) -> bool:
	var list := cosmetic_list(kind)
	return i >= 0 and i < list.size() and total_shards >= int(list[i]["cost"])


func equipped(kind: int) -> int:
	var i := dress if kind == 0 else accessory
	return i if cosmetic_unlocked(kind, i) else 0


## What the runner is wearing right now: the menu's try-on preview wins over the equipped item.
func look_dress() -> int:
	return preview_dress if preview_dress >= 0 else equipped(0)


func look_accessory() -> int:
	return preview_accessory if preview_accessory >= 0 else equipped(1)


func clear_preview() -> void:
	preview_dress = -1
	preview_accessory = -1


## Looks up a cosmetic by display name (used by the game-over "unlocked" line).
func find_cosmetic(cname: String) -> Dictionary:
	for list in [DRESSES, ACCESSORIES]:
		for c in list:
			if String(c["name"]) == cname:
				return c
	return {}


var _hap_until := 0
var _hap_level := 0.0


## Vibrate. `amp` 0..1 (-1 = device default) needs Android 8+; `level` is a priority so a faint
## footstep tick can never cut short a strong dash or hit that is still buzzing.
func haptic(ms: int, amp: float = -1.0, level: float = 0.5) -> void:
	if not haptics_on or not OS.has_feature("android"):
		return
	var now := Time.get_ticks_msec()
	if now < _hap_until and level < _hap_level:
		return
	_hap_until = now + ms
	_hap_level = level
	if amp >= 0.0:
		Input.vibrate_handheld(ms, clampf(amp, 0.0, 1.0))
	else:
		Input.vibrate_handheld(ms)


## Called once per finished run. Returns {new_best: bool, unlocked: Array[String]}.
func record_run(meters: float, score: float, shards: int) -> Dictionary:
	var before := total_shards
	runs += 1
	total_shards += shards
	var new_best := int(score) > best_score
	if new_best:
		best_score = int(score)
	best_meters = maxi(best_meters, int(meters))
	var unlocked: Array[String] = []
	for list in [DRESSES, ACCESSORIES]:
		for c in list:
			var cost := int(c["cost"])
			if cost > before and cost <= total_shards:
				unlocked.append(String(c["name"]))
	save_data()
	return {"new_best": new_best, "unlocked": unlocked}


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "best_score", best_score)
	cf.set_value("progress", "best_meters", best_meters)
	cf.set_value("progress", "total_shards", total_shards)
	cf.set_value("progress", "runs", runs)
	cf.set_value("progress", "dress", dress)
	cf.set_value("progress", "accessory", accessory)
	cf.set_value("progress", "hints", hints_seen.keys())
	cf.set_value("flags", "intro_seen", intro_seen)
	cf.set_value("flags", "tutorial_done", tutorial_done)
	cf.set_value("settings", "sound_on", sound_on)
	cf.set_value("settings", "haptics_on", haptics_on)
	cf.set_value("settings", "shake_on", shake_on)
	cf.set_value("settings", "low_fx", low_fx)
	cf.set_value("settings", "fps30", fps30)
	cf.set_value("settings", "show_fps", show_fps)
	cf.save(SAVE_PATH)


func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	best_score = int(cf.get_value("progress", "best_score", 0))
	best_meters = int(cf.get_value("progress", "best_meters", 0))
	total_shards = int(cf.get_value("progress", "total_shards", 0))
	runs = int(cf.get_value("progress", "runs", 0))
	dress = int(cf.get_value("progress", "dress", 0))
	accessory = int(cf.get_value("progress", "accessory", 0))
	# A save file that predates these flags belongs to a returning player: no cinematic, no tutorial.
	# (A brand-new install has no file at all, so both stay false until they have been shown.)
	intro_seen = bool(cf.get_value("flags", "intro_seen", true))
	tutorial_done = bool(cf.get_value("flags", "tutorial_done", true))
	hints_seen = {}
	for k in cf.get_value("progress", "hints", []):
		hints_seen[int(k)] = true
	sound_on = bool(cf.get_value("settings", "sound_on", true))
	haptics_on = bool(cf.get_value("settings", "haptics_on", true))
	shake_on = bool(cf.get_value("settings", "shake_on", true))
	low_fx = bool(cf.get_value("settings", "low_fx", false))
	fps30 = bool(cf.get_value("settings", "fps30", false))
	show_fps = bool(cf.get_value("settings", "show_fps", false))
