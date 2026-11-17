# Architecture — 64-bit Android, offline, 5–10 GB content budget

## 1. Engine choice

**Godot 4.3, mobile renderer.** Chosen over Unity/Unreal for four reasons that
matter for this specific brief:

1. **Free and open source (MIT), with no revenue terms, no licence server, and
   no account required to build.** The entire toolchain — engine, export
   templates, CI scripts — is downloadable from GitHub, which is exactly the
   constraint ("everything available free on GitHub").
2. **True arm64-only Android export.** The preset exports a single ABI. There is
   no accidental 32-bit support library to audit, and CI can prove the APK is
   64-bit only by listing its `lib/` folders.
3. **Small runtime, fast cold start.** The exported APK here is ~30–40 MB with
   no art. That leaves almost the entire 5–10 GB budget for content rather than
   engine overhead.
4. **The mobile renderer targets exactly our hardware class**: Forward Mobile
   with a single directional shadow, no SSAO, no glow. What you can turn off is
   what keeps a phone cool.

Rejected: Unity (licence/binary size), Unreal (overkill for a 60-actor sandbox,
heavy shader compile), custom C++ engine (no time-to-playable).

## 2. Why the game is code, not scenes

`scenes/main.tscn` is the only scene. Every node — player, bots, HUD, menus,
map, zone — is constructed in GDScript at runtime.

- Diffs are readable and reviewable in a pull request.
- No scene file can break a build with a stale UID or a dangling resource path.
- The whole game is validated by a single headless script load pass
  (`tools/validate.gd`), which is what CI runs before every export.
- Procedural construction is also the reason there are no binary assets to keep
  in sync — the repo stays text.

## 3. Module map

```
Main (Node3D)                          scripts/core/main.gd
├── WorldEnvironment + DirectionalLight    sky, fog, sun (quality-tiered shadows)
├── MatchManager (Node)                  scripts/core/match_manager.gd
│   ├── MapBuilder (Node3D)              procedural island, sectors, cover graph
│   ├── ZoneController (Node)            cordon phases, damage, sector sealing
│   ├── LootSpawner (Node3D)             ~220–320 LootItem nodes
│   ├── SquadManager (Node)              squad roster + contact blackboard
│   ├── Player (CharacterBody3D)
│   └── Bot × N (CharacterBody3D)
├── HUD (CanvasLayer)                    vitals, ammo, minimap, kill feed, subtitles
├── TouchControls (CanvasLayer)          virtual stick + action cluster
└── MainMenu (CanvasLayer)               menu, pause, codex, result card

Autoloads (singletons):
  GameState        settings + profile persistence (user://blacktide_profile.json)
  InputHub         single input surface for keyboard, mouse and touch
  StoryDirector    beats, audio logs, sector sealing narration
  AudioDirector    procedural synthesiser + optional asset override
```

**Dependency direction is one-way:** UI → MatchManager → systems → data tables.
Combat code never references the HUD; it emits signals. That is what lets the
headless smoke test run a full match with no renderer.

## 4. Frame and memory budget

Target: **60 fps on a Snapdragon 7-series / Dimensity 8000-class phone**, 30 fps
floor on a four-year-old mid-ranger.

| Budget | Value | How it is held |
|---|---|---|
| Draw calls | < 400 | All props are `MultiMesh` (2 draws for 520 trees); structures share one material per sector. |
| Terrain | 1 mesh, 96×96 quads | `ArrayMesh` + trimesh collider, built once (~1 s). |
| Actors | 40 (39 bots + player) | ~5 primitives each, no skeletal animation in the default build. |
| Physics | 1 trimesh + ~150 boxes + 40 capsules | Layer 1 world, layer 2 actors. Loot has **no** collider. |
| Raycasts | bounded | AI throttled by distance (60 Hz near, 8 Hz mid, 3 Hz far); loot scan cached 0.6 s; interact scan at 20 Hz. |
| Audio | 16-voice pool + 3D emitters | SFX synthesised once at boot, ~40 KB of RAM total. |

