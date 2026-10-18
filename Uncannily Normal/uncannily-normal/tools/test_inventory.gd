extends Node

## Inventory integration test — Q opens it in the real map0, with the beep.
##
## This is the check that matters: the key handler, the panel, and the sound
## all have to work together in the scene the player actually plays.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var map_scene: PackedScene = load("res://scenes/map0.tscn")
	var map := map_scene.instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _wait(20)

	# --- the inventory must exist and start closed ---
	var inv := _find_capability(map, "is_open")
	_check("the inventory exists in map0", inv != null)
	if inv == null:
		_finish()
		return
	_check("the inventory starts closed", inv.call("is_open") == false)

	# --- the key handler must be attached (the Interact node) ---
	var handler := _find_capability(map, "_unhandled_input")
	_check("a key handler node exists", handler != null)

	# --- press Q ---
	GameAudio.last_oneshot = ""
	_press("inventory")
	await _wait(10)
	_check("Q opens the inventory", inv.call("is_open") == true)
	_check("opening plays the beep", GameAudio.last_oneshot == "beep")

	# --- the panel should be fading in ---
	var alpha: float = inv.get("_panel").modulate.a
	print("  [INFO] panel alpha after opening = ", alpha)
	_check("the panel is becoming visible", alpha > 0.0)

	# --- press Q again to close ---
	GameAudio.last_oneshot = ""
	_press("inventory")
	await _wait(10)
	_check("Q closes the inventory", inv.call("is_open") == false)
	_check("closing plays the beep too", GameAudio.last_oneshot == "beep")

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _find_capability(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _find_capability(c, method)
		if f != null:
			return f
	return null


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
