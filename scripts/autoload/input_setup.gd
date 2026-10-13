extends Node
## Registers the input actions in code so the project works without editing the Input Map.

func _ready() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_mouse("bolt1", MOUSE_BUTTON_LEFT)
	_keys("bolt1", [KEY_J])
	_mouse("bolt2", MOUSE_BUTTON_RIGHT)
	_keys("bolt2", [KEY_K])
	_keys("control1", [KEY_Q])
	_keys("control2", [KEY_E])
	_keys("signature", [KEY_R])
	_keys("magick", [KEY_F])
	_keys("swap_signature", [KEY_TAB])
	_keys("blink", [KEY_SPACE])
	_keys("pick1", [KEY_1])
	_keys("pick2", [KEY_2])
	_keys("confirm", [KEY_ENTER, KEY_KP_ENTER])
	_keys("practice", [KEY_F1])
	_keys("autoplay", [KEY_F2])
	_keys("wipe", [KEY_DELETE])


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
