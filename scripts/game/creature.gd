class_name Creature
extends RefCounted
## The thing behind you. `gap` is its distance (px) behind the runner.
## Looking back makes it close in faster the longer you stare, and it remembers:
## look time decays slowly, so repeated peeks add up.

signal lunged
signal stepped(strength: float)   ## cosmetic: a heavy footfall (drives camera kick / thud, never gameplay)

const DEATH_GAP := 90.0
const MAX_GAP := 760.0

var gap := 680.0
var look_time := 0.0
var aggression := 0.0   ## smoothed 0..1, drives visuals/audio
var surge := 0.0        ## seconds of event-driven extra pressure
var _lunge_done := false
var gait := 0.0         ## cosmetic: integrated stride phase (rad). Purely visual, never read by the simulation.
var _step_i := -1


func reset() -> void:
	gap = 680.0
	look_time = 0.0
	aggression = 0.0
	surge = 0.0
	_lunge_done = false
	gait = 0.0
	_step_i = -1


## Where the creature settles when you are not looking. Shrinks with distance run.
func rest_gap(meters: float) -> float:
	return maxf(300.0, 640.0 - meters * 0.5)


func threat() -> float:
	return clampf(1.0 - (gap - DEATH_GAP) / 560.0, 0.0, 1.0)


func update(dt: float, looking: bool, meters: float, dark: float) -> void:
	if looking:
		look_time += dt
		gap -= (80.0 + look_time * 230.0 + dark * 90.0) * dt
		if look_time > 1.5 and not _lunge_done:
			_lunge_done = true
			gap -= 120.0
			lunged.emit()
	else:
		_lunge_done = false
		look_time = maxf(0.0, look_time - dt * 1.5)
		var rest := rest_gap(meters)
		gap = move_toward(gap, rest, (60.0 if gap < rest else 25.0) * dt)
	if surge > 0.0:
		surge -= dt
		gap -= 110.0 * dt
	gap = minf(gap, MAX_GAP)
	aggression = lerpf(aggression, clampf(look_time / 2.0, 0.0, 1.0), 1.0 - exp(-6.0 * dt))


## Cosmetic only: advances the gait so legs / wings / spine stay continuous when the pace changes
## (the old drawer used `t * rate`, which snapped whenever the rate changed), and reports footfalls.
func animate(dt: float) -> void:
	gait += dt * (5.0 + aggression * 3.0 + (1.2 if surge > 0.0 else 0.0))
	var si := int(floorf((gait - PI * 0.5) / PI))
	if si != _step_i:
		_step_i = si
		stepped.emit(threat())
