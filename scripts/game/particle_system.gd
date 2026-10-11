class_name ParticleSystem
extends RefCounted
## Pooled CPU particles + expanding rings, drawn straight to a CanvasItem (no node per particle).
## Kinds: 0 square, 1 circle, 2 tumbling shard, 3 streak (stretches along velocity), 4 soft glow.

class P:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var size := 3.0
	var size_end := 1.0
	var color := Color.WHITE
	var gravity := 0.0
	var drag := 0.0
	var additive := false
	var scroll := 0.0      ## fraction of world speed applied (sticks to the ground)
	var kind := 0
	var rot := 0.0
	var rot_v := 0.0

class Ring:
	var pos := Vector2.ZERO
	var r0 := 8.0
	var r1 := 120.0
	var life := 0.4
	var max_life := 0.4
	var color := Color.WHITE
	var width := 4.0

var items: Array[P] = []
var rings: Array[Ring] = []
var cap := 420
var density := 1.0        ## 0.5 on "Low FX"
var _pool: Array[P] = []


func spawn(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, gravity: float = 0.0, additive: bool = false, scroll: float = 0.0, kind: int = 0, size_end: float = -1.0, drag: float = 0.0) -> void:
	if items.size() >= cap:
		return
	var p: P = _pool.pop_back() if not _pool.is_empty() else P.new()
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.size_end = size if size_end < 0.0 else size_end
	p.color = color
	p.gravity = gravity
	p.additive = additive
	p.scroll = scroll
	p.kind = kind
	p.drag = drag
	p.rot = randf() * TAU
	p.rot_v = randf_range(-14.0, 14.0)
	items.append(p)


func burst(pos: Vector2, count: int, color: Color, speed: float, life: float, size: float, gravity: float = 700.0, additive: bool = false, angle_min: float = 0.0, angle_max: float = TAU, scroll: float = 0.0, kind: int = 0) -> void:
	var n := int(ceilf(float(count) * density))
	for i in n:
		var a := randf_range(angle_min, angle_max)
		var s := speed * randf_range(0.35, 1.0)
		spawn(pos, Vector2(cos(a), sin(a)) * s, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.3), color, gravity, additive, scroll, kind, 0.0)


func ring(pos: Vector2, r1: float, life: float, color: Color, width: float = 4.0, r0: float = 8.0) -> void:
	var r := Ring.new()
	r.pos = pos
	r.r0 = r0
	r.r1 = r1
	r.life = life
	r.max_life = life
	r.color = color
	r.width = width
	rings.append(r)


func update(dt: float, world_speed: float) -> void:
	var i := items.size() - 1
	while i >= 0:
		var p := items[i]
		p.life -= dt
		if p.life <= 0.0:
			items.remove_at(i)
			_pool.append(p)
		else:
			p.vel.y += p.gravity * dt
			if p.drag > 0.0:
				p.vel *= maxf(0.0, 1.0 - p.drag * dt)
			p.pos += p.vel * dt
			p.pos.x -= world_speed * p.scroll * dt
			p.rot += p.rot_v * dt
		i -= 1
	i = rings.size() - 1
	while i >= 0:
		rings[i].life -= dt
		if rings[i].life <= 0.0:
			rings.remove_at(i)
		i -= 1


func draw_pass(ci: CanvasItem, additive: bool) -> void:
	for p in items:
		if p.additive != additive:
			continue
		var k := p.life / p.max_life
		var s := lerpf(p.size_end, p.size, k)
		var c := p.color
		c.a *= k
		match p.kind:
			1:
				ci.draw_circle(p.pos, s, c)
			2:
				var q := PackedVector2Array()
				for a in [0.0, 2.3, 4.0]:
					q.append(p.pos + Vector2(cos(p.rot + a), sin(p.rot + a)) * s * (1.6 if a == 0.0 else 1.0))
				ci.draw_colored_polygon(q, c)
			3:
				var d := p.vel.normalized() if p.vel.length() > 1.0 else Vector2.LEFT
				ci.draw_line(p.pos, p.pos - d * (s * 4.0 + p.vel.length() * 0.03), c, maxf(s * 0.5, 1.0), true)
			4:
				Gfx.glow(ci, p.pos, s * 3.0, c)
			_:
				ci.draw_rect(Rect2(p.pos.x - s * 0.5, p.pos.y - s * 0.5, s, s), c)
	if additive:
		for r in rings:
			var k := 1.0 - r.life / r.max_life
			var e := 1.0 - pow(1.0 - k, 3.0)
			var c := r.color
			c.a *= (1.0 - k)
			ci.draw_arc(r.pos, lerpf(r.r0, r.r1, e), 0.0, TAU, 48, c, maxf(r.width * (1.0 - k), 0.8), true)
