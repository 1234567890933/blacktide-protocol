class_name MapBuilder
extends Node3D
## Procedural island: Kestrel Atoll. Deterministic from a seed, built once at
## match start in ~1-2 s on a mid-range phone, then never touched again.
##
## Everything is primitives: no textures, no imported meshes, no NavMesh bake.
## Bots navigate with two-probe steering plus a cover-point graph, which is both
## cheaper and more robust on mobile than a 1200 m navmesh.

const MAP_SIZE := 1200.0
const GRID := 96
const SEA_LEVEL := 0.0
const ISLAND_RADIUS := 470.0

## Sector anchors — ids must match StoryDirector.SECTORS.
const SECTOR_ANCHORS := {
	"quay7": {"pos": Vector2(-330, -250), "radius": 78.0, "tier": 3, "pad": 4.0},
	"vantage": {"pos": Vector2(120, -330), "radius": 70.0, "tier": 3, "pad": 16.0},
	"coldline": {"pos": Vector2(-90, -60), "radius": 74.0, "tier": 2, "pad": 9.0},
	"holloway": {"pos": Vector2(300, 40), "radius": 96.0, "tier": 3, "pad": 6.0},
	"refinery": {"pos": Vector2(-300, 150), "radius": 80.0, "tier": 2, "pad": 5.0},
	"oldkestrel": {"pos": Vector2(60, 300), "radius": 86.0, "tier": 1, "pad": 3.0},
	"relay": {"pos": Vector2(230, 250), "radius": 62.0, "tier": 1, "pad": 7.0},
	"powerhouse": {"pos": Vector2(-170, 320), "radius": 66.0, "tier": 2, "pad": 5.0},
}

var rng := RandomNumberGenerator.new()
var heights: PackedFloat32Array = PackedFloat32Array()
var loot_points: Array = []          # Vector3
var cover_points: Array = []         # Vector3
var spawn_points: Array = []         # Vector3 (drop candidates)
var structure_count := 0
var zone_controller: Node = null
var loot_spawner: Node = null

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _terrain_mesh: MeshInstance3D
var _props_root: Node3D


func build(seed_value: int) -> void:
	rng.seed = seed_value
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0032
	_noise.fractal_octaves = 4
	_detail.seed = seed_value + 17
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.011
	_detail.fractal_octaves = 3

	_generate_heights()
	_build_terrain_mesh()
	_build_water()
	_build_sectors()
	_build_props()
	_build_spawn_points()


# ---------------------------------------------------------------- terrain ----

func _generate_heights() -> void:
	heights.resize((GRID + 1) * (GRID + 1))
	var step := MAP_SIZE / float(GRID)
	for gz in GRID + 1:
		for gx in GRID + 1:
			var x := -MAP_SIZE * 0.5 + float(gx) * step
			var z := -MAP_SIZE * 0.5 + float(gz) * step
			heights[gz * (GRID + 1) + gx] = _raw_height(x, z)
	# Flatten sector pads so structures sit level.
	for sector_id in SECTOR_ANCHORS.keys():
		var anchor: Dictionary = SECTOR_ANCHORS[sector_id]
		var c: Vector2 = anchor["pos"]
		var pad_h := float(anchor["pad"])
		var r: float = float(anchor["radius"]) * 1.15
		for gz in GRID + 1:
			for gx in GRID + 1:
				var x := -MAP_SIZE * 0.5 + float(gx) * step
				var z := -MAP_SIZE * 0.5 + float(gz) * step
				var d := Vector2(x, z).distance_to(c)
				if d < r:
					var t: float = clampf(1.0 - d / r, 0.0, 1.0)
					var idx := gz * (GRID + 1) + gx
					heights[idx] = lerpf(heights[idx], pad_h, smoothstep(0.0, 0.55, t))


func _raw_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var falloff: float = clampf(1.0 - pow(d / ISLAND_RADIUS, 2.2), 0.0, 1.0)
	var base := _noise.get_noise_2d(x, z) * 15.0 + 9.0
	var detail := _detail.get_noise_2d(x, z) * 2.4
	var ridge := 0.0
	var ridge_noise := absf(_noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6 - 200.0))
	if ridge_noise > 0.62:
		ridge = (ridge_noise - 0.62) * 26.0
	return (base + detail + ridge) * falloff - 6.0 * (1.0 - falloff)


