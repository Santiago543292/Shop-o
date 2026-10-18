extends Node3D

## The escape — night falls, the shop changes, the player must get out.
##
## After working all day, night falls. The shop is different now — lights
## flicker, the owner is gone, and something is in the walls. The player
## must find the exit before the monster finds them.
##
## This is the horror payoff: the trap closes, the player is complicit, and
## the only way out is through the dark.

@export var escape_delay := 30.0     # seconds of work before night falls
@export var monster_speed := 3.5
@export var exit_position := Vector3(0, 0, -8)

var _hud: Node
var _player: Node3D
var _timer := 0.0
var _night := false
var _escaped := false
var _monster: Node3D = null


func _ready() -> void:
	_hud = _hud_node()
	_player = _find_player()


func _find_player() -> Node3D:
	var root := _scene_root()
	if root == null:
		return null
	for c in root.get_children():
		if c is CharacterBody3D and c != self and c.has_method("move_and_slide"):
			return c
	return null


func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n


func _hud_node() -> Node:
	var root := _scene_root()
	if root == null:
		root = get_tree().root
	return _hud_find(root, "set_prompt")


func _hud_find(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _hud_find(c, method)
		if f != null:
			return f
	return null


func _process(delta: float) -> void:
	if _escaped:
		return

	if not _night:
		# Nightfall waits for the trap to fire. Before the player has bought
		# the last item the shop is open — counting down here would let the
		# monster spawn before the contract is signed.
		if not GameState.has_flag("trapped_in_shop"):
			return
		_timer += delta
		if _timer >= escape_delay:
			_start_night()
		return

	# Night is here — the monster hunts. It is a dark shape in the walls,
	# so a plain Node3D that drifts toward the player is enough (no physics
	# body, no velocity property to set).
	if _monster != null and is_instance_valid(_monster) and _player != null and is_instance_valid(_player):
		var to := _player.global_position - _monster.global_position
		to.y = 0.0
		if to.length() > 0.5:
			_monster.translate(to.normalized() * monster_speed * delta)

	# Check if the player reached the exit
	if _player != null and is_instance_valid(_player):
		var dist := _player.global_position.distance_to(exit_position)
		if dist < 2.0:
			_escaped = true
			if _hud != null:
				_hud.call("show_message", "You found the exit.\nRUN.", 3.0)
			_go_home()


func _start_night() -> void:
	_night = true
	# The shop changes while you watch. The cutscene freezes you as the doors
	# seal and the hunting begins.
	var slides: Array[Dictionary] = [
		{"text": "the front door is gone.\nthe windows are black.\nthe lights will not turn off.", "min": 2.2},
		{"text": "you hear something\nmoving in the walls.", "min": 2.2},
	]
	var cut := get_node_or_null("/root/Cutscene")
	if cut != null and cut.has_method("play") and not cut.is_playing():
		cut.play(slides, Callable(self, "_on_night_cutscene_done"))
	else:
		_on_night_cutscene_done()


func _on_night_cutscene_done() -> void:
	if _hud != null:
		_hud.call("show_message", "Night falls.\nFind the way out before it finds you.", 4.0)
	_spawn_monster()
	_unlock_exit()


func _spawn_monster() -> void:
	# The monster appears — a dark figure in the walls.
	_monster = Node3D.new()
	_monster.name = "Monster"
	_monster.position = global_position + Vector3(10, 0, 10)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 2.0, 0.8)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.0, 0.0, 1)
	mat.emission_energy = 0.5
	mesh.material_override = mat
	_monster.add_child(mesh)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.8, 0.1, 0.1, 1)
	glow.light_energy = 2.0
	glow.omni_range = 6.0
	_monster.add_child(glow)

	add_child(_monster)


func _unlock_exit() -> void:
	# The exit door opens — the player can now leave.
	var root := _scene_root()
	if root == null:
		return
	for c in root.get_children():
		if c.name.to_lower().contains("exit") or c.name.to_lower().contains("door"):
			if c.has_method("open"):
				c.call("open")
			elif c.has_method("set") and not c.name.begins_with("_"):
				c.call("set", "visible", true)
			break


func _go_home() -> void:
	# The player escapes — they get home before the monster catches them.
	await get_tree().create_timer(3.0).timeout
	if _hud != null:
		_hud.call("show_message",
			"You made it home.\nBut the shop is still there.\nIt will always be there.", 6.0)
	await get_tree().create_timer(6.0).timeout
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
