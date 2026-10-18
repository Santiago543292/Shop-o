extends Node3D

## HUD demo — a room with the HUD on it, so the list UI can be seen working.
##
## Press E to tick off the next item on the list, R to reset. This exists so
## the interface can be checked and styled before the shop is finished.

var _index := 0


func _ready() -> void:
	_welcome()


func _welcome() -> void:
	var hud := _hud()
	if hud != null:
		hud.call("show_message", "HUD TEST — press E to tick the list, R to reset", 6.0)


func _hud() -> Node:
	for c in get_children():
		if c.has_method("set_prompt"):
			return c
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_advance()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameState.reset()
		_index = 0


func _advance() -> void:
	var entries := GameState.list()
	if _index >= entries.size():
		GameState.reset()
		_index = 0
		return
	var e: Dictionary = entries[_index]
	_index += 1
	GameState.collect(str(e["id"]))

	var hud := _hud()
	if hud != null:
		hud.call("set_prompt", "[E]  TAKE  %s" % str(e["label"]))
		if bool(e.get("trap", false)):
			GameState.set_flag("warned")
			hud.call("show_message",
				"THE LAST ONE.\nIt is warm. The label is in a language you do not read.", 4.0)
		else:
			var p := GameState.normal_progress()
			hud.call("show_message", "%s  —  %d / %d" % [str(e["label"]), p.x, p.y], 2.0)
