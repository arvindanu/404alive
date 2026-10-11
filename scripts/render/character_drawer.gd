class_name CharacterDrawer
extends RefCounted
## The runner: a hooded figure with a lantern. Fully procedural, so every pose is continuous.
##
## Run cycle: each leg follows a stance/swing path (foot planted and moving back at ground
## speed, then lifting and swinging forward); the hips bounce twice per cycle (lowest in mid
## stance, highest in flight), the torso leans with acceleration, arms counter-swing, the coat
## hem / hood tail / scarf lag behind, and the lantern swings on a real pendulum.
## Poses for jump, fall, slide, dash, landing crouch and stumble are blended on top, then
## legs/arms are solved with two-bone IK.

const COAT := Color(0.28, 0.23, 0.42)
const COAT_D := Color(0.14, 0.11, 0.24)
const COAT_FAR := Color(0.12, 0.09, 0.20)
const TRIM := Color(0.70, 0.64, 0.84)
const BOOT := Color(0.09, 0.07, 0.14)
const RIM := Color(0.78, 0.82, 1.0, 0.45)
const GLASS := Color(1.0, 0.70, 0.28)
const HIP_H := 57.0
const THIGH := 32.0
const SHIN := 32.0
const TORSO := 36.0
const UARM := 20.0
const FARM := 20.0


## Foot path over one gait cycle (u in 0..1). Planted: the foot slides back at exactly ground speed.
## Swing: a Hermite curve that leaves the ground and arrives still moving backward (leg retraction),
## so foot velocity is continuous at toe-off and touch-down - no hitch, no skating.
static func _run_foot(u: float, stance: float, rf: float, rb: float, lift: float) -> Vector2:
	if u < stance:
		return Vector2(lerpf(rf, -rb, u / stance), 0.0)
	var span := 1.0 - stance
	var s := (u - stance) / span
	var vs := -(rf + rb) / stance
	var m0 := vs * 0.25 * span
	var m1 := vs * 0.65 * span
	var s2 := s * s
	var s3 := s2 * s
	var x := (2.0 * s3 - 3.0 * s2 + 1.0) * (-rb) + (s3 - 2.0 * s2 + s) * m0 + (-2.0 * s3 + 3.0 * s2) * rf + (s3 - s2) * m1
	return Vector2(x, -lift * sin(PI * pow(s, 0.8)))


static func _boot_ang(u: float, stance: float) -> float:
	if u < stance:
		var k := u / stance
		return -0.15 * (1.0 - clampf(k * 4.0, 0.0, 1.0)) + 0.5 * pow(k, 3.0)   # toe-off at the end of stance
	var s := (u - stance) / (1.0 - stance)
	return lerpf(0.6, -0.15, s * s * (3.0 - 2.0 * s))


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, w1: float, w2: float, col: Color, rim_off: Vector2, rim: bool) -> void:
	if rim:
		Gfx.capsule(ci, a + rim_off, b + rim_off, w1 + 2.0, w1 * 0.9 + 1.5, RIM)
		Gfx.capsule(ci, b + rim_off, c + rim_off, w1 * 0.9 + 1.5, w2 + 2.0, RIM)
	Gfx.capsule(ci, a, b, w1, w1 * 0.9, col)
	Gfx.capsule(ci, b, c, w1 * 0.9, w2, col)


static func _boot(ci: CanvasItem, ankle: Vector2, ang: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-7.0, -5.0), Vector2(5.0, -6.0), Vector2(13.0, 0.0), Vector2(14.0, 5.0), Vector2(-7.0, 5.0)])
	for i in pts.size():
		pts[i] = ankle + pts[i].rotated(ang)
	ci.draw_colored_polygon(pts, col)


