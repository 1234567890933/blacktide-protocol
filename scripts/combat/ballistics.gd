class_name Ballistics
extends RefCounted
## Raycast ballistics with distance falloff and geometric hit zones.
## One ray per pellet. Cheap, deterministic, and identical for the player and
## the bots — fairness comes from shared code, not from tuning two paths.

const WORLD_MASK := 1 | 2


static func fire(space_state: PhysicsDirectSpaceState3D, shooter: Actor, origin: Vector3,
		direction: Vector3, stats: Dictionary, exclude: Array) -> Dictionary:
	var pellets := int(stats.get("pellets", 1))
	var max_range := 400.0
	var falloff: Array = stats.get("falloff", [60.0, 150.0, 0.7])
	var best := {"hit": false, "position": origin + direction * max_range, "actor": null,
		"zone": "body", "damage": 0.0, "normal": -direction}
	var total_damage := 0.0
	for i in pellets:
		var dir := direction
		if i > 0:
			# Shotgun pellets spread in a small cone around the aim ray.
			dir = (direction + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))).normalized()
		var to := origin + dir * max_range
		var q := PhysicsRayQueryParameters3D.create(origin, to, WORLD_MASK, exclude)
		q.hit_from_inside = false
		var hit := space_state.intersect_ray(q)
		if hit.is_empty():
			if i == 0:
				best["position"] = to
			continue
		var point: Vector3 = hit["position"]
		var dist := origin.distance_to(point)
		var mult := _falloff_mult(dist, falloff)
		var dmg := float(stats.get("damage", 20.0)) * mult
		var collider: Variant = hit.get("collider")
		if collider is Actor:
			var target: Actor = collider
			if target == shooter or not target.is_alive:
				continue
			var zone := target.hit_zone_at(point)
			total_damage += dmg
			if i == 0 or dmg > float(best["damage"]):
				best = {"hit": true, "position": point, "actor": target, "zone": zone,
					"damage": dmg, "normal": hit.get("normal", -dir)}
		else:
			if i == 0:
				best = {"hit": true, "position": point, "actor": null, "zone": "world",
					"damage": 0.0, "normal": hit.get("normal", -dir)}
	if best["actor"] != null:
		var target: Actor = best["actor"]
		target.take_damage(total_damage, shooter, String(best["zone"]))
		best["damage"] = total_damage
	return best


static func _falloff_mult(dist: float, falloff: Array) -> float:
	var start := float(falloff[0])
	var end := float(falloff[1])
	var floor_mult := float(falloff[2])
	if dist <= start:
		return 1.0
	if dist >= end:
		return floor_mult
	var t := (dist - start) / maxf(end - start, 0.001)
	return lerpf(1.0, floor_mult, t)


static func has_line_of_sight(space_state: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3, exclude: Array) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude)
	var hit := space_state.intersect_ray(q)
	return hit.is_empty()
