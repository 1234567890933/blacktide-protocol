# Free Asset Pipeline (everything from GitHub, everything licensed)

The project builds and plays with **zero** third-party assets. This document is
how you take it from blockout to a full 5–10 GB production build using only
free, openly licensed content hosted on GitHub.

## 1. How the swap works

| System | Built-in fallback | Asset override |
|---|---|---|
| Audio | `AudioDirector._synth()` — PCM generated at boot | `assets/external/audio/<sfx_key>.ogg` (same keys as `_recipes()`) |
| Weapons | blocky `BoxMesh` viewmodel | replace `Player._build_viewmodel()` meshes with `GLTF` scenes |
| Bots | capsule + sphere + box | swap `Bot._build_body()` meshes |
| Environment | `MultiMesh` primitives | instance `GLB` props in `MapBuilder._build_props()` |
| Textures | vertex colour only | `StandardMaterial3D.albedo_texture` from `assets/external/textures/` |

The audio override is already live: drop `gun_ar.ogg` into
`assets/external/audio/` and it wins automatically, no code change. The model
swaps are three small functions, each marked with a comment.

## 2. Packs worth pulling (all CC0 unless noted)

| Pack | Source | Licence | Use |
|---|---|---|---|
| Kenney — Weapon Pack | `github.com/KenneyNL/Weapon-Pack` | CC0 | 40+ modular weapon meshes, the fastest way to real gun silhouettes |
| Kenney — Industrial Kit | `github.com/KenneyNL/Industrial-Kit` | CC0 | crates, pipes, barriers — matches the docks/refinery sectors |
| Kenney — Audio Kit | `github.com/KenneyNL/Audio-Kit` | CC0 | UI, impacts, ambience beds |
| Kenney — Prototype Textures | `github.com/KenneyNL/Prototype-Textures` | CC0 | greybox → textured in one step |
| Quaternius — Ultimate Modular Men | `github.com/quaternius/…` (mirrors) | CC0 | humanoid base mesh for bot bodies |
| Poly Haven HDRIs | `github.com/Poly-Haven/Assets` | CC0 | sky/IBL for the coastal look |
| Godot demo projects | `github.com/godotengine/godot-demo-projects` | MIT | reference implementations for GLTF import and LOD |

`tools/fetch_assets.sh` clones the Kenney/Poly Haven packs into
`assets/external/_src/` (git-ignored). Verify each licence file inside the pack
before shipping — CC0 needs no attribution, but keep the file anyway; it is
evidence.

## 3. Import settings that protect the frame budget

For every texture: **VRAM Compressed, ETC2/ASTC, 2K max, mipmaps on, no
anisotropy above 2×.**

For every mesh: **generate 2–4 LODs** (Godot's import dock → LODs), enable
`meshoptimizer`, keep materials ≤ 3 per mesh so props batch.

For audio: **Ogg Vorbis, 44.1 kHz, q5**; loop points only on ambience.

## 4. Order of work that pays off fastest

1. **Gun audio** (biggest perceived-quality jump per MB, 1 hour of work).
2. **Weapon viewmodels + bot bodies** (silhouette recognition).
3. **Sector-specific props** (docks look like docks).
4. **Terrain and building textures** (largest size, do it last).
5. **VO for MERIDIAN and SALT-6** — the story beats are already written in
   `StoryDirector.PHASE_BEATS`; record 16 lines and the match sounds authored.

## 5. Attribution

Code: MIT (`LICENSE`). Assets keep their own licences. If you add CC-BY content,
append it to `assets/MANIFEST.md` with the author and source URL — that file is
the single place a lawyer or a store reviewer needs to read.
