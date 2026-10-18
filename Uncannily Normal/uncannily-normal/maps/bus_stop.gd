extends Area3D

## Bus stop interaction — the player waits here to go to the next map.

@export var next_map := "res://scenes/map1.tscn"
@export var prompt := "[E]  WAIT FOR THE BUS"

var _hud: Node
var _player: Node3D
var _prompt_shown := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
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
		return null
	for c in root.get_children():
		if c.has_method("set_prompt"):
			return c
	return null


func _on_body_entered(body: Node3D) -> void:
	if _hud != null:
		_hud.call("set_prompt", prompt)
	_prompt_shown = true


func _on_body_exited(body: Node3D) -> void:
	if _hud != null:
		_hud.call("set_prompt", "")
	_prompt_shown = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not _prompt_shown:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return
	# Check the player is actually near.
	var dist := global_position.distance_to(_player.global_position)
	if dist > 5.0:
		return
	if _hud != null:
		_hud.call("show_message", "The bus is coming...", 3.0)
	get_tree().change_scene_to_file(next_map)
