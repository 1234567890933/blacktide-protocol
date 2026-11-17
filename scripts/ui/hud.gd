class_name HUD
extends CanvasLayer
## Match HUD. Built entirely in code so it scales with the viewport and needs no
## imported theme resources. Every element is anchored for phones in landscape.

const HUD_FONT_SIZE := 20
const BIG_FONT_SIZE := 30

var match_manager: MatchManager = null
var player: Player = null

var _root: Control
var _health_bar: ColorRect
var _health_back: ColorRect
var _plate_bar: ColorRect
var _plate_back: ColorRect
var _health_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _alive_label: Label
var _kills_label: Label
var _zone_label: Label
var _zone_timer: Label
var _subtitle: Label
var _prompt: Label
var _kill_feed: VBoxContainer
var _damage_flash: ColorRect
var _minimap: Minimap
var _crosshair: Control
var _reload_bar: ColorRect
var _reload_back: ColorRect
var _result_panel: Control
var _result_title: Label
var _result_body: Label
var _reload_total := 1.0
var _reload_left := 0.0
var _subtitle_time := 0.0
var _damage_alpha := 0.0
var _kills := 0


func _ready() -> void:
	layer = 5
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Damage vignette sits under everything else.
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.6, 0.05, 0.05, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_flash)

	_build_top_bar()
	_build_crosshair()
	_build_vitals()
	_build_weapon_panel()
	_build_feed()
	_build_subtitle()
	_build_result_panel()
	_visible(false)


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18
	bar.offset_top = 10
	bar.offset_right = -18
	bar.add_theme_constant_override("separation", 22)
	_root.add_child(bar)

	_alive_label = _make_label("ALIVE 60", BIG_FONT_SIZE, Color(0.95, 0.95, 0.9))
	bar.add_child(_alive_label)
	_kills_label = _make_label("KILLS 0", HUD_FONT_SIZE, Color(0.85, 0.85, 0.8))
	bar.add_child(_kills_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_zone_label = _make_label("STANDBY", HUD_FONT_SIZE, Color(0.95, 0.6, 0.35))
	bar.add_child(_zone_label)
	_zone_timer = _make_label("--:--", BIG_FONT_SIZE, Color(0.95, 0.95, 0.9))
	bar.add_child(_zone_timer)

	_minimap = Minimap.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -196
	_minimap.offset_top = 54
	_minimap.offset_right = -16
	_minimap.offset_bottom = 234
	_root.add_child(_minimap)


func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	for i in 4:
		var line := ColorRect.new()
		line.color = Color(0.95, 0.95, 0.9, 0.9)
		line.size = Vector2(2, 8) if i % 2 == 0 else Vector2(8, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.name = "Cross%d" % i
		_crosshair.add_child(line)


func _build_vitals() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 24
	box.offset_top = -110
	box.offset_right = 344
	box.offset_bottom = -22
	box.add_theme_constant_override("separation", 4)
	_root.add_child(box)

	_health_label = _make_label("100", HUD_FONT_SIZE, Color(0.95, 0.95, 0.9))
	box.add_child(_health_label)

	_health_back = ColorRect.new()
	_health_back.color = Color(0.08, 0.09, 0.09, 0.8)
	_health_back.custom_minimum_size = Vector2(300, 14)
	box.add_child(_health_back)
	_health_bar = ColorRect.new()
	_health_bar.color = Color(0.75, 0.82, 0.72)
	_health_bar.size = Vector2(300, 14)
	_health_back.add_child(_health_bar)

	_plate_back = ColorRect.new()
	_plate_back.color = Color(0.08, 0.09, 0.09, 0.8)
	_plate_back.custom_minimum_size = Vector2(300, 8)
	box.add_child(_plate_back)
	_plate_bar = ColorRect.new()
	_plate_bar.color = Color(0.42, 0.62, 0.85)
	_plate_bar.size = Vector2(300, 8)
	_plate_back.add_child(_plate_bar)


func _build_weapon_panel() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -330
	box.offset_top = -120
	box.offset_right = -24
	box.offset_bottom = -22
	box.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(box)

	_weapon_label = _make_label("—", HUD_FONT_SIZE, Color(0.85, 0.85, 0.8))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_weapon_label)
	_ammo_label = _make_label("0 / 0", BIG_FONT_SIZE, Color(0.95, 0.95, 0.9))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_ammo_label)
	_reload_back = ColorRect.new()
	_reload_back.color = Color(0.08, 0.09, 0.09, 0.85)
	_reload_back.custom_minimum_size = Vector2(300, 6)
	_reload_back.visible = false
	box.add_child(_reload_back)
	_reload_bar = ColorRect.new()
	_reload_bar.color = Color(0.95, 0.72, 0.35)
	_reload_bar.size = Vector2(0, 6)
	_reload_back.add_child(_reload_bar)


