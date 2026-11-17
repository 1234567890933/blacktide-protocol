class_name Bot
extends Actor
## Offline tactical AI. One state machine, four difficulty profiles, and a
## shared squad blackboard. Bots use the exact same ballistics, armour and
## healing code as the player, so nothing about a firefight is fake.
##
## CPU budget: logic runs at full 60 Hz inside 70 m of the player, at 8 Hz
## beyond it, and at 3 Hz when the bot is outside the cordon and unobserved.

enum State { DROP, LOOT, ROTATE, ENGAGE, COVER, HEAL, FLANK, HOLD, DEAD }

const PROFILES := {
	"RECRUIT": {
		"reaction": 0.62, "aim_error_deg": 4.2, "view_range": 55.0, "aggression": 0.35,
		"burst": 3, "heal_chance": 0.35, "cover_use": 0.35, "flank_chance": 0.1,
		"accuracy_growth": 0.35, "move_speed": 3.9,
	},
	"REGULAR": {
		"reaction": 0.38, "aim_error_deg": 2.6, "view_range": 72.0, "aggression": 0.55,
		"burst": 5, "heal_chance": 0.6, "cover_use": 0.6, "flank_chance": 0.3,
		"accuracy_growth": 0.6, "move_speed": 4.3,
	},
	"VETERAN": {
		"reaction": 0.24, "aim_error_deg": 1.5, "view_range": 88.0, "aggression": 0.75,
		"burst": 7, "heal_chance": 0.8, "cover_use": 0.8, "flank_chance": 0.5,
		"accuracy_growth": 0.85, "move_speed": 4.7,
	},
	"ELITE": {
		"reaction": 0.15, "aim_error_deg": 0.9, "view_range": 105.0, "aggression": 0.9,
		"burst": 9, "heal_chance": 0.95, "cover_use": 0.95, "flank_chance": 0.65,
		"accuracy_growth": 1.0, "move_speed": 5.0,
	},
}

const FOV_DEG := 130.0
const BODY_COLORS := [
	Color(0.31, 0.36, 0.28), Color(0.28, 0.30, 0.34), Color(0.35, 0.30, 0.24),
	Color(0.24, 0.32, 0.33), Color(0.33, 0.26, 0.26), Color(0.26, 0.27, 0.31),
	Color(0.30, 0.33, 0.26), Color(0.34, 0.31, 0.29),
]

var profile_name := "REGULAR"
var state: int = State.DROP
var map_ref: Node = null
var squad_manager: Node = null

var inventory := Inventory.new()
var mag_rounds := 0
var fire_cooldown := 0.0
var burst_left := 0
var burst_pause := 0.0
var reaction_left := 0.0
var aim_error := 0.0

var target: Actor = null
var target_visible := false
var last_seen_pos := Vector3.ZERO
var last_seen_time := -100.0
var alert_pos := Vector3.ZERO
var has_alert := false

var waypoint := Vector3.ZERO
var has_waypoint := false
var strafe_dir := 1.0
var strafe_timer := 0.0
var _repath_timer := 0.0
var stuck_timer := 0.0
var _last_pos := Vector3.ZERO
var _logic_accum := 0.0
var _space: PhysicsDirectSpaceState3D
var _mesh_root: Node3D
var _rng := RandomNumberGenerator.new()
var _squad_target_shared := false
var _flank_timer := 0.0
var deploy_grace := 0.0   # seconds after landing before a bot may open fire
var dbg_los_fail := 0
var dbg_fired := 0
var dbg_damage := 0.0
var dbg_noammo := 0


func _ready() -> void:
	super._ready()
	_rng.seed = randi()
	display_name = "Operator"
	body_height = 1.8
	setup_body(1.8, 0.36)
	_build_body()
	_space = get_world_3d().direct_space_state
	_last_pos = global_position


