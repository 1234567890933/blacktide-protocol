class_name LootSpawner
extends Node3D
## Fills the island from the map builder's loot points. Tier of the sector sets
## the weapon rarity ceiling, so Quay 7 and Holloway Strip are worth contesting.

const MAX_ITEMS := 420

var map_ref: Node = null
var rng := RandomNumberGenerator.new()
var spawned := 0


func setup(map_builder: Node, seed_value: int) -> void:
	map_ref = map_builder
	rng.seed = seed_value + 4507


func populate() -> void:
	if map_ref == null:
		return
	var points: Array = map_ref.get("loot_points")
	if points.is_empty():
		return
	for entry in points:
		if spawned >= MAX_ITEMS:
			break
		var data: Dictionary = entry
		var tier: int = int(data["tier"])
		var pos: Vector3 = data["pos"]
		var roll := rng.randf()
		var item := _roll_item(tier, roll)
		if item.is_empty():
			continue
		_spawn(item, pos + Vector3(rng.randf_range(-1.4, 1.4), 0.05, rng.randf_range(-1.4, 1.4)))
	# Guaranteed floor loot near each sector edge so no drop is empty.
	for entry in points.slice(0, mini(points.size(), 40)):
		var d: Dictionary = entry
		_spawn({"kind": "ammo", "ammo": "556", "qty": 30}, d["pos"] + Vector3(2.0, 0.05, 2.0))


func _roll_item(tier: int, roll: float) -> Dictionary:
	if roll < 0.34:
		var w := WeaponDB.random_weapon(mini(tier + 1, 4), rng)
		var atts := {}
		if rng.randf() < 0.45:
			var att := WeaponDB.random_attachment(rng)
			atts[String(WeaponDB.get_attachment(att).get("slot", "optic"))] = att
		return {"kind": "weapon", "id": w, "attachments": atts}
	if roll < 0.58:
		var ammo_types: Array = WeaponDB.AMMO.keys()
		var ammo_id := String(ammo_types[rng.randi() % ammo_types.size()])
		return {"kind": "ammo", "ammo": ammo_id, "qty": int(WeaponDB.AMMO[ammo_id]["stack"]) * (1 + rng.randi() % 3)}
	if roll < 0.74:
		return {"kind": "heal"}
	if roll < 0.88:
		return {"kind": "plate"}
	if roll < 0.95:
		return {"kind": "throwable"}
	return {"kind": "attachment", "id": WeaponDB.random_attachment(rng)}


func _spawn(item: Dictionary, pos: Vector3) -> void:
	var loot := LootItem.new()
	loot.setup(item)
	add_child(loot)
	loot.global_position = pos
	spawned += 1


func spawn_cache(pos: Vector3, weapon_id: String) -> void:
	if weapon_id != "":
		_spawn({"kind": "weapon", "id": weapon_id, "attachments": {}}, pos + Vector3(0.6, 0.05, 0))
	_spawn({"kind": "ammo", "ammo": "556", "qty": 30}, pos + Vector3(-0.6, 0.05, 0))
	_spawn({"kind": "plate"}, pos + Vector3(0, 0.05, 0.8))