func _build_feed() -> void:
	_kill_feed = VBoxContainer.new()
	_kill_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kill_feed.offset_left = -420
	_kill_feed.offset_top = 250
	_kill_feed.offset_right = -20
	_kill_feed.offset_bottom = 430
	_kill_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_kill_feed)


func _build_subtitle() -> void:
	_subtitle = _make_label("", HUD_FONT_SIZE, Color(0.92, 0.92, 0.86))
	_subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_left = 120
	_subtitle.offset_right = -120
	_subtitle.offset_top = -190
	_subtitle.offset_bottom = -140
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate = Color(1, 1, 1, 0)
	_root.add_child(_subtitle)

	_prompt = _make_label("", HUD_FONT_SIZE, Color(0.98, 0.85, 0.45))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -160
	_prompt.offset_top = 60
	_prompt.offset_right = 160
	_prompt.offset_bottom = 96
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)


func _build_result_panel() -> void:
	_result_panel = Control.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	_root.add_child(_result_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.04, 0.72)
	_result_panel.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -260
	box.offset_top = -140
	box.offset_right = 260
	box.offset_bottom = 140
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_panel.add_child(box)
	_result_title = _make_label("", 52, Color(0.95, 0.95, 0.9))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_body = _make_label("", HUD_FONT_SIZE, Color(0.85, 0.85, 0.8))
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_body)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _visible(v: bool) -> void:
	if _root != null:
		_root.visible = v


func show_hud() -> void:
	_visible(true)
	_result_panel.visible = false
	_kills = 0


func bind(manager: MatchManager) -> void:
	match_manager = manager
	manager.state_changed.connect(_on_state_changed)
	manager.kill_event.connect(_on_kill_event)
	manager.alive_changed.connect(_on_alive_changed)
	manager.player_placement.connect(_on_placement)
	StoryDirector.beat.connect(_on_story_beat)


func _on_state_changed(state: int, label: String) -> void:
	if state == MatchManager.State.DROP or state == MatchManager.State.BRIEFING:
		_bind_player()
	if state == MatchManager.State.DROP:
		_show_subtitle("DEPLOY — steer the drop, canopy opens at 65 m", 4.0)
	if state == MatchManager.State.LIVE:
		_show_subtitle("CORDON ARMED — last standing unit wins", 4.0)


func _bind_player() -> void:
	if match_manager == null or match_manager.player == null:
		return
	player = match_manager.player
	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.reload_started.connect(_on_reload_started)
	player.reload_finished.connect(_on_reload_finished)
	player.interact_prompt.connect(_on_prompt)
	player.damaged_by.connect(_on_damaged)
	player.died.connect(_on_player_died)
	_on_health_changed(player.health, player.max_health, player.plate_health)


func _process(delta: float) -> void:
	if match_manager == null:
		return
	if _subtitle_time > 0.0:
		_subtitle_time -= delta
		_subtitle.modulate.a = clampf(_subtitle_time, 0.0, 1.0)
	if _damage_alpha > 0.0:
		_damage_alpha = maxf(0.0, _damage_alpha - delta * 1.6)
		_damage_flash.color.a = _damage_alpha * 0.55
	# Zone readout
	if match_manager.zone != null:
		var zone := match_manager.zone
		_zone_label.text = zone.phase_label()
		_zone_timer.text = _format_time(zone.time_to_next())
		_minimap.zone = zone
	if player != null:
		_minimap.player = player
		_update_crosshair()
		if _reload_left > 0.0:
			_reload_left = maxf(0.0, _reload_left - delta)
			var frac := 1.0 - _reload_left / maxf(_reload_total, 0.01)
			_reload_bar.size.x = 300.0 * clampf(frac, 0.0, 1.0)
			_reload_back.visible = true
		else:
			_reload_back.visible = false


