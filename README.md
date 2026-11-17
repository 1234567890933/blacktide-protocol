# Blacktide Protocol

A complete, offline, 64-bit tactical **Battle Royale** for Android, built in
**Godot 4.3** (MIT licensed engine) from free, openly licensed components. Drop
onto a hostile atoll, loot, plate up, and survive a cordon that closes sector by
sector — while an automated wargame called MERIDIAN decides you are the test.

No servers. No accounts. No network permission. Everything — map, AI, audio,
story beats — is generated on the device.

---

## What is in this repository

| Area | Where | Notes |
|---|---|---|
| Story bible, factions, zone beats | `docs/00-story-bible.md` | Drives every narrative trigger in code |
| Engine choice + 64-bit Android architecture | `docs/01-architecture.md` | Why Godot, module map, memory/LOD/compression plan |
| Movement & COD-style gunplay | `docs/02-gunplay.md` | `scripts/combat/` |
| Battle Royale loop (drop, loot, zone) | `docs/03-br-loop.md` | `scripts/br/`, `scripts/core/match_manager.gd` |
| Offline tactical bots & squads | `docs/04-ai.md` | `scripts/ai/` |
| Build, packaging, size budget | `docs/05-build-and-release.md` | Local + GitHub Actions |
| Free asset sources and licences | `docs/06-asset-pipeline.md`, `assets/MANIFEST.md` | `tools/fetch_assets.sh` |
| CI: arm64 APK build | `.github/workflows/android.yml` | Exports, verifies arm64-only, uploads artifact |
| CI: script + match smoke test | `.github/workflows/validate.yml` | Runs a headless match, fails on script errors |

## Play it

**On a phone:** install the APK from the Actions artifact (or the release page),
open it, choose `DEPLOY`. Landscape, one thumb each side.

**On a desktop for development:** install Godot 4.3, open `project.godot`, press
F5. Keyboard/mouse works; the touch rig hides itself automatically.

| Action | Touch | Keyboard / mouse |
|---|---|---|
| Move / sprint | left stick, `SPRINT` | `WASD`, `Shift` |
| Look / aim | drag right side | mouse |
| Fire | `FIRE` | left click |
| Aim down sights | `ADS` | right click |
| Reload | `RELOAD` | `R` |
| Crouch / slide | `CROUCH` | `Ctrl` |
| Prone | `PRONE` | `Z` |
| Jump | `JUMP` | `Space` |
| Swap weapon | `SWAP` | `Q` |
| Take loot | `TAKE` | `F` |
| Plate / heal | `HEAL` | `H` |
| Pause | — | `Esc` |

## Build the APK

```bash
# one-time: Godot 4.3 export templates, JDK 17, Android SDK 34 + build-tools 34.0.0
./tools/build_local.sh
# -> build/blacktide.apk  (arm64-v8a only, no 32-bit code anywhere)
```

In CI, pushing to `main` runs `.github/workflows/android.yml`, which exports the
APK, **fails the build if any `armeabi-v7a` library is present**, and uploads
`blacktide-apk-arm64` as an artifact. Pushing a `v*` tag attaches the APK to a
GitHub Release.

## Design constraints this build honours

- **64-bit only.** `arm64-v8a` is the only architecture in the export preset;
  CI enforces it.
- **Fully offline.** No `INTERNET` permission is requested in the export preset.
- **Sized for 5–10 GB of content, shipped lean.** The repository itself builds a
  ~30–40 MB APK because all art is procedural. `docs/06-asset-pipeline.md`
  explains how to add the high-resolution packs that take it to the multi-GB
  budget without breaking the frame budget.
- **60 fps target on mid-range hardware**, via LOD bias, render-scale tiers,
  throttled AI and zero imported textures in the default build.

## Engine and assets: all free, all replaceable

- Engine: [Godot 4.3](https://godotengine.org) — MIT.
- Art/audio: procedural primitives and a synthesiser in this repo (no licence
  needed), plus optional CC0 packs fetched by `tools/fetch_assets.sh` from their
  own GitHub repositories. See `assets/MANIFEST.md`.

Code is MIT (see `LICENSE`). Third-party assets keep their own licences.

## Repository layout

```
scenes/main.tscn            single bootstrap scene (everything else is code)
scripts/autoload/           GameState, InputHub, StoryDirector, AudioDirector
scripts/core/               main.gd, match_manager.gd, map_builder.gd
scripts/combat/             actor, player, weapon_db, inventory, ballistics, vfx
scripts/ai/                 bot.gd, squad_manager.gd
scripts/br/                 zone_controller, loot_spawner, loot_item
scripts/ui/                 hud, minimap, touch_controls, menu
tools/                      validate.gd, build_local.sh, fetch_assets.sh
.github/workflows/          android.yml (APK), validate.yml (tests)
```

There are no `.tscn` files beyond the entry scene on purpose: the entire game is
assembled in GDScript, which makes diffs readable, keeps the repo reviewable,
and means no scene file can silently break a build.
