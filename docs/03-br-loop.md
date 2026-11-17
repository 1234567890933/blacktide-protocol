# Battle Royale Loop

`MatchManager` is a five-state machine. Everything else in the project is a
subscriber.

```
IDLE ──start_match(seed)──► BRIEFING ──► DROP ──landed──► LIVE ──► ENDED
                                                                     │
                                                          restart ◄──┘
```

| State | What happens | Duration |
|---|---|---|
| `BRIEFING` | Build island, sectors, loot, squads, spawn 40 actors. | ~1–2 s |
| `DROP` | Player free-falls from 240 m, steers, canopy at 65 m. Bots already grounded with a 7–12 s weapon grace. | ~12–15 s |
| `LIVE` | Cordon runs its 8 phases, bots loot and fight, zone damage applies. | 6–9 min |
| `ENDED` | Result card, profile saved, story closed. | until input |

## Drop / deployment

- The drop point is chosen **inside the first cordon**, rejection-sampled until
  it is on dry land (`height_at > 3 m`) — landing in the sea is a bug, not a
  hazard.
- Free-fall is 26 m/s with 16 m/s of lateral steering; below 65 m the canopy
  takes over at 7.5 m/s and 7 m/s of steering. That is long enough to be a real
  decision, short enough not to be a wait.
- Bots spawn spread out with **rejection sampling at 26 m minimum separation**.
  Without it, 40 bots inside one cordon wipe each other out in the first ten
  seconds (this is a measured result, not a guess — see the smoke-test notes in
  `docs/05-build-and-release.md`).

## Loot

- ~220–320 ground items from the map's sector loot points. Each sector's tier
  sets the weapon rarity ceiling, so Quay 7 and Holloway Strip are worth
  contesting and Old Kestrel is the safe start.
- Roll table: 34% weapon (45% of those carry an attachment), 24% ammo, 16%
  heal, 14% armour plate, 7% throwable, 5% attachment.
- **Interaction is distance-based** (`3.2 m`), not `Area3D` — 300 items × 40
  actors would otherwise be 300 physics bodies that do nothing.
- Swapping a weapon **drops the old one at your feet** instead of deleting it.
  Bots leave a **death cache** (their gun, ammo, a plate) where they fall.
- Ammo and heals auto-pick up; weapons and attachments need the `TAKE` press
  because they are a real decision.

## The cordon (`scripts/br/zone_controller.gd`)

| Phase | Wait | Move | End radius | Damage/s |
|---|---|---|---|---|
| 1 | 95 s | 55 s | 430 m | 1.0 |
| 2 | 70 s | 45 s | 320 m | 1.5 |
| 3 | 60 s | 40 s | 225 m | 2.0 |
| 4 | 55 s | 35 s | 150 m | 3.0 |
| 5 | 45 s | 30 s | 98 m | 4.5 |
| 6 | 40 s | 28 s | 60 m | 6.0 |
| 7 | 32 s | 24 s | 34 m | 9.0 |
| 8 | 26 s | 20 s | 14 m | 14.0 |

- The next centre is always **inside the current circle** (offset ≤ 55% of the
  remaining gap), so the final ring is always reachable on foot.
- Damage accumulates per actor and is applied in whole-second ticks, so a player
  crossing the line for 0.4 s does not take a phantom tick.
- Every phase start does three things at once: shrinks the circle, **seals the
  sectors that fall outside**, and fires the matching narrative beat.

## Story coupling (`scripts/autoload/story_director.gd`)

```
ZoneController._begin_phase(i)
   ├── StoryDirector.fire_phase(i)      → subtitle + radio bark + Codex unlock
   └── _lock_sectors_outside()
          └── StoryDirector.sector_locked(id) → "SECTOR LOST — QUAY 7" beat
```

Bots also emit story barks through the same channel (`radio("kill")`,
`radio("last_ten")`), which is why the match sounds populated without any VO.

## HUD and readability

- **Minimap** draws sector footprints, the cordon, the *next* ring preview and
  the player arrow. It deliberately shows **no enemy blips** — information is
  earned by looking.
- Top bar: alive count, kills, phase label, phase timer.
- Crosshair gap is computed from the **live spread value**, so the reticle tells
  you when to stop firing.
- Kill feed keeps six entries and fades each after 6 s.
- Subtitles are capped at 4.5 s and never take focus or block input.

## Win / loss

- Win: `alive_count <= 1` and the player is alive → `won: true`, placement 1.
- Loss: player dies → placement is the number of actors alive at that moment.
- Either way the result dictionary (placement, kills, damage, headshots, time,
  seed) is written to `user://blacktide_profile.json` and shown on the result
  card, then `REDEPLOY` starts a fresh seeded match with the same systems.
