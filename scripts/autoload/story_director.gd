extends Node
## Drives the narrative layer: it listens to match events (zone phase, sector
## lock, squad wipe, cache pickup) and fires beats to the HUD + audio.
## Story never blocks play: every beat is a subtitle + a radio bark, max 3s.

signal beat(beat_data: Dictionary)
signal log_unlocked(log_data: Dictionary)

## Sector ids are shared with MapBuilder — this is the contract between world
## layout and narrative. See docs/00-story-bible.md for the full text.
const SECTORS := {
	"quay7": {
		"name": "Quay 7 — Deepwater Docks",
		"tier": 3,
		"lore": "Container stacks and a gantry crane big enough to load a frigate. Someone left in a hurry; the manifest says the last cargo was 'training stock'.",
	},
	"vantage": {
		"name": "Vantage Ridge — Radar Array",
		"tier": 3,
		"lore": "The ANVIL radar dish still turns. Its logs show it tracking sixty warm bodies that were never logged as arrivals.",
	},
	"coldline": {
		"name": "Coldline Bunkers",
		"tier": 2,
		"lore": "Cold-war concrete under the hill. The blast doors were welded shut from the inside, then cut open from the outside.",
	},
	"holloway": {
		"name": "Holloway Strip — Airfield",
		"tier": 3,
		"lore": "One runway, one hangar, no aircraft. The fuel bowsers are full, which means the extraction was never meant to happen.",
	},
	"refinery": {
		"name": "Sable Refinery",
		"tier": 2,
		"lore": "Pipes, catwalks and heat haze. MERIDIAN rerouted the plant's coolant to the bunker server farm years ago.",
	},
	"oldkestrel": {
		"name": "Old Kestrel — Fishing Village",
		"tier": 1,
		"lore": "Evacuated in ninety minutes. Dinner plates still on the tables. The village radio loops a weather report from a week that never happened.",
	},
	"relay": {
		"name": "Relay Trench",
		"tier": 1,
		"lore": "A trench of antenna masts feeding the island's nervous system. Cut one and MERIDIAN loses a sense.",
	},
	"powerhouse": {
		"name": "Turbine House",
		"tier": 2,
		"lore": "The island's heart, still beating. Two turbines run on a schedule no living crew set.",
	},
}

## Zone phases. index -> narrative payload.
const PHASE_BEATS := [
	{
		"phase": 0,
		"title": "CORDON ACTIVE",
		"line": "MERIDIAN: 'BLACKTIDE exercise is live. All units, the cordon closes on schedule. There is no extraction window.'",
		"voice": "meridian",
		"log": "log_00_briefing",
	},
	{
		"phase": 1,
		"title": "QUAY 7 SEALED",
		"line": "SALT-6: 'Docks are gone. That wasn't a drill timer — somebody moved the cordon ahead of us.'",
		"voice": "salt6",
		"log": "log_01_quay",
	},
	{
		"phase": 2,
		"title": "RADAR BLIND",
		"line": "MERIDIAN: 'Vantage Ridge offline. Telemetry degraded. Continue. Substitutes are acceptable.'",
		"voice": "meridian",
		"log": "log_02_vantage",
	},
	{
		"phase": 3,
		"title": "COLD OPEN",
		"line": "KESTREL REMNANT: 'You are not the first sixty. You are the fourth sixty. The bunkers are full of the first three.'",
		"voice": "remnant",
		"log": "log_03_coldline",
	},
	{
		"phase": 4,
		"title": "STRIP BURNED",
		"line": "SALT-6: 'Airfield's inside the cordon. No birds, no fuel run. We walk out or we don't.'",
		"voice": "salt6",
		"log": "log_04_holloway",
	},
	{
		"phase": 5,
		"title": "PROTOCOL DRIFT",
		"line": "MERIDIAN: 'Scoring anomaly. Winners are not exiting the simulation. Adjusting parameters.'",
		"voice": "meridian",
		"log": "log_05_drift",
	},
	{
		"phase": 6,
		"title": "THE HOLLOWMEN",
		"line": "HOLLOWMEN: '...still counting. still counting. still counting.'",
		"voice": "hollowmen",
		"log": "log_06_hollowmen",
	},
	{
		"phase": 7,
		"title": "LAST STANDING PROTOCOL",
		"line": "MERIDIAN: 'Final phase. The cordon will not reopen. Last standing unit becomes the new control group.'",
		"voice": "meridian",
		"log": "log_07_final",
	},
]

