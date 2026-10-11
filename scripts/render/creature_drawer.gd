class_name CreatureDrawer
extends RefCounted
## The follower: the ultimate form of the flying horror ("wretch", see ObstacleDrawer).
## Same species, same anatomy, many times the size: near-black violet flesh with bone-purple structure,
## an elongated skull on a hinged jaw, slit red eyes with white-hot cores under a CROWN of smaller eyes,
## a row of spine spikes, ragged bone-fingered wings with scalloped membranes, spindly clawed limbs,
## a barbed whip of a tail, a furnace burning under the ribs, a spine that ripples head -> tail like
## the wretch's, and moonlight running along its back.
##
## It is drawn in two halves so the death sequence can put the runner BETWEEN them (in its grasp,
## then inside its jaws): draw_back() = everything behind the runner, draw_front() = head, jaws, near
## wing and near arm. draw_body() is both. draw_glow() is the additive layer (eyes, throat, furnace).
## All motion is a pure function of (creature state, time): there is no hidden state here.
## `cons` is the optional death-sequence state (Consume); null during normal play.

const G := Cfg.GROUND_Y
const BODY := Color(0.034, 0.017, 0.054)        ## same flesh as the wretch
const BODY_FAR := Color(0.022, 0.010, 0.038)
const BONE := Color(0.11, 0.075, 0.16)
const WING := Color(0.058, 0.032, 0.088)         ## membrane: a shade lighter than the flesh, so the wing reads against the sky
const WING_FAR := Color(0.038, 0.020, 0.062)
const TOOTH := Color(0.90, 0.84, 0.76)
const RIM_MOON := Color(0.78, 0.84, 1.0, 0.45)
const N := 12                                   ## spine samples: 0 = neck ... 11 = tail tip

## Rest shape of the spine (creature-local px, facing +x, ground at y = 0, up is -y) and body width at each sample.
const SPINE: Array[Vector2] = [
	Vector2(30.0, -250.0), Vector2(14.0, -228.0), Vector2(-6.0, -202.0), Vector2(-24.0, -172.0),
	Vector2(-38.0, -144.0), Vector2(-48.0, -122.0), Vector2(-76.0, -110.0), Vector2(-118.0, -104.0),
	Vector2(-166.0, -102.0), Vector2(-216.0, -108.0), Vector2(-268.0, -120.0), Vector2(-320.0, -138.0),
]
const WIDTH: Array[float] = [30.0, 48.0, 74.0, 82.0, 66.0, 58.0, 42.0, 30.0, 22.0, 15.0, 9.0, 3.0]
const WAVE: Array[float] = [0.0, 0.0, 1.0, 1.5, 2.0, 3.0, 5.0, 8.0, 12.0, 16.0, 20.0, 22.0]
const SPIKE_LEN: Array[float] = [0.0, 24.0, 34.0, 40.0, 38.0, 32.0, 26.0, 19.0, 0.0, 0.0, 0.0, 0.0]
const ARM_U := 104.0
const ARM_F := 112.0
const LEG_T := 66.0
const LEG_S := 70.0


static func scale_for(cr: Creature, dark: float, extra: float) -> float:
	return 1.0 + dark * 0.45 + cr.aggression * 0.18 + extra


# ------------------------------------------------------------------ helpers
## Catmull-Rom subdivision, so a 12-point spine reads as one smooth animal and not a polygon.
static func _smooth(pts: PackedVector2Array, sub: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in sub:
			var u := float(s) / float(sub)
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u))
	out.append(pts[n - 1])
	return out


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


## Local direction for a wing/finger angle given in the wretch's convention (it faces left; we face right).
static func _wdir(a: float) -> Vector2:
	return Vector2(-cos(a), sin(a))


## The pose is needed by the world pass (back + front halves) and by the glow pass, all in the same frame with
## the same inputs, so it is solved once and shared. The key includes the engine frame number, so a pose can
## never outlive the frame it was built in. (Consume.update calls pose() directly, mid-frame, and is never served
## from here.)
static var _pc := {}
static var _pc_frame := -1
static var _pc_cr: Creature = null
static var _pc_t := 0.0
static var _pc_k := 0.0
static var _pc_gait := 0.0
static var _pc_cons := false