func height_at(x: float, z: float) -> float:
	var step := MAP_SIZE / float(GRID)
	var fx := (x + MAP_SIZE * 0.5) / step
	var fz := (z + MAP_SIZE * 0.5) / step
	var gx := int(clampf(floor(fx), 0.0, float(GRID - 1)))
	var gz := int(clampf(floor(fz), 0.0, float(GRID - 1)))
	var tx := clampf(fx - float(gx), 0.0, 1.0)
	var tz := clampf(fz - float(gz), 0.0, 1.0)
	var w := GRID + 1
	var h00 := heights[gz * w + gx]
	var h10 := heights[gz * w + gx + 1]
	var h01 := heights[(gz + 1) * w + gx]
	var h11 := heights[(gz + 1) * w + gx + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build_terrain_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := MAP_SIZE / float(GRID)
	var w := GRID + 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.22, 0.19)
	mat.roughness = 0.95
	mat.vertex_color_use_as_albedo = true
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for gz in GRID:
		for gx in GRID:
			var x0 := -MAP_SIZE * 0.5 + float(gx) * step
			var z0 := -MAP_SIZE * 0.5 + float(gz) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var h00 := heights[gz * w + gx]
			var h10 := heights[gz * w + gx + 1]
			var h01 := heights[(gz + 1) * w + gx]
			var h11 := heights[(gz + 1) * w + gx + 1]
			var v00 := Vector3(x0, h00, z0)
			var v10 := Vector3(x1, h10, z0)
			var v01 := Vector3(x0, h01, z1)
			var v11 := Vector3(x1, h11, z1)
			_tri(st, v00, v10, v11)
			_tri(st, v00, v11, v01)
	st.generate_normals()
	var mesh := st.commit()
	_terrain_mesh = MeshInstance3D.new()
	_terrain_mesh.name = "Terrain"
	_terrain_mesh.mesh = mesh
	_terrain_mesh.material_override = mat
	add_child(_terrain_mesh)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Vertex colour gives free biome variation: sand low, scrub mid, rock high.
	for v: Vector3 in [a, b, c]:
		var h: float = v.y
		var col := Color(0.20, 0.22, 0.19)
		if h < 2.2:
			col = Color(0.34, 0.32, 0.26)
		elif h < 6.0:
			col = Color(0.24, 0.26, 0.20)
		elif h > 15.0:
			col = Color(0.27, 0.27, 0.26)
		st.set_color(col)
		st.add_vertex(v)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE * 3.0, MAP_SIZE * 3.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.13, 0.16, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.35
	mat.roughness = 0.12
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = Vector3(0, SEA_LEVEL - 0.35, 0)
	add_child(mi)


# --------------------------------------------------------------- sectors ----

func _build_sectors() -> void:
	for sector_id in SECTOR_ANCHORS.keys():
		var anchor: Dictionary = SECTOR_ANCHORS[sector_id]
		_build_sector(String(sector_id), anchor)


func _build_sector(sector_id: String, anchor: Dictionary) -> void:
	var center2: Vector2 = anchor["pos"]
	var radius: float = anchor["radius"]
	var tier: int = anchor["tier"]
	var base_y := height_at(center2.x, center2.y)
	var root := Node3D.new()
	root.name = "Sector_" + sector_id
	root.position = Vector3(center2.x, base_y, center2.y)
	add_child(root)

	# Every sector gets a readable silhouette: a handful of large masses plus
	# clutter. Layout is seeded, so a given seed always produces the same map.
	var big_count := 6 + tier * 3
	for i in big_count:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(radius * 0.15, radius * 0.85)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var size := Vector3(rng.randf_range(7.0, 16.0), rng.randf_range(4.0, 11.0), rng.randf_range(7.0, 16.0))
		_add_structure(root, pos, size, _structure_color(sector_id))
		_register_cover_ring(root, pos, size)
	var small_count := 10 + tier * 6
	for i in small_count:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(radius * 0.1, radius)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var size := Vector3(rng.randf_range(2.0, 4.2), rng.randf_range(1.1, 3.2), rng.randf_range(2.0, 4.2))
		_add_structure(root, pos, size, _structure_color(sector_id))
		_register_cover_ring(root, pos, size)
	# Loot density scales with sector tier: hot drops are worth the risk.
	var loot_count := 8 + tier * 7
	for i in loot_count:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(4.0, radius * 0.95)
		var p := Vector3(center2.x + cos(angle) * dist, 0, center2.y + sin(angle) * dist)
		p.y = height_at(p.x, p.z)
		loot_points.append({"pos": p, "tier": tier, "sector": sector_id})


func _structure_color(sector_id: String) -> Color:
	match sector_id:
		"quay7":
			return Color(0.35, 0.19, 0.13)   # rusted containers
		"vantage":
			return Color(0.30, 0.31, 0.30)   # concrete + steel
		"coldline":
			return Color(0.27, 0.28, 0.25)
		"holloway":
			return Color(0.33, 0.33, 0.31)
		"refinery":
			return Color(0.32, 0.28, 0.18)
		"oldkestrel":
			return Color(0.36, 0.33, 0.27)
		"relay":
			return Color(0.28, 0.30, 0.29)
		_:
			return Color(0.29, 0.29, 0.27)


