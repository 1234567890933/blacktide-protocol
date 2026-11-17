class_name Inventory
extends RefCounted
## Two-weapon loadout, ammo pools, armour plates, heals, throwables.
## Deliberately small and flat: every field is JSON-safe so a match state can
## be serialised for debugging or a future save-anywhere feature.

const MAX_PLATES := 4
const MAX_HEALS := 5
const MAX_THROWABLES := 3

var weapons: Array = [null, null]   # {"id": String, "attachments": Dictionary}
var active_slot := 0
var ammo: Dictionary = {}           # ammo_type -> reserve rounds
var plates := 0
var heals := 0
var throwables := 0


func _init() -> void:
	ammo = {}


func current() -> Dictionary:
	var w: Variant = weapons[active_slot]
	if w == null:
		return {}
	return w


func current_id() -> String:
	var w := current()
	return "" if w.is_empty() else String(w["id"])


func current_stats() -> Dictionary:
	var id := current_id()
	if id == "":
		return {}
	var w := current()
	var atts: Dictionary = w.get("attachments", {})
	return WeaponDB.resolved_stats(id, atts)


func equip(weapon_id: String, attachments: Dictionary = {}) -> String:
	## Returns the id of the weapon that was dropped ("" if none).
	var entry := {"id": weapon_id, "attachments": attachments.duplicate(true)}
	var dropped := ""
	# Prefer an empty slot, else replace the active weapon.
	if weapons[0] == null:
		weapons[0] = entry
		active_slot = 0
	elif weapons[1] == null:
		weapons[1] = entry
		active_slot = 1
	else:
		var old: Dictionary = weapons[active_slot]
		dropped = String(old["id"])
		weapons[active_slot] = entry
	var stats := WeaponDB.resolved_stats(weapon_id, attachments)
	var ammo_type := String(stats.get("ammo", "556"))
	if not ammo.has(ammo_type):
		ammo[ammo_type] = 0
	ammo[ammo_type] = int(ammo[ammo_type]) + int(stats.get("mag", 30))
	return dropped


func swap() -> void:
	if weapons[0] != null and weapons[1] != null:
		active_slot = 1 - active_slot


func add_ammo(ammo_type: String, amount: int) -> void:
	ammo[ammo_type] = int(ammo.get(ammo_type, 0)) + amount


func reserve_for(ammo_type: String) -> int:
	return int(ammo.get(ammo_type, 0))


func take_ammo(ammo_type: String, amount: int) -> int:
	var have := reserve_for(ammo_type)
	var taken: int = mini(have, amount)
	ammo[ammo_type] = have - taken
	return taken


func add_plate() -> bool:
	if plates >= MAX_PLATES:
		return false
	plates += 1
	return true


func add_heal() -> bool:
	if heals >= MAX_HEALS:
		return false
	heals += 1
	return true


func add_throwable() -> bool:
	if throwables >= MAX_THROWABLES:
		return false
	throwables += 1
	return true


func total_gear_score() -> int:
	var score := 0
	for w in weapons:
		if w != null:
			score += WeaponDB.tier_of(String(w["id"])) * 10
			score += int(w.get("attachments", {}).size()) * 2
	score += plates * 3 + heals * 2 + throwables
	return score
