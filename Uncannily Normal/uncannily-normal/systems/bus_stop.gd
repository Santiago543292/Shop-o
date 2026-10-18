extends Node3D

## Bus stop progression — how the player moves between maps.
##
## The bus stop is the exit point of each map. The player interacts with it,
## the bus arrives (or doesn't), and the next map loads.
##
## Map 0 → Map 1 → Map 2 → Escape

var _hud: Node
var _player: Node3D
var _prompt_shown := false
var _bus_arriving := false

@export var next_map_id := "map1"
@export var bus_wait_time := 3.0


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
		return null
	for c in root.get_children():
		if c.has_method("set_prompt"):
			return c
	return null


func _process(_delta: float) -> void:
	if _bus_arriving:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return
	if _hud == null:
		return

	var dist := _player.global_position.distance_to(global_position)
	if dist < 5.5:
		_hud.call("set_prompt", "[E]  WAIT FOR THE BUS")
	else:
		_hud.call("set_prompt", "")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _bus_arriving:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return
	var dist := _player.global_position.distance_to(global_position)
	if dist > 6.5:
		return

	_bus_arriving = true
	if _hud != null:
		_hud.call("show_message", "The bus is coming...\nHold on.", bus_wait_time + 1.0)
	await get_tree().create_timer(bus_wait_time).timeout

	# Load the next map
	var next_scene := GameState.next_scene(next_map_id)
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	else:
		# No next map — reset or end
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
