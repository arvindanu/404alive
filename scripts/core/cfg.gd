class_name Cfg
extends RefCounted
## Layout + shared constants.
##
## The gameplay is authored in a 1280x720 "design" space. The project uses stretch mode
## canvas_items + aspect "expand", so the real viewport is >= 1280x720 and ALWAYS fills the
## screen (no black bars). Gameplay stays in a centred 16:9 design rect; backgrounds, the sky
## and the HUD extend to the real screen edges. `ox`/`oy` map design space -> viewport space.

const VIEW_W := 1280.0
const VIEW_H := 720.0
const GROUND_Y := 600.0
const PLAYER_X := 400.0
const PX_PER_M := 100.0   ## 1 "metre" of score/progression
## The frame rate the game aims for (see GameState.target_fps: it follows the display, never exceeds this on
## displays that divide into it cleanly, and is lower on slower panels). The simulation is delta-timed, so it
## plays identically at any rate.
const TARGET_FPS := 90

## Action button colours: JUMP is red, SLIDE is blue. DASH moved to amber and LOOK to pale violet so
## that no two buttons are ever the same hue (DASH used to be red, which would now read as JUMP).
const COL_JUMP := Color(1.0, 0.24, 0.27)
const COL_SLIDE := Color(0.32, 0.58, 1.0)
const COL_DASH := Color(1.0, 0.72, 0.26)
const COL_LOOK := Color(0.80, 0.74, 1.0)
const COL_BONE := Color(0.93, 0.90, 0.87)
const COL_CRIMSON := Color(0.86, 0.12, 0.22)
const COL_INK := Color(0.03, 0.02, 0.06)

const HUD_MARGIN := 34.0
## Distance from the real screen edge to the OUTER edge of the big thumb buttons - the same on both
## sides. Deliberately NOT affected by notch insets: a cut-out sits mid-edge, not under the thumbs.
const CONTROL_EDGE := 34.0

static var view_w := 1280.0   ## real viewport size in canvas units
static var view_h := 720.0
static var ox := 0.0          ## design -> viewport offset (design rect is centred horizontally,
static var oy := 0.0          ##   bottom-aligned vertically)
static var safe := Vector4.ZERO   ## notch / cutout insets: left, top, right, bottom (canvas units)
static var quality := 1.0     ## 1.0 = full, 0.5 = "Low FX"


static func update_view(vp: Viewport) -> void:
	var r := vp.get_visible_rect().size
	view_w = maxf(r.x, VIEW_W)
	view_h = maxf(r.y, VIEW_H)
	ox = (view_w - VIEW_W) * 0.5
	oy = view_h - VIEW_H
	safe = Vector4.ZERO
	if OS.has_feature("android"):
		var sa := DisplayServer.get_display_safe_area()
		var ws := DisplayServer.window_get_size()
		if ws.x > 0 and sa.size.x > 0:
			var k := view_w / float(ws.x)
			safe = Vector4(
				clampf(float(sa.position.x) * k, 0.0, 160.0),
				clampf(float(sa.position.y) * k, 0.0, 120.0),
				clampf(float(ws.x - sa.end.x) * k, 0.0, 160.0),
				clampf(float(ws.y - sa.end.y) * k, 0.0, 120.0))


## Usable HUD rectangle (inside notches + margin), in viewport units.
static func hud_rect() -> Rect2:
	var l := safe.x + HUD_MARGIN
	var t := safe.y + HUD_MARGIN * 0.7
	var r := view_w - safe.z - HUD_MARGIN
	var b := view_h - safe.w - HUD_MARGIN * 0.7
	return Rect2(l, t, r - l, b - t)


## Pixel scale of UI relative to a 720-high screen.
static func ui_scale() -> float:
	return view_h / VIEW_H if view_h > VIEW_H * 1.35 else 1.0