func _add_structure(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.15
	mi.material_override = mat
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	structure_count += 1


func _register_cover_ring(parent: Node3D, local_pos: Vector3, size: Vector3) -> void:
	# Cover points hug the corners of each mass — that is where players actually
	# peek from, so that is where bots should go.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := local_pos + Vector3(sx * (size.x * 0.5 + 1.1), 0, sz * (size.z * 0.5 + 1.1))
			var world := p + parent.position
			world.y = height_at(world.x, world.z)
			cover_points.append(world)


func _build_props() -> void:
	_props_root = Node3D.new()
	_props_root.name = "Props"
	add_child(_props_root)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 4.2
	trunk_mesh.radial_segments = 5
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 2.1
	canopy_mesh.height = 3.4
	canopy_mesh.radial_segments = 6
	canopy_mesh.rings = 4
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.16, 0.14, 0.12)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.11, 0.17, 0.12)
	canopy_mat.roughness = 1.0
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	var canopy_mm := MultiMesh.new()
	canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_mm.mesh = canopy_mesh
	var count := 520
	trunk_mm.instance_count = count
	canopy_mm.instance_count = count
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 6:
		attempts += 1
		var x := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var z := rng.randf_range(-ISLAND_RADIUS, ISLAND_RADIUS)
		var h := height_at(x, z)
		if h < 2.5 or h > 16.0:
			continue
		var in_sector := false
		for sector_id in SECTOR_ANCHORS.keys():
			var anchor: Dictionary = SECTOR_ANCHORS[sector_id]
			var c: Vector2 = anchor["pos"]
			if Vector2(x, z).distance_to(c) < float(anchor["radius"]) * 0.92:
				in_sector = true
				break
		if in_sector:
			continue
		var scale_factor := rng.randf_range(0.75, 1.5)
		var basis := Basis().scaled(Vector3(scale_factor, scale_factor, scale_factor))
		var origin := Vector3(x, h + 2.1 * scale_factor, z)
		trunk_mm.set_instance_transform(placed, Transform3D(basis, origin))
		canopy_mm.set_instance_transform(placed, Transform3D(basis, origin + Vector3(0, 2.4 * scale_factor, 0)))
		placed += 1
	trunk_mm.visible_instance_count = placed
	canopy_mm.visible_instance_count = placed
	var trunk_mi := MultiMeshInstance3D.new()
	trunk_mi.multimesh = trunk_mm
	trunk_mi.material_override = trunk_mat
	trunk_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props_root.add_child(trunk_mi)
	var canopy_mi := MultiMeshInstance3D.new()
	canopy_mi.multimesh = canopy_mm
	canopy_mi.material_override = canopy_mat
	canopy_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props_root.add_child(canopy_mi)


func _build_spawn_points() -> void:
	for sector_id in SECTOR_ANCHORS.keys():
		var anchor: Dictionary = SECTOR_ANCHORS[sector_id]
		var c: Vector2 = anchor["pos"]
		for i in 6:
			var angle := rng.randf() * TAU
			var dist := rng.randf_range(0.0, float(anchor["radius"]))
			var p := Vector3(c.x + cos(angle) * dist, 0, c.y + sin(angle) * dist)
			p.y = height_at(p.x, p.z)
			spawn_points.append(p)


# ------------------------------------------------------------- utilities ----

func sector_at(world_pos: Vector3) -> String:
	for sector_id in SECTOR_ANCHORS.keys():
		var anchor: Dictionary = SECTOR_ANCHORS[sector_id]
		var c: Vector2 = anchor["pos"]
		if Vector2(world_pos.x, world_pos.z).distance_to(c) < float(anchor["radius"]):
			return String(sector_id)
	return ""


func random_point_in_zone(local_rng: RandomNumberGenerator) -> Vector3:
	if zone_controller == null or not zone_controller.has_method("random_point_inside"):
		var p := Vector3(local_rng.randf_range(-300, 300), 0, local_rng.randf_range(-300, 300))
		p.y = height_at(p.x, p.z)
		return p
	var point: Vector3 = zone_controller.call("random_point_inside", local_rng)
	point.y = height_at(point.x, point.z)
	return point


func nearest_cover(from_pos: Vector3, threat_pos: Vector3) -> Vector3:
	var best := from_pos
	var best_score := INF
	var threat_dir := (threat_pos - from_pos).normalized()
	for p: Vector3 in cover_points:
		var d := from_pos.distance_to(p)
		if d > 26.0:
			continue
		# Prefer cover that is between us and the threat, but not on top of it.
		var to_p: Vector3 = (p - from_pos).normalized()
		var facing: float = to_p.dot(threat_dir)
		var score: float = d - facing * 9.0
		if score < best_score:
			best_score = score
			best = p
	return best


func drop_death_cache(pos: Vector3, weapon_id: String) -> void:
	if loot_spawner == null or not loot_spawner.has_method("spawn_cache"):
		return
	loot_spawner.call("spawn_cache", pos, weapon_id)
