class_name Consume
extends RefCounted
## The death sequence: the creature does not just touch you, it takes you.
##
##   0.00  caught: hit-stop, flash, the claw strikes out and the creature surges
##   0.50  the claws close; you are lifted; the lantern is flung from your hand and dies
##   0.80  the wings flare, the head lowers to meet you
##   1.70  carried to the jaws; you shrink into light; the lens pinches toward the mouth
##   2.55  the gulp: your heart stops, the ambience cuts, a bulge of light slides down into the furnace
##   3.00  the furnace flares, it roars; the world drops to darkness except its eyes
##   3.75  glitch crescendo, then the screen collapses like a switched-off CRT -> CONSUMED
##
## Everything is a pure function of `c` (scaled seconds since the catch), so it can be skipped, tuned
## or previewed at any point. Gameplay is already over when this starts: nothing here touches the
## simulation. The creature reads the "drivers" below (see CreatureDrawer.pose), the world / glow
## renderers draw the runner and the extras, the camera and shader passes read the screen drivers.

const T_STRIKE := 0.36
const T_GRAB := 0.52
const T_DROP := 0.50
const T_LIFT0 := 0.62
const T_FACE := 1.55
const T_MOUTH := 2.35
const T_GULP := 2.55
const T_FLARE := 3.00
const T_GLITCH := 3.75
const T_CRT := 4.45
const T_END := 4.95
const HIP := 57.0   ## CharacterDrawer.HIP_H: where the claw holds the runner
## Scripted beats (scaled seconds): sound / flash / shake / particles fire once as the clock passes them.
const EV: Array[float] = [0.50, 0.80, 1.00, 2.55, 3.00, 3.75, 4.45]

var active := false
var done := false
var c := 0.0

# ---- creature drivers (read by CreatureDrawer.pose / draw_glow)
var lunge := 0.0
var head_dip := 0.0
var jaw_x := 0.0
var wing_x := 0.0
var roar := 0.0
var reach := 0.0
var grab := 0.0
var grip_local := Vector2(120.0, -100.0)   ## where the claw is, in creature-local space
var furnace := 0.0
var eye_hot := 0.0
var throat := -1.0                         ## 0..1 = a swallowed light travelling down the neck
var extra := 0.0                           ## it grows as it feeds

# ---- runner
var runner_origin := Vector2.ZERO
var runner_rot := 0.0
var runner_scale := 1.0
var runner_visible := true
var held := 0.0
var mouth_world := Vector2.ZERO
var chest_world := Vector2.ZERO
var burn := 0.0                            ## 0..1 the runner turning to light as he is drawn in

# ---- camera / screen / audio drivers
var cam_w := 0.0
var cam_zoom := 1.0
var cam_world := Vector2.ZERO
var cam_screen := Vector2(640.0, 380.0)
var cam_roll := 0.0
var dark_k := 0.0
var lantern_k := 1.0
var glitch := 0.0
var ab := 0.0
var warp := 0.0
var crt := 0.0
var duck := 0.0

var _ev := 0
var _a_local := Vector2.ZERO
var _lan_state := 0                        ## 0 in hand, 1 falling / rolling
var _lan_pos := Vector2.ZERO
var _lan_vel := Vector2.ZERO
var _lan_rot := 0.0
var _struggle := 0.0
var _spawn_t := 0.0


func begin(g) -> void:
	active = true
	done = false
	c = 0.0
	_ev = 0
	_lan_state = 0
	_struggle = 0.0
	lantern_k = 1.0
	var cr: Creature = g.creature
	var origin := Vector2(Cfg.PLAYER_X - cr.gap, Cfg.GROUND_Y)
	var s := CreatureDrawer.scale_for(cr, g.dark, 0.0)
	_a_local = (Vector2(Cfg.PLAYER_X, g.player.y - HIP) - origin) / s
	runner_origin = Vector2(Cfg.PLAYER_X, g.player.y)


## < 1 for the first beat (the catch lands in slow motion), 1 afterwards.
func time_scale() -> float:
	return lerpf(0.30, 1.0, smoothstep(0.16, 0.60, c))