func _update_crosshair() -> void:
	var center := _crosshair.size * 0.5
	var stats := player.inventory.current_stats()
	var spread := 14.0
	if not stats.is_empty():
		var base := lerpf(float(stats.get("spread_hip", 2.5)), float(stats.get("spread_ads", 0.4)), player.ads_blend)
		spread = 8.0 + base * 6.0 + player.spread_growth * 2.0
	var len := 8.0
	for i in 4:
		var line := _crosshair.get_node("Cross%d" % i) as ColorRect
		match i:
			0:
				line.position = Vector2(center.x - 1, center.y - spread - len)
			1:
				line.position = Vector2(center.x - spread - len, center.y - 1)
			2:
				line.position = Vector2(center.x - 1, center.y + spread)
			3:
				line.position = Vector2(center.x + spread, center.y - 1)
		line.color = Color(0.95, 0.95, 0.9, 0.85 if player.ads_blend < 0.5 else 0.4)


func _on_health_changed(health: float, max_health: float, plate: float) -> void:
	var frac := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	_health_bar.size.x = 300.0 * frac
	_health_bar.color = Color(0.75, 0.82, 0.72) if frac > 0.5 else (Color(0.9, 0.7, 0.35) if frac > 0.25 else Color(0.85, 0.3, 0.28))
	_health_label.text = "%d  |  PLATES %d" % [int(ceil(health)), player.plates_held if player != null else 0]
	_plate_bar.size.x = 300.0 * clampf(plate / 55.0, 0.0, 1.0)


func _on_ammo_changed(mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [mag, reserve]


func _on_weapon_changed(stats: Dictionary, mag: int, reserve: int) -> void:
	if stats.is_empty():
		_weapon_label.text = "UNARMED"
		return
	_weapon_label.text = "%s  ·  %s" % [String(stats.get("name", "")), String(stats.get("class", ""))]
	_ammo_label.text = "%d / %d" % [mag, reserve]


func _on_reload_started(duration: float) -> void:
	_reload_total = duration
	_reload_left = duration
	_reload_bar.size.x = 0.0
	_reload_back.visible = true


func _on_reload_finished() -> void:
	_reload_left = 0.0
	_reload_back.visible = false


func _on_prompt(text: String) -> void:
	_prompt.text = text


func _on_damaged(_attacker: Actor, amount: float, _headshot: bool) -> void:
	_damage_alpha = clampf(_damage_alpha + amount / 60.0, 0.0, 1.0)


func _on_player_died(_actor: Actor, _killer: Actor) -> void:
	_show_subtitle("SIGNAL LOST — SALT-6 down", 5.0)


func _on_alive_changed(count: int) -> void:
	_alive_label.text = "ALIVE %d" % count


func _on_placement(placement: int) -> void:
	_kills_label.text = "KILLS %d" % (player.kills if player != null else 0)


func _on_kill_event(killer_name: String, victim_name: String, weapon: String) -> void:
	if killer_name == "SALT-6 'Gull'":
		_kills += 1
		_kills_label.text = "KILLS %d" % _kills
	var label := _make_label("%s  ⟶  %s   %s" % [killer_name, victim_name, weapon], 16, Color(0.9, 0.9, 0.86))
	_kill_feed.add_child(label)
	if _kill_feed.get_child_count() > 6:
		_kill_feed.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func _on_story_beat(beat_data: Dictionary) -> void:
	var line := String(beat_data.get("line", ""))
	if line == "":
		return
	_show_subtitle(line, 4.5)


func _show_subtitle(text: String, seconds: float) -> void:
	_subtitle.text = text
	_subtitle_time = seconds
	_subtitle.modulate.a = 1.0


func show_result(result: Dictionary) -> void:
	_result_panel.visible = true
	var won := bool(result.get("won", false))
	_result_title.text = "LAST STANDING" if won else "ELIMINATED"
	_result_title.add_theme_color_override("font_color", Color(0.85, 0.92, 0.75) if won else Color(0.85, 0.4, 0.32))
	var body := "PLACEMENT  #%d / %d\nKILLS  %d\nDAMAGE  %d\nHEADSHOTS  %d\nTIME  %s" % [
		int(result.get("placement", 0)),
		int(result.get("alive", 0)) + int(result.get("placement", 0)) - 1,
		int(result.get("kills", 0)),
		int(result.get("damage", 0.0)),
		int(result.get("headshots", 0)),
		_format_time(float(result.get("duration", 0.0))),
	]
	_result_body.text = body


func _format_time(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]
