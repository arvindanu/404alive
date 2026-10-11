extends Node2D
## Emissive layer drawn ABOVE the lighting shader with additive blending: moonlight haze, windows,
## candles, obstacle rims + chevrons, shards, pickups, the lantern flame, the creature's eyes
## and mouth, rings, sparks. Nothing here is ever swallowed by the darkness.

var game = null


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func setup(g) -> void:
	game = g


func _draw() -> void:
	if game == null:
		return
	var g = game
	var lo := -Cfg.ox - 700.0
	var hi := Cfg.view_w - Cfg.ox + 700.0
	BackgroundDrawer.draw_lights(self, g.dist, g.t, g.dark)
	BackgroundDrawer.draw_eyes(self, g.dist, g.t, g.dark)
	for o in g.gen.obstacles:
		var sx: float = o.x - g.dist
		if o.dead or sx > hi or sx + o.w < lo:
			continue
		ObstacleDrawer.draw_glow(self, o, sx, g.t)
	if not g.consume.active:
		_shards(g, lo, hi)
		_pickup(g)
	# lantern flame: the source of all the warm light (it gutters out when it is dropped in the death sequence)
	var lw: Vector2 = g.player.lantern_world
	var fl := 0.8 + 0.2 * sin(g.t * 17.0) * sin(g.t * 9.3 + 1.0)
	var boost := 1.6 if g.lantern_t > 0.0 else 1.0
	var lk: float = g.consume.lantern_k
	if lk > 0.01:
		Gfx.glow(self, lw, 150.0 * boost * lk, Color(1.0, 0.6, 0.22, 0.13 * fl * lk))
		Gfx.glow(self, lw, 52.0 * boost * lk, Color(1.0, 0.72, 0.32, 0.5 * fl * lk))
		Gfx.glow(self, lw, 16.0, Color(1.0, 0.95, 0.7, 0.85 * lk))
	# dash: speed streaks behind the runner
	if g.player.dash_t > 0.0:
		var da: float = g.player.dash_curve()
		var q := int(g.t * 40.0)
		for i in 12:
			var yy := Cfg.GROUND_Y - 10.0 - Gfx.hash1(float(i) + float(q) * 0.37) * 130.0
			var ln := 120.0 + Gfx.hash1(float(i) * 3.1 + float(q)) * 340.0
			var xx := Cfg.PLAYER_X - 40.0 - Gfx.hash1(float(i) * 7.7 + float(q)) * 120.0
			draw_line(Vector2(xx, yy), Vector2(xx - ln, yy), Color(1.0, 0.35, 0.45, 0.4 * da), 2.5, true)
	# the creature
	if g.consume.active:
		var cons: Consume = g.consume
		CreatureDrawer.draw_glow(self, Cfg.PLAYER_X - g.creature.gap, g.creature, g.look_a, g.t, cons.extra, g.dark, cons)
		cons.draw_glow(self, g)
	else:
		CreatureDrawer.draw_glow(self, Cfg.PLAYER_X - g.creature.gap, g.creature, g.look_a, g.t, 0.0, g.dark)
	# false-creature event: eyes flash ahead of you
	if g.event_id == &"lie":
		var e: float = g.event_strength()
		for ex in [1000.0, 1078.0]:
			Gfx.glow(self, Vector2(ex, 300.0), 64.0, Color(1.0, 0.1, 0.12, 0.7 * e))
			draw_rect(Rect2(ex - 18.0, 296.0, 36.0, 8.0), Color(1.0, 0.85, 0.85, e))
	g.ps.draw_pass(self, true)


func _shards(g, lo: float, hi: float) -> void:
	for s in g.gen.shards:
		var sx: float = s.x - g.dist
		if s.got or sx < lo or sx > hi:
			continue
		var y: float = s.y + sin(g.t * 4.0 + s.phase) * 4.0
		var sc := 1.0 + 0.12 * sin(g.t * 6.0 + s.phase)
		Gfx.glow(self, Vector2(sx, y), 26.0, Color(1.0, 0.72, 0.2, 0.30))
		var top := Vector2(sx, y - 13.0 * sc)
		var bot := Vector2(sx, y + 13.0 * sc)
		var l := Vector2(sx - 8.5, y - 1.0)
		var r := Vector2(sx + 8.5, y - 1.0)
		draw_colored_polygon(PackedVector2Array([top, r, bot, l]), Color(1.0, 0.80, 0.28, 0.85))
		draw_colored_polygon(PackedVector2Array([top, Vector2(sx, y - 1.0), l]), Color(1.0, 0.95, 0.65, 0.65))   # lit facet
		draw_circle(Vector2(sx - 2.5, y - 6.0), 1.6, Color(1, 1, 1, 0.9))


func _pickup(g) -> void:
	var pk = g.pickup
	if pk == null:
		return
	var c: Color = pk.color()
	var pos := Vector2(Cfg.PLAYER_X - pk.off, Cfg.GROUND_Y - 75.0 + sin(g.t * 3.0) * 6.0)
	var a: float = 0.22 + g.look_a * 0.78 + (0.12 * sin(g.t * 9.0) if g.look_a < 0.3 else 0.0)
	Gfx.glow(self, pos, 52.0, Color(c.r, c.g, c.b, 0.85 * a))
	var col := Color(c.r, c.g, c.b, a)
	match pk.kind:
		Pickup.Kind.RELIC:
			var rot: float = g.t * 1.6
			var pts := PackedVector2Array()
			for i in 4:
				pts.append(pos + Vector2(0.0, -17.0 if i % 2 == 0 else -11.0).rotated(rot + TAU * float(i) / 4.0))
			draw_polyline(Gfx.closed(pts), col, 3.5, true)
			draw_circle(pos, 4.0, col)
		Pickup.Kind.WARD:
			draw_arc(pos, 15.0, g.t, g.t + TAU * 0.8, 24, col, 3.5, true)
			draw_arc(pos, 9.0, -g.t * 1.4, -g.t * 1.4 + TAU * 0.6, 16, col, 2.5, true)
		_:
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -16), pos + Vector2(9, 2), pos + Vector2(0, 12), pos + Vector2(-9, 2)]), col)
	if pk.grab > 0.0:
		draw_arc(pos, 28.0, -PI * 0.5, -PI * 0.5 + pk.grab / Pickup.GRAB_TIME * TAU, 32, Color(1, 1, 1, 0.95), 4.0, true)
