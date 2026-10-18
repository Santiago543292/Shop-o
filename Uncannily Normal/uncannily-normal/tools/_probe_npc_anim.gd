# Headless (no-GUI) probe for systems/npc.gd FBX + walk-anim wiring.
# Run: godot --headless --script tools/_probe_npc_anim.gd
@tool
extends Node

func _ready() -> void:
	var result := await _check()
	print("PROBE NPC:", result)
	get_tree().quit()

func _check() -> String:
	var sc := load("res://systems/npc.tscn") as PackedScene
	if sc == null:
		return "FAIL npc.tscn missing"
	var npc := sc.instantiate() as Node
	add_child(npc)
	# npc._ready fires on the next frame (after _load_fbx runs).
	await get_tree().process_frame
	var model := npc.get_node_or_null("Model") as Node3D
	if model == null:
		return "FAIL Model node missing on NPC"
	var n_children := model.get_child_count()
	var ap := _find_ap(model)
	var anims: Array = []
	if ap != null:
		anims = ap.get_animation_list()
	var mesh := npc.get_node_or_null("Mesh") as MeshInstance3D
	var mesh_vis := "n/a"
	if mesh != null:
		mesh_vis = str(mesh.visible)
	return "OK children=%d animation_player=%s anims=%s capsule_visible=%s" % [
		n_children, ap != null, anims, mesh_vis
	]

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null
