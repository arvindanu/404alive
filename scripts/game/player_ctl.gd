class_name PlayerCtl
extends RefCounted
## Runner physics + procedural-animation state. No nodes: pure logic, easy to tune.
##
## Feel features: smooth accel/decel toward a goal speed, coyote time, jump buffering,
## variable jump height (release early = short hop), heavier fall gravity, fast-fall dive
## that chains into a slide, hold-to-extend slide, eased dash with i-frames, and a
## damped spring that squashes/stretches the body on jump and landing.

signal jumped
signal landed(strength: float)
signal slide_started
signal slide_ended
signal dash_started
signal stepped
signal got_hit

const STAND_H := 120.0
const SLIDE_H := 54.0
const HALF_W := 17.0
const JUMP_V := -1060.0
const GRAV_UP := 2700.0
const GRAV_DOWN := 4300.0
const GRAV_CUT := 6400.0     ## gravity while rising with the button released
const FAST_FALL_V := 1500.0
const COYOTE := 0.09
const JUMP_BUFFER := 0.13
const SLIDE_MIN := 0.36
const SLIDE_MAX := 0.95
const DASH_TIME := 0.42
const DASH_COOLDOWN := 2.0
const ACCEL := 1500.0
const DECEL := 2400.0
const SCARF_N := 8

var y := Cfg.GROUND_Y
var vy := 0.0
var on_ground := true
var speed := 0.0
var t := 0.0

var coyote := 0.0
var jump_buf := 0.0
var jump_held := false
var slide_held := false
var sliding := false
var slide_t := 0.0
var slide_queued := false
var dash_t := 0.0
var dash_cd := 0.0
var inv := 0.0
var stun := 0.0

# animation state
var stride := 0.0
var lean := 0.1
var squash := 0.0        ## + = squashed, - = stretched
var squash_v := 0.0
var air_a := 0.0         ## 0..1 blend: in the air
var slide_a := 0.0       ## 0..1 blend: sliding pose
var scarf := PackedVector2Array()
var hood := PackedVector2Array()   ## hood tail chain (local, relative to the head)
var coat_pt := Vector2(-16.0, 14.0)   ## lagging coat hem offset from the hip
var lan_ang := 0.0        ## lantern pendulum angle (rad)
var lan_vel := 0.0
var lantern_world := Vector2(Cfg.PLAYER_X + 30.0, Cfg.GROUND_Y - 60.0)   ## set by the drawer
var _step_idx := 0
var caught := 0.0         ## cosmetic 0..1: in the creature's claw (set by Consume, never by gameplay)
var struggle := 0.0       ## cosmetic clock for the thrashing while held
var lan_gone := false     ## the lantern has been dropped: the drawer omits it


func reset() -> void:
	y = Cfg.GROUND_Y
	vy = 0.0
	on_ground = true
	speed = 0.0
	coyote = 0.0
	jump_buf = 0.0
	jump_held = false
	slide_held = false
	sliding = false
	slide_t = 0.0
	slide_queued = false
	dash_t = 0.0
	dash_cd = 0.0
	inv = 0.0
	stun = 0.0
	stride = 0.0
	lean = 0.1
	squash = 0.0
	squash_v = 0.0
	air_a = 0.0
	slide_a = 0.0
	_step_idx = 0
	caught = 0.0
	struggle = 0.0
	lan_gone = false
	coat_pt = Vector2(-16.0, 14.0)
	lan_ang = 0.0
	lan_vel = 0.0
	scarf.resize(SCARF_N)
	for i in SCARF_N:
		scarf[i] = Vector2(-float(i) * 10.0, 0.0)
	hood.resize(4)
	for i in 4:
		hood[i] = Vector2(-float(i) * 7.0, 2.0)


# ---------------------------------------------------------------- input
func press_jump() -> void:
	jump_held = true
	jump_buf = JUMP_BUFFER


func release_jump() -> void:
	jump_held = false


func press_slide() -> void:
	slide_held = true
	if on_ground:
		_start_slide()
	else:
		vy = maxf(vy, FAST_FALL_V)   # dive; chains into a slide on landing
		slide_queued = true


func release_slide() -> void:
	slide_held = false
	slide_queued = false


func press_dash() -> bool:
	if dash_t > 0.0 or dash_cd > 0.0:
		return false
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN
	inv = maxf(inv, DASH_TIME * 0.92)
	if sliding:
		_end_slide()
	squash = -0.1
	dash_started.emit()
	return true


func take_hit() -> void:
	stun = 0.55
	inv = 1.4
	squash = 0.25
	got_hit.emit()


func bounce(v: float) -> void:
	on_ground = false
	vy = v
	y -= 2.0


# ---------------------------------------------------------------- queries
func height() -> float:
	return SLIDE_H if (sliding and on_ground) else STAND_H


func box() -> Rect2:
	var h := height()
	return Rect2(Cfg.PLAYER_X - HALF_W, y - h, HALF_W * 2.0, h)


func dash_curve() -> float:
	if dash_t <= 0.0:
		return 0.0
	var u := 1.0 - dash_t / DASH_TIME
	return sin(minf(u / 0.15, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.45, 1.0, u))


## Gait cycles per second. The drawer sizes the stride from this so planted feet match the ground.
func cadence() -> float:
	var sn := clampf(speed / 1100.0, 0.0, 1.0)
	return lerpf(2.8, 4.4, sn) * clampf(speed / 260.0, 0.0, 1.0)