static func draw(ci: CanvasItem, p: PlayerCtl, origin: Vector2, flip: float, dress_i: int = 0, acc_i: int = 0, shadow: bool = true, rot: float = 0.0, scl: float = 1.0) -> void:
	var pal := palette(dress_i)
	var coat: Color = pal["coat"]
	var coat_d: Color = pal["coat_d"]
	var coat_far: Color = pal["coat_far"]
	var trim: Color = pal["trim"]
	var lift := clampf((Cfg.GROUND_Y - p.y) / 300.0, 0.0, 1.0)
	if shadow:
		# contact shadow + a longer one thrown away from the lantern
		Gfx.glow_ellipse(ci, Vector2(origin.x - 4.0, Cfg.GROUND_Y + 5.0), 42.0 * (1.0 - lift * 0.5), 9.0, Color(0, 0, 0, 0.6 * (1.0 - lift * 0.6)))
		Gfx.glow_ellipse(ci, Vector2(origin.x - 52.0, Cfg.GROUND_Y + 6.0), 64.0 * (1.0 - lift * 0.4), 8.0, Color(0, 0, 0, 0.28 * (1.0 - lift * 0.7)))

	var sq := p.squash
	var sc := Vector2((1.0 + sq * 0.22) * flip, 1.0 - sq * 0.32) * scl
	ci.draw_set_transform(origin, rot, sc)
	var ca := p.caught   # 0..1: hanging in the creature's claw
	var rim_off := Vector2(2.4 * flip, -1.6)

	# ------------------------------------------------------------ pose
	var u := fposmod(p.stride, 1.0)
	var sn := clampf(p.speed / 1100.0, 0.0, 1.0)
	var stance := lerpf(0.42, 0.30, sn)
	var sa := p.slide_a
	var aa := p.air_a * (1.0 - sa)
	var ra := (1.0 - aa) * (1.0 - sa)
	var da := p.dash_curve()
	var fall_w := clampf(p.vy / 1400.0 + 0.5, 0.0, 1.0)
	var crouch := maxf(sq, 0.0) * 46.0 + minf(sq, 0.0) * 22.0
	var bob := cos(TAU * 2.0 * (u - stance * 0.5)) * (4.0 + 5.0 * sn) * ra

	var hip := Vector2(lerpf(0.0, 8.0, sa), lerpf(-(HIP_H - 3.0 * sn) + bob + crouch, -27.0, sa) - 6.0 * aa)
	var ang := lerpf(lerpf(p.lean + sin(TAU * u) * 0.025 * ra, lerpf(-0.06, 0.2, fall_w), aa), -1.18, sa)
	hip = hip.lerp(Vector2(0.0, -HIP_H), ca)                               # pinned in the claw
	ang = lerpf(ang, -0.42 + sin(p.struggle * 9.0) * 0.10, ca)               # recoiling, head thrown back
	var td := Vector2(sin(ang), -cos(ang))
	var fwd := Vector2(-td.y, td.x)   # "forward" relative to the torso
	var shoulder := hip + td * TORSO
	var head := shoulder + td * 16.0 + Vector2(1.0 + 2.0 * sn, -bob * 0.22)

	# stride sized so the planted foot moves back exactly as far as the ground moves under it
	var travel := clampf(p.speed * stance / maxf(p.cadence(), 0.5), 38.0, 100.0)
	var ankles: Array[Vector2] = []
	var knees: Array[Vector2] = []
	var boot_a: Array[float] = []
	var hands: Array[Vector2] = []
	var elbows: Array[Vector2] = []
	for i in 2:
		var ui := fposmod(u + 0.5 * float(i), 1.0)
		var run_f := _run_foot(ui, stance, travel * 0.46 + da * 8.0, travel * 0.54 + da * 6.0, 15.0 + 11.0 * sn + da * 8.0)
		var rise_f := Vector2(20.0, -32.0) if i == 0 else Vector2(-16.0, -12.0)
		var drop_f := Vector2(16.0, -3.0) if i == 0 else Vector2(-10.0, -12.0)
		var slide_f := Vector2(60.0, -9.0) if i == 0 else Vector2(40.0, -3.0)
		var f := run_f.lerp(rise_f.lerp(drop_f, fall_w), aa).lerp(slide_f, sa)
		f = f.lerp(Vector2(-7.0 + 14.0 * float(i) + sin(p.struggle * 15.0 + float(i) * 2.6) * 14.0, -2.0 + sin(p.struggle * 11.0 + float(i) * 1.7) * 7.0), ca)   # legs dangle and kick
		f.y = minf(f.y, 0.0)
		var ankle := f + Vector2(0.0, -5.0)
		ankles.append(ankle)
		knees.append(Gfx.ik(hip, ankle, THIGH, SHIN, -1.0))
		boot_a.append(lerpf(lerpf(_boot_ang(ui, stance), lerpf(0.5, 0.15, fall_w), aa), -0.35, sa))

		# Natural cross-body gait: each arm swings OPPOSITE to the leg on its own side, which means it
		# moves WITH the opposite leg (left leg + right arm forward together, then right leg + left arm).
		# Phase comes from that side's actual leg phase, so arms and legs can never drift apart.
		var leg_ph := fposmod(u + 0.5 * float(i), 1.0)
		var swing := -cos(TAU * (leg_ph - 0.96))   # + = arm forward
		var amp := (13.0 if i == 0 else 24.0) + 6.0 * sn   # the near arm carries the lantern, so it swings less
		var run_h := shoulder + Vector2(swing * amp - 2.0 + (6.0 if i == 0 else 0.0), 22.0 - maxf(swing, 0.0) * (8.0 if i == 0 else 13.0))
		var dash_h := shoulder + Vector2(-36.0 - float(i) * 6.0, 10.0 + float(i) * 8.0)
		var rise_h := shoulder + (Vector2(26.0, -26.0) if i == 0 else Vector2(-14.0, -24.0))
		var drop_h := shoulder + (Vector2(30.0, -8.0) if i == 0 else Vector2(-24.0, -4.0))
		var slide_h := (shoulder + Vector2(30.0, 6.0)) if i == 0 else Vector2(-54.0, -3.0)
		var h := run_h.lerp(dash_h, da).lerp(rise_h.lerp(drop_h, fall_w), aa).lerp(slide_h, sa)
		h = h.lerp(shoulder + Vector2(sin(p.struggle * 17.0 + float(i) * 2.0) * 14.0 + (16.0 if i == 0 else -12.0), -24.0 + cos(p.struggle * 13.0 + float(i)) * 12.0), ca)   # arms thrown up, clawing the air
		h = shoulder + (h - shoulder).limit_length(UARM + FARM - 1.0)
		hands.append(h)
		elbows.append(Gfx.ik(shoulder, h, UARM, FARM, 1.0))

	var lantern_pt := hands[0] + Vector2(sin(p.lan_ang), cos(p.lan_ang)) * 17.0
	if not p.lan_gone:
		p.lantern_world = origin + Vector2(lantern_pt.x * sc.x, lantern_pt.y * sc.y)

	# ------------------------------------------------------------ far side
	_limb(ci, hip + Vector2(-2.0, 0.0), knees[1], ankles[1], 13.0, 9.0, coat_far, rim_off, false)
	_boot(ci, ankles[1], boot_a[1], Color(0.06, 0.05, 0.10))
	_limb(ci, shoulder, elbows[1], hands[1], 9.0, 7.0, coat_far, rim_off, false)
	# hood tail
	var hp := p.hood
	for i in range(1, hp.size()):
		Gfx.capsule(ci, head + fwd * -6.0 + hp[i - 1], head + fwd * -6.0 + hp[i], lerpf(11.0, 4.0, float(i - 1) / 3.0), lerpf(11.0, 4.0, float(i) / 3.0), coat_d)

	# ------------------------------------------------------------ torso + coat
	var hem_front := hip + fwd * 12.0 + Vector2(0.0, 13.0)
	var hem_back := hip + p.coat_pt
	var coat_poly := PackedVector2Array([shoulder - fwd * 11.0, shoulder + fwd * 11.0, hem_front, hem_back])
	Gfx.vgrad(ci, coat_poly, shoulder.y, maxf(hem_back.y, hem_front.y), coat, coat_d)
	Gfx.capsule(ci, hip + td * 8.0, shoulder, 22.0, 25.0, coat)
	ci.draw_line(shoulder + fwd * 11.0 + rim_off, hem_front + rim_off, RIM, 2.0, true)
	ci.draw_line(hip - fwd * 10.0, hip + fwd * 11.0, trim, 4.0, true)   # belt
	ci.draw_circle(hip + fwd * 1.0, 2.6, Color(0.95, 0.8, 0.4))
	_dress_details(ci, dress_i, p, hip, shoulder, td, fwd, hem_front, hem_back, pal)

	# ------------------------------------------------------------ near side
	_limb(ci, hip + Vector2(2.0, 0.0), knees[0], ankles[0], 14.0, 10.0, coat, rim_off, true)
	_boot(ci, ankles[0], boot_a[0], BOOT)
	_limb(ci, shoulder, elbows[0], hands[0], 10.0, 8.0, coat, rim_off, true)
	ci.draw_circle(hands[0], 5.0, Color(0.82, 0.76, 0.84))
	if not p.lan_gone:
		# lantern on a short chain
		var lc := lantern_pt
		ci.draw_line(hands[0], lc + Vector2(0.0, -8.0).rotated(p.lan_ang * 0.6), BOOT, 1.6, true)
		var cage := PackedVector2Array([Vector2(-6.5, -8.0), Vector2(6.5, -8.0), Vector2(7.5, 9.0), Vector2(-7.5, 9.0)])
		var glass := PackedVector2Array([Vector2(-4.5, -5.5), Vector2(4.5, -5.5), Vector2(5.0, 6.5), Vector2(-5.0, 6.5)])
		for i in 4:
			cage[i] = lc + cage[i].rotated(p.lan_ang * 0.5)
			glass[i] = lc + glass[i].rotated(p.lan_ang * 0.5)
		ci.draw_colored_polygon(cage, Color(0.10, 0.08, 0.13))
		ci.draw_colored_polygon(glass, GLASS)
		ci.draw_colored_polygon(PackedVector2Array([lc + Vector2(-7.5, -8.0).rotated(p.lan_ang * 0.5), lc + Vector2(0.0, -14.0).rotated(p.lan_ang * 0.5), lc + Vector2(7.5, -8.0).rotated(p.lan_ang * 0.5)]), Color(0.10, 0.08, 0.13))

	# ------------------------------------------------------------ head
	Gfx.capsule(ci, shoulder, shoulder + td * 9.0, 11.0, 10.0, Color(0.72, 0.66, 0.78))   # neck
	ci.draw_circle(head + rim_off, 16.8, RIM)
	ci.draw_circle(head, 15.5, coat)
	ci.draw_circle(head + fwd * 4.5 + Vector2(0.0, 0.5), 10.6, Color(0.035, 0.025, 0.06))   # shadowed face
	ci.draw_arc(head, 15.2, ang - 2.2, ang + 0.4, 14, trim, 1.8, true)   # hood trim
	ci.draw_circle(head + fwd * 9.0 + Vector2(0.0, -1.0), 2.4, Color(0.96, 0.93, 1.0))   # one wide eye
	ci.draw_circle(head + fwd * 9.8 + Vector2(0.0, -1.0), 1.0, Color(0.03, 0.02, 0.06))

	# ------------------------------------------------------------ trailing cloth + accessory
	_trail(ci, dress_i, p, shoulder + td * 5.0, pal)
	_accessory(ci, acc_i, p, head, shoulder, td, fwd, ang)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ====================================================================================== cosmetics
