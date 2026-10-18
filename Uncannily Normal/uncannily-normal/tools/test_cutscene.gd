extends Node

## Cutscene system tests — play, advance on input, auto-advance, freeze/unfreeze.
##
## Drives Cutscene.play() directly with short timings and synthesizes input
## events to advance, since headless mode has no real mouse/keyboard.

var _pass := 0
var _fail := 0
var _callback_fired := false
var _slide_shown := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var map := (load("res://scenes/map0.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _wait(20)

	var player := _find_player()
	var cut := get_node_or_null("/root/Cutscene")

	_check("Cutscene autoload exists", cut != null)
	_check("Cutscene idle at start", cut.is_playing() == false)

	# --- key advance (2 slides, min 0.3, no auto) ----------------------
	var cb := Callable(self, "_on_done")
	cut.play([
		{"text": "slide one", "min": 0.1, "auto": 0.0},
		{"text": "slide two", "min": 0.1, "auto": 0.0},
	], cb)

	await _wait(15)
	_check("Cutscene is playing", cut.is_playing() == true)
	_check("player frozen during cutscene", _is_frozen(player))
	var prompt := cut.get_node_or_null("Box/Prompt") as Label
	_check("advance prompt hidden (auto=0)", prompt == null or not prompt.is_visible_in_tree())

	# first key -> slide two
	_feed_key(32)   # Space
	await _wait(15)   # past the 0.1s min
	_check("advanced to slide two", cut.get("_index") == 1)
	_check("still playing on slide two", cut.is_playing() == true)

	# second key -> finish
	_feed_key(13)   # Enter
	await _wait(15)
	_check("callback fired after last slide", _callback_fired)
	_check("player unfrozen after cutscene", not _is_frozen(player))
	_check("cutscene finished", cut.is_playing() == false)

	# --- auto-advance only (no input) ----------------------------------
	_callback_fired = false
	_slide_shown = 0
	cut.play([
		{"text": "auto a", "min": 0.1, "auto": 0.3},
		{"text": "auto b", "min": 0.1, "auto": 0.3},
	], Callable(self, "_on_done"))
	await _wait(90)  # ~1.5s — both 0.3s auto-advances + min elapsed
	_check("auto-advance finished on its own", not cut.is_playing())
	_check("auto-advance callback fired", _callback_fired)

	_finish()


func _on_done() -> void:
	_callback_fired = true


func _feed_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.echo = false
	get_tree().root.push_input(ev, true)


func _is_frozen(player: Node) -> bool:
	if player == null:
		return false
	return player.get("disable_movement") == true


func _find_player() -> Node:
	return _search(get_tree().root)


func _search(n: Node) -> Node:
	if n is CharacterBody3D:
		return n
	for c in n.get_children():
		var f := _search(c)
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
		var cut := get_node_or_null("/root/Cutscene")
		print("  FAIL  ", label, "  (playing=", cut.is_playing() if cut else "?", ")")


func _finish() -> void:
	# cleanup
	var map := get_tree().current_scene
	if map != null:
		map.queue_free()
	print("\n=== CUTSCENE: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
