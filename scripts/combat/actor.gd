class_name Actor
extends CharacterBody3D
## Shared damage model for player and bots. Plate absorbs 60% of incoming
## damage until it breaks, health the rest. Headshots multiply before armour,
## which is why helmets never feel like magic in this sandbox.

signal died(actor: Actor, killer: Actor)
signal health_changed(health: float, max_health: float, plate: float)
signal damaged_by(attacker: Actor, amount: float, headshot: bool)

const HEAD_RATIO := 0.84
const LEG_RATIO := 0.32

var display_name := "Operator"
var squad_id := -1
var is_alive := true
var is_player := false

var max_health := 100.0
var health := 100.0
var plate_health := 0.0
var plate_capacity := 55.0
var plates_held := 0

var body_height := 1.8
var kills := 0
var damage_dealt := 0.0
var last_attacker: Actor = null
var last_attacker_time := -100.0

var heal_rate := 14.0
var _heal_remaining := 0.0
var _bleed := 0.0


func _ready() -> void:
	add_to_group("actors")
	collision_layer = 2
	collision_mask = 1 | 2
	health = max_health


func setup_body(height: float, radius: float) -> void:
	body_height = height
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = height
	capsule.radius = radius
	shape.shape = capsule
	shape.position = Vector3(0, height * 0.5, 0)
	add_child(shape)


## Hit-zone resolution is geometric: a raycast lands on the capsule, we compare
## its height against the actor's origin. No per-bone hitboxes needed, which is
## exactly the kind of shortcut that keeps 60 actors inside a mobile frame budget.
func hit_zone_at(world_point: Vector3) -> String:
	var local_y := world_point.y - global_position.y
	var ratio := local_y / maxf(body_height, 0.1)
	if ratio >= HEAD_RATIO:
		return "head"
	if ratio <= LEG_RATIO:
		return "leg"
	return "body"


func take_damage(amount: float, from: Actor, zone: String = "body") -> void:
	if not is_alive:
		return
	var dmg := amount
	match zone:
		"head":
			dmg *= 2.3
		"leg":
			dmg *= 0.75
	if plate_health > 0.0:
		var absorbed: float = minf(plate_health, dmg * 0.6)
		plate_health -= absorbed
		dmg -= absorbed
	health -= dmg
	if from != null:
		from.damage_dealt += amount
		last_attacker = from
		last_attacker_time = Time.get_ticks_msec() / 1000.0
	damaged_by.emit(from, amount, zone == "head")
	health_changed.emit(maxf(health, 0.0), max_health, plate_health)
	if health <= 0.0:
		die(from)


func die(killer: Actor) -> void:
	if not is_alive:
		return
	is_alive = false
	health = 0.0
	if killer != null and killer != self:
		killer.kills += 1
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	died.emit(self, killer)


func equip_plate() -> bool:
	if plates_held <= 0 or plate_health >= plate_capacity:
		return false
	plates_held -= 1
	plate_health = plate_capacity
	health_changed.emit(health, max_health, plate_health)
	return true


func begin_heal(seconds: float = 2.2) -> bool:
	if _heal_remaining > 0.0 or health >= max_health:
		return false
	_heal_remaining = seconds * heal_rate * 1.4
	return true


func add_bleed(amount: float) -> void:
	_bleed += amount


func tick_actor(delta: float) -> void:
	if not is_alive:
		return
	if _heal_remaining > 0.0:
		var step: float = minf(_heal_remaining, heal_rate * delta)
		health = minf(max_health, health + step)
		_heal_remaining -= step
		health_changed.emit(health, max_health, plate_health)
	elif _bleed > 0.0:
		var step: float = minf(_bleed, 4.0 * delta)
		_bleed -= step
		health -= step
		if health <= 0.0:
			die(last_attacker)


func is_healing() -> bool:
	return _heal_remaining > 0.0


func health_fraction() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