## Colours of each dress (index into GameState.DRESSES). `trail` is the cloth that streams behind the
## neck (it used to be the colour-coded scarf), `edge` its highlighted upper edge.
static func palette(i: int) -> Dictionary:
	match i:
		1:   # Gravedigger: mud-brown coat, rust trim, burlap trail
			return {"coat": Color(0.31, 0.25, 0.17), "coat_d": Color(0.15, 0.11, 0.07), "coat_far": Color(0.12, 0.09, 0.06), "trim": Color(0.80, 0.47, 0.19), "trail": Color(0.62, 0.51, 0.34), "edge": Color(0.0, 0.0, 0.0, 0.0), "trail_w": 11.0}
		2:   # Mourner: black crepe, bone trim, long pale-edged veil
			return {"coat": Color(0.10, 0.09, 0.13), "coat_d": Color(0.04, 0.035, 0.06), "coat_far": Color(0.035, 0.03, 0.05), "trim": Color(0.90, 0.87, 0.80), "trail": Color(0.07, 0.06, 0.10), "edge": Color(0.86, 0.84, 0.78, 0.85), "trail_w": 14.0}
		3:   # Bloodbound: crimson coat, black belt, ribbons of blood
			return {"coat": Color(0.50, 0.06, 0.10), "coat_d": Color(0.22, 0.02, 0.05), "coat_far": Color(0.16, 0.02, 0.04), "trim": Color(0.10, 0.02, 0.04), "trail": Color(0.78, 0.07, 0.14), "edge": Color(1.0, 0.35, 0.4, 0.5), "trail_w": 8.0}
		4:   # Void Regalia: night-indigo coat, star-gold trim, cosmic cape
			return {"coat": Color(0.08, 0.06, 0.20), "coat_d": Color(0.03, 0.02, 0.10), "coat_far": Color(0.03, 0.02, 0.09), "trim": Color(0.96, 0.80, 0.36), "trail": Color(0.16, 0.10, 0.42), "edge": Color(0.62, 0.52, 1.0, 0.8), "trail_w": 15.0}
	return {"coat": COAT, "coat_d": COAT_D, "coat_far": COAT_FAR, "trim": TRIM, "trail": Color(0.72, 0.69, 0.78), "edge": Color(0.0, 0.0, 0.0, 0.0), "trail_w": 11.0}