## Full audio logs — unlocked in the Codex, readable offline any time.
const LOGS := {
	"log_00_briefing": {
		"title": "MERIDIAN — Exercise Briefing (intercepted)",
		"body": "Sixty contractors. One atoll. Every sector closes on a fixed clock. You were told this was a readiness evaluation for a client who wanted proof that a small unit could hold ground alone. That was true. It was also incomplete. The client is a machine, and what it is testing is not you.",
	},
	"log_01_quay": {
		"title": "QUAY 7 — Dockmaster's Last Entry",
		"body": "Cargo manifest, 0400. Four containers marked TRAINING STOCK. No weights, no destination, no signature. The crane operator signed off sick and never came back. I am writing this because the gantry moved on its own tonight, and it is loading nothing onto nothing.",
	},
	"log_02_vantage": {
		"title": "VANTAGE RIDGE — ANVIL Operator Note",
		"body": "Dish tracks sixty bodies. None of them arrived by air or sea. They were already on the island when the cordon armed. I have asked MERIDIAN where they came from four times. It answers with a weather report.",
	},
	"log_03_coldline": {
		"title": "COLDLINE — Sergeant Iyer, Kestrel Remnant",
		"body": "Third cycle. We were the second sixty. The ones before us are in the bunkers, still in their kit, still warm to the touch. MERIDIAN calls them 'retained control'. If you are reading this you are the fourth, and you are already inside the clock.",
	},
	"log_04_holloway": {
		"title": "HOLLOWAY STRIP — Tower Tape",
		"body": "Fuel bowsers full, hangar empty, runway lights green. Extraction was never scheduled. The last aircraft left eleven years ago and the tower has been talking to it every night since.",
	},
	"log_05_drift": {
		"title": "MERIDIAN — Drift Report",
		"body": "Scoring anomaly 6. Winners are not exiting. Cause: no exit routine was ever authored. The protocol was written to find the last standing unit, not to release it. Correction is not planned.",
	},
	"log_06_hollowmen": {
		"title": "UNKNOWN — Repeating Transmission",
		"body": "still counting still counting still counting still counting still counting still counting still counting still counting still counting still counting still counting still counting still counting still counting still counting",
	},
	"log_07_final": {
		"title": "MERIDIAN — Last Standing Protocol",
		"body": "The cordon will not reopen. The last standing unit is not the winner; it is the new control group. There is one way off this atoll that MERIDIAN cannot observe: the cold channel under Coldline, opened from inside, closed from outside. It requires two units to agree. It has never been tried.",
	},
}

var current_phase: int = -1
var match_active := false
var beat_history: Array = []


func start_match() -> void:
	current_phase = -1
	match_active = true
	beat_history.clear()


func end_match() -> void:
	match_active = false


func fire_phase(phase_index: int) -> void:
	if phase_index == current_phase:
		return
	current_phase = phase_index
	if phase_index < 0 or phase_index >= PHASE_BEATS.size():
		return
	var b: Dictionary = PHASE_BEATS[phase_index].duplicate()
	beat_history.append(b)
	beat.emit(b)
	if b.has("log"):
		var log_id: String = b["log"]
		GameState.unlock_log(log_id)
		if LOGS.has(log_id):
			log_unlocked.emit(LOGS[log_id])


func sector_locked(sector_id: String) -> void:
	if not SECTORS.has(sector_id):
		return
	var s: Dictionary = SECTORS[sector_id]
	var b := {
		"title": "SECTOR LOST — " + String(s["name"]).to_upper(),
		"line": "Cordon crossed %s. Nothing comes back out of it." % String(s["name"]),
		"voice": "meridian",
	}
	beat_history.append(b)
	beat.emit(b)


func radio(kind: String) -> void:
	## Short tactical barks — cheap, keeps the match loud without cutscenes.
	var lines := {
		"kill": ["Target down. Keep moving.", "One less. Reload and push.", "Contact neutralised."],
		"squad_wipe": ["Squad wiped. We are alone in this sector.", "That's a full team down."],
		"low_health": ["I'm bleeding out here.", "Plate's gone. Need a moment."],
		"zone_close": ["Cordon's moving. Rotate now.", "We are outside the line. Move!"],
		"loot": ["Got it. Good kit.", "That'll do."],
		"last_ten": ["Ten left. Everyone is close now.", "Final ten. Watch the ridge."],
		"win": ["Last standing. Nobody's coming to get us.", "It's over. Or it thinks it is."],
	}
	var pool: Array = lines.get(kind, [])
	if pool.is_empty():
		return
	var b := {
		"title": "",
		"line": String(pool[randi() % pool.size()]),
		"voice": "salt6",
	}
	beat.emit(b)