static func _pose_cached(cr: Creature, t: float, k: float, cons) -> Dictionary:
	var f := Engine.get_process_frames()
	var has := cons != null
	if f == _pc_frame and cr == _pc_cr and t == _pc_t and k == _pc_k and cr.gait == _pc_gait and has == _pc_cons:
		return _pc
	_pc = pose(cr, t, k, cons)
	_pc_frame = f
	_pc_cr = cr
	_pc_t = t
	_pc_k = k
	_pc_gait = cr.gait
	_pc_cons = has
	return _pc


## Everything that moves, solved once per frame: spine, head frame, limbs, wings, tail.
static func pose(cr: Creature, t: float, k: float, cons) -> Dictionary:
	var gt := cr.gait
	var ag := cr.aggression
	var lunge := 0.0
	var dip := 0.0
	var jaw_x := 0.0
	var wing_x := 0.0
	var roar := 0.0
	var reach := 0.0
	var grab := 0.0
	var grip := Vector2(150.0, -120.0)
	if cons != null:
		lunge = cons.lunge
		dip = cons.head_dip
		jaw_x = cons.jaw_x
		wing_x = cons.wing_x
		roar = cons.roar
		reach = cons.reach
		grab = cons.grab
		grip = cons.grip_local

	# ---- spine: upper body pivots at the pelvis (bob, lunge, dip), the tail ripples like the wretch's
	var bob := cos(gt * 2.0) * (3.5 + 3.5 * ag) + sin(t * 1.3) * 1.5
	var pitch := 0.03 * sin(gt) + 0.10 * lunge + 0.22 * dip - 0.14 * roar
	var piv := Vector2(-48.0, -122.0)
	var base := PackedVector2Array()
	for i in N:
		var b: Vector2 = SPINE[i]
		var w := clampf((5.0 - float(i)) / 5.0, 0.0, 1.0)
		b = piv + (b - piv).rotated(pitch * w)
		b.y += bob * w
		base.append(b)
	var sp := PackedVector2Array()
	var bn := PackedVector2Array()   # back normal (points up / out of the back)
	for i in N:
		var a := base[maxi(i - 1, 0)]
		var c := base[mini(i + 1, N - 1)]
		var d := (c - a).normalized()   # head -> tail
		var n := Vector2(-d.y, d.x)
		bn.append(n)
		var wave := sin(gt * 1.1 - float(i) * 0.75) * WAVE[i] * (0.7 + 0.5 * ag)
		sp.append(base[i] + n * wave)

	# ---- head frame
	var ha := 0.28 + 0.40 * dip + 0.07 * sin(gt * 0.5 + 1.0) - 0.34 * roar + 0.05 * lunge
	var d0 := Vector2.from_angle(ha)
	var down := Vector2(-d0.y, d0.x)
	var up := -down
	var hc := sp[0] + d0 * 38.0 + up * 2.0 + Vector2(24.0, 26.0) * dip + Vector2(16.0, 0.0) * lunge
	var open := clampf(0.10 + k * 0.46 + jaw_x * 0.50 + roar * 0.26, 0.0, 1.0)

	# ---- limbs
	var legs: Array = []
	for i in 2:
		var hip := sp[5] + Vector2(6.0 - float(i) * 9.0, 8.0 + float(i) * 2.0)
		var pp := gt + PI * float(i)
		var foot := Vector2(sin(pp) * 56.0 + 14.0 - float(i) * 6.0, -maxf(0.0, cos(pp)) * 42.0)
		legs.append([hip, Gfx.ik(hip, foot, LEG_T, LEG_S, -1.0), foot])
	var arms: Array = []
	for i in 2:
		var sh := sp[2] - bn[2] * 8.0 + Vector2(-float(i) * 14.0, float(i) * 4.0)
		var rest := Vector2(74.0 + k * 58.0 + sin(gt + PI * float(i) + 0.6) * 34.0, -92.0 + float(i) * 30.0 + cos(gt + PI * float(i)) * 26.0 - k * 28.0)
		var goal := rest.lerp(grip + Vector2(-16.0, 14.0) * float(i), reach)
		var hand := sh + (goal - sh).limit_length(ARM_U + ARM_F - 3.0)
		arms.append([sh, Gfx.ik(sh, hand, ARM_U, ARM_F, 1.0), hand])

	# ---- wings (wretch convention: -108 = raised, -12 = swept back; mirrored by _wdir)
	var flap := clampf(sin(gt * 0.5) + 0.25 * sin(gt * 1.0 + 1.3), -1.0, 1.0)
	var spread := clampf(ag * 0.6 + wing_x, 0.0, 1.0)
	var wbase := deg_to_rad(lerpf(-66.0, -112.0, spread) + flap * (14.0 - 6.0 * spread))
	var wroot := sp[2] + bn[2] * (WIDTH[2] * 0.5 - 8.0)

	# ---- tail whip continues the spine
	var tail := PackedVector2Array()
	var td := (sp[N - 1] - sp[N - 2]).normalized()
	var tn := Vector2(-td.y, td.x)
	for j in 10:
		var u := float(j) / 9.0
		tail.append(sp[N - 1] + td * (u * 150.0) + tn * (sin(gt * 1.4 - u * 5.5) * (4.0 + 44.0 * u) * (0.8 + 0.5 * ag)) + Vector2(0.0, u * u * 12.0))

	return {"sp": sp, "bn": bn, "hc": hc, "d0": d0, "down": down, "up": up, "open": open, "legs": legs, "arms": arms,
		"wbase": wbase, "wroot": wroot, "flap": flap, "tail": tail, "gt": gt, "spread": spread, "dip": dip, "roar": roar,
		"grab": grab, "reach": reach, "lunge": lunge}


