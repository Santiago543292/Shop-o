extends StaticBody3D

## door.gd — a sealable door.
##
## Starts CLOSED (solid: its `Col` CollisionShape3D blocks the way, its `Mesh`
## is visible). escape.gd calls `open()` after nightfall to swing it away.
##
## Layout expected as children:
##   Col   CollisionShape3D   — the solid profile, disabled on open()
##   Mesh  MeshInstance3D     — the visual door, hidden on open()

@export var prompt := "[E]  DOOR"

var _col: CollisionShape3D
var _mesh: MeshInstance3D


func _ready() -> void:
	_col = get_node_or_null("Col")
	if _col == null:
		for c in get_children():
			if c is CollisionShape3D:
				_col = c
				break
	_mesh = get_node_or_null("Mesh")
	if _mesh == null:
		for c in get_children():
			if c is MeshInstance3D:
				_mesh = c
				break
	# ensure it starts shut and solid
	if _col:
		_col.set_deferred("disabled", false)
	if _mesh:
		_mesh.visible = true


func open() -> void:
	if _col and is_instance_valid(_col):
		_col.set_deferred("disabled", true)
	if _mesh and is_instance_valid(_mesh):
		_mesh.visible = false
	# graceful no-op until the player provides the door sound file
	var ga := get_node_or_null("/root/GameAudio")
	if ga != null and ga.has_method("play_sound"):
		ga.call("play_sound", "door")


func close() -> void:
	if _col and is_instance_valid(_col):
		_col.set_deferred("disabled", false)
	if _mesh and is_instance_valid(_mesh):
		_mesh.visible = true
