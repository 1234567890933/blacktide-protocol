class_name LootItem
extends Node3D
## A single ground item. Interaction is distance-based (no Area3D), which keeps
## 60 actors × 100+ items off the physics broadphase entirely.

const COLORS := {
	"weapon": Color(0.85, 0.55, 0.18),
	"ammo": Color(0.55, 0.62, 0.30),
	"heal": Color(0.75, 0.25, 0.28),
	"plate": Color(0.30, 0.55, 0.80),
	"throwable": Color(0.60, 0.45, 0.75),
	"attachment": Color(0.80, 0.80, 0.40),
}

var item: Dictionary = {}
var _mesh: MeshInstance3D
var _bob_time := 0.0
var _label: Label3D
var _taken := false


func setup(p_item: Dictionary) -> void:
	item = p_item
	add_to_group("loot")
	_bob_time = randf() * TAU
	_build_visual()


func _build_visual() -> void:
	var kind := String(item.get("kind", "ammo"))
	var color: Color = COLORS.get(kind, Color(0.7, 0.7, 0.7))
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	match kind:
		"weapon":
			box.size = Vector3(0.75, 0.10, 0.20)
		"plate":
			box.size = Vector3(0.36, 0.30, 0.10)
		"heal":
			box.size = Vector3(0.22, 0.22, 0.14)
		"attachment":
			box.size = Vector3(0.18, 0.12, 0.24)
		"throwable":
			box.size = Vector3(0.18, 0.24, 0.18)
		_:
			box.size = Vector3(0.24, 0.16, 0.16)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.6
	_mesh.material_override = mat
	_mesh.position.y = 0.25
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_label = Label3D.new()
	_label.text = _display_name()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 42
	_label.pixel_size = 0.0035
	_label.modulate = Color(1, 1, 1, 0.9)
	_label.outline_size = 12
	_label.no_depth_test = false
	_label.position.y = 0.62
	_label.visible = false   # shown only when the player is close
	add_child(_label)


func _display_name() -> String:
	match String(item.get("kind", "")):
		"weapon":
			return String(WeaponDB.get_weapon(String(item["id"])).get("name", "Weapon"))
		"ammo":
			return "%s x%d" % [String(WeaponDB.AMMO.get(String(item["ammo"]), {}).get("name", "Ammo")), int(item["qty"])]
		"heal":
			return "Field Dressing"
		"plate":
			return "Armour Plate"
		"throwable":
			return "Frag Grenade"
		"attachment":
			return String(WeaponDB.get_attachment(String(item["id"])).get("name", "Attachment"))
	return "Item"


var _label_timer := 0.0


func _process(delta: float) -> void:
	_bob_time += delta * 1.8
	if _mesh != null:
		_mesh.position.y = 0.25 + sin(_bob_time) * 0.04
		_mesh.rotation.y += delta * 0.9
	# Label proximity is polled at 5 Hz: 280 ground items must not cost 280
	# tree lookups per frame on a phone.
	_label_timer += delta
	if _label != null and _label_timer >= 0.2:
		_label_timer = 0.0
		var player := get_tree().get_first_node_in_group("player") as Node3D
		_label.visible = player != null and player.global_position.distance_to(global_position) < 6.0


func prompt_text() -> String:
	return "[F] Take " + _display_name()


func try_pickup(player: Player) -> bool:
	if _taken:
		return false
	var kind := String(item.get("kind", ""))
	match kind:
		"weapon":
			var dropped := player.equip_weapon(String(item["id"]), item.get("attachments", {}))
			if dropped != "":
				_convert_to_dropped_weapon(dropped)
				return true
		"ammo":
			player.pickup_auto(item)
		"heal":
			if player.inventory.heals >= Inventory.MAX_HEALS:
				return false
			player.pickup_auto(item)
		"plate":
			if player.inventory.plates >= Inventory.MAX_PLATES:
				return false
			player.pickup_auto(item)
		"throwable":
			if player.inventory.throwables >= Inventory.MAX_THROWABLES:
				return false
			player.pickup_auto(item)
		"attachment":
			# Attachments auto-slot into the active weapon when the slot is free.
			var att_id := String(item["id"])
			var slot := String(WeaponDB.get_attachment(att_id).get("slot", "optic"))
			var active := player.inventory.current()
			if active.is_empty():
				return false
			var atts: Dictionary = active.get("attachments", {})
			if atts.has(slot):
				return false
			atts[slot] = att_id
			active["attachments"] = atts
			player.emit_signal("weapon_changed", player.inventory.current_stats(), player.mag_rounds, 0)
	_consume()
	return true


func _convert_to_dropped_weapon(weapon_id: String) -> void:
	## Swapping leaves the old gun on the ground instead of deleting it.
	item = {"kind": "weapon", "id": weapon_id, "attachments": {}}
	if _label != null:
		_label.text = _display_name()


func bot_take(bot: Bot) -> bool:
	if _taken:
		return false
	var kind := String(item.get("kind", ""))
	match kind:
		"weapon":
			var new_tier := WeaponDB.tier_of(String(item["id"]))
			var current := bot.inventory.current_id()
			if current != "" and WeaponDB.tier_of(current) >= new_tier:
				return false
			bot.inventory.equip(String(item["id"]), item.get("attachments", {}))
			bot.inventory.add_ammo(String(WeaponDB.get_weapon(String(item["id"])).get("ammo", "556")), 60)
		"ammo":
			bot.inventory.add_ammo(String(item["ammo"]), int(item["qty"]))
		"heal":
			if not bot.inventory.add_heal():
				return false
		"plate":
			if bot.inventory.add_plate():
				bot.plates_held = bot.inventory.plates
			else:
				return false
		"throwable":
			if not bot.inventory.add_throwable():
				return false
		"attachment":
			bot.inventory.add_ammo("556", 10)
	_consume()
	return true


func _consume() -> void:
	_taken = true
	remove_from_group("loot")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.12)
	tween.tween_callback(queue_free)