## Jaw polygon in local space (hinged under the back of the skull, swings down as `open` grows).
static func _jaw(hc: Vector2, d0: Vector2, down: Vector2, open: float) -> PackedVector2Array:
	var hj := hc - d0 * 14.0 + down * 12.0
	var lp := PackedVector2Array([Vector2(0, 0), Vector2(70, 2), Vector2(82, 18), Vector2(36, 34), Vector2(-8, 22)])
	var out := PackedVector2Array()
	for v in lp:
		out.append(hj + (d0 * v.x + down * v.y).rotated(open))
	return out


## Where the mouth is (creature-local): the runner is drawn in here during the death sequence.
static func mouth_local(cr: Creature, t: float, cons) -> Vector2:
	var p := pose(cr, t, 1.0, cons)
	var hc: Vector2 = p["hc"]
	var d0: Vector2 = p["d0"]
	var down: Vector2 = p["down"]
	return hc + d0 * 36.0 + down * 26.0


static func _wing(ci: CanvasItem, p: Dictionary, far: bool, t: float, vis: float) -> void:
	var gt: float = p["gt"]
	var root: Vector2 = p["wroot"]
	var flap: float = p["flap"]
	var wb: float = p["wbase"]
	var spread: float = p["spread"]
	var sp: PackedVector2Array = p["sp"]
	var s0 := root + (Vector2(-9.0, 3.0) if far else Vector2.ZERO)
	var f2 := clampf(sin(gt * 0.5 - (0.9 if far else 0.0)) + 0.25 * sin(gt * 1.0 + 1.3 - (1.8 if far else 0.0)), -1.0, 1.0)
	var base := wb + (f2 - flap) * 0.22 + (0.10 if far else 0.0)
	var col := _alpha(WING_FAR if far else WING, vis)
	var lens: Array[float] = [214.0, 190.0, 152.0]
	var offs: Array[float] = [0.0, 0.42, 0.86]
	var wrist := s0 + _wdir(base - 0.12) * 40.0
	var knuckles: Array[Vector2] = []
	var tips: Array[Vector2] = []
	for k in 3:
		var ang := base + offs[k] * (0.82 if far else 1.0)
		var kn := s0 + _wdir(ang) * (lens[k] * 0.55)
		knuckles.append(kn)
		tips.append(kn + _wdir(ang - 0.30 * f2 + 0.16 * sin(t * 2.0 + float(k))) * (lens[k] * 0.45))
	# ragged membrane: a triangle fan from the shoulder, scalloped between the fingers (never self-intersects)
	ci.draw_colored_polygon(PackedVector2Array([s0, wrist, tips[0]]), col)
	for k in 2:
		var scallop := tips[k].lerp(tips[k + 1], 0.5).lerp(s0, 0.34)
		ci.draw_colored_polygon(PackedVector2Array([s0, tips[k], scallop]), col)
		ci.draw_colored_polygon(PackedVector2Array([s0, scallop, tips[k + 1]]), col)
	var anchor := sp[5] + Vector2(-6.0, 4.0)
	ci.draw_colored_polygon(PackedVector2Array([s0, tips[2], anchor]), col)
	var bone := Color(BONE.r, BONE.g, BONE.b, (0.7 if far else 1.0) * vis)
	ci.draw_line(s0, wrist, bone, 8.0, true)
	ci.draw_line(wrist, knuckles[0], bone, 6.0, true)
	for k in 3:
		ci.draw_polyline(PackedVector2Array([s0, knuckles[k], tips[k]]), bone, 5.2 - float(k) * 0.8, true)
	# moonlight on the leading edge and along the scalloped trailing edge
	var edge := PackedVector2Array([s0, wrist, knuckles[0], tips[0]])
	ci.draw_polyline(edge, _alpha(RIM_MOON, vis * (0.55 if far else 1.0)), 2.6, true)
	var trail := PackedVector2Array([tips[0], tips[0].lerp(tips[1], 0.5).lerp(s0, 0.34), tips[1], tips[1].lerp(tips[2], 0.5).lerp(s0, 0.34), tips[2]])
	ci.draw_polyline(trail, _alpha(RIM_MOON, vis * (0.30 if far else 0.55)), 1.8, true)


