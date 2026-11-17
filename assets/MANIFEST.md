# Asset manifest

The default build ships **no binary assets**. Everything below is optional
content you can drop in; the game runs and passes CI without any of it.

## Required filenames for audio overrides

`AudioDirector` looks for `assets/external/audio/<key>.ogg` before it
synthesises a sound. Supported keys:

```
gun_ar  gun_smg  gun_sniper  gun_lmg  gun_shotgun  gun_pistol
hit_flesh  hit_head  hit_plate  reload  click  heal  pickup  footstep
zone_warn  zone_damage  explosion  ui  deploy  victory  defeat
```

## Optional model slots

| Slot | Function to edit | Notes |
|---|---|---|
| Weapon viewmodel | `Player._build_viewmodel()` | GLB, ~15k tris, origin at grip, -Z forward |
| Bot body | `Bot._build_body()` | GLB, ~20k tris, feet at y=0, 1.8 m tall |
| Environment props | `MapBuilder._build_props()` | GLB, MultiMesh-compatible (single material) |

## Licences

| Content | Author | Licence | Source |
|---|---|---|---|
| Engine | Godot Engine contributors | MIT | https://godotengine.org |
| All code in this repository | Blacktide Protocol contributors | MIT | see `LICENSE` |
| Procedural audio (synthesised) | this repository | MIT | `scripts/autoload/audio_director.gd` |
| Procedural meshes (generated) | this repository | MIT | `scripts/core/map_builder.gd` |

When you add a pack, append a row with author, licence and URL. CC0 packs need no
attribution but must still be listed here.
