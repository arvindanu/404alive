class_name WorldGen
extends RefCounted
## Endless procedural track. Builds *patterns* (not random single obstacles) so every
## section is readable and fair; spacing is derived from current speed so reaction time
## stays humane while difficulty ramps up.

class Shard:
	var x := 0.0
	var y := 0.0
	var phase := 0.0
	var got := false

var obstacles: Array[Obstacle] = []
var shards: Array[Shard] = []
var rng := RandomNumberGenerator.new()
var next_x := 2300.0     ## first hazard is ~4 s away: time to learn the controls
var last_wall_x := -99999.0
var _last: StringName = &""
var _count := 0          ## patterns spawned so far (drives the gentle opening)
var _m := 0.0            ## meters at the moment of spawning


func fill(dist: float, speed: float, meters: float) -> void:
	while next_x < dist + 2400.0:
		_spawn_pattern(speed, meters)


func update(dt: float, dist: float) -> void:
	for o in obstacles:
		# crows only start flying once they are on screen, so pattern spacing holds
		if o.kind == Obstacle.Kind.CROW and o.x - dist < 1300.0:
			o.x -= o.crow_speed * dt
	var i := obstacles.size() - 1
	while i >= 0:
		var o := obstacles[i]
		if o.dead or o.x + o.w < dist - 900.0:
			obstacles.remove_at(i)
		i -= 1
	i = shards.size() - 1
	while i >= 0:
		var s := shards[i]
		if s.got or s.x < dist - 900.0:
			shards.remove_at(i)
		i -= 1


func _add(kind: int, x: float) -> Obstacle:
	var o := Obstacle.make(kind, x, rng)
	# the opening uses smaller, easier-to-clear hazards; full size is reached by ~60 m
	if kind == Obstacle.Kind.GRAVE or kind == Obstacle.Kind.SPIKES:
		o.h = minf(o.h, lerpf(112.0, 170.0, clampf(_m / 60.0, 0.0, 1.0)))
	obstacles.append(o)
	return o


func _shard(x: float, y: float) -> void:
	var s := Shard.new()
	s.x = x
	s.y = y
	s.phase = rng.randf() * TAU
	shards.append(s)


func _arc(cx: float, base_y: float, n: int, rise: float, spacing: float = 46.0) -> void:
	for i in n:
		var u := float(i) / float(maxi(n - 1, 1))
		_shard(cx + (float(i) - float(n - 1) * 0.5) * spacing, base_y - sin(u * PI) * rise)


func _line(cx: float, y: float, n: int, spacing: float = 44.0) -> void:
	for i in n:
		_shard(cx + (float(i) - float(n - 1) * 0.5) * spacing, y)


func _spawn_pattern(speed: float, m: float) -> void:
	var g := Cfg.GROUND_Y
	_m = m
	var pool: Array[StringName] = [&"grave"]
	if m >= 40.0:
		pool.append_array([&"spikes", &"hanging"])
	if m >= 90.0:
		pool.append(&"pit")
	if m >= 150.0:
		pool.append_array([&"grave_slide", &"double_grave"])
	if m >= 210.0 and next_x - last_wall_x > speed * 2.6:
		pool.append_array([&"wall", &"wall"])
	if m >= 280.0:
		pool.append(&"crow")
	if m >= 360.0:
		pool.append_array([&"slide_jump", &"crow_grave"])
	if rng.randf() < 0.14:
		pool = [&"trail"]
	# the opening, scripted: single grave -> breather of shards -> single graves, then variety
	if _count == 1:
		pool = [&"trail"]
	elif _count < 4:
		pool = [&"grave"]
	elif _count < 7:
		pool = [&"grave", &"spikes", &"trail"]
	var p: StringName = pool[rng.randi() % pool.size()]
	if p == _last and pool.size() > 1 and rng.randf() < 0.6:
		p = pool[(pool.find(p) + 1) % pool.size()]
	_last = p

	var react := lerpf(1.25, 0.8, clampf(m / 1000.0, 0.0, 1.0))   # seconds of breathing room
	react *= 1.0 + clampf(1.0 - float(_count) / 7.0, 0.0, 1.0) * 0.9   # up to ~1.9x roomier at the very start
	_count += 1
	var x := next_x
	var length := 0.0
	match p:
		&"grave":
			var o := _add(Obstacle.Kind.GRAVE, x)
			_arc(o.x + o.w * 0.5, g - o.h - 40.0, 5, 90.0)
			length = o.w
		&"spikes":
			var o := _add(Obstacle.Kind.SPIKES, x)
			_arc(o.x + o.w * 0.5, g - o.h - 40.0, 6, 90.0)
			length = o.w
		&"hanging":
			var o := _add(Obstacle.Kind.HANGING, x)
			_line(o.x + o.w * 0.5, g - 34.0, 5, 44.0)
			length = o.w
		&"pit":
			var o := _add(Obstacle.Kind.PIT, x)
			_arc(o.x + o.w * 0.5, g - 150.0, 6, 100.0)
			length = o.w
		&"wall":
			var o := _add(Obstacle.Kind.WALL, x)
			_line(o.x + o.w * 0.5, g - 70.0, 4, 44.0)
			last_wall_x = x
			length = o.w
		&"double_grave":
			var a := _add(Obstacle.Kind.GRAVE, x)
			var b := _add(Obstacle.Kind.GRAVE, x + a.w + 50.0)
			a.h = minf(a.h, 140.0)   # keep the pair clearable with one jump at top speed
			b.h = minf(b.h, 140.0)
			_arc((a.x + b.x + b.w) * 0.5, g - maxf(a.h, b.h) - 40.0, 7, 90.0, 50.0)
			length = b.x + b.w - x
		&"grave_slide":
			var a := _add(Obstacle.Kind.GRAVE, x)
			var b := _add(Obstacle.Kind.HANGING, x + a.w + speed * 0.95)
			_arc(a.x + a.w * 0.5, g - a.h - 40.0, 5, 90.0)
			_line(b.x + b.w * 0.5, g - 34.0, 4, 44.0)
			length = b.x + b.w - x
		&"slide_jump":
			var a := _add(Obstacle.Kind.HANGING, x)
			var b := _add(Obstacle.Kind.GRAVE, x + a.w + speed * 0.8)
			_line(a.x + a.w * 0.5, g - 34.0, 4, 44.0)
			_arc(b.x + b.w * 0.5, g - b.h - 40.0, 5, 90.0)
			length = b.x + b.w - x
		&"crow":
			var o := _add(Obstacle.Kind.CROW, x + 300.0)
			length = 300.0 + o.w
		&"crow_grave":
			_add(Obstacle.Kind.CROW, x + 300.0)
			var b := _add(Obstacle.Kind.GRAVE, x + 300.0 + speed * 1.35)
			_arc(b.x + b.w * 0.5, g - b.h - 40.0, 5, 90.0)
			length = b.x + b.w - x
		&"trail":
			for i in 10:
				_shard(x + float(i) * 50.0, g - 90.0 - sin(float(i) * 0.6) * 70.0)
			length = 500.0
	# never closer than ~0.9 s of running or 560 px, whatever the speed was when this was generated
	var gap_px := maxf(speed * react, maxf(speed * 0.9, 560.0))
	next_x = x + length + gap_px + rng.randf_range(0.0, 160.0)
