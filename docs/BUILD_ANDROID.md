# Build, sign and publish — 404: Alive (Android)

There are three ways to get an APK. Pick one.

| Route | Best for | Needs |
|---|---|---|
| **A. Godot editor** | first build, easiest to debug | Godot + templates, JDK 17, Android SDK |
| **B. `tools/build_android.sh`** | repeatable local builds | same as A, plus a shell (Linux/macOS/WSL) |
| **C. GitHub Actions** | no local Android setup at all | a GitHub account |

## 0. Prerequisites (routes A and B)

1. **Godot 4.3 or newer**, standard (non-.NET) build — https://godotengine.org/download
2. **Export templates** matching your Godot version exactly: *Editor → Manage Export Templates → Download and Install*.
3. **JDK 17** (OpenJDK is fine).
4. **Android SDK** (install Android Studio, or just the command-line tools) and then:
   ```bash
   sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;23.2.8568313"
   ```
   The exact build-tools / NDK versions differ between Godot versions — check the *"Exporting for Android"* page of the Godot
   docs for the version you use, and adjust if it lists something different.
5. In Godot: *Editor → Editor Settings → Export → Android* → set **Android SDK Path** and **Java SDK Path**.

## A. Godot editor

1. *Import* the project folder (`project.godot`). First open takes a minute: it imports the sounds and icons.
   Open the **Output** panel — if anything prints an error, see *Troubleshooting* below.
2. Press **F5** once to run it on desktop (space = jump, S = slide, D/Shift = dash, hold A/L = look back).
3. *Project → Export…* — the **Android** preset already exists (package `com.dontlookback.game`, arm64 + armv7,
   immersive mode, vibrate permission, adaptive icons).
4. **Debug APK** (for testing): tick *Export With Debug*, click **Export Project**, save `build/404-alive-debug.apk`.
   The debug keystore is created for you by the editor (or set one under Editor Settings → Export → Android).
5. **Install:** enable *Developer options → USB debugging* on the phone, plug it in, then
   `adb install -r build/404-alive-debug.apk` — or use the Android icon in the editor's top-right ("one-click deploy").

## B. Command line

```bash
export GODOT=/path/to/godot          # if it is not on PATH as `godot`
export ANDROID_HOME=$HOME/Android/Sdk
tools/build_android.sh debug         # -> build/404-alive-debug.apk
```

The script imports the assets, writes the SDK/JDK paths into Godot's editor settings, creates a debug keystore if needed
and runs the headless export.

## C. GitHub Actions (no local setup)

1. Push this folder to a GitHub repo (branch `main`).
2. The workflow `.github/workflows/build-android.yml` runs in the `barichello/godot-ci` container (Godot + templates + JDK + SDK)
   and uploads `404-alive-apk` as a build artifact. Download it from the run's page.
3. The recipe is standard for that image; if the image layout changes, adjust the two paths in the workflow
   (`ANDROID_HOME`, template folder) — the image's README documents them.

## Signed release build

Play Store and most other stores require a **release-signed** build with a key that is yours forever.

```bash
tools/make_release_keystore.sh ~/dlb-release.keystore dontlookback   # asks for a password; BACK IT UP, never commit it
RELEASE_KEYSTORE=~/dlb-release.keystore RELEASE_KEY_ALIAS=dontlookback RELEASE_KEY_PASS='…' \
  tools/build_android.sh release                                      # -> build/404-alive-release.apk
```

In the editor instead: *Project → Export → Android → Options → Keystore*: fill **Release**, **Release User** (= alias) and
**Release Password**, untick *Export With Debug*. (Godot needs store password = key password.)

For CI releases: add repository secrets `RELEASE_KEYSTORE_BASE64` (`base64 -w0 your.keystore`), `RELEASE_KEY_ALIAS`,
`RELEASE_KEY_PASS`, then push a tag such as `v1.0.0`.