static func _patch(ci: CanvasItem, c: Vector2, td: Vector2, fwd: Vector2, w: float, h: float, col: Color) -> void:
	var a := fwd * (w * 0.5)
	var b := td * (h * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([c - a - b, c + a - b, c + a + b, c - a + b]), col)
	var st := col.darkened(0.55)
	ci.draw_line(c - a * 0.78 - b * 0.78, c + a * 0.78 - b * 0.78, st, 1.0)
	ci.draw_line(c + a * 0.78 - b * 0.78, c + a * 0.78 + b * 0.78, st, 1.0)
	ci.draw_line(c + a * 0.78 + b * 0.78, c - a * 0.78 + b * 0.78, st, 1.0)
	ci.draw_line(c - a * 0.78 + b * 0.78, c - a * 0.78 - b * 0.78, st, 1.0)


## Surface details of the coat, drawn over the torso and under the near arm.
static func _dress_details(ci: CanvasItem, i: int, p: PlayerCtl, hip: Vector2, shoulder: Vector2, td: Vector2, fwd: Vector2, hem_front: Vector2, hem_back: Vector2, pal: Dictionary) -> void:
	var trim: Color = pal["trim"]
	var coat_d: Color = pal["coat_d"]
	match i:
		1:   # Gravedigger: suspender, stitched patches, a muddy hem
			ci.draw_line(shoulder + fwd * 5.0, hip + fwd * 4.0 + td * 3.0, trim, 3.0, true)
			_patch(ci, hip + td * 23.0 + fwd * 2.0, td, fwd, 11.0, 9.0, Color(0.47, 0.38, 0.24))
			_patch(ci, hip + td * 11.0 - fwd * 6.0, td, fwd, 8.0, 8.0, Color(0.21, 0.16, 0.11))
			ci.draw_line(hem_back, hem_front, Color(0.08, 0.055, 0.03, 0.75), 5.0, true)
		2:   # Mourner: bone buttons, a stiff pale collar, a tattered hem
			ci.draw_colored_polygon(PackedVector2Array([shoulder - fwd * 9.0 + td * 1.0, shoulder + fwd * 9.0 + td * 1.0, shoulder + fwd * 6.0 + td * 10.0, shoulder - fwd * 6.0 + td * 10.0]), Color(0.90, 0.88, 0.82, 0.95))
			for k in 3:
				ci.draw_circle(hip + td * (10.0 + float(k) * 9.5) + fwd * 8.0, 1.9, trim)
			for k in 4:
				var hp := hem_back.lerp(hem_front, (float(k) + 0.5) / 4.0)
				ci.draw_colored_polygon(PackedVector2Array([hp + Vector2(-4.5, -1.0), hp + Vector2(4.5, -1.0), hp + Vector2(0.0, 6.0 + 3.0 * sin(p.t * 8.0 + float(k) * 1.7))]), coat_d)
		3:   # Bloodbound: claw marks across the chest, a dripping hem
			for k in 3:
				var a0 := hip + td * (13.0 + float(k) * 7.0) - fwd * 10.0
				var a1 := a0 + fwd * 19.0 + td * 8.0
				ci.draw_line(a0, a1, Color(0.12, 0.0, 0.02, 0.8), 3.4, true)
				ci.draw_line(a0, a1, Color(1.0, 0.20, 0.28, 0.95), 1.8, true)
			for k in 4:
				var base := hem_back.lerp(hem_front, (float(k) + 0.5) / 4.0)
				var ln := 5.0 + 7.0 * (0.5 + 0.5 * sin(p.t * 2.2 + float(k) * 1.9))
				ci.draw_line(base, base + Vector2(0.0, ln), Color(0.80, 0.05, 0.12), 2.4, true)
				ci.draw_circle(base + Vector2(0.0, ln), 2.0, Color(0.9, 0.08, 0.15))
		4:   # Void Regalia: a glowing front edge and a constellation sewn into the coat
			ci.draw_line(shoulder + fwd * 9.0, hem_front, Color(0.62, 0.52, 1.0, 0.85), 2.4, true)
			var st := PackedVector2Array([Vector2(-7.0, 8.0), Vector2(1.0, 14.0), Vector2(-3.0, 22.0), Vector2(6.0, 27.0), Vector2(-5.0, 31.0)])
			var pts := PackedVector2Array()
			for q in st:
				pts.append(hip + fwd * q.x + td * q.y)
			for k in range(1, pts.size()):
				ci.draw_line(pts[k - 1], pts[k], Color(trim.r, trim.g, trim.b, 0.45), 1.0, true)
			for k in pts.size():
				ci.draw_circle(pts[k], 1.4 + 0.5 * sin(p.t * 5.0 + float(k) * 2.0), trim)


