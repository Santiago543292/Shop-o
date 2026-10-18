extends Node3D

## shop_controller.gd — the shop's brain while the player is inside.
##
## Two jobs right now, both small:
##   1. materialise the trap contract on the counter once the fine-print
##      cutscene finishes (called by TrapItem._spawn_contract, which looks for
##      any root child with a `spawn_contract` method).
##   2. own the customer/NPC wiring later — the CustomerSystem needs NPCs with
##      walk_to/talk_to; that loop is deferred until the escape/horror beats
##      are solid, so for now customers simply do not spawn.
##
## The contract is the thing the player is now forced to serve. It is a
## visible plain thing on the counter: ordinary enough that the player might
## not notice it is paperwork they cannot unread.

@export var contract_position := Vector3(0, 0.3, 0)   # local offset on the counter

var _hud: Node
var _contract_spawned := false


func _ready() -> void:
	_hud = _hud_node()


func spawn_contract() -> void:
	if _contract_spawned:
		return
	_contract_spawned = true

	# A flat, paper-thin slab on the counter — the fine print made real.
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.02, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.90, 0.82)
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.10, 0.08)
	mat.emission_energy = 0.4
	box.material = mat
	mesh.mesh = box
	add_child(mesh)

	if _hud != null:
		_hud.call("show_message",
			"A contract appears on the counter.\n"
			+ "It was always there in invisible ink.", 5.0)
	GameAudio.play_beep()


func _hud_node() -> Node:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search(root)


func _search(n: Node) -> Node:
	if n.has_method("set_prompt"):
		return n
	for c in n.get_children():
		var f := _search(c)
		if f != null:
			return f
	return null