func _build_body() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	var color: Color = BODY_COLORS[int(abs(squad_id)) % BODY_COLORS.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.35
	torso.mesh = cap
	torso.material_override = mat
	torso.position = Vector3(0, 1.0, 0)
	_mesh_root.add_child(torso)
	var head_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head_mesh.mesh = sphere
	head_mesh.material_override = mat
	head_mesh.position = Vector3(0, 1.78, 0)
	_mesh_root.add_child(head_mesh)
	var pack := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.42, 0.2)
	pack.mesh = box
	pack.material_override = mat
	pack.position = Vector3(0, 1.12, 0.26)
	_mesh_root.add_child(pack)
	var rifle := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.07, 0.07, 0.72)
	rifle.mesh = rb
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.1, 0.1, 0.11)
	gun_mat.metallic = 0.7
	gun_mat.roughness = 0.4
	rifle.material_override = gun_mat
	rifle.position = Vector3(0.2, 1.15, -0.34)
	_mesh_root.add_child(rifle)


func configure(p_profile: String, p_map: Node, p_squad_manager: Node, p_squad_id: int, p_name: String) -> void:
	profile_name = p_profile if PROFILES.has(p_profile) else "REGULAR"
	map_ref = p_map
	squad_manager = p_squad_manager
	squad_id = p_squad_id
	display_name = p_name
	var prof: Dictionary = PROFILES[profile_name]
	max_health = 100.0
	health = 100.0
	plate_capacity = 55.0
	plate_health = plate_capacity
	plates_held = 1
	inventory = Inventory.new()
	inventory.equip("m9a3")
	inventory.add_ammo("9mm", 60)
	_refill_mag()
	aim_error = float(prof["aim_error_deg"])


func _refill_mag() -> void:
	var stats := inventory.current_stats()
	mag_rounds = int(stats.get("mag", 12))


