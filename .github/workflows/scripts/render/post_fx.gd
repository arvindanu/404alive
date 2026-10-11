extends ColorRect
## Drives one of the two full-screen shader passes.
##   kind = "light" : lantern lighting on the world layer      (light.gdshader)
##   kind = "grade" : bloom / aberration / vignette / grain    (grade.gdshader)

@export var kind: String = "light"

var game = null
var _mat: ShaderMaterial


func setup(g) -> void:
	game = g
	_mat = material as ShaderMaterial


func update_fx() -> void:
	if _mat == null or game == null:
		return
	var g = game
	var aspect := Cfg.view_w / Cfg.view_h
	_mat.set_shader_parameter("aspect", aspect)
	if kind == "light":
		var fog: float = g.fog_amount()
		_mat.set_shader_parameter("light_pos", g.light_uv())
		_mat.set_shader_parameter("light_radius", g.light_radius())
		var dk: float = g.consume.dark_k   # the death sequence drains the world until only its eyes are left
		_mat.set_shader_parameter("darkness", minf(0.30 + g.dark * 0.20 + fog * 0.08 + dk * 0.62, 0.97))
		_mat.set_shader_parameter("track_y", g.track_uv_y())
		# the moonlit band thins out as the world corrupts, so the late game gets moodier but stays readable
		_mat.set_shader_parameter("track_fill", maxf(0.55 - g.dark * 0.15 - g.event_blackout() * 0.30 - dk * 0.55, 0.0))
		_mat.set_shader_parameter("desat", g.dark * 0.30 + g.look_a * 0.12 + g.death_desat)
		_mat.set_shader_parameter("fog", fog)
		return
	var thr: float = g.creature.threat()
	var low: bool = GameState.fx_low()
	var gl: float = g.glitch_amount()   # 0 during normal play; only the death sequence tears the screen
	_mat.set_shader_parameter("threat", thr)
	_mat.set_shader_parameter("look", g.look_a)
	_mat.set_shader_parameter("pulse", g.pulse)
	_mat.set_shader_parameter("glitch", gl)
	var cs: Consume = g.consume
	_mat.set_shader_parameter("aberration", 0.0 if low else 0.0008 + g.player.dash_curve() * 0.006 + cs.ab)
	var wp := Vector2(0.5, 0.5)
	if cs.active:   # the lens pinches toward the creature's mouth
		wp = (g.cam * cs.mouth_world) / Vector2(Cfg.view_w, Cfg.view_h)
	_mat.set_shader_parameter("warp", cs.warp)
	_mat.set_shader_parameter("warp_pos", wp)
	_mat.set_shader_parameter("crt", cs.crt)
	_mat.set_shader_parameter("grain", 0.0 if low else 0.05 + g.dark * 0.05)
	_mat.set_shader_parameter("bloom", 0.0 if low else 0.45)
	var c: Color = g.flash_col
	_mat.set_shader_parameter("flash_col", Color(c.r, c.g, c.b, g.flash_a))
