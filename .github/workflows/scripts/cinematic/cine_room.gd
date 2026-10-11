class_name CineRoom
extends RefCounted
## The cabin interior of the first-boot cinematic, as a small perspective scene (so the camera can
## genuinely ORBIT instead of faking it with a flat side view).
##
## World units are the old room's pixels (the runner is built at K = 2.7x his in-game rig); +X is to the
## right when you stand in the room looking at the back wall, +Y is up, +Z comes out of the back wall
## toward you. The desk stands against the back wall (z = 0); the monitor faces +Z, toward the chair.
##
## Rendering is deliberately simple and robust: everything is projected through a pinhole camera into
## the 1280x720 design space; boxes cull their back faces; objects are queued and painted far-to-near
## (the room shell is painted immediately, before the queue). Colours carry the lighting directly (the
## lamp dying dims every surface; the monitor tints what faces it), which keeps occlusion honest: the
## runner's head really does cover part of the screen when the camera is behind him.
##
## Camera story: a 3/4 profile of him working at the PC -> a slow orbit around behind his shoulder (so the
## screen and he share the frame) -> the cut, the fear, the wake-up and the pull play out from there ->
## the camera follows him into the glass.

const K := 2.7
const DESK_Y := 144.0
const MON_C := Vector3(0.0, 245.0, 64.0)          ## centre of the screen glass
const GLASS_W := 231.0
const GLASS_H := 130.0
const SEAT := Vector3(0.0, 106.0, 254.0)          ## his hip while he sits
const LANTERN_AT := Vector3(-120.0, 167.0, 172.0)  ## where it waits on the desk
const MUG_AT := Vector3(92.0, 156.0, 172.0)
const SOCKET := Vector3(470.0, 40.0, 1.0)
const LAMP_BULB := Vector3(-190.0, 256.0, 72.0)

const C_POLY := 0
const C_GRAD := 1
const C_CAP := 2
const C_CIRC := 3
const C_LINE := 4
const C_GLOW := 5
const C_SCREEN := 6

const FACE_N: Array[Vector3] = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]
const FACE_V := [
	[Vector3(-1.0, 1.0, -1.0), Vector3(1.0, 1.0, -1.0), Vector3(1.0, 1.0, 1.0), Vector3(-1.0, 1.0, 1.0)],
	[Vector3(-1.0, -1.0, 1.0), Vector3(1.0, -1.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(-1.0, 1.0, 1.0)],
	[Vector3(1.0, -1.0, -1.0), Vector3(-1.0, -1.0, -1.0), Vector3(-1.0, 1.0, -1.0), Vector3(1.0, 1.0, -1.0)],
	[Vector3(1.0, -1.0, 1.0), Vector3(1.0, -1.0, -1.0), Vector3(1.0, 1.0, -1.0), Vector3(1.0, 1.0, 1.0)],
	[Vector3(-1.0, -1.0, -1.0), Vector3(-1.0, -1.0, 1.0), Vector3(-1.0, 1.0, 1.0), Vector3(-1.0, 1.0, -1.0)],
]
const FACE_SHADE: Array[float] = [1.16, 1.0, 0.58, 0.74, 0.86]

static var _pos := Vector3(0.0, 300.0, 700.0)
static var _fw := Vector3(0.0, 0.0, -1.0)
static var _rt := Vector3(1.0, 0.0, 0.0)
static var _up := Vector3(0.0, 1.0, 0.0)
static var _f := 1250.0
static var _c0 := Vector2(640.0, 360.0)
static var _q: Array = []
static var _now: CanvasItem = null   ## when set, primitives are painted immediately instead of queued
static var _dk := 0.0                ## 0..1: how dark the room is (the lamp dying)
static var _mi := 0.22               ## the monitor's light intensity
static var _t := 0.0
static var _vs := 1.0
static var _vo := Vector2.ZERO


# ======================================================================================== camera
static func _set_camera(pos: Vector3, target: Vector3, f: float, c0: Vector2) -> void:
	_pos = pos
	_fw = (target - pos).normalized()
	_rt = _fw.cross(Vector3.UP).normalized()
	_up = _rt.cross(_fw)
	_f = f
	_c0 = c0


static func _dp(p: Vector3) -> float:
	return (p - _pos).dot(_fw)


static func _pr(p: Vector3) -> Vector2:
	var v := p - _pos
	var z := maxf(v.dot(_fw), 25.0)
	return _c0 + Vector2(v.dot(_rt), -v.dot(_up)) * (_f / z)


## Screen pixels per world unit at p.
static func _sc(p: Vector3) -> float:
	return _f / maxf((p - _pos).dot(_fw), 25.0)


## The camera as a polar move around a pivot: yaw is measured from "straight behind him" toward the left.
static func _polar(pivot: Vector3, yaw_deg: float, r: float, h: float) -> Vector3:
	var a := deg_to_rad(yaw_deg)
	return pivot + Vector3(-sin(a) * r, h, cos(a) * r)


## Camera for time t -> [position, target, focal length].
##   11.7 - 20.0  orbit from a 3/4 profile of him working to over his left shoulder
##   20.0 - 24.0  hold (a slow drift), the power cut and the wake-up happen in this shot
##   24.0 - 33.0  a dolly toward the glowing screen
##   33.0 - 38.3  the dive into the glass
static func _camera(t: float) -> Array:
	var u0 := CineArt._io((t - CineArt.T_INT) / 8.2)
	var u1 := CineArt._io((t - 24.0) / 9.0)
	var yaw := lerpf(64.0, 37.0, u0) - 10.0 * u1
	var r := lerpf(980.0, 800.0, u0) - 150.0 * u1
	var h := lerpf(85.0, 150.0, u0) - 40.0 * u1
	var pivot := Vector3(10.0, 215.0, 170.0).lerp(Vector3(-78.0, 236.0, 118.0), u0).lerp(Vector3(26.0, 236.0, 200.0), u1)
	# a barely-there handheld drift so the shot breathes
	pivot += Vector3(sin(t * 0.37) * 5.0, cos(t * 0.29) * 3.0, 0.0)
	var pos := _polar(pivot, yaw, r, h)
	var tgt := pivot
	var f := 1250.0 + 60.0 * u1
	var dive := pow(CineArt._e((t - CineArt.T_ZOOM) / 5.3), 1.5)
	if dive > 0.0:
		pos = pos.lerp(Vector3(0.0, 245.0, 64.0 + 205.0), dive)
		tgt = tgt.lerp(MON_C, dive)
		f = lerpf(f, 1250.0, dive)
	return [pos, tgt, f]


# ======================================================================================== lighting helpers
## The room dims with the lamp: every surface colour is pulled toward the night's blue-black.
static func _lc(c: Color) -> Color:
	return Color(lerpf(c.r, 0.006, _dk), lerpf(c.g, 0.010, _dk), lerpf(c.b, 0.035, _dk), c.a)


## Surface colour: face brightness, the lamp, and the monitor's cold light on whatever faces it.
static func _shade(col: Color, k: float, n: Vector3, p: Vector3) -> Color:
	var c := _lc(Color(col.r * k, col.g * k, col.b * k, col.a))
	var d := MON_C - p
	var md2 := d.length_squared()
	var fall := 1.0 / (1.0 + md2 / 60000.0)
	var face := maxf(n.dot(d.normalized()), 0.0)
	var a := _mi * 0.7 * fall * face
	return Color(c.r + 0.26 * a, c.g + 0.62 * a, c.b + 1.0 * a, c.a)


# ======================================================================================== queue / primitives
static func _push(cmd: Array) -> void:
	if _now != null:
		_exec(_now, cmd)
	else:
		_q.append(cmd)


static func _cmp(a: Array, b: Array) -> bool:
	return float(a[0]) > float(b[0])   # far first


## Paints the queue far -> near. The sort is done NATIVELY: each command's depth (to 1/65536 of a unit) and its
## index are packed into one number, a PackedFloat64Array sorts those, and the index is unpacked. That is the same
## order the comparator gave (ties keep insertion order), with no script callback per comparison, which at
## ~300 commands a frame was well over a thousand calls into GDScript.
static func _paint_sorted(ci: CanvasItem) -> void:
	var n := _q.size()
	if n >= 4096:   # (never happens) fall back to the slow, exact way
		_q.sort_custom(CineRoom._cmp)
		for cmd in _q:
			_exec(ci, cmd)
		return
	var keys := PackedFloat64Array()
	keys.resize(n)
	for i in n:
		var c: Array = _q[i]
		keys[i] = floorf(float(c[0]) * 65536.0) * 4096.0 + float(4095 - i)
	keys.sort()
	for j in range(n - 1, -1, -1):
		_exec(ci, _q[4095 - int(fposmod(keys[j], 4096.0))])


static func _exec(ci: CanvasItem, cmd: Array) -> void:
	var kind: int = cmd[1]
	if kind == C_POLY:
		ci.draw_colored_polygon(cmd[2], cmd[3])
	elif kind == C_GRAD:
		ci.draw_polygon(cmd[2], cmd[3])
	elif kind == C_CAP:
		Gfx.capsule(ci, cmd[2], cmd[3], cmd[4], cmd[5], cmd[6])
	elif kind == C_CIRC:
		ci.draw_circle(cmd[2], cmd[3], cmd[4])
	elif kind == C_LINE:
		ci.draw_line(cmd[2], cmd[3], cmd[5], cmd[4], true)
	elif kind == C_GLOW:
		Gfx.glow_ellipse(ci, cmd[2], cmd[3], cmd[4], cmd[5])
	elif kind == C_SCREEN:
		_draw_screen(ci)


static func _poly(pts: PackedVector2Array, col: Color, depth: float) -> void:
	_push([depth, C_POLY, pts, col])


static func _cap(a: Vector3, b: Vector3, wa: float, wb: float, col: Color, bias: float = 0.0) -> void:
	var m := (a + b) * 0.5
	_push([_dp(m) + bias, C_CAP, _pr(a), _pr(b), wa * _sc(a), wb * _sc(b), col])


static func _ball(p: Vector3, r: float, col: Color, bias: float = 0.0) -> void:
	_push([_dp(p) + bias, C_CIRC, _pr(p), r * _sc(p), col])


static func _seg(a: Vector3, b: Vector3, w: float, col: Color, bias: float = 0.0) -> void:
	_push([_dp((a + b) * 0.5) + bias, C_LINE, _pr(a), _pr(b), maxf(w * _sc(a), 0.8), col])


static func _quad3(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, depth: float) -> void:
	_poly(PackedVector2Array([_pr(a), _pr(b), _pr(c), _pr(d)]), col, depth)


static func _glow3(p: Vector3, rx: float, ry: float, col: Color, bias: float = 0.0) -> void:
	var s := _sc(p)
	_push([_dp(p) + bias, C_GLOW, _pr(p), rx * s, ry * s, col])


## An axis-aligned (yaw-able) box. Back faces are culled; `glass` insets a lit pane into every side face.
static func _box(c: Vector3, s: Vector3, yaw: float, col: Color, glass: Color = Color(0.0, 0.0, 0.0, 0.0), bias: float = 0.0) -> void:
	var cy := cos(yaw)
	var sy := sin(yaw)
	var h := s * 0.5
	for i in 5:
		var n: Vector3 = FACE_N[i]
		var nw := Vector3(n.x * cy + n.z * sy, n.y, -n.x * sy + n.z * cy)
		var vs: Array = FACE_V[i]
		var p3: Array[Vector3] = []
		var mid := Vector3.ZERO
		for j in 4:
			var v: Vector3 = vs[j]
			var lx := v.x * h.x
			var lz := v.z * h.z
			var wv := c + Vector3(lx * cy + lz * sy, v.y * h.y, -lx * sy + lz * cy)
			p3.append(wv)
			mid += wv
		mid = mid * 0.25
		if nw.dot(_pos - mid) <= 0.0:
			continue
		var pts := PackedVector2Array([_pr(p3[0]), _pr(p3[1]), _pr(p3[2]), _pr(p3[3])])
		var d := _dp(mid) + bias
		_poly(pts, _shade(col, FACE_SHADE[i], nw, mid), d)
		if glass.a > 0.0 and i != 0:
			var q3: Array[Vector3] = []
			for j in 4:
				q3.append(mid + (p3[j] - mid) * 0.66)
			_poly(PackedVector2Array([_pr(q3[0]), _pr(q3[1]), _pr(q3[2]), _pr(q3[3])]), glass, d - 0.5)


## Convex hull (gift wrapping): the silhouette of a lofted body part.
static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	if n < 3:
		return pts
	var start := 0
	for i in n:
		if pts[i].x < pts[start].x or (pts[i].x == pts[start].x and pts[i].y < pts[start].y):
			start = i
	var cur := start
	for guard in n + 2:
		out.append(pts[cur])
		var nxt := (cur + 1) % n
		for i in n:
			if i == cur:
				continue
			var cr := (pts[nxt] - pts[cur]).cross(pts[i] - pts[cur])
			if cr < 0.0 or (cr == 0.0 and pts[cur].distance_squared_to(pts[i]) > pts[cur].distance_squared_to(pts[nxt])):
				nxt = i
		cur = nxt
		if cur == start:
			break
	return out


## A point on a flat face of the room: origin + ux * u + uy * v, projected.
static func _fp(o: Vector3, ux: Vector3, uy: Vector3, u: float, v: float) -> Vector2:
	return _pr(o + ux * u + uy * v)


# ======================================================================================== frame entry
static func draw(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	_t = t
	_vs = vs
	_vo = vo
	var lamp := CineArt._lamp(t)
	_dk = 0.84 * (1.0 - lamp)
	_mi = CineArt._mon_i(t)
	var cam := _camera(t)
	var sh: Vector2 = CineArt._shake(t)
	_set_camera(cam[0], cam[1], cam[2], Vector2(640.0, 360.0) + sh)
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))
	_q = []
	_now = ci
	_shell(ci, t)
	_furniture(t)
	_now = null
	var p := _pose(t)
	_props(t, lamp, p)
	_person(t, p)
	_paint_sorted(ci)
	_q = []
	_window_glass(ci, t)
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))