func skip() -> void:
	if not active or done or c < 1.6 or c >= T_GLITCH - 0.2:
		return
	c = T_GLITCH - 0.2
	while _ev < EV.size() and EV[_ev] < c:
		_ev += 1   # the beats we jumped over stay silent


func update(dt: float, g) -> void:
	if not active:
		return
	if done:
		_update_done(dt, g)
		return
	c += dt
	var cr: Creature = g.creature
	cr.gap = move_toward(cr.gap, 50.0, 150.0 * dt)
	cr.aggression = 1.0

	# ---- creature drivers
	lunge = smoothstep(0.0, 0.18, c) * (1.0 - 0.5 * smoothstep(0.5, 1.5, c)) * (1.0 - smoothstep(T_GULP, T_GULP + 0.5, c))
	var rr := clampf(c / T_STRIKE, 0.0, 1.0)
	reach = (1.0 - pow(1.0 - rr, 3.0)) * (1.0 - smoothstep(T_GULP + 0.05, T_GULP + 0.65, c))
	grab = smoothstep(T_STRIKE, T_GRAB, c) * (1.0 - 0.75 * smoothstep(T_GULP, T_GULP + 0.3, c))
	head_dip = 0.85 * smoothstep(0.5, 1.5, c) - 0.95 * smoothstep(T_GULP + 0.05, T_FLARE + 0.2, c)
	wing_x = smoothstep(0.7, 1.4, c)
	jaw_x = 0.55 * smoothstep(0.9, 1.6, c) + 0.45 * smoothstep(1.9, 2.3, c)
	jaw_x *= 1.0 - 0.9 * smoothstep(T_GULP - 0.05, T_GULP + 0.15, c)
	jaw_x += smoothstep(T_FLARE + 0.05, T_FLARE + 0.3, c) * (1.0 - smoothstep(T_CRT - 0.15, T_CRT, c))
	roar = smoothstep(T_FLARE, T_FLARE + 0.35, c) * (1.0 - smoothstep(T_CRT - 0.2, T_CRT, c))
	furnace = 0.35 * smoothstep(1.2, 2.4, c) + 0.65 * smoothstep(T_FLARE - 0.1, T_FLARE + 0.15, c)
	eye_hot = smoothstep(2.4, 3.0, c)
	throat = -1.0
	if c >= T_GULP and c < T_GULP + 0.5:
		throat = (c - T_GULP) / 0.5
	extra = 0.26 * smoothstep(0.7, 1.7, c) + 0.14 * smoothstep(T_FLARE, T_FLARE + 0.6, c)

	var s := CreatureDrawer.scale_for(cr, g.dark, extra)
	var origin := Vector2(Cfg.PLAYER_X - cr.gap, Cfg.GROUND_Y)
	if c < T_GRAB:
		_a_local = (Vector2(Cfg.PLAYER_X, g.player.y - HIP) - origin) / s   # chase him until the claws close

	# ---- the claw's path: runner -> in front of the face -> the jaws
	var pz := CreatureDrawer.pose(cr, g.t, 1.0, self)
	var hc: Vector2 = pz["hc"]
	var d0: Vector2 = pz["d0"]
	var down: Vector2 = pz["down"]
	var mouth_l := hc + d0 * 36.0 + down * 26.0
	var face_l := mouth_l + Vector2(46.0, 30.0)
	var u1 := smoothstep(T_LIFT0, T_FACE, c)
	var u2 := smoothstep(T_FACE + 0.15, T_MOUTH, c)
	grip_local = _a_local.lerp(face_l, u1).lerp(mouth_l, u2) + Vector2(0.0, -sin(u1 * PI) * 26.0)
	mouth_world = origin + mouth_l * s
	chest_world = origin + (CreatureDrawer.SPINE[3] + Vector2(8.0, 4.0)) * s

	# ---- the runner, hanging from the claw, swung toward the jaws and shrinking into them
	var gw := origin + grip_local * s
	var rs := 1.0 - 0.72 * smoothstep(1.75, 2.5, c)
	var rot := -0.30 * smoothstep(T_LIFT0, 1.3, c) - 1.0 * smoothstep(1.75, 2.45, c)
	var held_origin := gw + Vector2(0.0, HIP * rs).rotated(rot)
	var free_origin := Vector2(Cfg.PLAYER_X, g.player.y)
	held = smoothstep(T_STRIKE, T_GRAB + 0.12, c)
	runner_origin = free_origin.lerp(held_origin, held)
	runner_rot = rot * held
	runner_scale = lerpf(1.0, rs, held)
	runner_visible = c < T_GULP
	burn = smoothstep(1.7, 2.5, c)
	_struggle += dt * (1.0 + 1.6 * held)
	g.player.caught = held
	g.player.struggle = _struggle
	g.player.lan_gone = c >= T_DROP
	g.death_desat = 0.85 * smoothstep(0.2, 1.4, c)

	_update_lantern(dt, g)

	# ---- camera: push in on the claw, travel up to the face, then on to the eyes
	var runner_hip := runner_origin + Vector2(0.0, -HIP * runner_scale).rotated(runner_rot)
	cam_zoom = 1.04 + 0.30 * smoothstep(0.15, 1.7, c) + 0.24 * smoothstep(2.9, 4.3, c)
	cam_w = smoothstep(0.10, 0.90, c)
	var head_w := origin + hc * s
	cam_world = runner_hip.lerp(mouth_world, smoothstep(1.2, 2.4, c)).lerp(head_w, smoothstep(2.8, 3.6, c))
	var k3 := smoothstep(2.8, 3.8, c)
	cam_screen = Vector2(Cfg.VIEW_W * 0.5 + 40.0 - 90.0 * k3, Cfg.VIEW_H * 0.5 + 20.0 - 50.0 * k3)
	cam_roll = -0.030 * smoothstep(0.9, 2.0, c) + 0.048 * smoothstep(3.1, 3.9, c)

	# ---- screen
	var flick := 0.75 + 0.25 * sin(c * 61.0)
	glitch = 0.18 * smoothstep(0.0, 0.08, c) * (1.0 - smoothstep(0.1, 0.5, c))
	glitch += 0.10 * smoothstep(1.0, 2.4, c)
	glitch += 0.45 * smoothstep(T_GULP - 0.05, T_GULP + 0.05, c) * (1.0 - smoothstep(T_GULP + 0.1, T_GULP + 0.45, c))
	glitch += 0.30 * smoothstep(T_FLARE, T_GLITCH, c) + 0.45 * smoothstep(T_GLITCH, T_CRT, c)
	glitch = clampf(glitch * flick, 0.0, 1.0)
	ab = 0.004 * smoothstep(0.0, 0.1, c) * (1.0 - smoothstep(0.1, 0.7, c)) + 0.010 * glitch
	warp = 0.50 * smoothstep(1.7, 2.45, c) * (1.0 - smoothstep(T_GULP - 0.02, T_GULP + 0.12, c))
	warp += 0.32 * smoothstep(T_FLARE, T_FLARE + 0.12, c) * (1.0 - smoothstep(T_FLARE + 0.12, T_FLARE + 0.6, c))
	dark_k = 0.30 * smoothstep(1.3, 2.4, c) + 0.62 * smoothstep(T_FLARE, T_GLITCH, c)
	lantern_k = 1.0 if c < T_DROP + 0.1 else (1.0 - smoothstep(0.6, 2.0, c)) * (0.82 + 0.18 * sin(c * 47.0) * sin(c * 13.0))
	var x := clampf((c - T_CRT) / (T_END - T_CRT), 0.0, 1.0)
	crt = pow(x, 0.8)
	duck = 0.8 * smoothstep(T_GULP, T_GULP + 0.12, c) * (1.0 - smoothstep(T_FLARE - 0.1, T_FLARE + 0.1, c)) + smoothstep(T_CRT - 0.2, T_CRT, c)

	_stream(dt, g)
	while _ev < EV.size() and c >= EV[_ev]:
		_fire(_ev, g)
		_ev += 1
	if c >= T_END:
		done = true


