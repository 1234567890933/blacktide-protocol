class_name Player
extends Actor
## Tactical operator controller: sprint / slide / crouch / prone, ADS with a
## real recoil pattern, magazine-driven gunplay and plate-based armour.
## Tuned for touch: every action is reachable from the on-screen rig, and the
## controller never requires a second thumbstick click or a double-tap.

signal weapon_changed(stats: Dictionary, mag: int, reserve: int)
signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal fired(stats: Dictionary)
signal interact_prompt(text: String)
signal stance_changed(stance: int)
signal landed

enum Stance { STAND, CROUCH, PRONE }

const SPEED_WALK := 4.7
const SPEED_SPRINT := 7.6
const SPEED_CROUCH := 2.5
const SPEED_PRONE := 1.15
const SPEED_ADS := 2.7
const ACCEL_GROUND := 14.0
const ACCEL_AIR := 3.0
const JUMP_VELOCITY := 6.4
const SLIDE_SPEED := 9.4
const SLIDE_TIME := 0.72
const MOUSE_SCALE := 0.14
const TOUCH_SCALE := 0.22

var head: Node3D
var camera: Camera3D
var viewmodel: Node3D
var muzzle: Node3D

var inventory := Inventory.new()
var mag_rounds := 0
var reload_time_left := 0.0
var fire_cooldown := 0.0
var burst_left := 0
var burst_cooldown := 0.0

var stance: int = Stance.STAND
var ads_blend := 0.0
var is_sprinting := false
var is_sliding := false
var slide_time_left := 0.0
var pitch := 0.0
var yaw := 0.0
var recoil_pitch := 0.0
var recoil_yaw := 0.0
var spread_growth := 0.0
var shake := 0.0

var _bob := 0.0
var _footstep_accum := 0.0
var _space: PhysicsDirectSpaceState3D
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _nearby_loot: Node = null
var _match_started := false
var _shots_fired := 0
var _headshots := 0
var freefall := false


func _ready() -> void:
	super._ready()
	display_name = "SALT-6 'Gull'"
	is_player = true
	max_health = 100.0
	health = max_health
	plate_capacity = 55.0
	body_height = 1.8
	_build_body()
	_build_camera()
	_build_viewmodel()
	_space = get_world_3d().direct_space_state
	if not InputHub.using_touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_body() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.height = 1.8
	_capsule.radius = 0.36
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position = Vector3(0, 0.9, 0)
	add_child(_collision)


func _build_camera() -> void:
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.64, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 900.0
	camera.current = true
	head.add_child(camera)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.18, -0.12, -0.55)
	camera.add_child(muzzle)


