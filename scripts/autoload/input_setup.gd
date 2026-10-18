extends Node
## Registers the input actions in code so the project works without editing the Input Map.

func _ready() -> void:
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	# The six spellbook slots, then the Magick.
	_mouse("slot1", MOUSE_BUTTON_LEFT)
	_keys("slot1", [KEY_J])
	_mouse("slot2", MOUSE_BUTTON_RIGHT)
	_keys("slot2", [KEY_K])
	_keys("slot3", [KEY_Q])
	_keys("slot4", [KEY_E])
	_keys("slot5", [KEY_R])
	_keys("slot6", [KEY_F])
	_keys("magick", [KEY_C])
	_keys("blink", [KEY_SPACE])
	_keys("pick1", [KEY_1])
	_keys("pick2", [KEY_2])
	_keys("confirm", [KEY_ENTER, KEY_KP_ENTER])
	_keys("practice", [KEY_F1])
	_keys("autoplay", [KEY_F2])
	_keys("wipe", [KEY_DELETE])
	_keys("shrine", [KEY_G])
	_keys("cancel", [KEY_ESCAPE])
	_keys("pick3", [KEY_3])
	_keys("pick4", [KEY_4])
	_keys("pick5", [KEY_5])
	_keys("pick6", [KEY_6])
	_keys("pick7", [KEY_7])
	_keys("pick8", [KEY_8])
	_keys("tests", [KEY_T])
	_keys("mood", [KEY_F3])
	_keys("graphics", [KEY_F4])
	_keys("controls", [KEY_TAB])
	# The open world (design/open-world/interactions.md §1).
	_keys("interact", [KEY_G])
	_keys("map", [KEY_M])
	_keys("wait", [KEY_Z])
	_keys("mute", [KEY_F8])
	# The League-style scheme (scripts/controls.gd): right-click moves, Q W E R D F cast.
	_mouse("lol_move", MOUSE_BUTTON_RIGHT)
	_keys("lol_stop", [KEY_S])
	_keys("lol_slot1", [KEY_Q])
	_keys("lol_slot2", [KEY_W])
	_keys("lol_slot3", [KEY_E])
	_keys("lol_slot4", [KEY_R])
	_keys("lol_slot5", [KEY_D])
	_keys("lol_slot6", [KEY_F])
	_keys("lol_magick", [KEY_C])


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