**Bump `version/code` (integer, must always increase) and `version/name` in the export preset for every upload.**

## Publishing to Google Play

Google Play requires an **Android App Bundle (.aab)**, not an APK:

1. *Project → Install Android Build Template…* (one time; creates `android/build/`).
2. In the Android export preset turn on **Gradle Build → Use Gradle Build**, set **Export Format = Export AAB**.
   Keep `arm64-v8a` enabled (Play requires 64-bit). Check Google's *current* minimum **target API level** and set
   *Gradle Build → Target SDK* accordingly if Godot's default is lower.
3. Export a **release** build → `.aab`.
4. Play Console → create app → upload the `.aab` to an **Internal testing** track first. Enrol in **Play App Signing**
   (Google holds the app-signing key; your keystore becomes the *upload* key).
5. Store listing checklist:
   * 512×512 icon: `assets/images/icon.png` · feature graphic 1024×500 and 2–8 landscape screenshots (record on device)
   * Content rating questionnaire — mild horror/fantasy violence, no gore, no user-generated content
   * **Data safety:** the game collects **no data**, has **no internet permission**, no ads, no analytics; progress is stored
     locally in `user://dont_look_back.cfg`
   * Privacy-policy URL (Play requires one even for apps that collect nothing — a one-line page is enough)
   * Note for the description: contains flashing effects (screen glitch/flashes) — consider a photosensitivity notice.
     Players can turn off *Shake* and *Low FX* in the menu.
6. New personal developer accounts may have to run a closed test with a minimum number of testers for a minimum period before
   production access — check the current Play Console requirements.

Other channels (itch.io, Amazon Appstore, direct download) accept the release-signed **APK** from route A/B/C.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "No export template found" | *Editor → Manage Export Templates* → install the templates for your exact Godot version |
| "Invalid Android SDK path" / "Could not find keytool" | set SDK + Java paths in Editor Settings → Export → Android (JDK 17, not 8/11) |
| "Debug keystore not configured" | run `keytool` as in `tools/build_android.sh`, set it in Editor Settings, or use the script |
| Build fails on `cmake`/`ndk` | install the versions your Godot version's docs list via `sdkmanager` |
| No sound in the editor after first open | let the import finish (bottom-right progress), then restart the scene |
| Script parse error on first open | open the **Output/Debugger** panel, fix or report the reported line — the project is small and typed; also run `python3 tools/lint_gd.py` |
| Screen stays black on a very old GPU | the post-FX shader needs a screen-texture read; disable it by hiding `PostFX` in `scenes/game.tscn` (you lose the lighting/vignette) |
| Music does not play | file must be `.ogg/.mp3/.wav` inside `assets/music/`; reopen the editor so it imports it |
| Black bars / UI cut off by a notch | the game uses stretch aspect `expand` and reads the display safe-area; if a device still shows bars, check `display/window/stretch/aspect` is `expand` and send me the device model |
| Fonts look different / fallback font | let the editor finish importing `assets/fonts/*.ttf` (first open), then rerun |
| Want to see the first-boot cinematic / button tutorial again | they only run on a fresh save. Delete `user://dont_look_back.cfg` (desktop: *Project → Open User Data Folder*) or, on Android, *Settings → Apps → 404: Alive → Clear storage* |
| Cinematic has no sound / the picture drifts from the score | let the editor import the 15 `assets/sounds/cine_*.wav` files, then restart; regenerate them with `python3 tools/generate_cinematic_audio.py` if any are missing |

## Performance notes

* GL Compatibility renderer, no 3D, no lights nodes, no per-particle nodes; all drawing is batched `_draw()` calls
* two full-screen shader passes (lighting; grade). **Low effects mode** in Settings halves particles and drops bloom/grain/glitch/aberration and some background decoration;
  **30 FPS** halves the frame rate for battery
* audio is 22.05 kHz mono WAV (~1.3 MB for everything)