# ======================================================================================== the room shell
static func _shell(ci: CanvasItem, t: float) -> void:
	var xl := -1100.0
	var xr := 1100.0
	var zf := 1700.0
	var wall_h := 640.0
	# floor
	var fl_a := _lc(Color(0.13, 0.082, 0.065))
	var fl_b := _lc(Color(0.045, 0.028, 0.028))
	ci.draw_polygon(PackedVector2Array([_pr(Vector3(xl, 0.0, 0.0)), _pr(Vector3(xr, 0.0, 0.0)), _pr(Vector3(xr, 0.0, zf)), _pr(Vector3(xl, 0.0, zf))]), PackedColorArray([fl_a, fl_a, fl_b, fl_b]))
	# (floor and wall detail lines go out as one draw_multiline per group: ~490 separate draw_line calls before)
	var planks := PackedVector2Array()
	for i in range(-16, 17):
		var x := float(i) * 70.0
		planks.append(_pr(Vector3(x, 0.0, 0.0)))
		planks.append(_pr(Vector3(x, 0.0, zf)))
	ci.draw_multiline(planks, _lc(Color(0, 0, 0, 0.26)), 1.6)
	var seams := PackedVector2Array()
	for j in 24:
		var z := 40.0 + float(j) * 78.0
		var off := 35.0 if j % 2 == 0 else 0.0
		for i in range(-8, 9):
			var x2 := float(i) * 140.0 + off
			seams.append(_pr(Vector3(x2, 0.0, z)))
			seams.append(_pr(Vector3(x2, 0.0, z + 14.0)))
	ci.draw_multiline(seams, _lc(Color(0, 0, 0, 0.18)), 1.2)
	# rug under the chair: it grounds him in the over-the-shoulder shot
	var rg := _lc(Color(0.16, 0.07, 0.09))
	ci.draw_colored_polygon(PackedVector2Array([_pr(Vector3(-250.0, 0.4, 190.0)), _pr(Vector3(250.0, 0.4, 190.0)), _pr(Vector3(250.0, 0.4, 620.0)), _pr(Vector3(-250.0, 0.4, 620.0))]), rg)
	var rg2 := _lc(Color(0.30, 0.17, 0.14))
	ci.draw_polyline(Gfx.closed(PackedVector2Array([_pr(Vector3(-228.0, 0.6, 208.0)), _pr(Vector3(228.0, 0.6, 208.0)), _pr(Vector3(228.0, 0.6, 602.0)), _pr(Vector3(-228.0, 0.6, 602.0))])), rg2, 2.0, true)

	# back wall (boards + skirting)
	var wt := _lc(Color(0.21, 0.14, 0.11))
	var wb := _lc(Color(0.12, 0.078, 0.063))
	ci.draw_polygon(PackedVector2Array([_pr(Vector3(xl, wall_h, 0.0)), _pr(Vector3(xr, wall_h, 0.0)), _pr(Vector3(xr, 0.0, 0.0)), _pr(Vector3(xl, 0.0, 0.0))]), PackedColorArray([wt, wt, wb, wb]))
	var boards := PackedVector2Array()
	for i in range(-23, 24):
		var x3 := float(i) * 48.0
		boards.append(_pr(Vector3(x3, 0.0, 0.5)))
		boards.append(_pr(Vector3(x3, wall_h, 0.5)))
	ci.draw_multiline(boards, _lc(Color(0, 0, 0, 0.20)), 1.6)
	_box(Vector3(0.0, 8.0, 3.0), Vector3(2200.0, 16.0, 6.0), 0.0, Color(0.085, 0.057, 0.048))
	# right wall with a door (the far background of the opening shot)
	var rw := _lc(Color(0.15, 0.10, 0.08))
	var rw2 := _lc(Color(0.085, 0.056, 0.047))
	ci.draw_polygon(PackedVector2Array([_pr(Vector3(760.0, wall_h, 0.0)), _pr(Vector3(760.0, wall_h, zf)), _pr(Vector3(760.0, 0.0, zf)), _pr(Vector3(760.0, 0.0, 0.0))]), PackedColorArray([rw, rw2, rw2, rw]))
	var door := PackedVector2Array([_pr(Vector3(759.0, 0.0, 520.0)), _pr(Vector3(759.0, 0.0, 780.0)), _pr(Vector3(759.0, 440.0, 780.0)), _pr(Vector3(759.0, 440.0, 520.0))])
	ci.draw_colored_polygon(door, _lc(Color(0.10, 0.065, 0.05)))
	ci.draw_polyline(Gfx.closed(door), _lc(Color(0.20, 0.13, 0.10)), 3.0, true)
	ci.draw_circle(_pr(Vector3(758.0, 215.0, 556.0)), 4.0 * _sc(Vector3(758.0, 215.0, 556.0)), _lc(Color(0.55, 0.45, 0.25)))

	# the window (the glass itself is painted last, above the darkness: it carries moonlight)
	var wf := PackedVector2Array([_pr(Vector3(-602.0, 108.0, 1.0)), _pr(Vector3(-338.0, 108.0, 1.0)), _pr(Vector3(-338.0, 372.0, 1.0)), _pr(Vector3(-602.0, 372.0, 1.0))])
	ci.draw_colored_polygon(wf, _lc(Color(0.08, 0.05, 0.04)))
	_box(Vector3(-470.0, 104.0, 14.0), Vector3(290.0, 12.0, 28.0), 0.0, Color(0.10, 0.065, 0.05))   # sill
	# shelf with books
	_box(Vector3(290.0, 330.0, 13.0), Vector3(250.0, 8.0, 26.0), 0.0, Color(0.12, 0.08, 0.06))
	for i in 9:
		var hh := CineArt._h(float(i) * 2.9 + 3.0)
		var bk := Color(0.22 + 0.3 * CineArt._h(float(i)), 0.12 + 0.2 * CineArt._h(float(i) + 4.0), 0.12 + 0.2 * CineArt._h(float(i) + 8.0))
		var bh := 34.0 + hh * 18.0
		_box(Vector3(185.0 + float(i) * 24.0, 334.0 + bh * 0.5, 12.0), Vector3(20.0, bh, 20.0), 0.0, bk)
	# wall clock: the second hand stops dead when the power does
	var cc := Vector3(-60.0, 452.0, 2.0)
	var cs := _sc(cc)
	var c2 := _pr(cc)
	ci.draw_circle(c2, 34.0 * cs, _lc(Color(0.11, 0.075, 0.06)))
	ci.draw_circle(c2, 29.0 * cs, _lc(Color(0.80, 0.76, 0.68)))
	for i in 12:
		var ta := TAU * float(i) / 12.0
		ci.draw_line(_pr(cc + Vector3(sin(ta), cos(ta), 0.0) * 24.0), _pr(cc + Vector3(sin(ta), cos(ta), 0.0) * 28.0), _lc(Color(0.2, 0.15, 0.12)), 1.4, true)
	ci.draw_line(c2, _pr(cc + Vector3(sin(2.2), cos(2.2), 0.0) * 15.0), _lc(Color(0.1, 0.07, 0.06)), 3.0, true)
	ci.draw_line(c2, _pr(cc + Vector3(sin(5.1), cos(5.1), 0.0) * 22.0), _lc(Color(0.1, 0.07, 0.06)), 2.0, true)
	var sa := TAU * fposmod(minf(t, CineArt.T_CUT) * 1.0, 60.0) / 60.0
	ci.draw_line(c2, _pr(cc + Vector3(sin(sa), cos(sa), 0.0) * 24.0), _lc(Color(0.7, 0.1, 0.1)), 1.4, true)
	# pin board with notes
	var pb := PackedVector2Array([_pr(Vector3(-300.0, 360.0, 1.5)), _pr(Vector3(-190.0, 360.0, 1.5)), _pr(Vector3(-190.0, 444.0, 1.5)), _pr(Vector3(-300.0, 444.0, 1.5))])
	ci.draw_colored_polygon(pb, _lc(Color(0.28, 0.2, 0.12)))
	for i in 5:
		var nx := -290.0 + float(i % 3) * 32.0
		var ny := 368.0 + float(floori(float(i) / 3.0)) * 34.0
		ci.draw_colored_polygon(PackedVector2Array([_pr(Vector3(nx, ny, 2.0)), _pr(Vector3(nx + 24.0, ny, 2.0)), _pr(Vector3(nx + 24.0, ny + 26.0, 2.0)), _pr(Vector3(nx, ny + 26.0, 2.0))]), _lc(Color(0.9, 0.82 - 0.2 * float(i % 2), 0.4 + 0.3 * float(i % 2))))
	# the wall socket
	_box(SOCKET + Vector3(0.0, 0.0, 1.0), Vector3(34.0, 34.0, 3.0), 0.0, Color(0.72, 0.69, 0.62))