## After the screen has collapsed: hold the last frame (eyes in the dark) and let the picture "re-ignite"
## faintly behind the CONSUMED screen.
func _update_done(dt: float, g) -> void:
	crt = maxf(0.0, crt - dt * 1.2)
	duck = maxf(0.0, duck - dt * 0.7)
	dark_k = 0.96
	lantern_k = 0.0
	g.player.struggle += dt


## The death camera. Blends from the normal camera (`base_origin` at `base_zoom`) to one that holds
## `cam_world` at `cam_screen` (design coords) with a slight roll. `d` is the design-rect offset in the viewport.
func camera(base_zoom: float, base_origin: Vector2, d: Vector2, off: Vector2) -> Transform2D:
	var z := lerpf(base_zoom, cam_zoom, cam_w)
	var rot := cam_roll * cam_w
	var bx := Vector2(cos(rot), sin(rot)) * z
	var by := Vector2(-sin(rot), cos(rot)) * z
	var want := cam_screen + d - (bx * cam_world.x + by * cam_world.y) + off
	return Transform2D(rot, Vector2(z, z), 0.0, base_origin.lerp(want, cam_w))


# ------------------------------------------------------------------ beats
func _fire(i: int, g) -> void:
	var cr: Creature = g.creature
	match i:
		0:   # the claws have closed
			Audio.play(&"con_grab", 0.0)
			Audio.play(&"con_lantern", -4.0)
			g.shake = maxf(g.shake, 16.0)
			GameState.haptic(70)
			g.ps.burst(Vector2(Cfg.PLAYER_X, g.player.y - 70.0), 14, Color(1.0, 0.8, 0.5), 320.0, 0.5, 4.0, 900.0, true)
		1:   # wings flare
			Audio.play(&"con_wings", -2.0)
			g.shake = maxf(g.shake, 10.0)
		2:   # the pull begins
			Audio.play(&"con_suck", -3.0)
		3:   # the gulp
			Audio.play(&"con_gulp", 0.0)
			g.flash(Color(1.0, 0.72, 0.4), 0.75)
			g.shake = 24.0
			GameState.haptic(160)
			g.ps.burst(mouth_world, 26, Color(1.0, 0.75, 0.45), 380.0, 0.7, 5.0, 0.0, true)
			_fx_ring(g, mouth_world)
		4:   # the furnace flares: roar
			Audio.play(&"con_roar", 0.0)
			g.flash(Color(1.0, 0.82, 0.8), 0.95)
			g.shake = 30.0
			GameState.haptic(320)
			_fx_ring(g, chest_world)
			g.ps.burst(chest_world, 40, Color(1.0, 0.3, 0.25), 520.0, 1.0, 5.0, -120.0, true)
		5:   # the glitch crescendo
			Audio.play(&"con_glitch", -1.0)
			GameState.haptic(60, 0.5, 0.9)
		6:   # the screen dies
			Audio.play(&"con_cut", 0.0)
			g.flash(Color(0.9, 0.95, 1.0), 0.55)
			GameState.haptic(40)


