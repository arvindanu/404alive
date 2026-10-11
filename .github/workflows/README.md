# 404: Alive

A dark, cinematic 2D psychological-horror survival runner for Android (Godot 4, GDScript, zero third-party dependencies).
You run automatically. Something is always behind you. You can turn around and look — and it gets closer the longer you do.

* **Engine:** Godot 4.3+ (standard build, GL Compatibility renderer — runs on low/mid Android devices)
* **Orientation:** landscape, sensor-landscape (both directions); fills any aspect ratio with no black bars
* **Size:** ~7 MB of assets (sounds, the cinematic score, fonts, logo), no network, only the `VIBRATE` permission

> **Status — please read.** The whole project was authored without access to a Godot editor or the Android SDK, so it
> has been statically checked (`tools/lint_gd.py`) and its audio/icons were generated and verified, but it has **not been
> run inside Godot yet**, and **no APK binary is included** — an APK can only be produced by Godot's exporter.
> Follow [`docs/BUILD_ANDROID.md`](docs/BUILD_ANDROID.md) (about 15 minutes, or push to GitHub and let CI build it).
> On the very first open, expect to fix at most a few small engine-version nits; the code is small, typed and commented.

## Controls

| Action | Touch (landscape) | Keyboard |
|---|---|---|
| **Jump** (hold = higher, tap = short hop) | right thumb, big button | Space / W / Up |
| **Slide** (hold to stay low; in air = fast-fall dive) | right thumb, left button | S / Down |
| **Dash** (i-frames, smashes anything but pits; 2 s cooldown) | left thumb, small button | Shift / D / Right |
| **Look back** (hold) | left thumb, big button | A / L / Left |
| Pause | top-right button / Android Back | Esc / P |

Multi-touch is real: hold LOOK with one thumb while jumping and sliding with the other.

**Button colours** are fixed and never repeat: **Jump = red, Slide = blue, Dash = amber, Look = pale violet.** (Dash used to be red; it moved to amber so it can never be mistaken for Jump.)