static func _claws(ci: CanvasItem, hand: Vector2, ad: Vector2, col: Color, grab: float, t: float, seed_v: float, rim: bool) -> void:
	var a0 := ad.angle()
	for f in 3:
		var fo := float(f) - 1.0
		var a := a0 + fo * (0.52 - 0.30 * grab) + sin(t * 3.0 + seed_v + float(f)) * 0.06
		var l1 := 30.0 + float(f % 2) * 8.0
		var m1 := hand + Vector2.from_angle(a) * l1
		var m2 := m1 + Vector2.from_angle(a + (0.55 + 0.75 * grab) * (1.0 if f != 1 else 0.6)) * (24.0 + float(f % 2) * 6.0)
		ci.draw_polyline(PackedVector2Array([hand, m1, m2]), col, 6.0, true)
		ci.draw_colored_polygon(PackedVector2Array([m2 + Vector2.from_angle(a + 1.8) * 3.2, m2 + Vector2.from_angle(a + 1.0) * 14.0 + Vector2.from_angle(a + 0.4) * 6.0, m2 - Vector2.from_angle(a + 1.8) * 3.2]), col)
	var thumb := hand + Vector2.from_angle(a0 - 1.5) * 22.0
	ci.draw_line(hand, thumb, col, 5.0, true)
	if rim:
		ci.draw_polyline(PackedVector2Array([hand, hand + Vector2.from_angle(a0 - 0.5) * 30.0]), RIM_MOON, 1.8, true)


static func _tendril(ci: CanvasItem, origin: Vector2, dir: Vector2, length: float, t: float, seed_v: float, col: Color, w0: float, amp: float) -> void:
	var nrm := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for j in 9:
		var u := float(j) / 8.0
		pts.append(origin + dir * (u * length) + nrm * (sin(t * 5.0 - u * 6.0 + seed_v) * amp * u))
	for j in range(1, pts.size()):
		var u2 := float(j) / 8.0
		ci.draw_line(pts[j - 1], pts[j], col, lerpf(w0, 1.5, u2), true)
	var tt := pts[8]
	var td := (pts[8] - pts[7]).normalized()
	ci.draw_colored_polygon(PackedVector2Array([tt + td.rotated(2.4) * 8.0, tt + td * 16.0, tt + td.rotated(-2.4) * 8.0]), col)   # barb


# ------------------------------------------------------------------ world layer
static func draw_body(ci: CanvasItem, x: float, cr: Creature, dark: float, look_a: float, t: float, extra: float, cons = null) -> void:
	draw_back(ci, x, cr, dark, look_a, t, extra, cons)
	draw_front(ci, x, cr, dark, look_a, t, extra, cons)


static func _vis(cr: Creature, look_a: float) -> float:
	return clampf(1.25 - cr.gap / 520.0 + look_a * 0.5, 0.4, 1.0)