func profile() -> Dictionary:
	return PROFILES[profile_name]


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	tick_actor(delta)
	# Throttled logic: near the player we run hot, far away we coast.
	var player := _player()
	var dist := 9999.0
	if player != null:
		dist = global_position.distance_to(player.global_position)
	var interval := 0.0
	if dist < 70.0:
		interval = 0.0
	elif dist < 160.0:
		interval = 0.125
	else:
		interval = 0.33
	_logic_accum += delta
	if _logic_accum >= interval:
		_logic_accum = 0.0
		_think(delta + interval)
	_apply_gravity(delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()


func _player() -> Player:
	var p := get_tree().get_first_node_in_group("player")
	if p is Player:
		return p
	return null


func _think(delta: float) -> void:
	if state == State.DEAD:
		return
	deploy_grace = maxf(0.0, deploy_grace - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	burst_pause = maxf(0.0, burst_pause - delta)
	reaction_left = maxf(0.0, reaction_left - delta)
	strafe_timer -= delta
	_flank_timer -= delta
	_sense()
	_decide(delta)
	_act(delta)
	_check_stuck(delta)


func _sense() -> void:
	var prof := profile()
	var view_range := float(prof["view_range"])
	if target != null and (not target.is_alive or global_position.distance_to(target.global_position) > view_range * 1.25):
		target = null
		target_visible = false
	var best: Actor = null
	var best_score := INF
	var forward := -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("actors"):
		var other := node as Actor
		if other == null or other == self or not other.is_alive:
			continue
		if other.squad_id == squad_id and squad_id >= 0:
			continue
		var to := other.global_position - global_position
		var dist := to.length()
		if dist > view_range:
			continue
		var flat := Vector3(to.x, 0, to.z).normalized()
		var fwd := Vector3(forward.x, 0, forward.z).normalized()
		var in_fov := rad_to_deg(acos(clampf(flat.dot(fwd), -1.0, 1.0))) <= FOV_DEG * 0.5
		var close := dist < 12.0
		if not in_fov and not close:
			continue
		var eye := global_position + Vector3(0, body_height * 0.85, 0)
		var target_point := other.global_position + Vector3(0, other.body_height * 0.6, 0)
		if not Ballistics.has_line_of_sight(_space, eye, target_point, [get_rid(), other.get_rid()]):
			continue
		var score := dist
		if other.is_player:
			score *= 0.85   # players get hunted a little harder
		if score < best_score:
			best_score = score
			best = other
	if best != null:
		if target != best:
			# New contact: reaction delay before the bot can shoot.
			reaction_left = float(prof["reaction"]) * _rng.randf_range(0.75, 1.35)
			if squad_manager != null:
				squad_manager.call("alert", squad_id, best)
		target = best
		target_visible = true
		last_seen_pos = best.global_position
		last_seen_time = Time.get_ticks_msec() / 1000.0
	elif target != null:
		target_visible = false
	# Squad-shared contact: pull the target from the blackboard if a teammate
	# sees someone we do not.
	if target == null and squad_manager != null and not _squad_target_shared:
		var shared: Actor = squad_manager.call("squad_target", squad_id)
		if shared != null and shared.is_alive:
			target = shared
			last_seen_pos = shared.global_position
			has_alert = true
			alert_pos = shared.global_position
			_squad_target_shared = true


func _decide(delta: float) -> void:
	var prof := profile()
	var health_frac := health_fraction()
	if health_frac < 0.42 and inventory.heals > 0 and _rng.randf() < float(prof["heal_chance"]):
		if state != State.HEAL:
			state = State.HEAL
			_heal_timer = 0.0
		return
	if target != null and target.is_alive:
		if target_visible:
			if health_frac < 0.35 and _rng.randf() < float(prof["cover_use"]):
				state = State.COVER
			elif _rng.randf() < float(prof["flank_chance"]) and _flank_timer <= 0.0:
				state = State.FLANK
				_flank_timer = 6.0
				_pick_flank_point()
			else:
				state = State.ENGAGE
			return
		else:
			# Lost sight: push the last known position, or hold and watch.
			if Time.get_ticks_msec() / 1000.0 - last_seen_time < 6.0:
				state = State.ENGAGE
				if not has_waypoint:
					waypoint = last_seen_pos
					has_waypoint = true
			else:
				state = State.ROTATE
				has_waypoint = false
			return
	# No target: loot, then rotate toward the safe zone.
	var loot := _nearest_loot(28.0)
	if loot != null:
		state = State.LOOT
		waypoint = (loot as Node3D).global_position
		has_waypoint = true
		return
	if state == State.LOOT:
		state = State.ROTATE
		has_waypoint = false
	_repath_timer -= delta
	if not has_waypoint or _repath_timer <= 0.0:
		_repath_timer = _rng.randf_range(3.5, 7.0)
		waypoint = _zone_waypoint()
		has_waypoint = true
	if state != State.ROTATE and state != State.DROP:
		state = State.ROTATE


var _heal_timer := 0.0


func _act(delta: float) -> void:
	match state:
		State.ENGAGE:
			_act_engage(delta)
		State.COVER:
			_act_cover(delta)
		State.FLANK:
			_act_flank(delta)
		State.LOOT:
			_act_loot(delta)
		State.HEAL:
			_act_heal(delta)
		State.ROTATE, State.DROP, State.HOLD:
			_act_move_to(waypoint, float(profile()["move_speed"]), delta)


func _act_engage(delta: float) -> void:
	var prof := profile()
	if target == null:
		_act_move_to(waypoint, float(prof["move_speed"]), delta)
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	_face(to_target)
	# Strafe while shooting; shorter range means wider arcs.
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = _rng.randf_range(0.6, 1.6)
		strafe_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	var strafe := global_transform.basis.x * strafe_dir
	var desired := Vector3.ZERO
	var ideal := 26.0 if String(inventory.current_stats().get("class", "AR")) == "Sniper" else 14.0
	if dist > ideal * 1.4:
		desired = to_target.normalized() * float(prof["move_speed"]) * 0.8
	elif dist < ideal * 0.6:
		desired = -to_target.normalized() * float(prof["move_speed"]) * 0.7
	desired += strafe * float(prof["move_speed"]) * 0.55
	_apply_move(desired, delta)
	_try_fire(dist)


func _act_cover(delta: float) -> void:
	var prof := profile()
	if target == null:
		_act_move_to(waypoint, float(prof["move_speed"]), delta)
		return
	if not has_waypoint or _rng.randf() < 0.02:
		waypoint = _find_cover_point(target.global_position)
		has_waypoint = true
	_act_move_to(waypoint, float(prof["move_speed"]), delta)
	if target_visible and reaction_left <= 0.0:
		_try_fire(global_position.distance_to(target.global_position))


func _act_flank(delta: float) -> void:
	var prof := profile()
	if target == null:
		_act_move_to(waypoint, float(prof["move_speed"]), delta)
		return
	if not has_waypoint:
		_pick_flank_point()
	_act_move_to(waypoint, float(prof["move_speed"]) * 1.1, delta)
	if target_visible:
		_try_fire(global_position.distance_to(target.global_position))
	elif global_position.distance_to(waypoint) < 3.0:
		_face(target.global_position - global_position)
		state = State.ENGAGE


func _act_loot(delta: float) -> void:
	var prof := profile()
	var loot := _nearest_loot(30.0)
	if loot == null:
		state = State.ROTATE
		has_waypoint = false
		return
	waypoint = (loot as Node3D).global_position
	_act_move_to(waypoint, float(prof["move_speed"]), delta)
	if global_position.distance_to(waypoint) < 2.4:
		if loot.has_method("bot_take"):
			var got: bool = loot.call("bot_take", self)
			if got:
				_refill_mag()
				has_waypoint = false


func _act_heal(delta: float) -> void:
	_heal_timer += delta
	if not is_healing():
		if inventory.heals > 0:
			begin_heal(2.4)
			inventory.heals -= 1
		else:
			state = State.ROTATE
			return
	if health_fraction() > 0.85 or _heal_timer > 5.0:
		state = State.ROTATE
		has_waypoint = false


func _act_move_to(point: Vector3, speed: float, delta: float) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 2.0:
		has_waypoint = false
		_apply_move(Vector3.ZERO, delta)
		return
	var dir := _avoid(to.normalized())
	_face(dir)
	_apply_move(dir * speed, delta)


func _avoid(dir: Vector3) -> Vector3:
	## Two-probe obstacle avoidance. Cheap, and good enough around container
	## stacks because the map builder leaves 3 m corridors between structures.
	var origin := global_position + Vector3(0, 0.9, 0)
	for offset_deg in [0.0, 28.0, -28.0, 60.0, -60.0]:
		var probe_dir := dir.rotated(Vector3.UP, deg_to_rad(offset_deg))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + probe_dir * 3.2, 1)
		if _space.intersect_ray(q).is_empty():
			return probe_dir
	return dir.rotated(Vector3.UP, PI * 0.5)


func _apply_move(desired: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, desired.x, 26.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 26.0 * delta)


func _face(to: Vector3) -> void:
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() < 0.01:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.18)