static func _e(x: float) -> float:
	return CineArt._e(x)


static func _io(x: float) -> float:
	return CineArt._io(x)


static func _a(c: Color, v: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * v)


# ======================================================================================== the desk (painted immediately)
static func _furniture(t: float) -> void:
	var wood := Color(0.30, 0.19, 0.12)
	var leg := Color(0.19, 0.12, 0.08)
	_box(Vector3(0.0, 92.0, 12.0), Vector3(560.0, 86.0, 8.0), 0.0, Color(0.17, 0.11, 0.07))   # modesty panel
	_box(Vector3(-286.0, 68.0, 16.0), Vector3(16.0, 136.0, 16.0), 0.0, leg)
	_box(Vector3(286.0, 68.0, 16.0), Vector3(16.0, 136.0, 16.0), 0.0, leg)
	_box(Vector3(0.0, 140.0, 92.5), Vector3(600.0, 8.0, 185.0), 0.0, wood)                   # the top
	_box(Vector3(-286.0, 68.0, 172.0), Vector3(16.0, 136.0, 16.0), 0.0, leg)
	_box(Vector3(286.0, 68.0, 172.0), Vector3(16.0, 136.0, 16.0), 0.0, leg)


# ======================================================================================== things on the desk (queued, depth-sorted)
static func _props(t: float, lamp: float, p: Dictionary) -> void:
	var dark := Color(0.06, 0.06, 0.08)
	# --- the monitor: the screen's cold haze first (behind everything), then base, neck, bezel, glass
	var mi := _mi
	var mdep := _dp(MON_C)
	var mcol := Color(0.35, 0.72, 1.0)
	var g := CineArt.glitch(t)
	if g > 0.0 and sin(t * 29.0) > 0.0:
		mcol = mcol.lerp(Color(1.0, 0.25, 0.55), 0.55 * g)
	_glow3(MON_C + Vector3(0.0, -10.0, 20.0), 520.0, 430.0, Color(mcol.r, mcol.g, mcol.b, 0.17 * mi), 60.0)
	var dsk := Vector3(0.0, DESK_Y + 1.0, 118.0)
	var ex := absf(_pr(dsk + Vector3(330.0, 0.0, 0.0)).x - _pr(dsk).x)
	var ey := absf(_pr(dsk + Vector3(0.0, 0.0, 120.0)).y - _pr(dsk).y)
	_push([_dp(dsk) + 40.0, C_GLOW, _pr(dsk), ex, maxf(ey, 6.0), Color(mcol.r, mcol.g, mcol.b, 0.30 * mi)])
	_box(Vector3(0.0, 148.0, 72.0), Vector3(96.0, 8.0, 64.0), 0.0, dark)
	_box(Vector3(0.0, 176.0, 62.0), Vector3(22.0, 56.0, 12.0), 0.0, Color(0.07, 0.07, 0.09))
	_box(Vector3(0.0, 245.0, 56.0), Vector3(259.0, 158.0, 16.0), 0.0, Color(0.045, 0.045, 0.06))
	if _pos.z > 66.0:
		_push([mdep - 1.0, C_SCREEN])
		var led := _pr(Vector3(0.0, 175.0, 64.8))
		_push([mdep - 2.0, C_CIRC, led, 1.8 * _sc(MON_C), Color(0.3, 0.6, 1.0)])

	# --- the PC tower: LEDs, vents and a spinning fan on its face, its cable to the wall
	var tc := Vector3(270.0, DESK_Y + 49.0, 80.0)
	_box(tc, Vector3(73.0, 98.0, 150.0), 0.0, Color(0.09, 0.09, 0.13))
	var fz := tc.z + 75.5
	var td := _dp(Vector3(tc.x, tc.y, fz)) - 1.0
	if _pos.z > fz:
		_glow3(Vector3(240.0, 232.0, fz), 20.0, 20.0, Color(0.3, 0.6, 1.0, 0.45), 0.5)
		_push([td, C_CIRC, _pr(Vector3(240.0, 232.0, fz)), 3.0 * _sc(tc), Color(0.3, 0.6, 1.0)])
		var rl := Color(0.55, 0.12, 0.1).lerp(Color(1.0, 0.25, 0.15), 0.5 + 0.5 * sin(t * 23.0) * sin(t * 7.0))
		_glow3(Vector3(240.0, 220.0, fz), 14.0, 14.0, Color(1.0, 0.2, 0.15, 0.3 + 0.25 * sin(t * 23.0) * sin(t * 7.0)), 0.5)
		_push([td, C_CIRC, _pr(Vector3(240.0, 220.0, fz)), 2.4 * _sc(tc), rl])
		for i in 5:
			_seg(Vector3(236.0, 200.0 - float(i) * 6.0, fz), Vector3(250.0, 200.0 - float(i) * 6.0, fz), 1.4, _lc(Color(0, 0, 0, 0.5)), -1.0)
		var fc := Vector3(274.0, 180.0, fz)
		_push([td, C_CIRC, _pr(fc), 24.0 * _sc(tc), _lc(Color(0.03, 0.03, 0.05))])
		for i in 5:
			var fa := t * 16.0 + TAU * float(i) / 5.0
			_poly(PackedVector2Array([_pr(fc), _pr(fc + Vector3(cos(fa), sin(fa), 0.0) * 20.0), _pr(fc + Vector3(cos(fa + 0.55), sin(fa + 0.55), 0.0) * 20.0)]), _lc(Color(0.15, 0.15, 0.2)), td - 0.5)
	for i in 6:   # the side vents face the opening shot
		_seg(Vector3(233.0, 160.0 + float(i) * 12.0, 30.0), Vector3(233.0, 160.0 + float(i) * 12.0, 120.0), 1.6, _lc(Color(0, 0, 0, 0.55)), -1.0)
	var pu := _e((t - CineArt.T_CUT - 0.05) / 0.4)
	var plug := Vector3(470.0, 40.0, 8.0).lerp(Vector3(430.0, 8.0, 44.0), pu)
	var cab: Array[Vector3] = [Vector3(300.0, 152.0, 4.0), Vector3(350.0, 118.0, 4.0), Vector3(420.0, 76.0, 5.0), plug + Vector3(-14.0, 14.0, 2.0), plug]
	for i in range(1, cab.size()):
		_seg(cab[i - 1], cab[i], 3.2, _lc(Color(0.06, 0.06, 0.08)), 6.0)
	_box(plug, Vector3(16.0, 12.0, 14.0), 0.0, Color(0.08, 0.08, 0.1))
	var spk := exp(-(t - CineArt.T_CUT) * 13.0) if t >= CineArt.T_CUT else 0.0
	if spk > 0.02:   # the spark at the socket (queued, so he covers it when he is in front of it)
		var so := SOCKET + Vector3(0.0, 0.0, 10.0)
		_glow3(so, 120.0, 120.0, Color(0.85, 0.93, 1.0, 0.85 * spk), -4.0)
		for i in 7:
			var ra := CineArt._h(float(i) * 2.2) * TAU
			var e := so + Vector3(cos(ra), sin(ra) - 0.4, 0.4) * (14.0 + 44.0 * (1.0 - spk))
			_seg(so, e, 1.8, Color(1.0, 0.95, 0.7, spk), -5.0)

	# --- desk lamp (dies at the cut)
	_box(Vector3(-250.0, 148.0, 52.0), Vector3(46.0, 8.0, 46.0), 0.0, Color(0.11, 0.11, 0.14))
	_cap(Vector3(-250.0, 152.0, 52.0), Vector3(-234.0, 222.0, 46.0), 6.0, 6.0, _lc(Color(0.13, 0.13, 0.16)))
	_cap(Vector3(-234.0, 222.0, 46.0), Vector3(-210.0, 266.0, 54.0), 6.0, 6.0, _lc(Color(0.13, 0.13, 0.16)))
	_box(Vector3(-196.0, 272.0, 62.0), Vector3(64.0, 26.0, 52.0), 0.25, Color(0.17, 0.16, 0.2))
	_ball(LAMP_BULB, 6.5, Color(0.25, 0.22, 0.2).lerp(Color(1.0, 0.92, 0.65), lamp), -3.0)

	# --- keyboard, mug, the lantern waiting for him
	_box(Vector3(0.0, 149.5, 152.0), Vector3(140.0, 11.0, 46.0), 0.0, Color(0.11, 0.11, 0.14))
	for r in 3:
		var kz := 138.0 + float(r) * 14.0
		_seg(Vector3(-62.0, 155.4, kz), Vector3(62.0, 155.4, kz), 8.0, _shade(Color(0.2, 0.2, 0.27), 1.0, Vector3.UP, Vector3(0.0, 155.0, kz)), -1.0)
	var mug: Vector3 = p["mug"]
	var mc := Color(0.7, 0.68, 0.64)
	_cap(mug + Vector3(0.0, -11.0, 0.0), mug + Vector3(0.0, 11.0, 0.0), 22.0, 22.0, _shade(mc, 1.0, Vector3(0.0, 0.0, 1.0), mug))
	var rim := PackedVector2Array()
	for i in 14:
		var ma := TAU * float(i) / 14.0
		rim.append(_pr(mug + Vector3(cos(ma) * 10.0, 11.0, sin(ma) * 10.0)))
	_poly(rim, _lc(Color(0.2, 0.12, 0.08)), _dp(mug) - 3.0)
	_seg(mug + Vector3(11.0, 6.0, 0.0), mug + Vector3(19.0, 0.0, 0.0), 3.0, _shade(mc, 0.9, Vector3(1.0, 0.0, 0.0), mug), 1.0)
	_seg(mug + Vector3(19.0, 0.0, 0.0), mug + Vector3(11.0, -7.0, 0.0), 3.0, _shade(mc, 0.9, Vector3(1.0, 0.0, 0.0), mug), 1.0)
	for i in 3:
		var sy0 := fposmod(t * 14.0 + float(i) * 6.0, 18.0)
		var sx0 := float(i - 1) * 6.0
		var sp0 := mug + Vector3(sx0, 14.0 + sy0, 0.0)
		_seg(sp0, sp0 + Vector3(sin(t * 2.0 + float(i)) * 3.0, 8.0, 0.0), 2.0, Color(0.9, 0.9, 1.0, 0.16 * (1.0 - sy0 / 18.0)), -4.0)
	if float(p["lan"]) < 0.5:
		_lantern(LANTERN_AT, 0.0, 0.0, 1.0)
	_chair(t)


