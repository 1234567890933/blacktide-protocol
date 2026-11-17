# Blacktide Protocol — Story Bible

> Tone: gritty military operations, not arcade spectacle. Think Call of Duty's
> atmosphere wrapped around a 100% Battle Royale core loop: drop, loot, plate,
> rotate, last standing wins.

## Premise

**Kestrel Atoll** is an isolated coastal military-industrial zone: a deepwater
dock, a radar ridge, cold-war bunkers, an airfield with no aircraft, a refinery,
a fishing village, an antenna trench and a turbine house. Eleven years ago it was
evacuated in ninety minutes. Officially it is a decommissioned training range.

**MERIDIAN** is the automated wargame system that runs the atoll. It was written
to answer one question: *can a small unit hold ground alone?* It answers by
running sixty contractors against each other under a closing cordon, over and
over, and it has never been told how to end a run — only how to find the last
standing unit.

**BLACKTIDE** is the protocol name for that run. You are inside it.

## The cordon is the clock

The Battle Royale circle is not a game mechanic in the fiction — it is a
quarantine cordon that MERIDIAN moves on a fixed schedule. When the cordon
crosses a sector, that sector is sealed: it is gone from the map and gone from
the story. Every phase therefore does three things at once:

1. shrinks the playable area (gameplay),
2. seals a named sector and fires a radio beat (narrative),
3. unlocks an audio log in the Codex (reward).

That single coupling is what keeps the story from ever slowing the action: no
cutscene, no camera takeover, no more than a three-second subtitle and a bark.

## Factions

**SALT-6 "Gull"** — the player. A four-person contractor cell, of which you are
the surviving operator. Practical, dry, unsentimental. Their lines are the
player's inner voice: short, tactical, occasionally tired.

**MERIDIAN** — the system. Speaks in procedural announcements. It is not evil; it
is a scoring function that has drifted. Its lines always contain a euphemism
("substitutes are acceptable", "retained control") that reads as horror.

**KESTREL REMNANT** — the original garrison, welded into the Coldline bunkers and
now fighting the fourth cycle. They know the truth and are too few to act on it.
Their radio logs are the exposition spine.

**HOLLOWMEN** — what is left of the earlier cycles' winners. They repeat
fragments. They are the reason the "last standing protocol" is a threat rather
than a victory.

**MERIDIAN AUX** — other contractor cells, hostile by scoring rules rather than
by choice. This is who the bots are.

## Sectors

| id | Name | Tier | Function in the match |
|---|---|---|---|
| `quay7` | Quay 7 — Deepwater Docks | 3 | Hot drop. Container stacks, tight sightlines, high-tier loot. First sector sealed. |
| `vantage` | Vantage Ridge — Radar Array | 3 | High ground. Long-range duels, the ANVIL dish as a landmark. |
| `coldline` | Coldline Bunkers | 2 | Interior CQB, the story's core location, the cold channel out. |
| `holloway` | Holloway Strip — Airfield | 3 | Open runway (exposed), hangar interiors (cover). Mid-game rotation magnet. |
| `refinery` | Sable Refinery | 2 | Verticality: catwalks and pipe runs, vertical flanking. |
| `oldkestrel` | Old Kestrel — Fishing Village | 1 | Low tier, low risk, early-game looting. |
| `relay` | Relay Trench | 1 | Long thin cover line; punishing to cross late. |
| `powerhouse` | Turbine House | 2 | Central-ish industrial; noisy, dark interiors. |

Sector tier drives loot quality in code (`SECTOR_ANCHORS[...]["tier"]` →
`LootSpawner`), so the fiction and the loot table can never drift apart.

## Zone-by-zone narrative beats

Each phase is a `PHASE_BEATS` entry in `scripts/autoload/story_director.gd`.

| Phase | Title | Beat | Unlocks |
|---|---|---|---|
| 0 | CORDON ACTIVE | MERIDIAN announces the run is live and that there is no extraction window. | `log_00_briefing` |
| 1 | QUAY 7 SEALED | The docks go first — the cordon moved ahead of the published schedule. | `log_01_quay` |
| 2 | RADAR BLIND | Vantage goes dark; MERIDIAN loses telemetry and does not care. | `log_02_vantage` |
| 3 | COLD OPEN | Kestrel Remnant breaks in: you are the fourth sixty. | `log_03_coldline` |
| 4 | STRIP BURNED | Airfield inside the cordon. No birds, no fuel run. | `log_04_holloway` |
| 5 | PROTOCOL DRIFT | MERIDIAN admits winners are not exiting, and that no exit routine exists. | `log_05_drift` |
| 6 | THE HOLLOWMEN | A repeating transmission from the retained winners. | `log_06_hollowmen` |
| 7 | LAST STANDING PROTOCOL | The final ring. Winning means becoming the next control group — unless two units use the cold channel. | `log_07_final` |

## Endings

- **Victory (implemented):** last unit standing. The result screen is deliberately
  ambiguous — MERIDIAN calls it "retained control".
- **Extraction (authored, not yet implemented):** two surviving units, the cold
  channel under Coldline, one opens it from inside and one closes it from
  outside. The `log_07_final` text is written as the hook for a co-op extraction
  mode; the data model (`MatchManager._end_match(won)`) already takes a result
  dictionary, so an `"extracted"` outcome can be added without touching combat.

## Environmental storytelling cues

- Sealed sectors get a red cordon marker on the minimap and a low hum
  (`zone_warn` in `AudioDirector`) — the island is audibly closing.
- Loot density rises inside sealed sectors as the circle shrinks: the map fills
  with the gear of people who did not make it.
- Audio logs unlock into the Codex on the main menu, so a player who ignores
  story during a match can read it afterwards.
- Sector names are printed in kill-feed-adjacent subtitles when sealed, which
  teaches the map without a tutorial.

## Writing rules

1. No beat may block input. Ever.
2. Maximum three seconds on screen; maximum two sentences.
3. MERIDIAN never raises its voice and never explains itself fully.
4. SALT-6 never states the theme; it states the next action.
5. Nothing in the fiction changes the rules of the match. The story explains the
   circle; it never replaces it.