func _try_fire(dist: float) -> void:
	if target == null or not target.is_alive or reaction_left > 0.0:
		return
	if deploy_grace > 0.0:
		return
	var stats := inventory.current_stats()
	if stats.is_empty():
		return
	if mag_rounds <= 0:
		if inventory.reserve_for(String(stats.get("ammo", "556"))) > 0:
			mag_rounds = mini(int(stats.get("mag", 30)), inventory.reserve_for(String(stats.get("ammo", "556"))))
			inventory.take_ammo(String(stats.get("ammo", "556")), mag_rounds)
		else:
			dbg_noammo += 1
			inventory.equip("m9a3")
			inventory.add_ammo("9mm", 34)
			_refill_mag()
			return
	if fire_cooldown > 0.0 or burst_pause > 0.0:
		return
	if burst_left <= 0:
		burst_left = int(profile()["burst"])
	var muzzle_pos := global_position + Vector3(0, body_height * 0.82, 0) + (-global_transform.basis.z) * 0.5
	var aim_point := target.global_position + Vector3(0, target.body_height * 0.55, 0)
	var eye := global_position + Vector3(0, body_height * 0.85, 0)
	if not Ballistics.has_line_of_sight(_space, eye, aim_point, [get_rid(), target.get_rid()]):
		dbg_los_fail += 1
		return
	var dir := (aim_point - muzzle_pos).normalized()
	# Aim error: shrinks with accuracy_growth over time on target, grows with
	# distance and target speed. This is what makes bot fights feel human.
	var prof := profile()
	var error_deg: float = float(prof["aim_error_deg"]) * (0.6 + dist / 90.0)
	error_deg *= lerpf(1.0, 0.55, float(prof["accuracy_growth"]))
	dir = dir.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-error_deg, error_deg)))
	dir = dir.rotated(Vector3.RIGHT, deg_to_rad(_rng.randf_range(-error_deg, error_deg)))
	var result := Ballistics.fire(_space, self, muzzle_pos, dir, stats, [get_rid()])
	VFX.tracer(get_tree().current_scene, muzzle_pos, result["position"])
	VFX.muzzle_flash(get_tree().current_scene, muzzle_pos, dir)
	AudioDirector.play_at(String(stats.get("sfx", "gun_ar")), muzzle_pos, -4.0, _rng.randf_range(0.9, 1.1))
	if result["hit"] and result["actor"] != null:
		AudioDirector.play("hit_flesh", -8.0, _rng.randf_range(0.9, 1.1))
	mag_rounds -= 1
	dbg_fired += 1
	dbg_damage += float(result.get("damage", 0.0))
	fire_cooldown = 60.0 / maxf(float(stats.get("rpm", 600)), 30.0)
	burst_left -= 1
	if burst_left <= 0:
		burst_pause = _rng.randf_range(0.25, 0.85) * lerpf(1.4, 0.7, float(prof["aggression"]))