static func _lantern(c: Vector3, ang: float, lit: float, a: float) -> void:
	var glass := Color(0.30, 0.20, 0.10, a).lerp(Color(CharacterDrawer.GLASS.r, CharacterDrawer.GLASS.g, CharacterDrawer.GLASS.b, a), lit)
	_box(c, Vector3(35.0, 46.0, 30.0), ang, Color(0.10, 0.08, 0.13, a), glass)
	_box(c + Vector3(0.0, 27.0, 0.0), Vector3(40.0, 8.0, 34.0), ang, Color(0.10, 0.08, 0.13, a))
	_box(c + Vector3(0.0, 37.0, 0.0), Vector3(22.0, 10.0, 18.0), ang, Color(0.10, 0.08, 0.13, a))


static func _chair(t: float) -> void:
	var u := _e((t - CineArt.T_CUT - 0.1) / 0.75)
	var o := Vector3(40.0 * u, 0.0, 268.0 + 150.0 * u)
	var yaw := 1.2 * u
	var cy := cos(yaw)
	var sy := sin(yaw)
	var dark := Color(0.10, 0.10, 0.12)
	_cap(_cw(o, cy, sy, Vector3(0.0, 16.0, 0.0)), _cw(o, cy, sy, Vector3(0.0, 84.0, 0.0)), 12.0, 12.0, _lc(dark))
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		var e := _cw(o, cy, sy, Vector3(cos(a) * 54.0, 12.0, sin(a) * 54.0))
		_cap(_cw(o, cy, sy, Vector3(0.0, 16.0, 0.0)), e, 9.0, 8.0, _lc(dark))
		_ball(e + Vector3(0.0, -5.0, 0.0), 6.0, _lc(Color(0.05, 0.05, 0.06)))
	_box(_cw(o, cy, sy, Vector3(0.0, 93.0, 0.0)), Vector3(98.0, 14.0, 98.0), yaw, Color(0.14, 0.11, 0.2))
	_box(_cw(o, cy, sy, Vector3(0.0, 150.0, 52.0)), Vector3(88.0, 82.0, 12.0), yaw, Color(0.16, 0.13, 0.23))