## Launch sequence
Every launch opens with two splash screens (`scenes/splash.tscn`, the project's main scene), then continues exactly as before (main menu, or the first-boot cinematic on a fresh install):

1. **AN ORGANIZED CRIME ORIGINAL** (`assets/images/splash_organized_crime.jpg`): fades in, holds, fades out.
2. **made by TerMorgan** (`assets/images/splash_termorgan.jpg`): stutters on, then sits under a *subtle* horror glitch (a one-pixel colour fringe, the odd slipped row, a slow creeping push-in and vignette, scanlines, and a few short escalating bursts with red/cyan splits, torn rows and one-frame blinks) while an unsettling sound plays (`assets/sounds/splash_glitch.wav`); the last burst is the glitch-out into black.

~7.2 s in total. Files: `scripts/ui/splash.gd` (the sequence and hand-off), `splash_stage.gd` (drawing), `splash_fx.gd` (the glitch maths and its schedule). The splashes are drawn on a layer *above* the `Transition` autoload's black cover, and we then change scene normally, so the menu / cinematic still fade in from black on their own. Pictures are letterboxed on any screen shape; a picture that fails to load is skipped, never stalled on. Set `SKIPPABLE := true` in `splash.gd` to let any tap/key skip it while testing. The sound reads its timing from `splash_fx.gd`, so after editing the glitch schedule run `python3 tools/generate_splash_audio.py`.

## Frame rate (90 fps target)
The game used to hard-cap itself at 60 fps (30 in Battery saver), so no device could ever show more. It now follows the display (`GameState.target_fps()`, target `Cfg.TARGET_FPS = 90`): 90 Hz panels run at 90; 60 Hz panels (or anything slower) let vsync pace them exactly; 120/144 Hz panels run at their native rate (a 90 cap there would present frames unevenly); Battery saver is still 30. Everything in the simulation is delta-timed, so play is identical at any rate.

To fit an 11 ms frame the hottest per-frame work was trimmed *without changing a single pixel* (checked by comparing the exact draw-command stream before/after): the background's per-star / per-pebble random constants are computed once instead of every frame, the creature's pose is solved once and shared by the world and glow passes (was 3x), and the cinematic's draw queue is sorted natively and its floor/wall detail lines are batched (~860 -> ~370 draw calls a frame).

Safety net: if a device cannot even hold ~60% of what its display can show (two 2-second windows in a row), the game drops to the existing *Low effects* for the rest of the session (never touching your saved setting). It deliberately will not trigger for a phone that merely runs at 60 Hz. **Settings -> Show FPS counter** puts a small live number at the top of the screen so you can see what your device really does (it reads "(auto-low)" if the safety net has stepped in).

## First launch

* **Cinematic (once, ever).** On the very first launch of a fresh install the game opens with a ~40 s cinematic instead of the menu: a slow push through a moonlit forest to a small cabin, inside to a hooded programmer **sitting directly in front of his PC** (the monitor faces him; we first see him in 3/4 profile typing, reading code and sipping coffee, while the camera slowly **orbits around behind his shoulder** until he and the glowing screen share the frame), the lamp flickers and the **power cuts out**, he panics and grabs his lantern, but the **PC stays on by itself**, types `connection lost…`, shows **404: Alive**, glitches and distorts, **pulls him into the screen**, and the camera follows him in until it whites out and cuts straight into the first run, where he falls out of the screen into the world holding the same lantern. The interior is a small real perspective scene (`scripts/cinematic/cine_room.gd`: pinhole camera, culled boxes, a depth-sorted draw queue, a posable 3D runner with IK), so the camera move has true parallax; the exterior, the screen art and the timing stay in `scripts/cinematic/cine_art.gd`. It is drawn procedurally, uses the game's own grade shader for the tearing / chromatic split, and has its own score + sound design (`tools/generate_cinematic_audio.py`, `assets/sounds/cine_*.wav`). It can be skipped (SKIP button, Esc / Enter / Space, Android Back). **Finishing or skipping it saves `intro_seen`; it never plays again.** Existing players who update never see it (a save file that predates the flag counts as "already seen").
* **Button tutorial (first session only).** The first run freeze-frames four times, once per button (JUMP, SLIDE, DASH, LOOK): the screen dims, the button pulses, a short bubble explains it, and play resumes the moment you actually press it. Nothing can hurt you while a prompt is up, and there is a SKIP TUTORIAL pill. It is saved as `tutorial_done` as soon as it finishes, is skipped, or the session ends, and never shows again.
* **Seeing them again while testing.** Both flags live in the save file (`user://dont_look_back.cfg`, section `[flags]`). Delete the file (or Android: *Settings → Apps → 404: Alive → Clear storage*) to replay the cinematic and tutorial.

## Art direction

*Moonlit folk-horror, drawn as layered silhouettes.* A limited palette — **ink indigo, bone white, ember amber, one crimson accent** — and a single idea: **the runner carries the only warm light in the world.**

* **Lighting.** A two-pass shader pipeline. Pass A keeps the world dim and cold — but never crushed to black — with a soft band of **moonlight along the whole playfield** (ground, hazards, runner always readable) and a wide warm pool from the runner's swinging lantern (warm bounce near the flame, flicker, blackout events). The playfield band thins out as the world corrupts, so the late game gets moodier. An additive *glow layer* sits above it so rims, shards, windows and the creature's eyes never get swallowed. Pass B adds bloom, chromatic aberration, a filmic grade, vignette, grain, and the creeping-red edge that tracks the creature.
* **Depth.** Six parallax planes with atmospheric haze (stars → moon + rays → mountains → pine ridge → ruined chapels → dead trees → graveyard → lit path), mist banks, fast foreground grass and branches, soft contact shadows, ambient occlusion under the horizon, and shadows thrown *away from the lantern* (longer the closer they are to it).
* **Corruption.** Distance drains the sky from dusk-violet to blood-black, the moon swells and reddens, birds circle, eyes open in the trees, the ground cracks and glows, embers turn red, the creature grows.
* **Readable hazards, no outlines.** Hazards are big and read by *silhouette and material*, lit like real objects: carved pale stone gravestones and bleached bone tusks (jump), a pit that glows red from below (jump), a wooden-and-iron gibbet hanging from chains (slide), a crow with a burning red eye (slide), a thorn wall with glowing sap (dash through). They have cool moon-edge light, soft contact shadows cast away from the lantern, and a faint moonlit lift — but no outlines, decals or floating markers. The first time each kind appears the HUD names the action. Smashing one with a dash shatters it into material-coloured chunks, sparks and a shockwave ring with hit-stop and camera punch.
* **The runner.** Hooded, with a lagging coat, hood tail, scarf and a pendulum lantern. A real gait cycle (foot plants matched to ground speed, double-frequency hip bounce, counter-swinging arms), landing crouch, stretch on take-off, lean into acceleration, IK legs/arms blended between run / jump / fall / slide / dash.
* **The creature** is the *ultimate form* of the flying horror ("wretch"/crow): the same anatomy at ~3x scale — near-black violet flesh with bone-purple structure, an elongated skull on a hinged jaw (needle teeth), the wretch's slit eyes with white-hot cores **plus a crown of lesser eyes**, a row of spine spikes, ragged bone-fingered wings with scalloped membranes, spindly clawed limbs, a barbed whip of a tail and a furnace burning between its ribs, with a spine that ripples head-to-tail and moonlight along its back (`scripts/render/creature_drawer.gd`). Its gait is cosmetic state on `Creature` (`gait`, `animate()`), so wings/legs/spine stay continuous when the pace changes, and its footfalls kick the camera when it is close.
* **Being consumed.** A scripted death sequence (`scripts/game/consume.gd`, ~5 s, tap to skip after the first beat): the claw strikes and lifts you, your **lantern is flung from your hand and gutters out**, its head lowers and its wings flare, you are carried to its jaws and dissolve into light, your heartbeat stops at the gulp, the light slides down its throat and the furnace flares, it roars, the world drops to darkness but for its eyes, the picture glitches and collapses like a switched-off CRT, and only then does **CONSUMED** slam in. It is a pure function of its own clock and never touches the simulation.

## UI

Minimal, glassy, edge-anchored. Fonts: **Gloock** (titles), **Big Shoulders Bold** (numerals), **Instrument Sans** (labels) — all SIL OFL, bundled in `assets/fonts/` with their licences. All icons are drawn as vectors in code (`ui_draw.gd`), so there is nothing to blur at any resolution. HUD: distance + score top-left, a segmented **"it" proximity meter** with an eye that opens as it closes in, shard counter + multiplier + pause top-right, timer rings for power-ups, floating score popups, and glass thumb buttons (the LOOK ring fills as you stare; DASH shows its cooldown). Menus: logo screen over the live game, **Dress / Accessories** and Settings pages, and a pause card. **The ending is a full-screen cinematic**, not a dialog: letterbox bars close in over an almost-black, slightly translucent screen with a faint blood vignette, "CONSUMED" slams across ~78% of the width letter by letter with glitch bursts, the score counts up with ticks, stats spread edge to edge, and the buttons fade in (tap anywhere to skip ahead). Screen tearing/glitch exists **only** in this death sequence — never during play. Scene changes fade through black.

## Fills every screen

The project uses stretch mode `canvas_items` + aspect `expand`, so the viewport always covers the whole display — **no black bars** on 16:9, 18:9, 19.5:9, 20:9, 21:9, tablets, or foldables. Gameplay stays in a centred 16:9 design rect (so difficulty is identical everywhere); the sky, ground, parallax and the HUD extend to the real edges, HUD controls anchor to the real corners, and notch / cut-out insets are respected (`Cfg.update_view()` in `scripts/core/cfg.gd`).

## The rules of the world

* **Read the shape.** Gravestones and bone tusks → jump. Pits → jump. Hanging gibbets and crows → slide. Thorn walls → dash through (the only thing that can pass them).
* **A fair opening.** The first hazard is ~4.6 s away; the first three are single, smaller gravestones with a breather of shards in between; spacing never drops below ~0.9 s of running (560 px). Full-size hazards and variety phase in over the first ~60 m, and spacing is based on the speed you are *heading for*, not your current speed.
* **The creature.** `gap` is its distance behind you. Looking closes the gap faster the longer you stare (and it remembers — peeks add up). After 1.5 s of staring it **lunges**. Hits knock it closer; if it reaches you, you're consumed.
* **Risk / reward.** Every ~10–18 s something glints *behind* you (Lantern: pushes it back and widens your light · Relic: score x2 · Ward: absorbs one hit). Turn and hold your gaze ~0.45 s to grab it — while it creeps closer.
* **Progression.** Speed ramps 500 → 1060 px/s; hazards unlock with distance (tusks/gibbets → pits → combos → thorn walls → crows → chained combos); random events: whispers, blackouts, fog, false-creature scares, creature surges.
* **Meta.** Lifetime shards unlock **Dress** and **Accessories** (replacing the old scarf colours; prices are in `GameState.DRESSES` / `ACCESSORIES`). Dresses re-tailor the coat, its details and the cloth that streams behind the neck: *Wanderer* (free) · *Gravedigger* 500 · *Mourner* 1,800 · *Bloodbound* 4,800 · *Void Regalia* 11,000. Accessories are worn independently on top: *Bare* (free) · *Raven Omen* 1,000 (a raven perched on your shoulder, watching what is chasing you) · *Hollow Stag* 3,000 (bone antlers) · *Plague Mask* 7,500 · *Fallen Halo* 16,000. Tap a locked item to try it on the live runner before you buy. Collecting shards without being hit raises the score multiplier (x1 → x3).

## Audio tension

26+ procedural sounds (plus 15 for the cinematic and 11 for the creature / death sequence) and adaptive layers: a drone that deepens with distance, a growl that rises the longer you stare, a heartbeat that accelerates with proximity, whispers, and — new — a **proximity sub-bass**: silent until the creature is close, then a throbbing rumble (44 Hz fundamental with saturated 88/132 Hz harmonics so it is audible on phone speakers, not just headphones) that swells the nearer it gets, plus a heavy **boom under every heartbeat** in the danger zone, a vibration pulse on each beat, and a full-volume swell as it consumes you. Music dropped into `assets/music/` is low-pass-muffled as it closes in.

## Movement feel

`scripts/game/player_ctl.gd` is a small, tunable physics model: speed *eases* toward a state goal (accel 1500 / decel 2400 px/s²); coyote time (90 ms) + jump buffering (130 ms) + variable jump height + heavier fall gravity; eased dash with i-frames; hold-to-extend slide (0.36–0.95 s) and an air-dive that chains into a slide; damped-spring squash & stretch; forgiving hit-boxes; hit-stop on impacts.

## Project layout

```
404-alive/
├── project.godot            engine config (Compatibility renderer, landscape, autoloads)
├── export_presets.cfg       ready-made "Android" export preset (APK, arm64 + armv7)
├── assets/
│   ├── images/              launcher icons + logo (tools/generate_icons.py, generate_logo.py)
│   ├── fonts/               Gloock, Big Shoulders, Instrument Sans (+ OFL licences)
│   ├── sounds/              26 WAVs: SFX + seamless ambience loops (tools/generate_audio.py)
│   │                        + 15 `cine_*` WAVs for the first-boot cinematic (tools/generate_cinematic_audio.py)
│   │                        + 11 `con_*` WAVs for the creature / death sequence (tools/generate_consume_audio.py)
│   │                        + `splash_glitch.wav` under the second launch splash (tools/generate_splash_audio.py)
│   ├── music/               <- DROP YOUR MUSIC HERE (.ogg/.mp3/.wav) — auto-detected, see README.txt
│   └── shaders/             light.gdshader (lantern lighting) · grade.gdshader (bloom, aberration, vignette, grain)
├── scenes/                  splash (main scene) · main_menu · game · hud · pause_menu · game_over · cinematic
├── scripts/
│   ├── autoload/            game_state.gd (save, settings, fonts, input map) · audio_manager.gd · transition.gd
│   ├── cinematic/           cinematic.gd (timeline, sound cues, skip, hand-off) · cine_art.gd (exterior, screen art, timing) · cine_room.gd (the 3D interior + orbiting camera)
│   ├── core/                cfg.gd (layout / fill-screen maths) · gfx.gd (draw helpers, IK)
│   ├── game/                game.gd (run controller) · consume.gd (the death sequence) · player_ctl · creature · obstacle · world_gen · particle_system · pickup
│   ├── render/              world_renderer · glow_renderer · post_fx + background/obstacle/character/creature drawers
│   └── ui/                  splash · splash_stage · splash_fx (launch sequence) · hud · main_menu · pause_menu · game_over · ui_draw (icons) · fancy_button · switch_row · glass_panel
│                            · cosmetic_card / cosmetic_art (Dress page) · tutorial_draw (first-session prompts)
├── tools/                   build_android.sh · make_release_keystore.sh · generate_*.py · lint_gd.py
├── docs/BUILD_ANDROID.md    build, sign and publish guide
└── .github/workflows/       CI that builds the APK for you
```

Rendering is stacked layers: **world** → **light pass** (`light.gdshader`) → **glow** (additive, above the darkness) → **grade pass** (`grade.gdshader`) → **HUD**. Everything in the game world is drawn procedurally with `_draw()` — there are no sprite sheets to ship.

## Tuning cheat-sheet

| Want to change… | Edit |
|---|---|
| Jump height / gravity / coyote / buffer / slide & dash timings | constants at the top of `scripts/game/player_ctl.gd` |
| Run speed ramp, darkness curve, event timing | `_update_play()`, `_process()` in `scripts/game/game.gd` |
| How aggressive the creature is | `Creature.update()` / `rest_gap()` in `scripts/game/creature.gd` |
| Which hazards appear when, spacing, shard placement | `_spawn_pattern()` in `scripts/game/world_gen.gd` |
| Hazard look, size & colour language | `scripts/render/obstacle_drawer.gd`, `Cfg.COL_*` |
| Palette / world corruption | `scripts/render/background_drawer.gd` |
| Lighting strength, bloom, grade | `assets/shaders/*.gdshader`, `scripts/render/post_fx.gd` |
| HUD layout | `scripts/ui/hud.gd` |
| Touch-button positions/sizes | `BTN` in `scripts/ui/hud.gd` |
| Sound design | edit/re-run `tools/generate_audio.py`, or replace the WAVs (same filenames) |
| Cinematic picture / timing | `scripts/cinematic/cine_art.gd` (`T_*` constants are the timeline) |
| Cinematic camera path, room layout, runner's pose per beat | `scripts/cinematic/cine_room.gd` (`_camera()`, `_pose()`, `_props()`) |
| Creature's look / anatomy / animation | `scripts/render/creature_drawer.gd` (`SPINE`, `WIDTH`, `pose()`) |
| Death sequence beats, camera, glitch, sound cues | `scripts/game/consume.gd` (`T_*` + `EV` are the timeline; every driver is a function of `c`) |
| Death sequence sound | `tools/generate_consume_audio.py` (`assets/sounds/con_*.wav`) |
| Cinematic sound | `tools/generate_cinematic_audio.py` (cue times in `cinematic.gd` → `CUES`) |
| Cosmetic prices / looks | `GameState.DRESSES` / `ACCESSORIES`; art in `character_drawer.gd` (`palette`, `_dress_details`, `_accessory`) |
| Tutorial text | `TutorialDraw.STEPS` in `scripts/ui/tutorial_draw.gd` |

## Regenerating assets / checking sources

```bash
pip install numpy pillow
python3 tools/generate_audio.py   # rewrites assets/sounds/*.wav (the in-game sounds)
pip install scipy
python3 tools/generate_cinematic_audio.py   # rewrites assets/sounds/cine_*.wav (the cinematic's score + effects)
python3 tools/generate_consume_audio.py     # rewrites assets/sounds/con_*.wav (creature footsteps / breath + the death sequence)
python3 tools/generate_splash_audio.py      # rewrites assets/sounds/splash_glitch.wav (the second launch splash)
python3 tools/generate_icons.py   # rewrites the launcher icons
python3 tools/generate_logo.py    # rewrites assets/images/logo.png
python3 tools/check_refs.py       # verifies every cross-script call + resource path
python3 tools/lint_gd.py          # cheap static checks (indentation, brackets)
```

## Previews of the creature / death sequence / cinematic redesign
`previews/` holds before/after sheets (`monster_BEFORE/AFTER`, `crow_and_its_ultimate_form`, `death_sequence`, `cinematic_BEFORE/new_opening`). They were rendered by a Python port of the draw code (not by Godot itself), so treat them as a faithful layout/animation reference rather than pixel-exact screenshots; delete the folder freely, nothing references it.
