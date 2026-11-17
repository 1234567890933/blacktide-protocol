extends Node
## Global persistent state: player profile, match settings, quality tiers.
## Everything lives offline in user://blacktide_profile.json — no network, ever.

signal settings_changed
signal match_result_recorded(result: Dictionary)

const SAVE_PATH := "user://blacktide_profile.json"
const SAVE_VERSION := 3

## Quality tiers map to concrete engine knobs. Tier 0 = low-end 64-bit phones,
## tier 2 = flagship. Kept data-driven so the build can be tuned without code edits.
const QUALITY_TIERS := [
	{
		"name": "Battery",
		"render_scale": 0.65,
		"msaa": 0,
		"shadows": false,
		"shadow_distance": 40.0,
		"lod_bias": 2.0,
		"max_bots_visible": 28,
		"decals": false,
	},
	{
		"name": "Balanced",
		"render_scale": 0.85,
		"msaa": 1,
		"shadows": true,
		"shadow_distance": 70.0,
		"lod_bias": 1.0,
		"max_bots_visible": 40,
		"decals": true,
	},
	{
		"name": "Sharp",
		"render_scale": 1.0,
		"msaa": 2,
		"shadows": true,
		"shadow_distance": 110.0,
		"lod_bias": 0.0,
		"max_bots_visible": 60,
		"decals": true,
	},
]

var settings := {
	"quality_tier": 1,
	"bot_count": 39,          # 39 bots + player = 40 operators (10 squads of 4)
	"squad_size": 4,
	"difficulty": "REGULAR",  # RECRUIT | REGULAR | VETERAN | ELITE
	"master_volume": 0.85,
	"sfx_volume": 1.0,
	"music_volume": 0.5,
	"sensitivity": 1.0,
	"invert_y": false,
	"auto_pickup": true,
	"haptics": true,
	"subtitles": true,
	"show_fps": false,
}

var profile := {
	"matches": 0,
	"wins": 0,
	"kills": 0,
	"deaths": 0,
	"best_placement": 40,
	"damage_dealt": 0.0,
	"headshots": 0,
	"time_played": 0.0,
	"last_match": {},
	"unlocked_logs": [],
}

var run_seed: int = 0


func _ready() -> void:
	randomize()
	load_profile()
	apply_quality()


func quality() -> Dictionary:
	var tier: int = clampi(int(settings["quality_tier"]), 0, QUALITY_TIERS.size() - 1)
	return QUALITY_TIERS[tier]


func apply_quality() -> void:
	var q := quality()
	var vp := get_viewport()
	if vp != null:
		vp.scaling_3d_scale = float(q["render_scale"])
		vp.msaa_3d = int(q["msaa"])
		vp.positional_shadow_atlas_size = int(q["shadow_distance"]) * 32
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(settings["master_volume"]), 0.0, 1.0)))
	settings_changed.emit()


func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		return
	settings[key] = value
	apply_quality()
	save_profile()


func record_match(result: Dictionary) -> void:
	profile["matches"] = int(profile["matches"]) + 1
	if bool(result.get("won", false)):
		profile["wins"] = int(profile["wins"]) + 1
	profile["kills"] = int(profile["kills"]) + int(result.get("kills", 0))
	profile["deaths"] = int(profile["deaths"]) + (0 if bool(result.get("won", false)) else 1)
	profile["damage_dealt"] = float(profile["damage_dealt"]) + float(result.get("damage", 0.0))
	profile["headshots"] = int(profile["headshots"]) + int(result.get("headshots", 0))
	profile["time_played"] = float(profile["time_played"]) + float(result.get("duration", 0.0))
	profile["best_placement"] = mini(int(profile["best_placement"]), int(result.get("placement", 60)))
	profile["last_match"] = result
	save_profile()
	match_result_recorded.emit(result)


func unlock_log(log_id: String) -> void:
	var logs: Array = profile["unlocked_logs"]
	if not logs.has(log_id):
		logs.append(log_id)
		save_profile()


func save_profile() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"settings": settings,
		"profile": profile,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write profile: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		return  # schema bump: keep defaults, never crash on stale saves
	for k in data.get("settings", {}).keys():
		if settings.has(k):
			settings[k] = data["settings"][k]
	for k in data.get("profile", {}).keys():
		if profile.has(k):
			profile[k] = data["profile"][k]


func new_run_seed() -> int:
	run_seed = int(randi())
	if run_seed == 0:
		run_seed = 1
	return run_seed