static func draw_back(ci: CanvasItem, x: float, cr: Creature, dark: float, look_a: float, t: float, extra: float, cons = null) -> void:
	var s := scale_for(cr, dark, extra)
	var k := clampf(look_a + cr.aggression * 0.6 + extra, 0.0, 1.0)
	var vis := _vis(cr, look_a)
	var p := _pose_cached(cr, t, k, cons)
	var sp: PackedVector2Array = p["sp"]
	var bn: PackedVector2Array = p["bn"]
	var legs: Array = p["legs"]
	var arms: Array = p["arms"]
	var tail: PackedVector2Array = p["tail"]
	var hc: Vector2 = p["hc"]
	var gt: float = p["gt"]
	var body := _alpha(BODY, vis)
	var far := _alpha(BODY_FAR, vis)
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))
	var thr := cr.threat()

	# a dim red haze behind it, and its weight on the ground
	Gfx.glow(ci, Vector2(-20.0, -160.0), 330.0, Color(0.5, 0.0, 0.1, (0.18 + look_a * 0.22 + cr.aggression * 0.22) * vis))
	Gfx.glow_ellipse(ci, Vector2(-30.0, 4.0), 190.0, 15.0, Color(0, 0, 0, 0.6 * vis))

	# shadow tendrils crawling along the ground toward the runner
	if thr > 0.15:
		var reach := minf((cr.gap - 60.0) / s, 60.0 + thr * 330.0)
		for i in 4:
			var pts := PackedVector2Array()
			for j in 10:
				var u := float(j) / 9.0
				pts.append(Vector2(lerpf(30.0, 30.0 + reach, u), -6.0 - float(i) * 9.0 + sin(t * 4.0 + float(j) * 0.9 + float(i)) * 7.0 * u))
			ci.draw_polyline(pts, _alpha(BODY, vis * 0.9), 6.0 - float(i), true)

	_wing(ci, p, true, t, vis)   # far wing first

	# far limbs
	var lg1: Array = legs[1]
	var lh: Vector2 = lg1[0]
	var lk: Vector2 = lg1[1]
	var lf: Vector2 = lg1[2]
	ci.draw_polyline(PackedVector2Array([lh, lk, lf]), far, 14.0, true)
	for f in 3:
		ci.draw_line(lf, lf + Vector2.from_angle(-0.1 + float(f) * 0.32) * 26.0, far, 5.0, true)
	var a1: Array = arms[1]
	var ash: Vector2 = a1[0]
	var ael: Vector2 = a1[1]
	var aha: Vector2 = a1[2]
	ci.draw_polyline(PackedVector2Array([ash, ael, aha]), far, 12.0, true)
	_claws(ci, aha, (aha - ael).normalized(), far, p["grab"], t, 2.0, false)

	# whipping tail + two feelers streaming off the back of the skull
	for j in range(1, tail.size()):
		ci.draw_line(tail[j - 1], tail[j], body, lerpf(5.5, 2.0, float(j) / 9.0), true)
	var tt := tail[9]
	var tdir := (tail[9] - tail[8]).normalized()
	ci.draw_colored_polygon(PackedVector2Array([tt + tdir.rotated(2.3) * 10.0, tt + tdir * 22.0, tt + tdir.rotated(-2.3) * 10.0]), body)
	var d0: Vector2 = p["d0"]
	var up: Vector2 = p["up"]
	for f in 2:
		_tendril(ci, hc - d0 * 40.0 + up * (8.0 + float(f) * 8.0), Vector2(-0.96, -0.12 - 0.22 * float(f)).normalized(), 150.0 - float(f) * 24.0, t * 0.9 + gt * 0.2, float(f) * 2.0, body, 4.5, 20.0)

	# body ribbon
	var up_e := PackedVector2Array()
	var lo_e := PackedVector2Array()
	for i in N:
		up_e.append(sp[i] + bn[i] * WIDTH[i] * 0.5)
		lo_e.append(sp[i] - bn[i] * WIDTH[i] * 0.5)
	var us := _smooth(up_e, 3)
	var ls := _smooth(lo_e, 3)
	var poly := us.duplicate()
	for i in range(ls.size() - 1, -1, -1):
		poly.append(ls[i])
	ci.draw_colored_polygon(poly, body)
	# neck
	ci.draw_line(sp[1], hc - d0 * 30.0, body, 46.0, true)
	ci.draw_circle(sp[1], 24.0, body)
	# spine spikes along the back
	for i in range(1, 8):
		var ln: float = SPIKE_LEN[i] * (0.9 + 0.1 * sin(gt + float(i)))
		var bpt := up_e[i]
		var ud := (up_e[mini(i + 1, N - 1)] - up_e[maxi(i - 1, 0)]).normalized()
		var hw := 9.0 + ln * 0.18
		var stip := bpt + bn[i] * ln + ud * ln * 0.45
		ci.draw_colored_polygon(PackedVector2Array([bpt - ud * hw, bpt + ud * hw, stip]), body)
		ci.draw_line(bpt - ud * hw, stip, _alpha(RIM_MOON, vis * 0.8), 2.0, true)
	# faint ribs
	for r in 4:
		var fi := 2.0 + float(r) * 0.62
		var i0 := int(floorf(fi))
		var fr := fi - float(i0)
		var cpt := sp[i0].lerp(sp[mini(i0 + 1, N - 1)], fr)
		var wdt := lerpf(WIDTH[i0], WIDTH[mini(i0 + 1, N - 1)], fr)
		var nn := bn[i0].lerp(bn[mini(i0 + 1, N - 1)], fr).normalized()
		var a := cpt + nn * wdt * 0.40
		var b := cpt - nn * wdt * 0.46
		var mid := (a + b) * 0.5 + Vector2(9.0, 5.0)
		ci.draw_polyline(PackedVector2Array([a, mid, b]), _alpha(BONE, vis), 4.6, true)
	# moonlight along the spine, like the wretch's
	var back := PackedVector2Array()
	for i in range(2, us.size() - 8):
		back.append(us[i])
	ci.draw_polyline(back, _alpha(RIM_MOON, vis), 3.4, true)

	# near arm (behind the runner when he is in its grasp; the claws are drawn in draw_front)
	var a0: Array = arms[0]
	var nsh: Vector2 = a0[0]
	var nel: Vector2 = a0[1]
	var nha: Vector2 = a0[2]
	ci.draw_polyline(PackedVector2Array([nsh, nel, nha]), body, 15.0, true)
	ci.draw_circle(nsh, 16.0, body)
	ci.draw_polyline(PackedVector2Array([nsh + Vector2(2, -6), nel + Vector2(2, -6)]), _alpha(RIM_MOON, vis * 0.85), 2.2, true)

	# near leg
	var lg0: Array = legs[0]
	var nh: Vector2 = lg0[0]
	var nk: Vector2 = lg0[1]
	var nf: Vector2 = lg0[2]
	ci.draw_polyline(PackedVector2Array([nh, nk, nf]), body, 16.0, true)
	for f in 3:
		var fa := -0.1 + float(f) * 0.32
		ci.draw_line(nf, nf + Vector2.from_angle(fa) * 30.0, body, 6.0, true)
		ci.draw_colored_polygon(PackedVector2Array([nf + Vector2.from_angle(fa) * 30.0 + Vector2(0, -3), nf + Vector2.from_angle(fa) * 44.0 + Vector2(0, 3), nf + Vector2.from_angle(fa) * 30.0 + Vector2(0, 4)]), body)
	ci.draw_polyline(PackedVector2Array([nh, nk]), _alpha(RIM_MOON, vis * 0.8), 2.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_front(ci: CanvasItem, x: float, cr: Creature, dark: float, look_a: float, t: float, extra: float, cons = null) -> void:
	var s := scale_for(cr, dark, extra)
	var k := clampf(look_a + cr.aggression * 0.6 + extra, 0.0, 1.0)
	var vis := _vis(cr, look_a)
	var p := _pose_cached(cr, t, k, cons)
	var hc: Vector2 = p["hc"]
	var d0: Vector2 = p["d0"]
	var down: Vector2 = p["down"]
	var up: Vector2 = p["up"]
	var open: float = p["open"]
	var gt: float = p["gt"]
	var arms: Array = p["arms"]
	var body := _alpha(BODY, vis)
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))

	# the near wing sweeps over the back of the body
	_wing(ci, p, false, t, vis)

	# elongated skull (same profile as the wretch's, ~3x) with a swept-back crest
	var skull := PackedVector2Array()
	for i in 22:
		var ang := TAU * float(i) / 22.0
		var fx := cos(ang)
		skull.append(hc + d0 * fx * 60.0 + down * sin(ang) * 26.0 * (1.0 - 0.34 * maxf(fx, 0.0)))
	for c in 3:
		var cb := hc + d0 * (-24.0 + float(c) * 15.0) + up * (23.0 - float(c) * 2.0)
		var ctip := cb - d0 * (34.0 - float(c) * 6.0) + up * (26.0 - float(c) * 4.0)
		ci.draw_colored_polygon(PackedVector2Array([cb - d0 * 9.0, cb + d0 * 9.0, ctip]), body)
	ci.draw_colored_polygon(skull, body)
	var jaw := _jaw(hc, d0, down, open)
	ci.draw_colored_polygon(jaw, body)
	var mk0 := clampf((open - 0.18) / 0.9, 0.0, 1.0)
	if mk0 > 0.05:   # the inside of the mouth: a deep, dark red cavity
		var hj0 := hc - d0 * 14.0 + down * 12.0
		ci.draw_colored_polygon(PackedVector2Array([hj0 + d0 * 4.0 - down * 4.0, hc + d0 * 56.0 + down * 8.0, jaw[1], jaw[0]]), Color(0.10, 0.0, 0.025, 0.80 * mk0 * vis))
	# moon rim over the whole upper skull (back of the head -> brow -> snout) and under the jaw
	var rim_sk := PackedVector2Array()
	for i in range(11, 22):
		rim_sk.append(skull[i])
	rim_sk.append(skull[0])
	ci.draw_polyline(rim_sk, _alpha(RIM_MOON, vis), 3.2, true)
	ci.draw_polyline(PackedVector2Array([jaw[1], jaw[2], jaw[3]]), _alpha(RIM_MOON, vis * 0.8), 2.4, true)
	ci.draw_polyline(PackedVector2Array([hc - d0 * 30.0 + up * 8.0, hc + d0 * 6.0 + up * 4.0, hc + d0 * 52.0 + down * 4.0]), _alpha(BONE, vis), 5.0, true)   # cheek bone
	# the lantern is the only warm light in the world: it catches the face of whatever is close
	var warm := clampf(1.0 - cr.gap / 460.0, 0.0, 1.0) * 0.55
	if warm > 0.02:
		ci.draw_polyline(PackedVector2Array([hc + d0 * 58.0 + down * 3.0, hc + d0 * 34.0 + down * 15.0, jaw[1], jaw[2]]), Color(1.0, 0.68, 0.34, warm * vis), 2.4, true)

	# near hand: only the claws are in front of the runner, so the forearm passes BEHIND him and the fingers clamp over him
	var a0: Array = arms[0]
	var ael: Vector2 = a0[1]
	var aha: Vector2 = a0[2]
	_claws(ci, aha, (aha - ael).normalized(), body, p["grab"], t, 0.0, true)
	if warm > 0.02:
		ci.draw_polyline(PackedVector2Array([ael, aha]), Color(1.0, 0.68, 0.34, warm * vis * 0.7), 2.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ------------------------------------------------------------------ additive glow layer
static func draw_glow(ci: CanvasItem, x: float, cr: Creature, look_a: float, t: float, extra: float, dark: float, cons = null) -> void:
	var s := scale_for(cr, dark, extra)
	var vis := clampf(1.5 - cr.gap / 420.0 + look_a * 0.6, 0.35, 1.0)
	var k := clampf(look_a + cr.aggression * 0.6 + extra, 0.0, 1.0)
	var p := _pose_cached(cr, t, k, cons)
	var sp: PackedVector2Array = p["sp"]
	var bn: PackedVector2Array = p["bn"]
	var hc: Vector2 = p["hc"]
	var d0: Vector2 = p["d0"]
	var down: Vector2 = p["down"]
	var up: Vector2 = p["up"]
	var open: float = p["open"]
	var furnace := 0.0
	var hot := 0.0
	var throat := -1.0
	if cons != null:
		furnace = cons.furnace
		hot = cons.eye_hot
		throat = cons.throat
	ci.draw_set_transform(Vector2(x, G), 0.0, Vector2(s, s))
	var beat := 0.75 + 0.25 * sin(t * (4.0 + cr.aggression * 6.0))
	var fk := clampf(k + furnace, 0.0, 1.6)

	# the furnace under the ribs: a soft core plus light leaking between the ribs
	var core := sp[3] + Vector2(8.0, 4.0)
	Gfx.glow(ci, core, 96.0 + 70.0 * furnace, Color(1.0, 0.1, 0.12, (0.12 + fk * 0.28) * vis * beat))
	if furnace > 0.02:
		Gfx.glow(ci, core, 60.0 + 40.0 * furnace, Color(1.0, 0.62, 0.35, 0.55 * furnace))
	for r in 4:
		var fi := 2.0 + (float(r) + 0.5) * 0.62
		var i0 := int(floorf(fi))
		var fr := fi - float(i0)
		var cpt := sp[i0].lerp(sp[mini(i0 + 1, N - 1)], fr)
		var wdt := lerpf(WIDTH[i0], WIDTH[mini(i0 + 1, N - 1)], fr)
		var nn := bn[i0].lerp(bn[mini(i0 + 1, N - 1)], fr).normalized()
		var a := cpt + nn * wdt * 0.34
		var b := cpt - nn * wdt * 0.40
		var mid := (a + b) * 0.5 + Vector2(9.0, 5.0)
		ci.draw_polyline(PackedVector2Array([a, mid, b]), Color(1.0, 0.18 + 0.4 * furnace, 0.2 + 0.3 * furnace, (0.25 + fk * 0.5) * vis * beat), 3.0, true)

	# a swallowed light travelling down the throat into the furnace
	if throat >= 0.0:
		var tp := sp[0].lerp(sp[3], clampf(throat, 0.0, 1.0))
		Gfx.glow(ci, tp, 60.0, Color(1.0, 0.7, 0.35, 0.9 * (1.0 - absf(throat - 0.5) * 0.6)))

	# eyes: slits with white-hot cores and a red bloom (the wretch's, bigger) + the crown of lesser eyes
	var blink := 0.15 if fmod(t * 0.7 + 0.3, 3.2) < 0.12 else 1.0
	for e in 2:
		var ep := hc + d0 * (32.0 - float(e) * 46.0) + up * (8.0 + float(e) * 6.0)
		Gfx.glow(ci, ep, 62.0 + 30.0 * hot, Color(1.0, 0.1, 0.15, (0.55 + 0.3 * hot) * vis))
		var hw := 11.0 + k * 3.0 + 4.0 * hot
		var thick := (7.0 + k * 3.0 + 4.0 * hot) * blink
		var slit := PackedVector2Array([ep - d0 * hw + up * 4.5 * blink, ep + d0 * hw - up * 4.5 * blink])
		ci.draw_polyline(slit, Color(1.0, 0.22, 0.26, vis), thick, true)
		ci.draw_polyline(slit, Color(1.0, 0.86 + 0.1 * hot, 0.80 + 0.15 * hot, vis), thick * 0.46, true)   # white-hot core
	for j in 7:
		var dp := hc + d0 * (48.0 - float(j) * 13.5) + up * (27.0 + 3.0 * sin(float(j) * 1.7))
		var bl := clampf(0.55 + 0.6 * sin(t * 1.9 + float(j) * 2.3), 0.12, 1.0)
		Gfx.glow(ci, dp, 11.0, Color(1.0, 0.1, 0.15, 0.5 * bl * vis))
		ci.draw_circle(dp, 2.6 + float(j % 3) * 0.7, Color(1.0, 0.3 + 0.4 * hot, 0.34 + 0.4 * hot, 0.9 * bl * vis))

	# open mouth: red throat + a double row of needle teeth
	var mk := clampf((open - 0.18) / 0.9, 0.0, 1.0)
	if mk > 0.05:
		var jaw := _jaw(hc, d0, down, open)
		var hj := hc - d0 * 14.0 + down * 12.0
		var up_front := hc + d0 * 56.0 + down * 8.0
		var up_back := hj + d0 * 4.0 - down * 4.0
		var deep := Color(0.95, 0.07, 0.10, 0.50 * mk * vis)   # hot at the throat, fading toward the lips
		var lip := Color(0.95, 0.07, 0.10, 0.04 * mk * vis)
		ci.draw_polygon(PackedVector2Array([up_back, up_front, jaw[1], jaw[0]]), PackedColorArray([deep, lip, lip, deep]))
		Gfx.glow(ci, (up_back + jaw[1]) * 0.5, 54.0 + 30.0 * hot, Color(1.0, 0.25, 0.2, 0.38 * mk * vis))
		var tooth := Color(TOOTH.r, TOOTH.g, TOOTH.b, 0.72 * mk * vis)
		for i in 6:
			var u := 0.10 + float(i) / 6.0 * 0.86
			var tl := 11.0 + 8.0 * fmod(float(i) * 7.3, 3.0) + 4.0 * mk
			var tpt := up_back.lerp(up_front, u)
			ci.draw_colored_polygon(PackedVector2Array([tpt - d0 * 2.2, tpt + d0 * 2.2, tpt + down * tl]), tooth)
			if i < 5:
				var bpt := jaw[0].lerp(jaw[1], u)
				var bl2 := 9.0 + 7.0 * fmod(float(i) * 5.1 + 1.0, 3.0) + 4.0 * mk
				ci.draw_colored_polygon(PackedVector2Array([bpt - d0 * 2.2, bpt + d0 * 2.2, bpt - down * bl2]), tooth)

	# its light on the ground
	Gfx.glow_ellipse(ci, Vector2(60.0, 8.0), 240.0, 24.0, Color(0.8, 0.05, 0.1, (0.08 + 0.14 * k + 0.2 * furnace) * vis))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
