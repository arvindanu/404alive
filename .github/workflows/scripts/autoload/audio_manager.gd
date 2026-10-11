extends Node
## Autoload "Audio": SFX pool, adaptive ambience layers, heartbeat, whispers, and a
## drop-in music playlist (assets/music/). Missing files are skipped silently.

signal beat   ## emitted on every heartbeat so visuals can pulse in sync

const SFX: Array[StringName] = [
	&"jump", &"land", &"slide", &"dash", &"hit", &"shard", &"powerup", &"shield_break",
	&"look_in", &"look_out", &"lunge", &"die", &"ui_click", &"warn", &"thorn_break",
	&"crow", &"step_a", &"step_b", &"heartbeat", &"whisper_a", &"whisper_b", &"whisper_c", &"sting", &"boom", &"wretch",
	# the creature / death sequence (tools/generate_consume_audio.py)
	&"con_catch", &"con_grab", &"con_lantern", &"con_wings", &"con_suck", &"con_gulp", &"con_roar", &"con_glitch", &"con_cut", &"con_step", &"con_breath",
]
const LOOPS: Array[StringName] = [&"drone", &"growl", &"wind", &"subbass"]

var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _loops := {}
var _music: AudioStreamPlayer
var _music_list: Array[AudioStream] = []
var _music_i := 0
var _lowpass: AudioEffectLowPassFilter
var _hb_t := 0.0
var _br_t := 2.0
var duck := 0.0   ## 0..1: pulls every ambience loop down (the death sequence goes silent at the gulp and at the end)
var _wh_t := 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for n in SFX:
		var path := "res://assets/sounds/%s.wav" % String(n)
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for n in LOOPS:
		var path := "res://assets/sounds/%s.wav" % String(n)
		if not ResourceLoader.exists(path):
			continue
		var st := load(path) as AudioStreamWAV
		if st == null:
			continue
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() >> 1   # 16-bit mono -> samples
		var lp := AudioStreamPlayer.new()
		lp.stream = st
		lp.bus = "Ambience"
		lp.volume_db = -60.0
		add_child(lp)
		lp.play()
		_loops[n] = lp
	_load_music()
	if not _music_list.is_empty():
		_music = AudioStreamPlayer.new()
		_music.bus = "Music"
		add_child(_music)
		_music.finished.connect(_next_track)
		_music_list.shuffle()
		_play_track()


func _setup_buses() -> void:
	for b in ["SFX", "Ambience", "Music"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -3.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -8.0)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 18000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _lowpass)


func _load_music() -> void:
	var dir := DirAccess.open("res://assets/music")
	if dir == null:
		return
	var seen := {}
	for f in dir.get_files():
		# exported builds list "name.ogg.import"/".remap" instead of the raw file
		var fname := f.trim_suffix(".import").trim_suffix(".remap")
		if seen.has(fname) or not (fname.get_extension().to_lower() in ["ogg", "mp3", "wav"]):
			continue
		seen[fname] = true
		var path := "res://assets/music/" + fname
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				_music_list.append(st)


func _play_track() -> void:
	_music.stream = _music_list[_music_i % _music_list.size()]
	_music.play()


func _next_track() -> void:
	_music_i += 1
	_play_track()


func play(sfx_name: StringName, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = _sfx.get(sfx_name)
	if s == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_whisper() -> void:
	play([&"whisper_a", &"whisper_b", &"whisper_c"].pick_random(), randf_range(-14.0, -8.0), randf_range(0.85, 1.1))


func _set_loop(loop_name: StringName, db: float, pitch: float, k: float) -> void:
	var p := _loops.get(loop_name) as AudioStreamPlayer
	if p == null:
		return
	p.volume_db = lerpf(p.volume_db, db - duck * 44.0, k)
	p.pitch_scale = lerpf(p.pitch_scale, pitch, k)


## Called every frame by the run controller. Everything is driven by how scared you should be.
func update_layers(dt: float, threat: float, dark: float, look_time: float, active: bool, dying: bool) -> void:
	var k := 1.0 - exp(-4.0 * dt)
	_set_loop(&"drone", -26.0 + dark * 8.0 + threat * 10.0, 0.9 + threat * 0.25, k)
	var growl_db := -60.0
	if active:
		growl_db = -46.0 + minf(look_time, 2.0) * 22.0
	if dying:
		growl_db = -2.0
	_set_loop(&"growl", growl_db, 0.9 + minf(look_time, 2.0) * 0.12, k)
	_set_loop(&"wind", -32.0 + dark * 6.0, 1.0, k)
	# Proximity bass: silent until the creature is close, then a deepening, throbbing rumble that
	# swells the nearer it gets (and holds at full while it is consuming you).
	var near := smoothstep(0.38, 1.0, threat)
	var sub_db := -60.0
	if active:
		sub_db = lerpf(-46.0, -1.5, pow(near, 1.15)) if near > 0.001 else -60.0
	if dying:
		sub_db = -0.5
		near = 1.0
	_set_loop(&"subbass", sub_db, lerpf(1.0, 0.80, near), 1.0 - exp(-6.0 * dt))
	_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, lerpf(18000.0, 1100.0, threat * threat), k)
	if not active:
		return
	_hb_t -= dt
	if _hb_t <= 0.0:
		_hb_t = 1.25 - threat * 0.8
		play(&"heartbeat", -16.0 + threat * 14.0, 1.0 + threat * 0.12)
		if threat > 0.7:   # a heavy thud under every heartbeat once it is on top of you
			play(&"boom", lerpf(-24.0, -8.0, clampf((threat - 0.7) / 0.3, 0.0, 1.0)), lerpf(1.1, 0.9, threat))
		beat.emit()
	_br_t -= dt   # a wet, rasping breath on your neck once it is close
	if _br_t <= 0.0:
		_br_t = lerpf(2.4, 1.3, clampf((threat - 0.7) / 0.3, 0.0, 1.0))
		if threat > 0.72:
			play(&"con_breath", lerpf(-26.0, -12.0, clampf((threat - 0.72) / 0.28, 0.0, 1.0)), randf_range(0.92, 1.05))
	_wh_t -= dt
	if _wh_t <= 0.0:
		_wh_t = maxf(3.0, randf_range(5.0, 12.0) - dark * 3.0)
		if dark > 0.1:
			play_whisper()
