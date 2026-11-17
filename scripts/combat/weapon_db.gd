class_name WeaponDB
extends RefCounted
## Data-driven weapon + attachment tables. Balance lives here, not in code, so
## a designer can retune the whole sandbox without touching a system script.
## All values tuned for a 1.8 m actor, 60 m typical engagement, hitscan-ish
## raycast ballistics with distance falloff.

const AMMO := {
	"9mm": {"name": "9x19mm", "stack": 30},
	"45acp": {"name": ".45 ACP", "stack": 20},
	"57": {"name": "5.7x28mm", "stack": 40},
	"556": {"name": "5.56x45mm", "stack": 30},
	"762": {"name": "7.62x39mm", "stack": 30},
	"762n": {"name": "7.62x54mmR", "stack": 20},
	"338": {"name": ".338 Lapua", "stack": 10},
	"12g": {"name": "12 gauge", "stack": 8},
}

## damage        : per pellet, at point blank
## rpm           : rounds per minute (auto/burst)
## auto          : hold to fire
## burst         : shots per trigger pull (0 = single)
## pellets       : shotgun pellet count
## recoil_v/h    : degrees of kick per shot (vertical / horizontal)
## spread_hip/ads: cone half-angle in degrees
## falloff       : [start_m, end_m, multiplier_at_end]
const WEAPONS := {
	"m9a3": {
		"name": "M9A3", "class": "Pistol", "damage": 26.0, "rpm": 320, "auto": false, "burst": 0,
		"mag": 17, "reserve": 68, "reload": 1.9, "recoil_v": 1.1, "recoil_h": 0.35,
		"spread_hip": 2.4, "spread_ads": 0.55, "falloff": [25.0, 70.0, 0.55], "ads_time": 0.16,
		"ammo": "9mm", "sfx": "gun_pistol", "tier": 1, "move_mult": 1.0, "zoom": 0.0,
	},
	"hammerhead": {
		"name": "D50 'Hammerhead'", "class": "Pistol", "damage": 52.0, "rpm": 180, "auto": false, "burst": 0,
		"mag": 7, "reserve": 28, "reload": 2.4, "recoil_v": 2.6, "recoil_h": 0.9,
		"spread_hip": 3.0, "spread_ads": 0.7, "falloff": [20.0, 55.0, 0.5], "ads_time": 0.2,
		"ammo": "45acp", "sfx": "gun_pistol", "tier": 2, "move_mult": 1.0, "zoom": 0.0,
	},
	"v9": {
		"name": "V9 Vector", "class": "SMG", "damage": 22.0, "rpm": 1100, "auto": true, "burst": 0,
		"mag": 33, "reserve": 132, "reload": 2.0, "recoil_v": 0.75, "recoil_h": 0.4,
		"spread_hip": 1.9, "spread_ads": 0.75, "falloff": [18.0, 45.0, 0.45], "ads_time": 0.15,
		"ammo": "45acp", "sfx": "gun_smg", "tier": 2, "move_mult": 0.98, "zoom": 0.0,
	},
	"mp7": {
		"name": "MP7A2", "class": "SMG", "damage": 19.0, "rpm": 950, "auto": true, "burst": 0,
		"mag": 40, "reserve": 160, "reload": 1.8, "recoil_v": 0.7, "recoil_h": 0.45,
		"spread_hip": 1.7, "spread_ads": 0.6, "falloff": [20.0, 50.0, 0.45], "ads_time": 0.14,
		"ammo": "57", "sfx": "gun_smg", "tier": 2, "move_mult": 1.0, "zoom": 0.0,
	},
	"ak74m": {
		"name": "AK-74M", "class": "AR", "damage": 31.0, "rpm": 620, "auto": true, "burst": 0,
		"mag": 30, "reserve": 120, "reload": 2.5, "recoil_v": 1.7, "recoil_h": 0.55,
		"spread_hip": 2.7, "spread_ads": 0.4, "falloff": [60.0, 150.0, 0.65], "ads_time": 0.22,
		"ammo": "762", "sfx": "gun_ar", "tier": 2, "move_mult": 0.95, "zoom": 0.0,
	},
	"m4a1": {
		"name": "M4A1", "class": "AR", "damage": 28.0, "rpm": 780, "auto": true, "burst": 0,
		"mag": 30, "reserve": 120, "reload": 2.2, "recoil_v": 1.3, "recoil_h": 0.45,
		"spread_hip": 2.4, "spread_ads": 0.3, "falloff": [65.0, 160.0, 0.68], "ads_time": 0.2,
		"ammo": "556", "sfx": "gun_ar", "tier": 3, "move_mult": 0.95, "zoom": 0.0,
	},
	"scarh": {
		"name": "SCAR-H", "class": "AR", "damage": 38.0, "rpm": 590, "auto": true, "burst": 0,
		"mag": 20, "reserve": 80, "reload": 2.6, "recoil_v": 2.1, "recoil_h": 0.6,
		"spread_hip": 2.8, "spread_ads": 0.32, "falloff": [70.0, 170.0, 0.7], "ads_time": 0.24,
		"ammo": "762", "sfx": "gun_ar", "tier": 3, "move_mult": 0.93, "zoom": 0.0,
	},
	"pkm": {
		"name": "PKM", "class": "LMG", "damage": 34.0, "rpm": 650, "auto": true, "burst": 0,
		"mag": 100, "reserve": 200, "reload": 5.5, "recoil_v": 1.9, "recoil_h": 0.8,
		"spread_hip": 4.2, "spread_ads": 0.5, "falloff": [80.0, 190.0, 0.7], "ads_time": 0.3,
		"ammo": "762n", "sfx": "gun_lmg", "tier": 3, "move_mult": 0.86, "zoom": 0.0,
	},
	"svd": {
		"name": "SVD", "class": "DMR", "damage": 62.0, "rpm": 200, "auto": false, "burst": 0,
		"mag": 10, "reserve": 40, "reload": 3.0, "recoil_v": 2.8, "recoil_h": 0.7,
		"spread_hip": 4.5, "spread_ads": 0.12, "falloff": [110.0, 260.0, 0.8], "ads_time": 0.3,
		"ammo": "762n", "sfx": "gun_sniper", "tier": 3, "move_mult": 0.9, "zoom": 4.0,
	},
	"awm": {
		"name": "AWM .338", "class": "Sniper", "damage": 118.0, "rpm": 45, "auto": false, "burst": 0,
		"mag": 5, "reserve": 20, "reload": 3.6, "recoil_v": 4.2, "recoil_h": 1.0,
		"spread_hip": 6.0, "spread_ads": 0.05, "falloff": [200.0, 400.0, 0.9], "ads_time": 0.38,
		"ammo": "338", "sfx": "gun_sniper", "tier": 4, "move_mult": 0.85, "zoom": 6.0,
	},
	"m870": {
		"name": "M870 Breacher", "class": "Shotgun", "damage": 15.0, "rpm": 75, "auto": false, "burst": 0,
		"mag": 6, "reserve": 24, "reload": 3.4, "recoil_v": 3.4, "recoil_h": 1.0,
		"spread_hip": 6.5, "spread_ads": 4.6, "falloff": [12.0, 32.0, 0.25], "ads_time": 0.24,
		"ammo": "12g", "sfx": "gun_shotgun", "tier": 2, "move_mult": 0.94, "zoom": 0.0, "pellets": 8,
	},
	"saiga": {
		"name": "Saiga-12K", "class": "Shotgun", "damage": 12.0, "rpm": 240, "auto": true, "burst": 0,
		"mag": 8, "reserve": 32, "reload": 3.0, "recoil_v": 2.6, "recoil_h": 1.2,
		"spread_hip": 7.0, "spread_ads": 5.0, "falloff": [12.0, 30.0, 0.22], "ads_time": 0.26,
		"ammo": "12g", "sfx": "gun_shotgun", "tier": 3, "move_mult": 0.92, "zoom": 0.0, "pellets": 9,
	},
}

