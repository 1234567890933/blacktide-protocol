extends Node
## Single source of truth for input. Keyboard/mouse (desktop + CI smoke tests)
## and the on-screen touch rig both write here, so gameplay code never cares
## which device is driving it.

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"crouch": [KEY_CTRL, KEY_C],
	"prone": [KEY_Z],
	"fire": [],
	"aim": [],
	"reload": [KEY_R],
	"interact": [KEY_F, KEY_E],
	"heal": [KEY_H],
	"swap_weapon": [KEY_Q, KEY_TAB],
	"fire_mode": [KEY_B],
	"inventory": [KEY_I],
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"throw": [KEY_G],
	"lean_left": [KEY_Q],
	"toggle_flashlight": [KEY_L],
}

## Touch rig writes these every frame.
var touch_move := Vector2.ZERO        # -1..1, x = strafe, y = forward
var touch_look := Vector2.ZERO        # accumulated pixels this frame
var touch_fire := false
var touch_aim := false
var touch_sprint := false
var touch_actions: Dictionary = {}    # action_name -> true while held

## Mouse look accumulated by the player camera rig.
var mouse_look := Vector2.ZERO
var mouse_sensitivity := 0.0022
var invert_y := false
var using_touch := false


func _ready() -> void:
	_register_actions()
	using_touch = OS.has_feature("mobile") or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()


func _register_actions() -> void:
	for action_name in ACTIONS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		for key in ACTIONS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action_name, ev)
	# Mouse buttons for desktop testing.
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", lmb)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim", rmb)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		mouse_look += mm.relative * mouse_sensitivity * float(GameState.settings["sensitivity"])


func move_vector() -> Vector2:
	var v := touch_move
	if v.length() > 1.0:
		v = v.normalized()
	return v


func consume_look() -> Vector2:
	var total := touch_look + mouse_look
	touch_look = Vector2.ZERO
	mouse_look = Vector2.ZERO
	if invert_y:
		total.y = -total.y
	return total


func is_action(action_name: String) -> bool:
	if touch_actions.get(action_name, false):
		return true
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func just_pressed(action_name: String) -> bool:
	if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
		return true
	return false


func is_firing() -> bool:
	return touch_fire or is_action("fire")


func is_aiming() -> bool:
	return touch_aim or is_action("aim")


func wants_sprint() -> bool:
	return touch_sprint or is_action("sprint")


func clear_touch_state() -> void:
	touch_move = Vector2.ZERO
	touch_look = Vector2.ZERO
	touch_fire = false
	touch_aim = false
	touch_sprint = false
	touch_actions.clear()