## Blocky procedural viewmodel — readable silhouette at phone resolution and
## replaced automatically by a GLB if an art pack is present.
func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	camera.add_child(viewmodel)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.13, 0.14, 0.15)
	body_mat.metallic = 0.6
	body_mat.roughness = 0.45
	var parts := [
		{"size": Vector3(0.075, 0.075, 0.52), "pos": Vector3(0, -0.055, -0.30)},   # receiver
		{"size": Vector3(0.045, 0.045, 0.34), "pos": Vector3(0, -0.045, -0.66)},   # barrel
		{"size": Vector3(0.05, 0.16, 0.09), "pos": Vector3(0, -0.14, -0.26)},      # grip
		{"size": Vector3(0.055, 0.11, 0.14), "pos": Vector3(0, -0.12, -0.44)},     # mag
		{"size": Vector3(0.05, 0.07, 0.22), "pos": Vector3(0, -0.005, -0.14)},     # stock
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p["size"]
		mi.mesh = bm
		mi.material_override = body_mat
		mi.position = p["pos"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewmodel.add_child(mi)


func start_match(loadout_weapon: String = "m9a3") -> void:
	_match_started = true
	inventory = Inventory.new()
	inventory.equip(loadout_weapon)
	inventory.add_ammo(String(inventory.current_stats().get("ammo", "9mm")), 60)
	inventory.add_plate()
	inventory.add_heal()
	plates_held = inventory.plates
	plate_health = plate_capacity
	_refill_mag()
	_emit_weapon()


func _refill_mag() -> void:
	var stats := inventory.current_stats()
	if stats.is_empty():
		mag_rounds = 0
		return
	mag_rounds = int(stats.get("mag", 0))


func _emit_weapon() -> void:
	var stats := inventory.current_stats()
	if stats.is_empty():
		return
	var ammo_type := String(stats.get("ammo", "556"))
	weapon_changed.emit(stats, mag_rounds, inventory.reserve_for(ammo_type))


func _physics_process(delta: float) -> void:
	if freefall:
		_handle_look(delta)
		_freefall_move(delta)
		_update_camera(delta)
		return
	if not is_alive:
		velocity = velocity.move_toward(Vector3.ZERO, 20.0 * delta)
		velocity.y -= 18.0 * delta
		move_and_slide()
		return
	tick_actor(delta)
	_handle_look(delta)
	_handle_stance(delta)
	_handle_movement(delta)
	_handle_combat(delta)
	_update_camera(delta)
	_scan_interactables()


func set_freefall(enabled: bool) -> void:
	## Deployment is a real descent: you steer the drop, the canopy auto-opens,
	## and where you land is where the match starts for you.
	freefall = enabled
	velocity = Vector3.ZERO
	if enabled:
		viewmodel.visible = false
	else:
		viewmodel.visible = true


func _freefall_move(delta: float) -> void:
	var input := InputHub.move_vector()
	var wish := (transform.basis.x * input.x - transform.basis.z * input.y)
	var speed := 16.0
	var fall := 26.0
	if global_position.y < 65.0:
		speed = 7.0
		fall = 7.5
	velocity.x = move_toward(velocity.x, wish.x * speed, 30.0 * delta)
	velocity.z = move_toward(velocity.z, wish.z * speed, 30.0 * delta)
	velocity.y = -fall
	move_and_slide()
	if is_on_floor() or global_position.y <= 0.6:
		set_freefall(false)
		velocity = Vector3.ZERO
		landed.emit()


func _handle_look(_delta: float) -> void:
	var look := InputHub.consume_look()
	var scale := TOUCH_SCALE if InputHub.using_touch else MOUSE_SCALE
	yaw -= look.x * scale
	pitch = clampf(pitch - look.y * scale, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotation.y = yaw


func _handle_stance(delta: float) -> void:
	if InputHub.just_pressed("crouch"):
		if stance == Stance.STAND and is_sprinting:
			_start_slide()
		elif stance == Stance.STAND:
			_set_stance(Stance.CROUCH)
		elif stance == Stance.CROUCH:
			_set_stance(Stance.STAND)
	if InputHub.just_pressed("prone"):
		_set_stance(Stance.PRONE if stance != Stance.PRONE else Stance.STAND)
	if is_sliding:
		slide_time_left -= delta
		if slide_time_left <= 0.0 or not InputHub.is_action("crouch"):
			is_sliding = false
			_set_stance(Stance.CROUCH)


func _start_slide() -> void:
	is_sliding = true
	slide_time_left = SLIDE_TIME
	_set_stance(Stance.CROUCH)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * SLIDE_SPEED
	velocity.z = forward.z * SLIDE_SPEED
	shake = maxf(shake, 0.35)
	AudioDirector.play("footstep", -6.0, 0.7)


func _set_stance(new_stance: int) -> void:
	if stance == new_stance:
		return
	stance = new_stance
	var target_height := 1.8
	match stance:
		Stance.CROUCH:
			target_height = 1.2
		Stance.PRONE:
			target_height = 0.7
	_capsule.height = target_height
	_collision.position.y = target_height * 0.5
	head.position.y = target_height * 0.9
	stance_changed.emit(stance)


func _handle_movement(delta: float) -> void:
	var input := InputHub.move_vector()
	var wish := (transform.basis.x * input.x - transform.basis.z * input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var speed := SPEED_WALK
	is_sprinting = InputHub.wants_sprint() and input.y > 0.15 and stance == Stance.STAND and ads_blend < 0.35
	match stance:
		Stance.CROUCH:
			speed = SPEED_CROUCH
		Stance.PRONE:
			speed = SPEED_PRONE
	if is_sprinting:
		speed = SPEED_SPRINT
	elif ads_blend > 0.5:
		speed = SPEED_ADS
	var stats := inventory.current_stats()
	if not stats.is_empty():
		speed *= float(stats.get("move_mult", 1.0))
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	if is_sliding:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	if is_on_floor():
		if InputHub.just_pressed("jump") and stance != Stance.PRONE:
			velocity.y = JUMP_VELOCITY
			if stance == Stance.CROUCH:
				_set_stance(Stance.STAND)
	else:
		velocity.y -= 18.0 * delta
	move_and_slide()
	# Footsteps: cadence follows speed, silent while crouched or prone.
	var planar := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar > 0.8:
		_footstep_accum += delta * planar
		var threshold := 2.6 if stance == Stance.STAND else 4.2
		if _footstep_accum >= threshold:
			_footstep_accum = 0.0
			if stance == Stance.STAND:
				AudioDirector.play("footstep", -12.0, randf_range(0.85, 1.15))
			else:
				AudioDirector.play("footstep", -22.0, randf_range(0.7, 0.9))


func _handle_combat(delta: float) -> void:
	var stats := inventory.current_stats()
	if stats.is_empty():
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	spread_growth = maxf(0.0, spread_growth - 5.0 * delta)
	recoil_pitch = move_toward(recoil_pitch, 0.0, 9.0 * delta)
	recoil_yaw = move_toward(recoil_yaw, 0.0, 9.0 * delta)
	shake = maxf(0.0, shake - 3.0 * delta)

	# ADS blend
	var want_ads := InputHub.is_aiming() and not is_sprinting and not is_sliding
	var ads_speed: float = 1.0 / maxf(float(stats.get("ads_time", 0.22)), 0.05)
	ads_blend = clampf(ads_blend + (ads_speed if want_ads else -ads_speed * 1.4) * delta, 0.0, 1.0)

	# Reload
	if reload_time_left > 0.0:
		reload_time_left -= delta
		if reload_time_left <= 0.0:
			_finish_reload()
	elif InputHub.just_pressed("reload"):
		start_reload()
	elif mag_rounds <= 0 and InputHub.is_firing():
		start_reload()

	# Swap
	if InputHub.just_pressed("swap_weapon"):
		inventory.swap()
		reload_time_left = 0.0
		_refill_mag()
		AudioDirector.play("reload", -4.0, 1.2)
		_emit_weapon()

	# Fire
	var can_fire := fire_cooldown <= 0.0 and reload_time_left <= 0.0 and burst_cooldown <= 0.0
	if not can_fire:
		return
	var wants_shot := false
	if bool(stats.get("auto", false)):
		wants_shot = InputHub.is_firing()
	else:
		wants_shot = InputHub.just_pressed("fire") or burst_left > 0 or InputHub.is_firing() and int(stats.get("burst", 0)) == 0 and _single_shot_ready()
	if wants_shot and mag_rounds > 0:
		_shoot(stats)


var _last_semi_time := 0.0


func _single_shot_ready() -> bool:
	## Semi-auto weapons on touch fire on press; this lets a held finger repeat
	## at the weapon's cyclic rate without needing tap-spam.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_semi_time > 0.28:
		_last_semi_time = now
		return true
	return false


func _shoot(stats: Dictionary) -> void:
	mag_rounds -= 1
	_shots_fired += 1
	var rpm := float(stats.get("rpm", 600))
	fire_cooldown = 60.0 / maxf(rpm, 30.0)
	var burst := int(stats.get("burst", 0))
	if burst > 0:
		burst_left -= 1
		if burst_left > 0:
			burst_cooldown = fire_cooldown
		else:
			burst_cooldown = 60.0 / rpm * 3.0

	var spread := _current_spread(stats)
	var cam_xform := camera.global_transform
	var origin := cam_xform.origin
	var dir := -cam_xform.basis.z
	# Cone spread, deterministic per shot.
	var right := cam_xform.basis.x
	var up := cam_xform.basis.y
	var spread_rad := deg_to_rad(spread)
	var angle := randf() * TAU
	var radius := sqrt(randf()) * spread_rad
	dir = (dir + right * sin(angle) * radius + up * cos(angle) * radius).normalized()

	var result := Ballistics.fire(_space, self, origin, dir, stats, [get_rid()])
	var hit_pos: Vector3 = result["position"]
	var muzzle_pos := muzzle.global_position
	VFX.tracer(get_tree().current_scene, muzzle_pos, hit_pos)
	VFX.muzzle_flash(get_tree().current_scene, muzzle_pos, dir)
	if result["hit"]:
		if result["actor"] != null:
			var zone := String(result["zone"])
			if zone == "head":
				_headshots += 1
				AudioDirector.play("hit_head", -2.0)
				VFX.impact(get_tree().current_scene, hit_pos, Vector3.UP, Color(0.85, 0.2, 0.15))
			else:
				AudioDirector.play("hit_flesh", -4.0, randf_range(0.9, 1.1))
				VFX.impact(get_tree().current_scene, hit_pos, Vector3.UP, Color(0.6, 0.1, 0.1))
		else:
			VFX.impact(get_tree().current_scene, hit_pos, result["normal"])
	# Audio: suppressed weapons are quieter and pitchier.
	var sound_key := String(stats.get("sfx", "gun_ar"))
	var sound_scale := float(stats.get("sound_scale", 1.0))
	AudioDirector.play(sound_key, linear_to_db(sound_scale) - 2.0, randf_range(0.95, 1.05))

	# Recoil: vertical climb plus a small alternating horizontal drift, scaled by
	# ADS (braced) and stance (prone is much steadier).
	var brace := lerpf(1.0, 0.55, ads_blend)
	if stance == Stance.PRONE:
		brace *= 0.45
	elif stance == Stance.CROUCH:
		brace *= 0.75
	recoil_pitch += deg_to_rad(float(stats.get("recoil_v", 1.4)) * brace)
	recoil_yaw += deg_to_rad(float(stats.get("recoil_h", 0.5)) * brace * (1.0 if _shots_fired % 2 == 0 else -1.0) * randf_range(0.5, 1.2))
	pitch = clampf(pitch + deg_to_rad(float(stats.get("recoil_v", 1.4)) * brace * 0.35), deg_to_rad(-88.0), deg_to_rad(88.0))
	spread_growth = minf(spread_growth + 1.6, 9.0)
	shake = maxf(shake, 0.22 * brace)
	fired.emit(stats)
	ammo_changed.emit(mag_rounds, inventory.reserve_for(String(stats.get("ammo", "556"))))


func _current_spread(stats: Dictionary) -> float:
	var hip := float(stats.get("spread_hip", 2.5))
	var ads := float(stats.get("spread_ads", 0.4))
	var base := lerpf(hip, ads, ads_blend)
	var move_penalty := 0.0
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.5:
		move_penalty = clampf(planar / SPEED_SPRINT, 0.0, 1.0) * (1.0 - ads_blend * 0.5) * 2.2
	if not is_on_floor():
		move_penalty += 1.8
	return base + move_penalty + spread_growth * lerpf(1.0, 0.35, ads_blend)


func start_reload() -> void:
	var stats := inventory.current_stats()
	if stats.is_empty():
		return
	var ammo_type := String(stats.get("ammo", "556"))
	var mag_size := int(stats.get("mag", 30))
	if mag_rounds >= mag_size:
		return
	if inventory.reserve_for(ammo_type) <= 0:
		return
	reload_time_left = float(stats.get("reload", 2.2))
	reload_started.emit(reload_time_left)
	AudioDirector.play("reload", -6.0, 1.0)


func _finish_reload() -> void:
	var stats := inventory.current_stats()
	if stats.is_empty():
		return
	var ammo_type := String(stats.get("ammo", "556"))
	var mag_size := int(stats.get("mag", 30))
	var needed := mag_size - mag_rounds
	var taken := inventory.take_ammo(ammo_type, needed)
	mag_rounds += taken
	AudioDirector.play("reload", -4.0, 1.25)
	reload_finished.emit()
	ammo_changed.emit(mag_rounds, inventory.reserve_for(ammo_type))


func _update_camera(delta: float) -> void:
	var target_fov := 78.0
	var stats := inventory.current_stats()
	var zoom := float(stats.get("zoom", 0.0))
	if ads_blend > 0.01:
		var ads_fov := 78.0 / (1.0 + zoom * 1.15) if zoom > 0.0 else lerpf(78.0, 56.0, 1.0)
		target_fov = lerpf(78.0, ads_fov, ads_blend)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 12.0, 0.0, 1.0))
	var planar := Vector2(velocity.x, velocity.z).length()
	_bob += delta * planar * 1.9
	var bob_amount := 0.014 * (1.0 - ads_blend * 0.8) * clampf(planar / SPEED_WALK, 0.0, 1.4)
	var bob_offset := Vector3(cos(_bob) * bob_amount, absf(sin(_bob)) * bob_amount * 0.8, 0.0)
	var shake_offset := Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0) * 0.02
	head.position.y = lerpf(head.position.y, _stance_height() * 0.9 + bob_offset.y, clampf(delta * 10.0, 0.0, 1.0))
	head.position.x = bob_offset.x + shake_offset.x
	head.rotation.x = pitch + recoil_pitch
	head.rotation.y = recoil_yaw * 0.4
	# Viewmodel settles into an ADS pose and swings with movement.
	if viewmodel != null:
		var hip_pos := Vector3(0.16, -0.10, -0.02)
		var ads_pos := Vector3(0.0, -0.062, -0.16)
		viewmodel.position = hip_pos.lerp(ads_pos, ads_blend) + bob_offset * 0.5 + shake_offset * 0.4
		viewmodel.rotation = Vector3(0.0, lerpf(0.06, 0.0, ads_blend), 0.0)


func _stance_height() -> float:
	match stance:
		Stance.CROUCH:
			return 1.2
		Stance.PRONE:
			return 0.7
	return 1.8


var _interact_timer := 0.0


func _scan_interactables() -> void:
	_interact_timer += get_physics_process_delta_time()
	if _interact_timer < 0.05:
		return
	_interact_timer = 0.0
	var best: Node = null
	var best_dist := 3.2
	for node in get_tree().get_nodes_in_group("loot"):
		var d := global_position.distance_to((node as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = node
	if best != _nearby_loot:
		_nearby_loot = best
		if best != null and best.has_method("prompt_text"):
			interact_prompt.emit(String(best.call("prompt_text")))
		else:
			interact_prompt.emit("")
	if _nearby_loot != null and InputHub.just_pressed("interact"):
		if _nearby_loot.has_method("try_pickup"):
			var taken: bool = _nearby_loot.call("try_pickup", self)
			if taken:
				AudioDirector.play("pickup", -4.0)


func pickup_auto(item: Dictionary) -> void:
	## Called by loot for ammo/heals that need no decision.
	match String(item.get("kind", "")):
		"ammo":
			inventory.add_ammo(String(item["ammo"]), int(item["qty"]))
		"heal":
			if not inventory.add_heal():
				return
		"plate":
			if not inventory.add_plate():
				return
			plates_held = inventory.plates
		"throwable":
			if not inventory.add_throwable():
				return
	ammo_changed.emit(mag_rounds, inventory.reserve_for(String(inventory.current_stats().get("ammo", "556"))))


func equip_weapon(weapon_id: String, attachments: Dictionary) -> String:
	var dropped := inventory.equip(weapon_id, attachments)
	inventory.add_ammo(String(WeaponDB.get_weapon(weapon_id).get("ammo", "556")), int(WeaponDB.get_weapon(weapon_id).get("mag", 30)))
	reload_time_left = 0.0
	_refill_mag()
	_emit_weapon()
	return dropped


func use_heal() -> bool:
	if inventory.heals <= 0:
		return false
	if not begin_heal(2.2):
		return false
	inventory.heals -= 1
	AudioDirector.play("heal", -4.0)
	return true


func use_plate() -> bool:
	plates_held = inventory.plates
	if not equip_plate():
		return false
	inventory.plates = plates_held
	AudioDirector.play("click", -4.0, 0.8)
	return true


func heal_and_replate() -> void:
	## One-button triage used by the touch HUD: plate first (fast), then heal.
	if plate_health < plate_capacity * 0.5 and use_plate():
		return
	use_heal()


func die(killer: Actor) -> void:
	if not is_alive:
		return
	super.die(killer)
	viewmodel.visible = false
	head.position.y = 0.35
	var tween := create_tween()
	tween.tween_property(head, "rotation:z", deg_to_rad(75.0), 0.6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if killer != null:
		StoryDirector.radio("squad_wipe")


func match_summary(won: bool, placement: int) -> Dictionary:
	return {
		"won": won,
		"placement": placement,
		"kills": kills,
		"damage": damage_dealt,
		"headshots": _headshots,
		"shots": _shots_fired,
		"accuracy": (float(_headshots) / maxf(float(_shots_fired), 1.0)) if _shots_fired > 0 else 0.0,
	}
