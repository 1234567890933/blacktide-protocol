# Movement & Gunplay

Goal: *Call of Duty* responsiveness — crisp ADS, readable recoil, instant hit
feedback — on a touchscreen, without a second thumbstick click or a double-tap.

## Movement (`scripts/combat/player.gd`)

| State | Speed | Notes |
|---|---|---|
| Walk | 4.7 m/s | base |
| Sprint | 7.6 m/s | forward-only, cancels ADS |
| Crouch | 2.5 m/s | +25% steadier recoil |
| Prone | 1.15 m/s | +55% steadier recoil, camera drops to 0.63 m |
| ADS | 2.7 m/s | weapon-dependent multiplier |
| Slide | 9.4 m/s for 0.72 s | from sprint + crouch; momentum bleeds at 6 m/s² |

- **Collision capsule resizes** with stance (1.8 / 1.2 / 0.7 m) and the head node
  follows, so crouching actually changes what can hit you.
- **Acceleration** is 14× speed on the ground, 3× in the air: snappy on foot,
  committed once airborne.
- **Footstep cadence** scales with speed and is silent crouched/prone — audio is
  a gameplay system here, not decoration.

## Aim, ADS and recoil

- ADS is a **blend value**, not a boolean: FOV, viewmodel pose, spread and recoil
  bracing all interpolate on it. That is what makes the transition feel
  mechanical rather than binary.
- Recoil per shot is `recoil_v` (vertical climb) and `recoil_h` (alternating
  horizontal drift), multiplied by a brace factor: 1.0 hip → 0.55 ADS → ×0.75
  crouched → ×0.45 prone. Recoil recovers at 9°/s.
- A fraction of the recoil (35%) is written into the camera pitch and **stays
  there**, so you have to pull down — the COD feel — while the rest recovers
  automatically so the reticle never ends up in the sky.
- Spread grows 1.6° per shot up to 9°, decays 5°/s, and is scaled by 0.35 when
  ADS. Movement and jumping add penalties. Every shot is a ray inside a cone.

## Ballistics (`scripts/combat/ballistics.gd`)

- **Hitscan raycast per pellet**, one ray per bullet, up to 9 for shotguns.
- **Distance falloff** as `[start_m, end_m, multiplier]` per weapon — an SMG
  loses 55% of its damage by 45 m, a DMR keeps 80% at 260 m.
- **Hit zones are geometric**, not per-bone: the ray's height on the capsule
  decides head (×2.3, top 16%), legs (×0.75, bottom 32%) or body. No skeleton
  means 40 actors cost 40 capsules, not 40 rigs.
- **Armour absorbs 60%** of incoming damage until the plate breaks; health takes
  the rest. Plates are 55 points, four carryable.
- **The player and the bots use the same function.** Every fight is fair by
  construction, and any balance change lands on both sides at once.

## Weapon table (`scripts/combat/weapon_db.gd`)

12 weapons across 5 classes, each a plain dictionary: damage, rpm, auto/burst,
magazine, reserve, reload, recoil, spread, falloff, ADS time, zoom, move
multiplier, ammo type, SFX key, tier.

| Class | Examples | Role |
|---|---|---|
| Pistol | M9A3, D50 "Hammerhead" | starting gun, last resort |
| SMG | V9 Vector, MP7A2 | building clears, 0–30 m |
| AR | AK-74M, M4A1, SCAR-H | the default answer, 20–90 m |
| LMG | PKM | suppression, 100-round commitment |
| DMR / Sniper | SVD, AWM .338 | 4× and 6× zoom, one-shot headshots |
| Shotgun | M870, Saiga-12K | 8–9 pellets, 12–32 m |

**Attachments** modify resolved stats rather than the base table
(`WeaponDB.resolved_stats`): optics change ADS spread/zoom, suppressors cut
recoil and shrink the AI's hearing radius (`sound_scale`), grips trade vertical
for horizontal recoil, magazines trade capacity for reload speed.

## Feedback stack (why it feels good)

1. **Muzzle flash** = 4-energy omni light + emissive sphere, 70 ms.
2. **Tracer** = a stretched box that shrinks over 60 ms along the shot line.
3. **Impact** = 55 mm sphere that expands and fades in 120 ms; red on flesh.
4. **Hit sound** differs for plate, flesh and headshot (`hit_plate`, `hit_flesh`,
   `hit_head` — a 1.65 kHz ping that is the single most important audio cue in
   the game).
5. **Camera shake** 0.22 × brace, decays in 0.3 s.
6. **Damage vignette** intensity scales with the damage taken, not a fixed flash.

## Touch ergonomics

- Left stick zone is the bottom-left 300×300 px; the right two-thirds of the
  screen is look-drag; buttons own their own rects so a thumb never fights the
  camera.
- `FIRE` is a 130 px circle at the bottom right, `ADS` sits above-left of it at
  96 px, so the aim-fire-thumb travel is ~40 px.
- Semi-auto weapons **auto-repeat on hold at 0.28 s** so a player never has to
  tap-spam a pistol.
- One `HEAL` button does triage: plate first if the plate is under 50%, else
  heal. Two taps saved per fight is a real advantage.