static func _cw(o: Vector3, cy: float, sy: float, l: Vector3) -> Vector3:
	return o + Vector3(l.x * cy + l.z * sy, l.y, -l.x * sy + l.z * cy)


# ======================================================================================== the runner: pose
## Two-bone IK in 3D. Returns [mid joint, reached end point]; `pole` says which way the joint bends.
static func _ik3(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := target - a
	var full := d.length()
	var dir := d / maxf(full, 0.001)
	var dist := clampf(full, 0.01, l1 + l2 - 0.01)
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var pv := pole - dir * pole.dot(dir)
	if pv.length() < 0.001:
		pv = Vector3.UP - dir * Vector3.UP.dot(dir)
	pv = pv.normalized()
	return [a + dir * x + pv * h, a + dir * dist]


static func _def(pt: Vector3, hip: Vector3, c: Vector3, d: Vector3, sx: float, ss: float) -> Vector3:
	var o := pt - hip
	o = o + d * (d.dot(o)) * (sx - 1.0)   # stretched along the pull
	return c + (hip + o - c) * ss          # and shrinking into the screen


## Joint-by-joint pose of the runner at time t, in world coordinates. Phases: typing (with a sip of coffee),
## the jolt at the cut, standing and snatching his lantern, backing away, freezing as the PC wakes,
## crouching with his hand to his head, then being dragged into the screen and swallowed.
static func _pose(t: float) -> Dictionary:
	var tc := CineArt.T_CUT
	var s1 := _e((t - tc - 0.1) / 0.45)
	var s2 := _e((t - 21.5) / 1.0)
	var lean_in := _e((t - 21.6) / 0.5)
	var s3 := _e((t - 22.3) / 1.7)
	var walk := 1.0 - _e((t - 23.6) / 0.4)
	var mv := walk * _e((t - 22.2) / 0.3)
	var tre := 0.0
	if t > tc:
		tre = 0.25 + 0.6 * _e((t - CineArt.T_WAKE) / 1.0)
	var gc := _e((t - CineArt.T_GLITCH) / 0.5)
	var wide := lerpf(1.0, 1.75, s1)
	var pp := _e((t - CineArt.T_PULL) / 3.6)
	var q := pow(pp, 1.8)

	# ---- hip: where it is, how high, how the torso leans
	var stand_c := Vector2(-48.0, 262.0)
	var back_c := Vector2(36.0, 392.0)
	var xz := Vector2(0.0, SEAT.z + 32.0 * s1).lerp(stand_c, lean_in).lerp(back_c, s3)
	var hy := lerpf(SEAT.y - 6.0 * s1, 57.0 * K, s2) - 16.0 * gc
	var ang := lerpf(lerpf(0.20, -0.5, s1), -0.12, s2)
	ang += 0.50 * _e((t - 21.7) / 0.4) * (1.0 - _e((t - 22.35) / 0.45))   # leans in to snatch the lantern
	ang += 0.25 * gc
	var sway := 0.0
	if t < tc + 0.1:
		hy += sin(t * 1.1) * 1.2
		ang += 0.012 * sin(t * 0.9)
		sway = sin(t * 0.5)
	var hip := Vector3(xz.x, hy, xz.y)
	var scr := MON_C + Vector3(0.0, 0.0, 10.0)
	if pp > 0.0:
		hip = Vector3(lerpf(xz.x, scr.x, q), lerpf(hy, scr.y, q * q), lerpf(xz.y, scr.z, q))
		ang = lerpf(ang, 1.45, pp)
		wide = 2.0
		tre = 0.0
	var by := atan2(-hip.x, hip.z - 64.0) + 0.35 * s1 * (1.0 - s2)
	var bf := Vector3(sin(by), 0.0, -cos(by))
	var br := Vector3(cos(by), 0.0, sin(by))
	var td := Vector3.UP * cos(ang) + bf * sin(ang)
	var sh := hip + td * (36.0 * K)
	var sl := sh - br * 46.0
	var sr := sh + br * 46.0
	var jit := Vector3(sin(t * 31.0), cos(t * 27.0), sin(t * 23.0)) * 1.8 * tre
	var head := sh + td * (16.0 * K) + bf * 4.0 + jit + br * (sway * 0.8)

	# ---- where he looks: reading the code -> the dead lamp -> the socket -> his lantern -> the PC
	var look := Vector3(-70.0 + 140.0 * (0.5 + 0.5 * sin(t * 0.9)), 245.0 + 34.0 * sin(t * 1.3), 64.0)
	if t >= tc:
		look = MON_C
		var a1 := _e((t - 21.05) / 0.2) * (1.0 - _e((t - 21.4) / 0.2))
		var a2 := _e((t - 21.4) / 0.2) * (1.0 - _e((t - 21.8) / 0.2))
		var a3 := _e((t - 21.8) / 0.2) * (1.0 - _e((t - 22.3) / 0.25))
		look = look.lerp(LAMP_BULB, a1).lerp(SOCKET + Vector3(0.0, 40.0, 40.0), a2).lerp(LANTERN_AT, a3)

	# ---- the sip: hand to the mug, mug to the mouth, and back
	var p1 := _e((t - 15.4) / 0.6)
	var p2 := _e((t - 16.1) / 0.8)
	var p3 := _e((t - 17.4) / 0.8)
	var p4 := _e((t - 18.3) / 0.6)
	look += Vector3(0.0, 40.0, 0.0) * p2 * (1.0 - p3)
	var hf := (look - head).normalized()

	# ---- hands
	var kl := Vector3(-38.0 + 3.0 * sin(t * 9.0), 161.0 + 2.5 * absf(sin(t * 9.5)), 150.0 + 3.0 * sin(t * 5.0))
	var kr := Vector3(34.0 + 3.0 * sin(t * 7.7 + 1.0), 161.0 + 2.5 * absf(sin(t * 8.3)), 152.0 + 3.0 * sin(t * 4.2))
	var grip_pt := MUG_AT + Vector3(14.0, 3.0, 0.0)
	var mouth := head + bf * 36.0 + Vector3(0.0, -14.0, 0.0)
	var hr := kr.lerp(grip_pt, p1).lerp(mouth, p2).lerp(grip_pt, p3).lerp(kr, p4)
	var hl := kl
	var gripped := _e((t - 16.0) / 0.2) * (1.0 - _e((t - 18.3) / 0.2))
	var mug := MUG_AT.lerp(hr - Vector3(14.0, 3.0, 0.0), gripped)
	# after the cut: both hands fly up, the left snatches the lantern and holds it low, the right goes to his chest, then his head
	var up_l := sl + br * -14.0 + Vector3(0.0, 60.0, 0.0) + bf * 45.0
	var up_r := sr + br * 14.0 + Vector3(0.0, 70.0, 0.0) + bf * 20.0
	hl = hl.lerp(up_l, s1)
	hr = hr.lerp(up_r, s1)
	hl = hl.lerp(LANTERN_AT + Vector3(0.0, 20.0, 0.0), _e((t - 21.85) / 0.45))
	hl = hl.lerp(sl + br * -8.0 + Vector3(0.0, -78.0, 0.0) + bf * 30.0, _e((t - 22.3) / 0.6))
	hr = hr.lerp(sr + br * -34.0 + Vector3(0.0, -30.0, 0.0) + bf * 36.0, _e((t - CineArt.T_WAKE) / 0.5))
	hr = hr.lerp(head + br * 26.0 + Vector3(0.0, -6.0, 0.0) + bf * 6.0, gc)
	hl += jit * 0.6
	hr += jit * 0.8
	if pp > 0.0:
		hl = hl.lerp(sl + bf * 66.0 + Vector3(0.0, -10.0, 0.0), pp)
		hr = hr.lerp(sr + bf * 60.0 + Vector3(0.0, 16.0, 0.0) + Vector3(sin(t * 40.0), cos(t * 33.0), 0.0) * 3.0, pp)
	var arm_l := _ik3(sl, hl, 20.0 * K, 20.0 * K, br * -1.0 + Vector3(0.0, -0.3, 0.7))
	var arm_r := _ik3(sr, hr, 20.0 * K, 20.0 * K, br + Vector3(0.0, -0.3, 0.7))
	var el: Vector3 = arm_l[0]
	var er: Vector3 = arm_r[0]
	hl = arm_l[1]
	hr = arm_r[1]

	# ---- feet: seated -> standing -> a stumbling walk backwards
	var wd2 := (back_c - stand_c).normalized()
	var wd := Vector3(wd2.x, 0.0, wd2.y)
	var ph := (t - 22.2) * 4.6
	var st_l := Vector3(hip.x, 14.0, hip.z) + br * -20.0 + wd * (sin(ph) * 14.0 * mv) + Vector3(0.0, maxf(0.0, sin(ph)) * 20.0 * mv, 0.0)
	var st_r := Vector3(hip.x, 14.0, hip.z) + br * 20.0 + wd * (sin(ph + PI) * 14.0 * mv) + Vector3(0.0, maxf(0.0, sin(ph + PI)) * 20.0 * mv, 0.0)
	var al := Vector3(-24.0, 14.0, 196.0).lerp(st_l, s2)
	var ar := Vector3(24.0, 14.0, 196.0).lerp(st_r, s2)
	if pp > 0.0:
		al = al.lerp(hip + bf * -80.0 + Vector3(0.0, -34.0, 0.0), pp)
		ar = ar.lerp(hip + bf * -98.0 + Vector3(0.0, -12.0, 0.0) + br * 10.0, pp)
	var hj_l := hip - br * 16.0
	var hj_r := hip + br * 16.0
	var leg_l := _ik3(hj_l, al, 32.0 * K, 32.0 * K, bf + Vector3(0.0, 0.35, 0.0))
	var leg_r := _ik3(hj_r, ar, 32.0 * K, 32.0 * K, bf + Vector3(0.0, 0.35, 0.0))
	var kl3: Vector3 = leg_l[0]
	var kr3: Vector3 = leg_r[0]
	al = leg_l[1]
	ar = leg_r[1]

	# ---- the lantern in his left hand, on its chain
	var lan := 1.0 if t >= 21.95 else 0.0
	var lit := _e((t - 22.0) / 0.6)
	var la := 0.3 * sin(t * 4.0) * (0.4 + tre)
	var lpos := hl + bf * (sin(la) * 17.0 * K) + Vector3(0.0, -cos(la) * 17.0 * K, 0.0)

	# ---- dragged into the screen: stretched toward it, then shrinking into the glass
	var ss := 1.0
	var vis := 1.0
	if pp > 0.0:
		var sx := 1.0 + 0.9 * q
		ss = 1.0 - 0.92 * _e((t - CineArt.T_SUCK) / 0.9)
		vis = 1.0 - _e((t - CineArt.T_SUCK - 0.6) / 0.4)
		var dv := (scr - hip).normalized()
		var js: Array[Vector3] = [sh, sl, sr, head, el, er, hl, hr, kl3, kr3, al, ar, hj_l, hj_r, lpos, hip]
		for i in js.size():
			js[i] = _def(js[i], hip, scr, dv, sx, ss)
		sh = js[0]
		sl = js[1]
		sr = js[2]
		head = js[3]
		el = js[4]
		er = js[5]
		hl = js[6]
		hr = js[7]
		kl3 = js[8]
		kr3 = js[9]
		al = js[10]
		ar = js[11]
		hj_l = js[12]
		hj_r = js[13]
		lpos = js[14]
		hip = js[15]
	return {"hip": hip, "sh": sh, "sl": sl, "sr": sr, "head": head, "hf": hf, "bf": bf, "br": br, "td": td, "el": el, "er": er, "hl": hl, "hr": hr,
		"kl": kl3, "kr": kr3, "al": al, "ar": ar, "hjl": hj_l, "hjr": hj_r, "lan": lan, "lit": lit, "la": la, "lpos": lpos, "wide": wide, "vis": vis, "ss": ss,
		"mug": mug, "pull": pp, "tre": tre}


# ======================================================================================== the runner: drawing
static func _limb(a: Vector3, b: Vector3, c: Vector3, w1: float, w2: float, col: Color, ss: float) -> void:
	_cap(a, b, w1 * K * ss, w1 * 0.9 * K * ss, col)
	_cap(b, c, w1 * 0.9 * K * ss, w2 * K * ss, col)


static func _person(t: float, p: Dictionary) -> void:
	var vis: float = p["vis"]
	if vis <= 0.01:
		return
	var ss: float = p["ss"]
	var wide: float = p["wide"]
	var hip: Vector3 = p["hip"]
	var sh: Vector3 = p["sh"]
	var sl: Vector3 = p["sl"]
	var sr: Vector3 = p["sr"]
	var head: Vector3 = p["head"]
	var hf: Vector3 = p["hf"]
	var bf: Vector3 = p["bf"]
	var br: Vector3 = p["br"]
	var td: Vector3 = p["td"]
	var el: Vector3 = p["el"]
	var er: Vector3 = p["er"]
	var hl: Vector3 = p["hl"]
	var hr: Vector3 = p["hr"]
	var kl: Vector3 = p["kl"]
	var kr: Vector3 = p["kr"]
	var al: Vector3 = p["al"]
	var ar: Vector3 = p["ar"]
	var hjl: Vector3 = p["hjl"]
	var hjr: Vector3 = p["hjr"]
	var coat := _lc(_a(CharacterDrawer.COAT, vis))
	var coat_d := _lc(_a(CharacterDrawer.COAT_D, vis))
	var coat_far := _lc(_a(CharacterDrawer.COAT_FAR, vis))
	var trim := _lc(_a(CharacterDrawer.TRIM, vis))
	var boot := _lc(_a(CharacterDrawer.BOOT, vis))
	var skin := _lc(_a(Color(0.82, 0.76, 0.84), vis))
	var rim_c := _a(CharacterDrawer.RIM, vis * (1.0 - _dk * 0.5))

	# ---- legs (the one farther from the camera is in shadow)
	var far_l := _dp(al) > _dp(ar)
	for side in 2:
		var is_l := side == 0
		var hj := hjl if is_l else hjr
		var kn := kl if is_l else kr
		var an := al if is_l else ar
		var lc := coat_far if (is_l == far_l) else coat
		_limb(hj, kn, an, 14.0, 10.0, lc, ss)
		_cap(an + Vector3(0.0, -3.0, 0.0) - bf * (5.0 * K * ss), an + bf * (12.0 * K * ss) + Vector3(0.0, -3.0, 0.0), 11.0 * K * ss, 9.0 * K * ss, boot)

	# ---- far arm
	var far_arm_l := _dp(hl) > _dp(hr)
	if far_arm_l:
		_limb(sl, el, hl, 9.0, 7.0, coat_far, ss)
		_ball(hl, 5.0 * K * ss, _lc(_a(Color(0.62, 0.57, 0.66), vis)), -30.0)
	else:
		_limb(sr, er, hr, 9.0, 7.0, coat_far, ss)
		_ball(hr, 5.0 * K * ss, _lc(_a(Color(0.62, 0.57, 0.66), vis)), -30.0)

	# ---- hood tail + the ash scarf hanging down his back
	var tl := head - bf * (30.0 * ss) + Vector3(0.0, -24.0 * ss, 0.0)
	var prev := tl
	for i in 3:
		var nx := prev - bf * (4.0 * K * ss) + Vector3(0.0, -7.0 * K * ss, 0.0)
		_cap(prev, nx, (10.0 - float(i) * 2.6) * K * ss, (10.0 - float(i + 1) * 2.6) * K * ss, coat_d, 2.0)
		prev = nx
	var n0 := sh + td * (13.0 * ss)
	var n1 := n0 - bf * (22.0 * ss) + Vector3(0.0, -20.0 * ss, 0.0)
	var n2 := n1 - bf * (8.0 * ss) + Vector3(0.0, -30.0 * ss, 0.0)
	var ash := _lc(_a(Color(0.50, 0.46, 0.58), vis))
	_cap(n0, n1, 10.0 * K * ss, 8.0 * K * ss, ash, 3.0)
	_cap(n1, n2, 8.0 * K * ss, 5.0 * K * ss, ash, 3.0)

	# ---- torso + coat: the hull of two lofted rings (shoulders / hem), with the capsule on top for roundness
	var dpv := (bf - td * bf.dot(td)).normalized()
	var ring := PackedVector2Array()
	var ctr_h := hip + Vector3(0.0, -13.0 * ss, 0.0)
	for i in 12:
		var a := TAU * float(i) / 12.0
		ring.append(_pr(sh + br * (cos(a) * 50.0 * ss) + dpv * (sin(a) * 29.0 * ss)))
		ring.append(_pr(ctr_h + br * (cos(a) * 47.0 * ss) + dpv * (sin(a) * 36.0 * ss)))
	var hull := _hull(ring)
	var mid := (sh + hip) * 0.5
	var td_depth := _dp(mid)
	var ymin := 1.0e9
	var ymax := -1.0e9
	for v in hull:
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
	var cols := PackedColorArray()
	for v in hull:
		cols.append(coat.lerp(coat_d, clampf((v.y - ymin) / maxf(ymax - ymin, 1.0), 0.0, 1.0)))
	var roff := Vector2(1.3, -0.9) * K * _sc(mid)
	var rim_h := PackedVector2Array()
	for v in hull:
		rim_h.append(v + roff)
	_poly(rim_h, rim_c, td_depth + 0.6)
	_push([td_depth, C_GRAD, hull, cols])
	_cap(hip + td * (8.0 * K * ss), sh, 22.0 * K * ss, 25.0 * K * ss, coat, -0.5)
	_seg(hip - br * (28.0 * ss), hip + br * (30.0 * ss), 4.0 * K * ss, trim, -1.0)

	# ---- near arm
	if far_arm_l:
		_limb(sr, er, hr, 10.0, 8.0, coat, ss)
		_ball(hr, 5.0 * K * ss, skin, -30.0)
	else:
		_limb(sl, el, hl, 10.0, 8.0, coat, ss)
		_ball(hl, 5.0 * K * ss, skin, -30.0)

	# ---- the lantern on its chain, in his left hand
	if float(p["lan"]) > 0.5:
		var lpos: Vector3 = p["lpos"]
		_seg(hl, lpos + Vector3(0.0, 20.0 * ss, 0.0), 1.6, boot, -2.0)
		_lantern_in_hand(lpos, float(p["la"]) * 0.5, float(p["lit"]), vis, ss)

	# ---- head: shadowed hood, a face opening, wide eyes. Fear = wider, paler eyes with pinpoint pupils.
	var cs := _sc(head)
	var hd := _dp(head) - 8.0
	var c2 := _pr(head)
	var rp := 15.5 * K * ss * cs
	_push([hd + 0.6, C_CIRC, c2 + Vector2(1.3, -0.9) * K * ss * cs, rp * 1.04, rim_c])
	_push([hd, C_CIRC, c2, rp, coat])
	var to_cam := (_pos - head).normalized()
	var low := PackedVector2Array()
	for j in 9:
		var la2 := PI * float(j) / 8.0
		low.append(c2 + Vector2(cos(la2), sin(la2)) * rp)
	_poly(low, _a(coat_d, 0.55), hd - 0.2)   # the hood's underside is in shadow
	if hf.dot(to_cam) > -0.30:
		var sd := hf.cross(Vector3.UP).normalized()
		var ud := sd.cross(hf)
		var rad := 15.5 * K * ss
		var patch := PackedVector2Array()
		for j in 14:
			var phi := TAU * float(j) / 14.0
			var dirv := hf * cos(0.78) + (sd * cos(phi) * 1.0 + ud * sin(phi) * 0.92) * sin(0.78)
			var pt := head + dirv.normalized() * rad
			var p2 := _pr(pt)
			if dirv.normalized().dot(_pos - pt) <= 0.0:
				var off := p2 - c2
				p2 = c2 + off.normalized() * rp
			patch.append(p2)
		_poly(_hull(patch), _lc(_a(Color(0.035, 0.025, 0.06), vis)), hd - 1.0)   # hull: wrapping past the silhouette must never self-intersect
		for e in 2:
			var sgn := -1.0 if e == 0 else 1.0
			var ed := (hf * cos(0.42) + sd * (sgn * sin(0.42)) + ud * 0.10).normalized()
			var ep := head + ed * rad
			if ed.dot(_pos - ep) > 0.12:
				var e2 := _pr(ep)
				_push([hd - 2.0, C_CIRC, e2, 2.4 * K * ss * wide * cs, _a(Color(0.96, 0.93, 1.0), vis)])
				_push([hd - 3.0, C_CIRC, e2, 1.0 * K * ss * cs / sqrt(wide), _a(Color(0.03, 0.02, 0.06), vis)])


static func _lantern_in_hand(c: Vector3, ang: float, lit: float, vis: float, ss: float) -> void:
	var glass := Color(0.30, 0.20, 0.10, vis).lerp(Color(CharacterDrawer.GLASS.r, CharacterDrawer.GLASS.g, CharacterDrawer.GLASS.b, vis), lit)
	var s := ss
	_box(c, Vector3(35.0, 46.0, 30.0) * s, ang, Color(0.10, 0.08, 0.13, vis), glass)
	_box(c + Vector3(0.0, 27.0 * s, 0.0), Vector3(40.0, 8.0, 34.0) * s, ang, Color(0.10, 0.08, 0.13, vis))
	_box(c + Vector3(0.0, 37.0 * s, 0.0), Vector3(22.0, 10.0, 18.0) * s, ang, Color(0.10, 0.08, 0.13, vis))


# ======================================================================================== window glass + the screen
static func _wp(u: float, v: float) -> Vector2:
	return _pr(Vector3(lerpf(-590.0, -350.0, u), lerpf(122.0, 358.0, v), 2.0))


static func _window_glass(ci: CanvasItem, t: float) -> void:
	var sky_t := Color(0.04, 0.07, 0.19)
	var sky_b := Color(0.11, 0.15, 0.30)
	ci.draw_polygon(PackedVector2Array([_wp(0.0, 1.0), _wp(1.0, 1.0), _wp(1.0, 0.0), _wp(0.0, 0.0)]), PackedColorArray([sky_t, sky_t, sky_b, sky_b]))
	var ws := _sc(Vector3(-470.0, 240.0, 2.0))
	for i in 14:
		ci.draw_circle(_wp(0.04 + CineArt._h(float(i) * 1.3) * 0.92, 0.38 + CineArt._h(float(i) * 2.9) * 0.58), 1.1 * ws + 0.4, Color(0.8, 0.88, 1.0, 0.5 + 0.4 * sin(t + float(i))))
	var mp := _wp(0.70, 0.80)
	Gfx.glow(ci, mp, 70.0 * ws, Color(0.5, 0.65, 1.0, 0.35))
	ci.draw_circle(mp, 15.0 * ws, Color(0.86, 0.9, 1.0))
	for i in 6:
		var u := 0.04 + float(i) * 0.17
		var th := 0.30 + CineArt._h(float(i) + 12.0) * 0.20
		ci.draw_colored_polygon(PackedVector2Array([_wp(u, th), _wp(u + 0.10, 0.0), _wp(u - 0.10, 0.0)]), Color(0.02, 0.03, 0.07))
	var fr := Color(0.08, 0.05, 0.04)
	ci.draw_line(_wp(0.5, 0.0), _wp(0.5, 1.0), fr, 7.0 * ws, true)
	ci.draw_line(_wp(0.0, 0.46), _wp(1.0, 0.46), fr, 7.0 * ws, true)
	ci.draw_polyline(Gfx.closed(PackedVector2Array([_wp(0.0, 1.0), _wp(1.0, 1.0), _wp(1.0, 0.0), _wp(0.0, 0.0)])), fr, 6.0 * ws, true)


## The existing screen art (code editor / terminal / title / tunnel), mapped onto the projected glass.
## It is affine-mapped from three corners; the glass is small and the camera far enough that the error is a few pixels,
## and during the final dive the camera is square-on, where the mapping is exact.
static func _draw_screen(ci: CanvasItem) -> void:
	var z := 64.6
	var tl := _pr(Vector3(-GLASS_W * 0.5, MON_C.y + GLASS_H * 0.5, z))
	var tr := _pr(Vector3(GLASS_W * 0.5, MON_C.y + GLASS_H * 0.5, z))
	var bl := _pr(Vector3(-GLASS_W * 0.5, MON_C.y - GLASS_H * 0.5, z))
	var br := _pr(Vector3(GLASS_W * 0.5, MON_C.y - GLASS_H * 0.5, z))
	ci.draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), Color(0.02, 0.03, 0.05))
	var ax := (tr - tl) / GLASS_W
	var ay := (bl - tl) / GLASS_H
	var o := tl - ax * CineArt.MONITOR.position.x - ay * CineArt.MONITOR.position.y
	ci.draw_set_transform_matrix(Transform2D(Vector2(_vs, 0.0), Vector2(0.0, _vs), _vo) * Transform2D(ax, ay, o))
	CineArt.screen(ci, _t)
	ci.draw_set_transform(_vo, 0.0, Vector2(_vs, _vs))


