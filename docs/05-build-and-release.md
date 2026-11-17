# Build, Packaging & Release

## 0. What you need once

| Tool | Version | Why |
|---|---|---|
| Godot | 4.3-stable | engine + editor |
| Godot export templates | 4.3-stable | Android templates |
| JDK | 17 (Temurin) | signing (`keytool`), `apksigner` host |
| Android SDK | platform 34, build-tools 34.0.0 | packaging |
| `adb` | any recent | install |

Set these in Godot once (Editor → Editor Settings → Export → Android):
`Android SDK Path`, `Java SDK Path`, and the debug keystore
(`~/.android/debug.keystore`, user `androiddebugkey`, pass `android`).

## 1. Local build

```bash
./tools/build_local.sh
# -> build/blacktide.apk
adb install -r build/blacktide.apk
```

The script mirrors CI exactly: import → validate every script → export → prove
the APK is arm64-only.

Manual equivalent:

```bash
godot --headless --path . --import
godot --headless --path . --script tools/validate.gd
godot --headless --path . --export-debug "Android" build/blacktide.apk
```

## 2. CI build (GitHub Actions)

`.github/workflows/android.yml` runs on every push to `main`, every `v*` tag and
on demand:

1. JDK 17, Godot 4.3 + export templates (cached), Android SDK 34 via
   `android-actions/setup-android`.
2. Generates a debug keystore and writes
   `~/.config/godot/editor_settings-4.3.tres` pointing Godot at the SDK, the JDK
   and that keystore — this is the step most CI guides omit and the reason
   headless Android exports fail with "Android SDK path is invalid".
3. Imports the project and validates all scripts.
4. Exports `build/blacktide.apk` (arm64-v8a only).
5. **Architecture gate:** unzips the APK and fails if `lib/armeabi-v7a/` exists
   or `lib/arm64-v8a/` is missing.
6. Uploads `blacktide-apk-arm64` as an artifact (30 days); on a tag, attaches the
   APK to a GitHub Release.

`.github/workflows/validate.yml` is the fast job: import, load every script,
then run a full headless match at `Engine.time_scale = 5` and fail on any
`SCRIPT ERROR`.

### Cut a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The APK lands on the Releases page. Version code and name live in
`export_presets.cfg` (`version/code`, `version/name`); bump them for each release
because Android refuses to install a lower version code over a higher one.

## 3. Release signing (beyond debug)

Debug keystores are fine for testing, not for Play. For a real release:

```bash
keytool -genkeypair -v -keystore release.keystore -storepass "$PASS" \
  -alias blacktide -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Blacktide"
```

Add these repository secrets and switch the workflow step from `--export-debug`
to `--export-release` with the same editor settings keys
(`export/android/keystore`, `_user`, `_pass`) — Godot reads them exactly like the
debug ones. Never commit a keystore; `.gitignore` already blocks `*.keystore`,
`*.jks`, `*.apk`.

## 4. Size budget: where the megabytes go

| Layer | Default build | With full art pack |
|---|---|---|
| Godot Android template (`libgodot_android.so`, arm64) | ~28 MB | ~28 MB |
| Scripts + scene + data tables | < 1 MB | < 1 MB |
| Procedural audio (generated at boot) | 0 | 0 |
| Meshes / textures | 0 | 4–8 GB |
| Audio files | 0 | 0.4–0.8 GB |
| **APK total** | **~30–40 MB** | **5–9 GB** |

Rules that keep the ceiling honest:

1. **ETC2/ASTC only** — `textures/vram_compression/import_etc2_astc=true` is set
   in `project.godot`; check with `unzip -l app.apk | grep .ctex` that nothing
   ships as raw PNG.
2. **LODs, not polys** — 2–4 LOD levels per prop, `lod_bias` is a quality knob.
3. **Audio streams, never preloads** — `AudioStreamPlayer3D` with Ogg; only the
   16-voice SFX pool stays in RAM.
4. **`assets/external/` is git-ignored.** Multi-GB content does not belong in
   git; ship it via release assets or a content pipeline, and keep clone times
   under a minute.
5. If the APK must exceed 2 GB, switch `gradle_build/export_format=1` (AAB) or
   split content into an expansion pack — both are one-line changes in
   `export_presets.cfg`.

## 5. Verification checklist before shipping

- [ ] `tools/validate.gd` → `VALIDATION PASSED` (23 scripts).
- [ ] Headless smoke test prints no `SCRIPT ERROR`.
- [ ] `unzip -l build/blacktide.apk | grep lib/` shows **only** `arm64-v8a`.
- [ ] APK has no `INTERNET` permission (`aapt dump permissions`).
- [ ] Installs and launches on a real 64-bit device.
- [ ] Full match: menu → deploy → drop → loot → fight → cordon closes → win/loss
      card → redeploy.
- [ ] Quality tiers switch without a restart-required glitch.
- [ ] Pause → resume restores mouse/touch capture.
- [ ] `user://blacktide_profile.json` survives an app restart (profile + Codex).
- [ ] Rotate the device: HUD stays anchored in landscape.

## 6. Known limitations (stated plainly)

- **No skeletal animation** in the default build: bots are capsule-and-primitive
  figures. Silhouette reads at range; a close-up will look like a blockout. The
  art pack path in `docs/06-asset-pipeline.md` is where that gets fixed.
- **No textures at all** by default — vertex colours and material tints only.
- **Tree props have no collision** (they are `MultiMesh`, deliberately, to keep
  the draw-call budget). Structures do.
- **Extraction ending is authored but not implemented** — see the story bible.
- **Bots do not revive downed teammates**: there is no downed state yet. Adding
  one means a new `Actor` state, not a rewrite of the AI.
