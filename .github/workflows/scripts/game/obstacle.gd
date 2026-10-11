class_name Obstacle
extends RefCounted
## One hazard on the track. `x` is a world coordinate (screen x = x - camera distance).

enum Kind { GRAVE, SPIKES, HANGING, PIT, WALL, CROW }

const HANG_BOTTOM := Cfg.GROUND_Y - 84.0   ## underside of a hanging slab (slide lane below)

var kind: int = Kind.GRAVE
var x := 0.0
var w := 100.0
var h := 140.0
var y_off := 100.0       ## crow height above ground
var crow_speed := 0.0    ## extra leftward speed once it is on screen
var seed_v := 0.0
var dead := false
var announced := false   ## crow screech already played


static func make(k: int, x0: float, rng: RandomNumberGenerator) -> Obstacle:
	var o := Obstacle.new()
	o.kind = k
	o.x = x0
	o.seed_v = rng.randf() * 100.0
	match k:
		Kind.GRAVE:
			o.w = rng.randf_range(96.0, 120.0)
			o.h = rng.randf_range(130.0, 170.0)
		Kind.SPIKES:
			o.w = rng.randf_range(210.0, 260.0)
			o.h = rng.randf_range(84.0, 104.0)
		Kind.HANGING:
			o.w = 220.0
		Kind.PIT:
			o.w = rng.randf_range(260.0, 310.0)
		Kind.WALL:
			o.w = 76.0
		Kind.CROW:
			o.w = 78.0
			o.y_off = 100.0
			o.crow_speed = 340.0
	return o


func action() -> StringName:
	match kind:
		Kind.HANGING, Kind.CROW:
			return &"slide"
		Kind.WALL:
			return &"dash"
	return &"jump"


func rect() -> Rect2:
	var g := Cfg.GROUND_Y
	match kind:
		Kind.GRAVE, Kind.SPIKES:
			return Rect2(x, g - h, w, h)
		Kind.HANGING:
			return Rect2(x, -300.0, w, HANG_BOTTOM + 300.0)
		Kind.WALL:
			return Rect2(x, -300.0, w, g + 300.0)
		Kind.CROW:
			return Rect2(x, g - y_off - 20.0, w, 40.0)
	return Rect2(x, g, w, 40.0)


## Slightly forgiving collision rect (world x, screen y).
func hit_rect() -> Rect2:
	var r := rect()
	match kind:
		Kind.GRAVE:
			return r.grow_individual(-12.0, -14.0, -12.0, 0.0)
		Kind.SPIKES:
			return r.grow_individual(-24.0, -22.0, -24.0, 0.0)
		Kind.HANGING:
			return r.grow_individual(-10.0, 0.0, -10.0, -8.0)
		Kind.WALL:
			return r.grow_individual(-8.0, 0.0, -8.0, 0.0)
		Kind.CROW:
			return r.grow_individual(-12.0, -8.0, -12.0, -8.0)
	return r
