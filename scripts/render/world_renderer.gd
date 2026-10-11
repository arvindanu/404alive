extends Node2D
## World layer: everything that is darkened by the lantern-lighting shader.

var game = null


func setup(g) -> void:
	game = g


func _draw() -> void:
	if game == null:
		return
	var g = game
	BackgroundDrawer.draw(self, g.dist, g.t, g.dark, g.fog_amount())
	var light_x: float = g.player.lantern_world.x
	var lo := -Cfg.ox - 700.0
	var hi := Cfg.view_w - Cfg.ox + 700.0
	for o in g.gen.obstacles:
		var sx: float = o.x - g.dist
		if o.dead or sx > hi or sx + o.w < lo:
			continue
		ObstacleDrawer.draw_shadow(self, o, sx, light_x)
		ObstacleDrawer.draw_body(self, o, sx, g.t, g.dark)
	g.ps.draw_pass(self, false)
	var flip := lerpf(1.0, -1.0, smoothstep(0.2, 0.8, g.look_a))   # turn around to look back
	var cx: float = Cfg.PLAYER_X - g.creature.gap
	if g.consume.active:
		# the death sequence: the runner is drawn BETWEEN the creature's halves, so its forearm passes behind
		# him, its claws clamp over him, and its jaws close over him
		var cons: Consume = g.consume
		CreatureDrawer.draw_back(self, cx, g.creature, g.dark, g.look_a, g.t, cons.extra, cons)
		cons.draw_runner(self, g, flip)
		CreatureDrawer.draw_front(self, cx, g.creature, g.dark, g.look_a, g.t, cons.extra, cons)
	else:
		CharacterDrawer.draw(self, g.player, Vector2(Cfg.PLAYER_X, g.player.y), flip, GameState.look_dress(), GameState.look_accessory())
		CreatureDrawer.draw_body(self, cx, g.creature, g.dark, g.look_a, g.t, 0.0)
	BackgroundDrawer.draw_foreground(self, g.dist, g.t)
