extends Node
## The launch sequence (this is the project's main scene):
##
##   1. "AN ORGANIZED CRIME ORIGINAL"  fades in, holds, fades out
##   2. "made by TerMorgan"             stutters on with a subtle horror glitch + an unsettling sound, then fades to black
##   3. the game, exactly as before: the main menu, or on a fresh install the first-boot cinematic
##
## The splashes live on a CanvasLayer ABOVE the Transition autoload's cover (layer 100), so they are visible while it
## is still black; when they end we change scene normally, leaving that cover untouched, so the menu / cinematic
## fades in from black on their own exactly as they always did. If a splash picture cannot be loaded it is skipped,
## and the player is never held up on launch.
##
## The glitch maths lives in splash_fx.gd, the drawing in splash_stage.gd, the sound in tools/generate_splash_audio.py.

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const IMG_A := "res://assets/images/splash_organized_crime.jpg"
const IMG_B := "res://assets/images/splash_termorgan.jpg"
const SFX_B := "res://assets/sounds/splash_glitch.wav"
const SFX_DB := -5.0
const SKIPPABLE := false   ## true: any tap / key skips the whole sequence (handy while testing)

# ---- timeline, in seconds from launch
const A_START := 0.30      ## a beat of black first, so the engine is settled before anything moves
const A_IN := 0.60
const A_HOLD := 1.60
const A_OUT := 0.50
const B_START := A_START + A_IN + A_HOLD + A_OUT + 0.35
const B_FADE := 0.55       ## splash 2 fades to black over the last stretch of its length
const END := B_START + SplashFx.LENGTH

var _base: SplashStage
var _ghost: SplashStage
var _sfx: AudioStreamPlayer
var _t := 0.0
var _sfx_started := false
var _b_start := B_START   ## when splash 2 begins (earlier if splash 1 is missing)
var _end := END            ## when we leave (earlier if splash 2 is missing)
var _done := false


func _ready() -> void:
	var a := _load_tex(IMG_A)
	var b := _load_tex(IMG_B)
	if a == null and b == null:
		_go.call_deferred()
		return
	if a == null:   # never make the player wait for a picture that is not there
		_b_start = A_START
	if b == null:
		_end = A_START + A_IN + A_HOLD + A_OUT + 0.15
	else:
		_end = _b_start + SplashFx.LENGTH
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	_base = SplashStage.new()
	_base.tex_a = a
	_base.tex_b = b
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_base)
	_ghost = SplashStage.new()
	_ghost.ghost = true
	_ghost.tex_b = b
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ghost.material = add
	layer.add_child(_ghost)
	if b != null and ResourceLoader.exists(SFX_B):
		_sfx = AudioStreamPlayer.new()
		_sfx.stream = load(SFX_B) as AudioStream
		_sfx.bus = "SFX"   # so the player's sound setting applies
		_sfx.volume_db = SFX_DB
		add_child(_sfx)


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _process(delta: float) -> void:
	if _done or _base == null:
		return
	_t += minf(delta, 0.05)   # a hitch while the first scene loads must not eat the sequence
	var a_end := A_START + A_IN + A_HOLD
	_base.a_alpha = smoothstep(0.0, 1.0, (_t - A_START) / A_IN) * (1.0 - smoothstep(0.0, 1.0, (_t - a_end) / A_OUT))
	var tb := _t - _b_start
	if tb >= 0.0:
		if not _sfx_started:
			_sfx_started = true
			if _sfx != null and _sfx.stream != null:
				_sfx.play()
		_base.tb = tb
		_base.b_alpha = 1.0 - smoothstep(0.0, 1.0, (tb - (SplashFx.LENGTH - B_FADE)) / B_FADE)
	_ghost.tb = _base.tb
	_ghost.b_alpha = _base.b_alpha
	_base.queue_redraw()
	_ghost.queue_redraw()
	if _t >= _end:
		_go()


func _input(event: InputEvent) -> void:
	if SKIPPABLE and not _done and event.is_pressed() and not event.is_echo():
		_go()


func _go() -> void:
	if _done:
		return
	_done = true
	if _sfx != null:
		_sfx.stop()
	get_tree().change_scene_to_file.call_deferred(NEXT_SCENE)
