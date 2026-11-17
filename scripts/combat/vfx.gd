class_name VFX
extends RefCounted
## Cheap, pooled-free effects: everything is a primitive mesh + tween that frees
## itself. No particle systems, no texture fetches — mobile GPUs spend their
## budget on the world, not on sparks.

static var _mats: Dictionary = {}


static func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(), emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.5)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var dist := from.distance_to(to)
	if dist < 0.4:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, minf(dist, 14.0))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, 1.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = from + (to - from) * 0.5
	if dist > 0.5:
		mi.look_at(to, Vector3.UP)
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(0.2, 0.2, 0.2), 0.06)
	tween.tween_callback(mi.queue_free)


static func muzzle_flash(parent: Node, pos: Vector3, dir: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.4)
	light.light_energy = 4.0
	light.omni_range = 9.0
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = pos + dir * 0.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(Color(1.0, 0.85, 0.55), 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + dir * 0.45
	var tween := mi.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.07)
	tween.parallel().tween_property(mi, "scale", Vector3(0.1, 0.1, 0.1), 0.07)
	tween.tween_callback(mi.queue_free)
	tween.tween_callback(light.queue_free)


static func impact(parent: Node, pos: Vector3, normal: Vector3, color: Color = Color(0.7, 0.7, 0.65)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + normal * 0.02
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(2.4, 2.4, 2.4), 0.12)
	tween.parallel().tween_property(mi, "transparency", 1.0, 0.12)
	tween.tween_callback(mi.queue_free)


static func explosion(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 9.0
	light.omni_range = 24.0
	parent.add_child(light)
	light.global_position = pos
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(Color(1.0, 0.6, 0.25), 2.5)
	parent.add_child(mi)
	mi.global_position = pos
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(6.0, 6.0, 6.0), 0.28)
	tween.parallel().tween_property(mi, "transparency", 1.0, 0.28)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(mi.queue_free)
	tween.tween_callback(light.queue_free)