func _fx_ring(g, pos: Vector2) -> void:
	g.ps.ring(pos, 300.0, 0.8, Color(1.0, 0.15, 0.18), 6.0, 10.0)
	g.ps.ring(pos, 190.0, 0.6, Color(1.0, 0.8, 0.6), 3.0, 6.0)


## Light drawn out of the runner and into the mouth as he is consumed; embers rising off the feeding furnace.
func _stream(dt: float, g) -> void:
	_spawn_t -= dt
	if _spawn_t > 0.0:
		return
	_spawn_t = 0.02
	if c >= 1.75 and c < T_GULP:
		var src := runner_origin + Vector2(0.0, -HIP * runner_scale).rotated(runner_rot)
		for i in 2:
			var p0 := src + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)) * runner_scale
			var life := 0.42
			g.ps.spawn(p0, (mouth_world - p0) / life, life, randf_range(3.0, 6.0), Color(1.0, 0.76, 0.42, 0.9), 0.0, true, 0.0, 0, 0.0, 0.0)
	if furnace > 0.5 and randf() < 0.5:
		g.ps.spawn(chest_world + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0)), Vector2(randf_range(-40.0, 40.0), randf_range(-160.0, -60.0)), 0.9, randf_range(2.0, 4.5), Color(1.0, 0.35, 0.25, 0.85), 0.0, true, 0.0, 0, 0.0, 0.0)