var _loot_cache: Node = null
var _loot_cache_timer := 0.0


func _nearest_loot(radius: float) -> Node:
	## Cached for 0.6 s — a bot does not need frame-accurate loot awareness,
	## and this keeps the item scan off the hot path.
	_loot_cache_timer -= 0.1
	if _loot_cache_timer > 0.0 and is_instance_valid(_loot_cache):
		return _loot_cache
	_loot_cache_timer = 0.6
	var best: Node = null
	var best_dist := radius
	for node in get_tree().get_nodes_in_group("loot"):
		var item := node as Node3D
		if item == null or not item.visible:
			continue
		var d := global_position.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	_loot_cache = best
	return best


func _zone_waypoint() -> Vector3:
	if map_ref == null or not map_ref.has_method("random_point_in_zone"):
		return global_position + Vector3(_rng.randf_range(-40, 40), 0, _rng.randf_range(-40, 40))
	return map_ref.call("random_point_in_zone", _rng)


func _find_cover_point(threat_pos: Vector3) -> Vector3:
	if map_ref == null or not map_ref.has_method("nearest_cover"):
		return global_position + (global_position - threat_pos).normalized() * 8.0
	return map_ref.call("nearest_cover", global_position, threat_pos)


func _pick_flank_point() -> void:
	if target == null:
		return
	var to := (global_position - target.global_position)
	to.y = 0.0
	var side := to.normalized().rotated(Vector3.UP, deg_to_rad(70.0 if _rng.randf() < 0.5 else -70.0))
	waypoint = target.global_position + side * _rng.randf_range(14.0, 24.0)
	waypoint.y = global_position.y
	has_waypoint = true


func _check_stuck(delta: float) -> void:
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if moved < 0.05 and state in [State.ROTATE, State.LOOT]:
		stuck_timer += delta
		if stuck_timer > 1.5:
			stuck_timer = 0.0
			waypoint = global_position + Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-14, 14))
			has_waypoint = true
	else:
		stuck_timer = 0.0


func receive_gunshot(from_pos: Vector3, radius: float) -> void:
	## Suppressors shrink the radius, so a quiet loadout actually keeps you hidden.
	if global_position.distance_to(from_pos) <= radius:
		has_alert = true
		alert_pos = from_pos
		if target == null:
			waypoint = from_pos
			has_waypoint = true


func die(killer: Actor) -> void:
	if not is_alive:
		return
	super.die(killer)
	state = State.DEAD
	_mesh_root.rotate_x(deg_to_rad(-82.0))
	_mesh_root.position.y = 0.1
	if killer != null and killer.is_player:
		StoryDirector.radio("kill")
	# Drop a cache so the fight has consequences.
	if map_ref != null and map_ref.has_method("drop_death_cache"):
		map_ref.call("drop_death_cache", global_position, inventory.current_id())
