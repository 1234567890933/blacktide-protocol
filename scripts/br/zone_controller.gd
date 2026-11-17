class_name ZoneController
extends Node
## The cordon. A Battle Royale circle that is also the story clock: every phase
## fires a narrative beat and seals the sectors it swallows.

signal phase_started(index: int, label: String)
signal phase_warning(index: int, seconds_left: float)
signal zone_updated(center: Vector3, radius: float)
signal actor_damaged_outside(actor: Actor, damage: float)

## wait  : seconds before the wall starts moving
## move  : seconds the wall takes to close
## radius: radius at the END of the move
## dps   : damage per second outside the wall
const PHASES := [
	{"wait": 95.0, "move": 55.0, "radius": 430.0, "dps": 1.0, "label": "CORDON — PHASE 1"},
	{"wait": 70.0, "move": 45.0, "radius": 320.0, "dps": 1.5, "label": "CORDON — PHASE 2"},
	{"wait": 60.0, "move": 40.0, "radius": 225.0, "dps": 2.0, "label": "CORDON — PHASE 3"},
	{"wait": 55.0, "move": 35.0, "radius": 150.0, "dps": 3.0, "label": "CORDON — PHASE 4"},
	{"wait": 45.0, "move": 30.0, "radius": 98.0, "dps": 4.5, "label": "CORDON — PHASE 5"},
	{"wait": 40.0, "move": 28.0, "radius": 60.0, "dps": 6.0, "label": "CORDON — PHASE 6"},
	{"wait": 32.0, "move": 24.0, "radius": 34.0, "dps": 9.0, "label": "CORDON — PHASE 7"},
	{"wait": 26.0, "move": 20.0, "radius": 14.0, "dps": 14.0, "label": "CORDON — LAST STANDING"},
]

var phase_index := -1
var center := Vector3.ZERO
var radius := 470.0
var target_center := Vector3.ZERO
var target_radius := 470.0
var timer := 0.0
var shrinking := false
var running := false
var map_ref: Node = null
var rng := RandomNumberGenerator.new()
var _damage_accum: Dictionary = {}   # actor -> seconds accumulated
var _locked_sectors: Array = []
var _warned := false


func setup(map_builder: Node, seed_value: int) -> void:
	map_ref = map_builder
	rng.seed = seed_value + 991
	center = Vector3.ZERO
	radius = 470.0
	target_center = center
	target_radius = radius
	phase_index = -1
	_locked_sectors.clear()
	_damage_accum.clear()


func start() -> void:
	running = true
	_begin_phase(0)


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	timer -= delta
	if shrinking:
		var t: float = clampf(1.0 - timer / maxf(_current_move_time, 0.01), 0.0, 1.0)
		radius = lerpf(_start_radius, target_radius, t)
		center = _start_center.lerp(target_center, t)
		zone_updated.emit(center, radius)
		if timer <= 0.0:
			shrinking = false
			radius = target_radius
			center = target_center
			zone_updated.emit(center, radius)
			if phase_index + 1 < PHASES.size():
				_begin_phase(phase_index + 1)
			else:
				running = false
	else:
		if timer <= 0.0:
			shrinking = true
			_start_radius = radius
			_start_center = center
			_current_move_time = float(PHASES[phase_index]["move"])
			timer = _current_move_time
			_warned = false
			AudioDirector.play("zone_warn", -6.0)
			StoryDirector.radio("zone_close")
		elif timer < 8.0 and not _warned:
			_warned = true
			phase_warning.emit(phase_index, timer)
	_apply_zone_damage(delta)


var _start_radius := 470.0
var _start_center := Vector3.ZERO
var _current_move_time := 40.0


func _begin_phase(index: int) -> void:
	phase_index = index
	var p: Dictionary = PHASES[index]
	target_radius = float(p["radius"])
	timer = float(p["wait"])
	shrinking = false
	# New centre stays inside the current circle so the final ring is reachable.
	var offset_radius: float = maxf(radius - target_radius, 0.0) * 0.55
	var angle := rng.randf() * TAU
	var offset := Vector3(cos(angle), 0, sin(angle)) * offset_radius * rng.randf()
	target_center = center + offset
	if map_ref != null and map_ref.has_method("height_at"):
		target_center.y = map_ref.call("height_at", target_center.x, target_center.z)
	phase_started.emit(index, String(p["label"]))
	StoryDirector.fire_phase(index)
	zone_updated.emit(center, radius)
	_lock_sectors_outside()


func _lock_sectors_outside() -> void:
	## Sectors whose anchor falls outside the NEW circle are "sealed" — pure
	## narrative sugar, but it teaches players where the next fight will be.
	if map_ref == null or not map_ref.has_method("sector_at"):
		return
	for sector_id in StoryDirector.SECTORS.keys():
		var anchor: Dictionary = MapBuilder.SECTOR_ANCHORS.get(sector_id, {})
		if anchor.is_empty():
			continue
		var c: Vector2 = anchor["pos"]
		var pos := Vector3(c.x, 0, c.y)
		if pos.distance_to(target_center) > target_radius and not _locked_sectors.has(sector_id):
			_locked_sectors.append(sector_id)
			StoryDirector.sector_locked(String(sector_id))


func _apply_zone_damage(delta: float) -> void:
	var dps := 0.0
	if phase_index >= 0:
		dps = float(PHASES[phase_index]["dps"])
	if dps <= 0.0:
		return
	for node in get_tree().get_nodes_in_group("actors"):
		var actor := node as Actor
		if actor == null or not actor.is_alive:
			continue
		if is_inside(actor.global_position):
			_damage_accum.erase(actor)
			continue
		var acc: float = float(_damage_accum.get(actor, 0.0)) + delta
		if acc >= 1.0:
			var ticks := int(floor(acc))
			acc -= float(ticks)
			actor.take_damage(dps * float(ticks), null, "body")
			actor_damaged_outside.emit(actor, dps * float(ticks))
			if actor.is_player:
				AudioDirector.play("zone_damage", -8.0)
		_damage_accum[actor] = acc


func is_inside(pos: Vector3) -> bool:
	var flat := Vector3(pos.x - center.x, 0, pos.z - center.z)
	return flat.length() <= radius


func distance_to_edge(pos: Vector3) -> float:
	var flat := Vector3(pos.x - center.x, 0, pos.z - center.z)
	return radius - flat.length()


func random_point_inside(local_rng: RandomNumberGenerator) -> Vector3:
	var angle := local_rng.randf() * TAU
	var dist := sqrt(local_rng.randf()) * radius * 0.82
	return Vector3(center.x + cos(angle) * dist, 0, center.z + sin(angle) * dist)


func phase_label() -> String:
	if phase_index < 0 or phase_index >= PHASES.size():
		return "STANDBY"
	return String(PHASES[phase_index]["label"])


func time_to_next() -> float:
	return maxf(timer, 0.0)