## The cloth streaming behind the neck (the old scarf's chain, restyled per dress).
static func _trail(ci: CanvasItem, i: int, p: PlayerCtl, neck: Vector2, pal: Dictionary) -> void:
	var sp := p.scarf
	var col: Color = pal["trail"]
	var edge: Color = pal["edge"]
	var tw: float = pal["trail_w"]
	var n := sp.size()
	if i == 3:   # two ribbons that flutter out of phase
		for r in 2:
			var off := Vector2(0.0, 4.5 * float(r))
			var rc := col if r == 0 else col.darkened(0.35)
			for k in range(1, n):
				var wr := lerpf(tw, 2.5, float(k) / float(n))
				var wob := Vector2(0.0, sin(p.t * 11.0 + float(k) * 0.8 + float(r) * 2.2) * 1.6 * float(r))
				ci.draw_line(neck + sp[k - 1] + off + wob, neck + sp[k] + off + wob, rc, wr, true)
		return
	for k in range(1, n):
		var w1 := lerpf(tw, 3.5, float(k) / float(n))
		ci.draw_line(neck + sp[k - 1] + Vector2(0.0, 2.0), neck + sp[k] + Vector2(0.0, 2.0), col.darkened(0.45), w1, true)
	for k in range(1, n):
		var w2 := lerpf(tw - 1.0, 3.0, float(k) / float(n))
		ci.draw_line(neck + sp[k - 1], neck + sp[k], col, w2, true)
	if edge.a > 0.0:
		for k in range(1, n):
			var w3 := lerpf(tw * 0.5, 1.0, float(k) / float(n))
			ci.draw_line(neck + sp[k - 1] + Vector2(0.0, -tw * 0.32), neck + sp[k] + Vector2(0.0, -tw * 0.32), edge, maxf(w3 * 0.35, 1.2), true)
	if i == 1:   # frayed burlap end
		var tip := neck + sp[n - 1]
		for k in 3:
			ci.draw_line(tip, tip + Vector2(-5.0 - float(k) * 2.0, (float(k) - 1.0) * 3.5 + sin(p.t * 9.0 + float(k)) * 1.5), col.darkened(0.2), 1.4, true)
	if i == 4:   # twinkling stars caught in the cape
		for k in range(1, n):
			var tw2 := 0.5 + 0.5 * sin(p.t * 6.0 + float(k) * 1.7)
			ci.draw_circle(neck + sp[k] + Vector2(0.0, -1.0), 1.1 + 0.5 * tw2, Color(1.0, 0.92, 0.55, 0.35 + 0.6 * tw2))


