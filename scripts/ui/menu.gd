class_name MainMenu
extends CanvasLayer
## Main menu, pause overlay, codex of unlocked logs and the end-of-match card.
## One CanvasLayer, three panels, no scene files.

signal deploy_requested
signal restart_requested

var _root: Control
var _menu_panel: Control
var _pause_panel: Control
var _result_panel: Control
var _codex_panel: Control
var _stats_label: Label
var _quality_button: Button
var _difficulty_button: Button
var _codex_list: VBoxContainer
var _paused := false


func _ready() -> void:
	layer = 20
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_menu()
	_build_pause()
	_build_result()
	_build_codex()


func _build_menu() -> void:
	_menu_panel = _panel()
	_root.add_child(_menu_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 90
	box.offset_top = -220
	box.offset_right = 560
	box.offset_bottom = 220
	box.add_theme_constant_override("separation", 12)
	_menu_panel.add_child(box)

	box.add_child(_label("BLACKTIDE", 72, Color(0.93, 0.94, 0.9)))
	box.add_child(_label("P R O T O C O L", 24, Color(0.82, 0.45, 0.32)))
	box.add_child(_label("Offline tactical Battle Royale · 60 operators · one atoll", 18, Color(0.75, 0.77, 0.74)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	box.add_child(_button("DEPLOY", func() -> void: deploy_requested.emit()))
	_quality_button = _button("QUALITY: BALANCED", func() -> void: _cycle_quality())
	box.add_child(_quality_button)
	_difficulty_button = _button("BOTS: REGULAR", func() -> void: _cycle_difficulty())
	box.add_child(_difficulty_button)
	box.add_child(_button("CODEX / FIELD LOGS", func() -> void: _open_codex()))

	_stats_label = _label("", 16, Color(0.7, 0.72, 0.7))
	box.add_child(_stats_label)
	_refresh_labels()


func _build_pause() -> void:
	_pause_panel = _panel()
	_pause_panel.visible = false
	_root.add_child(_pause_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -180
	box.offset_top = -140
	box.offset_right = 180
	box.offset_bottom = 140
	box.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(box)
	box.add_child(_label("PAUSED", 44, Color(0.93, 0.94, 0.9)))
	box.add_child(_button("RESUME", func() -> void: toggle_pause()))
	box.add_child(_button("ABORT TO MENU", func() -> void: _abort()))


func _build_result() -> void:
	_result_panel = _panel()
	_result_panel.visible = false
	_root.add_child(_result_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_top = -80
	box.offset_right = 200
	box.offset_bottom = 80
	box.add_theme_constant_override("separation", 14)
	_result_panel.add_child(box)
	box.add_child(_button("REDEPLOY", _on_redeploy))
	box.add_child(_button("MAIN MENU", _on_back_to_menu))


func _build_codex() -> void:
	_codex_panel = _panel()
	_codex_panel.visible = false
	_root.add_child(_codex_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 60
	box.offset_top = 40
	box.offset_right = -60
	box.offset_bottom = -60
	box.add_theme_constant_override("separation", 10)
	_codex_panel.add_child(box)
	box.add_child(_label("FIELD LOGS", 36, Color(0.93, 0.94, 0.9)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_codex_list = VBoxContainer.new()
	_codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_codex_list)
	box.add_child(_button("CLOSE", func() -> void: _codex_panel.visible = false))


func _on_redeploy() -> void:
	_result_panel.visible = false
	restart_requested.emit()


func _on_back_to_menu() -> void:
	_result_panel.visible = false
	show_menu()


func _open_codex() -> void:
	for child in _codex_list.get_children():
		child.queue_free()
	var unlocked: Array = GameState.profile["unlocked_logs"]
	if unlocked.is_empty():
		_codex_list.add_child(_label("No logs recovered yet. Play a match — every cordon phase unlocks one.", 18, Color(0.75, 0.75, 0.72)))
	for log_id in unlocked:
		if not StoryDirector.LOGS.has(log_id):
			continue
		var entry: Dictionary = StoryDirector.LOGS[log_id]
		var title := _label(String(entry["title"]), 22, Color(0.88, 0.75, 0.55))
		_codex_list.add_child(title)
		var body := _label(String(entry["body"]), 17, Color(0.78, 0.79, 0.76))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(900, 0)
		_codex_list.add_child(body)
	_codex_panel.visible = true


func _panel() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.05, 0.93)
	c.add_child(bg)
	return c


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.12, 0.13, 0.85)
	normal.border_color = Color(0.55, 0.58, 0.55, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.75, 0.35, 0.22, 0.55)
	hover.border_color = Color(0.95, 0.9, 0.8, 0.9)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(callback)
	return b


func _cycle_quality() -> void:
	var tier := (int(GameState.settings["quality_tier"]) + 1) % GameState.QUALITY_TIERS.size()
	GameState.set_setting("quality_tier", tier)
	AudioDirector.play("ui", -8.0)
	_refresh_labels()


func _cycle_difficulty() -> void:
	var order := ["RECRUIT", "REGULAR", "VETERAN", "ELITE"]
	var current := order.find(String(GameState.settings["difficulty"]))
	var next: String = order[(current + 1) % order.size()]
	GameState.set_setting("difficulty", next)
	AudioDirector.play("ui", -8.0)
	_refresh_labels()


func _refresh_labels() -> void:
	var q: Dictionary = GameState.QUALITY_TIERS[int(GameState.settings["quality_tier"])]
	if _quality_button != null:
		_quality_button.text = "QUALITY: " + String(q["name"]).to_upper()
	if _difficulty_button != null:
		_difficulty_button.text = "BOTS: " + String(GameState.settings["difficulty"])
	if _stats_label != null:
		var p: Dictionary = GameState.profile
		_stats_label.text = "MATCHES %d   WINS %d   KILLS %d   BEST #%d" % [
			int(p["matches"]), int(p["wins"]), int(p["kills"]), int(p["best_placement"])
		]


func show_menu() -> void:
	_menu_panel.visible = true
	_pause_panel.visible = false
	_result_panel.visible = false
	_codex_panel.visible = false
	_refresh_labels()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	_menu_panel.visible = false
	if not InputHub.using_touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_result(_result: Dictionary) -> void:
	_result_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle_pause() -> void:
	if _menu_panel.visible or _result_panel.visible:
		return
	_paused = not _paused
	_pause_panel.visible = _paused
	get_tree().paused = _paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_CAPTURED


func _abort() -> void:
	_paused = false
	_pause_panel.visible = false
	get_tree().paused = false
	var main := get_parent()
	if main != null and main.has_method("_on_restart_requested"):
		main.call("_on_restart_requested")
	show_menu()