## 5. Quality tiers (device scaling)

`GameState.QUALITY_TIERS` — Battery / Balanced / Sharp:

| Knob | Battery | Balanced | Sharp |
|---|---|---|---|
| `scaling_3d_scale` | 0.65 | 0.85 | 1.0 |
| MSAA | off | 2× | 4× |
| Shadows | off | on, 70 m | on, 110 m |
| LOD bias | 2.0 | 1.0 | 0.0 |
| Shadow atlas | 1280 | 2240 | 3520 |

These are applied at runtime (`GameState.apply_quality()`), so the same APK runs
on a budget phone and a flagship without a second build.

## 6. 64-bit Android configuration

`export_presets.cfg`:

```
architectures/armeabi-v7a = false
architectures/arm64-v8a   = true
architectures/x86         = false
architectures/x86_64      = false
package/unique_name       = "com.blacktide.protocol"
gradle_build/use_gradle_build = false   # prebuilt template, no Gradle step
```

Notes:

- **No 32-bit code path exists.** CI runs `unzip -l` on the finished APK and
  fails if `lib/armeabi-v7a/` appears.
- **No `INTERNET` permission.** The only permissions requested are `vibrate` and
  `wake_lock`. The game cannot phone home even by accident.
- **Min SDK 24 (Android 7.0)**, target SDK 34, via the Godot 4.3 template
  defaults — enough to cover effectively all live 64-bit devices.
- The prebuilt-template path (no Gradle) keeps CI to one export command and
  avoids a 10-minute Gradle cold start. Switch
  `gradle_build/use_gradle_build=true` only when adding Android plugins.

## 7. The 5–10 GB content budget, honestly

The shipped repository builds a **~30–40 MB APK** because every asset is
procedural. That is a deliberate engineering choice, not a limitation: it means
the gameplay, AI, netcode-free loop and story are complete and testable before a
single byte of art is bought or downloaded.

The budget is spent, when art is added, in this order (see
`docs/06-asset-pipeline.md` for the exact packs and licences):

| Content | Target size | Format | Why |
|---|---|---|---|
| Terrain + building textures | 1.5–2.5 GB | ETC2/ASTC compressed, 2K | Largest visual win per MB |
| Weapon + character models | 0.6–1.2 GB | glTF, 15–30k tris, LOD0–LOD3 | Silhouette matters more than polycount |
| Character animation | 0.3–0.6 GB | baked skeletal, 30 fps | No runtime IK in the default build |
| Audio (guns, steps, ambience, VO) | 0.4–0.8 GB | Ogg Vorbis q5, 44.1 kHz | Streaming, not RAM-resident |
| Environment props | 0.8–1.5 GB | MultiMesh-ready, instanced | Kept as few unique meshes, many instances |
| Cinematic/loading video | 0–0.5 GB | 720p VP9 | Optional |

**Rules that keep a multi-GB build playable:**

1. Textures ship **ETC2/ASTC only** (`textures/vram_compression/import_etc2_astc=true`).
   No uncompressed PNGs in the PCK.
2. Every prop has 2–4 LODs; LOD bias is a quality-tier knob, not a per-asset hack.
3. Audio is Ogg and streamed; only UI clicks and footsteps stay in RAM.
4. Nothing over 2K per texture. Tiling beats resolution.
5. `assets/external/` is git-ignored — the repo carries scripts and manifests,
   not gigabytes. Content is fetched by `tools/fetch_assets.sh` or attached to a
   release, keeping clone and CI times sane.

## 8. Determinism and testability

- Every match takes a `seed`. `MapBuilder`, `ZoneController` and `LootSpawner`
  all derive from it, so a bug is reproducible with one number.
- `-- --smoke` runs a full match headless at `Engine.time_scale = 5`, prints
  alive counts and per-bot diagnostics, and CI fails on any `SCRIPT ERROR`.
- `tools/validate.gd` loads all 23 scripts and fails the build on a parse error,
  which is the cheapest possible regression net for a code-only project.