# ======================================================================================== additive light pass
static func _gl(ci: CanvasItem, p: Vector3, radius: float, col: Color) -> void:
	Gfx.glow(ci, _pr(p), radius * _sc(p), col)


static func draw_light(ci: CanvasItem, t: float, vs: float, vo: Vector2) -> void:
	_t = t
	_vs = vs
	_vo = vo
	var lamp := CineArt._lamp(t)
	var cam := _camera(t)
	var sh: Vector2 = CineArt._shake(t)
	_set_camera(cam[0], cam[1], cam[2], Vector2(640.0, 360.0) + sh)
	ci.draw_set_transform(vo, 0.0, Vector2(vs, vs))
	var p := _pose(t)
	var nl := 1.0 - lamp
	# the lamp
	if lamp > 0.0:
		_gl(ci, LAMP_BULB, 470.0, Color(1.0, 0.72, 0.36, 0.22 * lamp))
		_gl(ci, Vector3(-60.0, 300.0, 140.0), 760.0, Color(1.0, 0.7, 0.4, 0.08 * lamp))
		var dp := Vector3(-40.0, DESK_Y + 1.0, 130.0)
		Gfx.glow_ellipse(ci, _pr(dp), absf(_pr(dp + Vector3(280.0, 0.0, 0.0)).x - _pr(dp).x), maxf(absf(_pr(dp + Vector3(0.0, 0.0, 110.0)).y - _pr(dp).y), 6.0), Color(1.0, 0.7, 0.35, 0.18 * lamp))
	# moonlight through the window: cold ambient fill + a shaft across the floor
	_gl(ci, Vector3(-470.0, 240.0, 40.0), 330.0, Color(0.3, 0.45, 0.9, 0.08 + 0.09 * nl))
	_gl(ci, Vector3(-200.0, 260.0, 300.0), 700.0, Color(0.30, 0.42, 0.9, 0.07 * nl))
	var shaft := PackedVector2Array([_pr(Vector3(-590.0, 0.5, 0.0)), _pr(Vector3(-350.0, 0.5, 0.0)), _pr(Vector3(-40.0, 0.5, 520.0)), _pr(Vector3(-440.0, 0.5, 520.0))])
	ci.draw_colored_polygon(shaft, Color(0.5, 0.65, 1.0, 0.040 + 0.035 * nl))
	# the monitor: cool light that keeps pouring out of a machine with no power
	var mi := _mi
	var g := CineArt.glitch(t)
	var mcol := Color(0.35, 0.72, 1.0).lerp(Color(1.0, 0.25, 0.55), 0.55 * g * (1.0 if sin(t * 29.0) > 0.0 else 0.0))
	_gl(ci, MON_C + Vector3(0.0, 0.0, 30.0), 560.0, Color(mcol.r, mcol.g, mcol.b, 0.20 * mi))
	# his lantern lights up in his hand
	var vis: float = p["vis"]
	var lit: float = p["lit"]
	if lit > 0.0 and vis > 0.05:
		var lp: Vector3 = p["lpos"]
		_gl(ci, lp, 330.0 * float(p["ss"]), Color(1.0, 0.72, 0.3, 0.50 * lit * vis))
	# sparks of data streaming from him into the screen
	var pp: float = p["pull"]
	if pp > 0.0 and t < CineArt.T_SUCK + 1.6:
		var hp: Vector3 = p["hip"]
		_gl(ci, hp, 230.0 * float(p["ss"]), Color(0.4, 0.85, 1.0, 0.30 * pp * vis))
		for i in 26:
			var f := fposmod(CineArt._h(float(i) * 1.7) + t * (0.8 + CineArt._h(float(i)) * 0.8), 1.0)
			var org := hp + Vector3((CineArt._h(float(i) * 3.3) - 0.5) * 120.0, (CineArt._h(float(i) * 5.1) - 0.5) * 140.0, (CineArt._h(float(i) * 8.3) - 0.5) * 80.0)
			var qv := org.lerp(MON_C + Vector3(0.0, 0.0, 12.0), f)
			var sz := (3.0 + 6.0 * CineArt._h(float(i) * 7.0)) * _sc(qv) * 0.9
			var q2 := _pr(qv)
			ci.draw_rect(Rect2(q2.x - sz * 0.5, q2.y - sz * 0.5, sz, sz), Color(0.5, 0.95, 1.0, 0.8 * pp * (1.0 - f)))
	# the screen is overwhelmingly bright by the time we are inside it
	var zz := _e((t - CineArt.T_ZOOM - 2.0) / 3.0)
	if zz > 0.0:
		_gl(ci, MON_C + Vector3(0.0, 0.0, 20.0), 700.0, Color(0.6, 0.9, 1.0, 0.5 * zz))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