func dash_ready_frac() -> float:
	return 1.0 - clampf(dash_cd / DASH_COOLDOWN, 0.0, 1.0)


# ---------------------------------------------------------------- update
func update(dt: float, target_speed: float, looking: bool) -> void:
	t += dt
	# horizontal speed eases toward a state-dependent goal (natural accel/decel)
	var mult := 1.0
	if stun > 0.0:
		mult *= 0.55
	if sliding:
		mult *= 0.93
	if looking:
		mult *= 0.94
	if dash_t > 0.0:
		mult *= 1.0 + 0.75 * dash_curve()
	var goal := target_speed * mult
	speed = move_toward(speed, goal, (ACCEL if goal > speed else DECEL) * dt)

	dash_t = maxf(0.0, dash_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	inv = maxf(0.0, inv - dt)
	stun = maxf(0.0, stun - dt)
	jump_buf = maxf(0.0, jump_buf - dt)
	coyote = COYOTE if on_ground else maxf(0.0, coyote - dt)

	if jump_buf > 0.0 and coyote > 0.0:
		_do_jump()

	if not on_ground:
		var g := GRAV_UP if vy < 0.0 else GRAV_DOWN
		if vy < 0.0 and not jump_held:
			g = GRAV_CUT
		vy += g * dt
		y += vy * dt
		if y >= Cfg.GROUND_Y:
			_land()

	if sliding:
		slide_t += dt
		if slide_t >= SLIDE_MAX or (slide_t >= SLIDE_MIN and not slide_held):
			_end_slide()

	_animate(dt, goal)


func _do_jump() -> void:
	if sliding:
		_end_slide()
	on_ground = false
	vy = JUMP_V
	y -= 1.0
	jump_buf = 0.0
	coyote = 0.0
	slide_queued = false
	squash = -0.22
	jumped.emit()


func _land() -> void:
	var impact := clampf(vy / 1600.0, 0.0, 1.0)
	y = Cfg.GROUND_Y
	vy = 0.0
	on_ground = true
	squash = 0.10 + impact * 0.28
	landed.emit(impact)
	if slide_queued and slide_held:
		_start_slide()
	slide_queued = false


func _start_slide() -> void:
	if sliding:
		return
	sliding = true
	slide_t = 0.0
	squash = 0.12
	slide_started.emit()


func _end_slide() -> void:
	if not sliding:
		return
	sliding = false
	slide_ended.emit()


func _animate(dt: float, goal: float) -> void:
	air_a = lerpf(air_a, 0.0 if on_ground else 1.0, 1.0 - exp(-18.0 * dt))
	slide_a = lerpf(slide_a, 1.0 if (sliding and on_ground) else 0.0, 1.0 - exp(-22.0 * dt))
	var accel_lean := clampf((goal - speed) / 900.0, -1.0, 1.0)
	var lean_t := 0.08 + speed / 1100.0 * 0.12 + accel_lean * 0.05
	if not on_ground:
		lean_t = -0.04 if vy < 0.0 else 0.16
	lean_t += dash_curve() * 0.38
	if stun > 0.0:
		lean_t = -0.12
	lean = lerpf(lean, lean_t, 1.0 - exp(-12.0 * dt))
	# critically-damped-ish spring for squash & stretch
	squash_v += (-380.0 * squash - 27.0 * squash_v) * dt
	squash += squash_v * dt
	if on_ground and not sliding:
		stride += dt * cadence()
		var idx := int(floorf(stride * 2.0))   # a foot strike every half cycle
		if idx != _step_idx:
			_step_idx = idx
			stepped.emit()
	_update_cloth(dt)


func _update_cloth(dt: float) -> void:
	# coat hem lags behind the hip and bounces with each step / landing
	var hem_target := Vector2(-14.0 - speed * 0.014, 12.0 + clampf(vy * 0.012, -10.0, 10.0) + sin(stride * TAU * 2.0) * 3.0)
	coat_pt = coat_pt.lerp(hem_target, 1.0 - exp(-13.0 * dt))
	# hood tail
	var hk := 1.0 - exp(-16.0 * dt)
	hood[0] = Vector2.ZERO
	for i in range(1, hood.size()):
		var ht := hood[i - 1] + Vector2(-7.0 - speed * 0.003, sin(t * 13.0 - float(i)) * 1.2 + 1.5 + clampf(-vy * 0.008, -5.0, 6.0))
		hood[i] = hood[i].lerp(ht, hk)
	# lantern swings like a real pendulum, kicked by the arm swing and vertical motion
	var kick := sin(stride * TAU) * 34.0 * clampf(speed / 700.0, 0.0, 1.0) - vy * 0.004 - (10.0 if dash_t > 0.0 else 0.0)
	lan_vel += (-95.0 * lan_ang - 6.5 * lan_vel + kick) * dt
	lan_ang = clampf(lan_ang + lan_vel * dt, -1.2, 1.2)
	_update_scarf(dt)


func _update_scarf(dt: float) -> void:
	var k := 1.0 - exp(-20.0 * dt)
	var flow := 9.0 + speed * 0.006
	var lift := clampf(-vy * 0.012, -10.0, 12.0)
	scarf[0] = Vector2.ZERO
	for i in range(1, SCARF_N):
		var target := scarf[i - 1] + Vector2(-flow, sin(t * 15.0 - float(i) * 0.9) * (1.5 + float(i) * 0.7) + 2.0 + lift * 0.25)
		scarf[i] = scarf[i].lerp(target, k)
