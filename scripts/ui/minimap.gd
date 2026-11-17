class_name Minimap
extends Control
## Tactical minimap: cordon circle, next ring, player heading. Deliberately
## shows no enemy blips — this is a Battle Royale, not a radar shooter.

var player: Player = null
var zone: ZoneController = null
var world_size := 1200.0
var _pulse := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	set_process(true)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var map_radius := minf(size.x, size.y) * 0.46
	draw_circle(center, map_radius + 4.0, Color(0.03, 0.05, 0.06, 0.85))
	draw_arc(center, map_radius + 2.0, 0.0, TAU, 48, Color(0.55, 0.6, 0.62, 0.6), 2.0)
	var scale_factor := map_radius / (world_size * 0.5)

	# Sector footprints — faint, just enough to orient.
	if zone != null and zone.map_ref != null:
		var anchors: Dictionary = MapBuilder.SECTOR_ANCHORS
		for sector_id in anchors.keys():
			var anchor: Dictionary = anchors[sector_id]
			var c: Vector2 = anchor["pos"]
			var pos := center + Vector2(c.x, c.y) * scale_factor
			var r := float(anchor["radius"]) * scale_factor
			draw_circle(pos, r, Color(0.35, 0.38, 0.36, 0.25))
		# Cordon
		var zc := Vector2(zone.center.x, zone.center.z) * scale_factor
		var zr: float = zone.radius * scale_factor
		draw_circle(center + zc, zr, Color(0.75, 0.22, 0.15, 0.10))
		draw_arc(center + zc, zr, 0.0, TAU, 64, Color(0.90, 0.32, 0.22, 0.9), 2.5)
		# Next ring preview
		if zone.running and zone.phase_index + 1 < ZoneController.PHASES.size():
			var next_r: float = float(ZoneController.PHASES[zone.phase_index + 1]["radius"]) * scale_factor
			var next_c := Vector2(zone.target_center.x, zone.target_center.z) * scale_factor
			draw_arc(center + next_c, next_r, 0.0, TAU, 48, Color(0.95, 0.85, 0.45, 0.55), 1.5)

	if player != null:
		var pp := center + Vector2(player.global_position.x, player.global_position.z) * scale_factor
		var yaw := player.rotation.y
		var dir := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-dir.y, dir.x)
		var p1 := pp + dir * 8.0
		var p2 := pp - dir * 5.0 + side * 5.0
		var p3 := pp - dir * 5.0 - side * 5.0
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(0.98, 0.98, 0.92))
		# North tick
	draw_line(center + Vector2(0, -map_radius - 6.0), center + Vector2(0, -map_radius + 2.0), Color(0.85, 0.85, 0.8, 0.9), 2.0)
