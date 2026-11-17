class_name TouchControls
extends CanvasLayer
## Landscape touch rig: left thumb moves, right thumb aims, buttons fire.
## Everything writes into InputHub, so the player controller stays device-blind.
## On desktop the rig hides itself and keyboard/mouse takes over.

const JOY_RADIUS := 92.0
const JOY_ZONE := Vector2(300, 300)

var match_manager: MatchManager = null
var _root: Control
var _joy_base: Control
var _joy_knob: ColorRect
var _buttons: Array[Button] = []
var _look_touch := -1
var _joy_touch := -1
var _joy_origin := Vector2.ZERO
var _enabled := false
var _button_rects: Array[Rect2] = []


func _ready() -> void:
	layer = 6
	_build()
	visible = false


func bind(manager: MatchManager) -> void:
	match_manager = manager
	manager.state_changed.connect(_on_state_changed)


func _on_state_changed(state: int, _label: String) -> void:
	_enabled = state == MatchManager.State.DROP or state == MatchManager.State.LIVE
	visible = _enabled and (InputHub.using_touch or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Joystick base
	_joy_base = Control.new()
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left = 30
	_joy_base.offset_top = -JOY_RADIUS * 2.0 - 30
	_joy_base.offset_right = 30 + JOY_RADIUS * 2.0
	_joy_base.offset_bottom = -30
	_root.add_child(_joy_base)
	var ring := ColorRect.new()
	ring.color = Color(0.1, 0.12, 0.13, 0.35)
	ring.size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(ring)
	_joy_knob = ColorRect.new()
	_joy_knob.color = Color(0.85, 0.87, 0.85, 0.55)
	_joy_knob.size = Vector2(64, 64)
	_joy_knob.position = Vector2(JOY_RADIUS - 32.0, JOY_RADIUS - 32.0)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_joy_knob)

	# Right-hand action cluster
	_add_button("FIRE", Vector2(-190, -190), Vector2(130, 130), "fire_hold")
	_add_button("ADS", Vector2(-330, -150), Vector2(96, 96), "aim_hold")
	_add_button("RELOAD", Vector2(-180, -330), Vector2(86, 62), "reload")
	_add_button("HEAL", Vector2(-286, -270), Vector2(86, 62), "heal")
	_add_button("JUMP", Vector2(-96, -320), Vector2(74, 74), "jump")
	_add_button("CROUCH", Vector2(-96, -232), Vector2(74, 74), "crouch")
	_add_button("PRONE", Vector2(-96, -144), Vector2(74, 74), "prone")
	_add_button("SWAP", Vector2(-400, -290), Vector2(84, 60), "swap")
	_add_button("TAKE", Vector2(-400, -220), Vector2(84, 60), "interact")
	_add_button("SPRINT", Vector2(-60, -100), Vector2(90, 60), "sprint_hold")


func _add_button(text: String, offset: Vector2, size_px: Vector2, action: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + size_px.x
	b.offset_bottom = offset.y + size_px.y
	b.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.13, 0.14, 0.45)
	normal.border_color = Color(0.75, 0.78, 0.75, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.85, 0.45, 0.25, 0.65)
	pressed.border_color = Color(1.0, 0.9, 0.7, 0.9)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.set_meta("action", action)
	b.button_down.connect(_on_button_down.bind(action))
	b.button_up.connect(_on_button_up.bind(action))
	_root.add_child(b)
	_buttons.append(b)


func _on_button_down(action: String) -> void:
	match action:
		"fire_hold":
			InputHub.touch_fire = true
		"aim_hold":
			InputHub.touch_aim = true
		"sprint_hold":
			InputHub.touch_sprint = true
		"reload":
			_trigger_player("start_reload")
		"heal":
			_trigger_player("heal_and_replate")
		"swap":
			_press_action("swap_weapon")
		"interact":
			_press_action("interact")
		"jump":
			_press_action("jump")
		"crouch":
			_press_action("crouch")
		"prone":
			_press_action("prone")


func _on_button_up(action: String) -> void:
	match action:
		"fire_hold":
			InputHub.touch_fire = false
		"aim_hold":
			InputHub.touch_aim = false
		"sprint_hold":
			InputHub.touch_sprint = false


func _press_action(action: String) -> void:
	## One-frame synthetic press so InputHub.just_pressed() logic still works.
	InputHub.touch_actions[action] = true
	await get_tree().create_timer(0.08).timeout
	InputHub.touch_actions[action] = false


func _trigger_player(method: String) -> void:
	if match_manager != null and match_manager.player != null and match_manager.player.is_alive:
		match_manager.player.call(method)


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_over_button(touch.position):
				return
			if touch.position.x < JOY_ZONE.x and touch.position.y > get_viewport().get_visible_rect().size.y - JOY_ZONE.y:
				_joy_touch = touch.index
				_joy_origin = touch.position
				_update_joystick(Vector2.ZERO)
			elif _look_touch == -1:
				_look_touch = touch.index
		else:
			if touch.index == _joy_touch:
				_joy_touch = -1
				InputHub.touch_move = Vector2.ZERO
				_update_joystick(Vector2.ZERO)
			if touch.index == _look_touch:
				_look_touch = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_touch:
			var delta := drag.position - _joy_origin
			if delta.length() > JOY_RADIUS:
				delta = delta.normalized() * JOY_RADIUS
			InputHub.touch_move = Vector2(delta.x / JOY_RADIUS, -delta.y / JOY_RADIUS)
			_update_joystick(delta)
		elif drag.index == _look_touch:
			InputHub.touch_look += drag.relative


func _is_over_button(pos: Vector2) -> bool:
	for b in _buttons:
		if b.get_global_rect().has_point(pos):
			return true
	return false


func _update_joystick(delta: Vector2) -> void:
	if _joy_knob == null:
		return
	_joy_knob.position = Vector2(JOY_RADIUS - 32.0, JOY_RADIUS - 32.0) + delta