# ------------------------------------------------------------------ the dropped lantern
func _update_lantern(dt: float, g) -> void:
	if c >= T_DROP and _lan_state == 0:
		_lan_state = 1
		_lan_pos = g.player.lantern_world
		_lan_vel = Vector2(150.0, -310.0)
	if _lan_state == 1:
		_lan_vel.y += 1700.0 * dt
		_lan_pos += _lan_vel * dt
		_lan_rot += _lan_vel.x * dt * 0.025
		var floor_y := Cfg.GROUND_Y - 9.0
		if _lan_pos.y > floor_y:
			_lan_pos.y = floor_y
			_lan_vel.y = -_lan_vel.y * 0.32
			_lan_vel.x *= 0.55
			if absf(_lan_vel.y) < 60.0:
				_lan_vel.y = 0.0
		_lan_vel.x = move_toward(_lan_vel.x, 0.0, 120.0 * dt)
		g.player.lantern_world = _lan_pos   # the light follows the lantern, wherever it lies


func draw_lantern(ci: CanvasItem) -> void:
	if _lan_state == 0:
		return
	var dim := 1.0 - lantern_k
	var glass := Color(1.0, 0.70, 0.28).lerp(Color(0.22, 0.10, 0.07), dim)
	var cage := PackedVector2Array([Vector2(-6.5, -8.0), Vector2(6.5, -8.0), Vector2(7.5, 9.0), Vector2(-7.5, 9.0)])
	var pane := PackedVector2Array([Vector2(-4.5, -5.5), Vector2(4.5, -5.5), Vector2(5.0, 6.5), Vector2(-5.0, 6.5)])
	ci.draw_set_transform(_lan_pos, _lan_rot, Vector2.ONE)
	ci.draw_colored_polygon(cage, Color(0.10, 0.08, 0.13))
	ci.draw_colored_polygon(pane, glass)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7.5, -8.0), Vector2(0.0, -14.0), Vector2(7.5, -8.0)]), Color(0.10, 0.08, 0.13))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ------------------------------------------------------------------ drawing hooks (called by the renderers)
## World layer, between the creature's back half and its front half: the runner in the claw.
func draw_runner(ci: CanvasItem, g, flip: float) -> void:
	if runner_visible:
		var lift := clampf((Cfg.GROUND_Y - (runner_origin.y - HIP * runner_scale)) / 300.0, 0.0, 1.0)
		Gfx.glow_ellipse(ci, Vector2(runner_origin.x - 4.0, Cfg.GROUND_Y + 5.0), 42.0 * (1.0 - lift * 0.5), 9.0, Color(0, 0, 0, 0.6 * (1.0 - lift * 0.6) * (1.0 - held * 0.2)))
		CharacterDrawer.draw(ci, g.player, runner_origin, flip, GameState.look_dress(), GameState.look_accessory(), false, runner_rot, runner_scale)
	draw_lantern(ci)


## Additive layer: the runner igniting as he is drawn in, and the lantern flame dying on the ground.
func draw_glow(ci: CanvasItem, g) -> void:
	if runner_visible and burn > 0.01:
		var p := runner_origin + Vector2(0.0, -HIP * runner_scale).rotated(runner_rot)
		Gfx.glow(ci, p, 40.0 + 90.0 * burn, Color(1.0, 0.78, 0.5, 0.38 * burn))
		Gfx.glow(ci, p, 16.0 + 28.0 * burn, Color(1.0, 0.95, 0.8, 0.7 * burn))
