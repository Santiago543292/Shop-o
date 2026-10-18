extends Node3D

## Light hum — the buzzing you hear near a street light.
##
## Attached to the map's `Lights` node. Every frame it measures the player's
## distance to the NEAREST light and drives a single hum bed's volume from it,
## so walking toward a lamp brings the buzz up and stepping away lets it fall
## off. One player for the whole map, not one per lamp.
##
## The map's lamps are spread far apart — the nearest to the spawn point is
## about 24 units away — so the hear distance has to be generous or the hum
## never leaves silence at all.

@export var hear_distance := 20.0
@export var check_every := 0.1

var _lights: Array[OmniLight3D] = []
var _player: Node3D
var _timer := 0.0


func _ready() -> void:
	for c in get_children():
		if c is OmniLight3D:
			_lights.append(c)
	if _lights.is_empty():
		# A map with no lights in this group: nothing to hum.
		set_physics_process(false)
		GameAudio.set_hum_proximity(0.0)
		return
	GameAudio.set_hum_proximity(0.0)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_every

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			GameAudio.set_hum_proximity(0.0)
			return

	var nearest := INF
	for l in _lights:
		if not is_instance_valid(l):
			continue
		nearest = minf(nearest, l.global_position.distance_to(_player.global_position))

	GameAudio.set_hum_proximity(1.0 - nearest / hear_distance)


func _find_player() -> Node3D:
	var root := get_tree().current_scene
	if root == null:
		return null
	return _search(root)


func _search(n: Node) -> Node3D:
	if n is CharacterBody3D:
		return n
	for c in n.get_children():
		var f := _search(c)
		if f != null:
			return f
	return null
