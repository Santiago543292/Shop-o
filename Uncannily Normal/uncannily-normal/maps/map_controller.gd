extends Node3D

## Map controller — runs one map in the Uncannily Normal progression.
##
## Each map has: a bus stop (the exit), lamps that should be lit, and a
## controller that tracks where the player is. The bus stop is how the player
## moves to the next map.
##
## Map 0  THE BUS STOP   — wake up, find the bus
## Map 1  THE STREETS    — explore, get food, see weird things
## Map 2  THE SHOP       — the trap, the work, the escape

@export var map_id := "map0"
@export var map_title := "THE BUS STOP"
@export var map_objective := "FIND THE BUS STOP"
@export var next_map := "res://scenes/map1.tscn"

@export var bus_stop_position := Vector3(0, 0, 0)
@export var bus_stop_prompt := "[E]  WAIT FOR THE BUS"

var _hud: Node
var _player: Node3D
var _bus_area: Area3D
var _arrived := false


func _ready() -> void:
	_hud = _hud_node()
	_player = _find_player()
	_setup_bus_stop()
	_welcome()


func _welcome() -> void:
	if _hud == null:
		return
	_hud.call("show_message", map_title + "\n" + map_objective, 5.0)


func _find_player() -> Node3D:
	for c in get_children():
		if c is CharacterBody3D and c != self and c.has_method("move_and_slide"):
			return c
	return null


func _hud_node() -> Node:
	for c in get_children():
		if c.has_method("set_prompt"):
			return c
	return null


func _setup_bus_stop() -> void:
	# Find the bus stop mesh and add an interaction area + collider.
	for c in get_children():
		if c.name.to_lower().contains("bus_stop") and c is MeshInstance3D:
			bus_stop_position = c.global_position
			_add_bus_area(c)
			_add_collider(c)
			_add_lamp(c)
			break


func _add_bus_area(mesh: MeshInstance3D) -> void:
	_bus_area = Area3D.new()
	_bus_area.name = "BusStopArea"
	_bus_area.position = mesh.global_position
	_bus_area.collision_layer = 1
	_bus_area.collision_mask = 1
	_bus_area.monitoring = true

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 3.0)
	shape.shape = box
	_bus_area.add_child(shape)

	var script := load("res://maps/bus_stop.gd")
	_bus_area.set_script(script)
	add_child(_bus_area)


func _add_collider(mesh: MeshInstance3D) -> void:
	# An invisible box collider so the player cannot walk through the bus stop.
	var body := StaticBody3D.new()
	body.name = mesh.name + "_Collider"
	body.position = mesh.global_position

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 3.0, 1.5)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _add_lamp(mesh: MeshInstance3D) -> void:
	# A cold light above the bus stop so it reads as a place, not a prop.
	var lamp := OmniLight3D.new()
	lamp.name = "BusStopLamp"
	lamp.position = mesh.global_position + Vector3(0, 3.5, 0)
	lamp.light_color = Color(0.75, 0.82, 0.95, 1)
	lamp.light_energy = 4.0
	lamp.omni_range = 14.0
	add_child(lamp)


func _process(_delta: float) -> void:
	if _arrived:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return
	# Show the prompt when the player is near the bus stop.
	if _hud == null:
		return
	var dist := _player.global_position.distance_to(bus_stop_position)
	if dist < 4.0:
		_hud.call("set_prompt", bus_stop_prompt)
	elif _hud != null:
		_hud.call("set_prompt", "")