## slot: optic | muzzle | grip | mag | stock
const ATTACHMENTS := {
	"red_dot": {"name": "Red Dot", "slot": "optic", "spread_ads": 0.85, "ads_time": 0.95, "zoom": 0.15},
	"holo": {"name": "Holo Sight", "slot": "optic", "spread_ads": 0.85, "ads_time": 0.95, "zoom": 0.2},
	"acog_4x": {"name": "4x ACOG", "slot": "optic", "spread_ads": 0.75, "ads_time": 1.15, "zoom": 2.0},
	"suppressor": {"name": "Suppressor", "slot": "muzzle", "recoil_v": 0.88, "falloff_end": 0.92, "sound_scale": 0.45},
	"compensator": {"name": "Compensator", "slot": "muzzle", "recoil_h": 0.7},
	"angled_grip": {"name": "Angled Grip", "slot": "grip", "recoil_h": 0.85, "spread_hip": 0.9},
	"vertical_grip": {"name": "Vertical Grip", "slot": "grip", "recoil_v": 0.85},
	"ext_mag": {"name": "Extended Mag", "slot": "mag", "mag": 1.4, "reload": 1.12},
	"quickdraw": {"name": "Quickdraw Mag", "slot": "mag", "reload": 0.82},
	"heavy_stock": {"name": "Heavy Stock", "slot": "stock", "recoil_v": 0.85, "spread_hip": 0.9},
}


static func ids() -> Array:
	return WEAPONS.keys()


static func get_weapon(id: String) -> Dictionary:
	if not WEAPONS.has(id):
		return {}
	return WEAPONS[id].duplicate(true)


static func tier_of(id: String) -> int:
	return int(WEAPONS.get(id, {}).get("tier", 1))


static func get_attachment(id: String) -> Dictionary:
	return ATTACHMENTS.get(id, {})


## Resolve final stats for a weapon with an attachment set:
## {"optic": "red_dot", "muzzle": "suppressor", ...}
static func resolved_stats(weapon_id: String, attachments: Dictionary) -> Dictionary:
	var stats := get_weapon(weapon_id)
	if stats.is_empty():
		return stats
	stats["mag_base"] = int(stats["mag"])
	stats["reload_base"] = float(stats["reload"])
	for slot in attachments.keys():
		var att_id: String = String(attachments[slot])
		var att := get_attachment(att_id)
		if att.is_empty():
			continue
		for k in att.keys():
			if k == "name" or k == "slot":
				continue
			var v: Variant = att[k]
			match k:
				"mag":
					stats["mag"] = int(round(float(stats["mag_base"]) * float(v)))
				"reload":
					stats["reload"] = float(stats["reload_base"]) * float(v)
				"zoom":
					stats["zoom"] = maxf(float(stats.get("zoom", 0.0)), float(v))
				"falloff_end":
					var fo: Array = stats["falloff"]
					stats["falloff"] = [fo[0], float(fo[1]) * float(v), fo[2]]
				_:
					if stats.has(k):
						stats[k] = float(stats[k]) * float(v)
	return stats


static func random_weapon(tier_max: int, rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	for id in WEAPONS.keys():
		if int(WEAPONS[id]["tier"]) <= tier_max:
			pool.append(id)
	if pool.is_empty():
		return "m9a3"
	return String(pool[rng.randi() % pool.size()])


static func random_attachment(rng: RandomNumberGenerator) -> String:
	var pool: Array = ATTACHMENTS.keys()
	return String(pool[rng.randi() % pool.size()])