## Mirror a raven-local point (so it faces backwards), tilt it and move it to the perch.
static func _rv(q: Vector2, rp: Vector2, tilt: float) -> Vector2:
	return rp + (Vector2(-q.x, q.y) * 1.3).rotated(tilt)


static func _antler(ci: CanvasItem, root: Vector2, up: Vector2, side: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array([root, root + up * 9.0 + side * 3.0, root + up * 19.0 + side * 8.0, root + up * 29.0 + side * 8.0])
	for k in 3:
		Gfx.capsule(ci, pts[k], pts[k + 1], w * (1.0 - float(k) * 0.22), w * (1.0 - float(k + 1) * 0.22), col)
	Gfx.capsule(ci, pts[1], pts[1] + up * 8.0 + side * 9.0, w * 0.62, w * 0.3, col)
	Gfx.capsule(ci, pts[2], pts[2] + up * 9.0 + side * 10.0, w * 0.55, w * 0.25, col)
	Gfx.capsule(ci, pts[3], pts[3] + up * 9.0 + side * 1.0, w * 0.4, w * 0.2, col)


## Worn items. `td` points up the torso, `fwd` is the direction the runner faces (both in the flipped frame).
static func _accessory(ci: CanvasItem, i: int, p: PlayerCtl, head: Vector2, shoulder: Vector2, td: Vector2, fwd: Vector2, ang: float) -> void:
	match i:
		1:   # Raven Omen: perched on the back shoulder, facing backwards: it watches what is chasing you
			var bob := sin(p.t * 9.0) * 0.8 * (1.0 - p.air_a)
			var rp := shoulder + td * 13.0 - fwd * 12.0 + Vector2(0.0, bob)
			var flap := p.air_a * (0.5 + 0.5 * sin(p.t * 26.0))
			var tilt := 0.30
			var body := PackedVector2Array([Vector2(-9.0, 0.0), Vector2(-4.0, -6.0), Vector2(5.0, -6.5), Vector2(11.0, -3.0), Vector2(7.0, 4.0), Vector2(-3.0, 5.5)])
			for k in body.size():
				body[k] = _rv(body[k], rp, tilt)
			for k in 3:   # tail feathers, pointing toward the runner's head
				ci.draw_line(_rv(Vector2(-8.0, 1.0 + float(k) * 1.5), rp, tilt), _rv(Vector2(-19.0 - float(k) * 2.0, 3.0 + float(k) * 3.0 + sin(p.t * 7.0 + float(k)) * 1.2), rp, tilt * 0.5), Color(0.03, 0.03, 0.07), 2.6, true)
			ci.draw_colored_polygon(body, Color(0.05, 0.05, 0.10))
			ci.draw_line(body[1], body[2], Color(0.55, 0.65, 1.0, 0.85), 1.6, true)   # moon rim
			var wing := PackedVector2Array([Vector2(-6.0, -2.0), Vector2(1.0, -5.0 - flap * 9.0), Vector2(9.0, -2.0 - flap * 4.0), Vector2(1.0, 3.0)])
			for k in wing.size():
				wing[k] = _rv(wing[k], rp, tilt)
			ci.draw_colored_polygon(wing, Color(0.09, 0.09, 0.17))
			var hd := _rv(Vector2(11.0, -5.0), rp, tilt)
			ci.draw_circle(hd, 4.2, Color(0.05, 0.05, 0.10))
			ci.draw_colored_polygon(PackedVector2Array([_rv(Vector2(13.5, -6.5), rp, tilt), _rv(Vector2(21.0, -4.0), rp, tilt), _rv(Vector2(13.5, -3.0), rp, tilt)]), Color(0.16, 0.14, 0.16))
			var eye := _rv(Vector2(12.5, -6.0), rp, tilt)
			Gfx.glow(ci, eye, 10.0, Color(1.0, 0.1, 0.15, 0.55))
			ci.draw_circle(eye, 1.2, Color(1.0, 0.35, 0.35))
		2:   # Hollow Stag: bone antlers grown out of the hood
			var root := head + td * 11.0
			_antler(ci, root - fwd * 6.0, td, -fwd * 0.9, Color(0.50, 0.47, 0.40), 5.0)
			_antler(ci, root + fwd * 3.0, td, fwd * 0.9, Color(0.90, 0.86, 0.74), 5.6)
			ci.draw_line(root + fwd * 1.0, root + fwd * 5.0, Color(0.62, 0.58, 0.48), 3.0, true)
		3:   # Plague Mask: pale leather beak, amber lens, strap
			var fc := head + fwd * 5.0 + Vector2(0.0, 0.5)
			ci.draw_line(head - fwd * 12.0 + td * 2.0, fc - fwd * 3.0, Color(0.13, 0.09, 0.07), 2.2, true)
			ci.draw_circle(fc, 10.4, Color(0.80, 0.73, 0.60))
			ci.draw_arc(fc, 10.0, ang - 1.9, ang + 0.7, 12, Color(0.55, 0.47, 0.36), 1.6, true)
			ci.draw_colored_polygon(PackedVector2Array([fc + fwd * 7.0 + td * 5.5, fc + fwd * 25.0 - td * 6.0, fc + fwd * 8.0 - td * 6.5]), Color(0.86, 0.79, 0.64))
			ci.draw_line(fc + fwd * 7.0 + td * 5.5, fc + fwd * 25.0 - td * 6.0, Color(0.55, 0.47, 0.36), 1.3, true)
			var lens := head + fwd * 8.5 + td * 1.8
			Gfx.glow(ci, lens, 16.0, Color(1.0, 0.65, 0.2, 0.55))
			ci.draw_circle(lens, 5.0, Color(0.16, 0.11, 0.07))
			ci.draw_circle(lens, 3.7, Color(1.0, 0.72, 0.26))
			ci.draw_circle(lens + Vector2(-1.1, -1.3), 1.0, Color(1.0, 0.97, 0.85))
		4:   # Fallen Halo: a cracked, guttering ring of light above the hood
			var hc := head + td * 29.0 + Vector2(0.0, sin(p.t * 3.0) * 1.6)
			var pulse := 0.75 + 0.25 * sin(p.t * 5.0)
			Gfx.glow(ci, hc, 40.0, Color(1.0, 0.82, 0.4, 0.30 * pulse))
			var ring := PackedVector2Array()
			for k in range(0, 17):
				var a := 0.9 + float(k) / 16.0 * (TAU - 0.9)   # a gap in the ring: it is cracked
				ring.append(hc + Vector2(cos(a) * 14.0, sin(a) * 4.6).rotated(-0.12))
			ci.draw_polyline(ring, Color(0.35, 0.22, 0.05, 0.9), 4.6, true)
			ci.draw_polyline(ring, Color(1.0, 0.88, 0.45, pulse), 2.6, true)
			for k in 3:
				var fk := fposmod(p.t * 0.6 + float(k) * 0.33, 1.0)
				ci.draw_circle(hc + Vector2(-9.0 + float(k) * 9.0, 4.0 + fk * 14.0), 1.3 * (1.0 - fk), Color(1.0, 0.85, 0.4, 0.8 * (1.0 - fk)))
