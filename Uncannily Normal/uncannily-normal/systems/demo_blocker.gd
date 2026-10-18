# systems/demo_blocker.gd — demo-only barrier.
#
# A physical gate that keeps the player out of the unfinished part of the map
# (the real map transition / escape route) until GameState.has_flag(block_flag)
# — default "demo_complete", which the demo never sets, so the player cannot
# "finish" the unfinished game yet.
#
# Scene layout (demo_blocker.tscn):
#   DemoBlocker(Area3D, demo_blocker.gd)
#     Block   StaticBody3D          ← solid collision that stops the player
#     BlockCol CollisionShape3D      ← child of Block (the wall)
#     Sign    MeshInstance3D          ← visible "DEMO" marker
#
# While armed: the child Block solidly blocks movement (the player's
# move_and_slide cannot cross it) AND touching the Area3D pushes them back with
# a short on-screen note. When the flag is set, _disarm() frees the Block +
# Sign and the barrier opens.
extends Area3D
class_name DemoBlocker

@export var block_flag := "demo_complete"
@export var block_message := "this area isn't ready yet.\nkeep exploring."
@export var push_strength := 8.0

var _block: StaticBody3D
var _sign: MeshInstance3D
var _hud: Node
var _armed := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	_block = get_node_or_null("Block")
	if GameState.has_flag(block_flag):
		_disarm()
	else:
		_sign = get_node_or_null("Sign")


func _on_body_entered(body: Node3D) -> void:
	if not _armed or not body.has_method("move_and_slide"):
		return
	_hud = _find_hud()
	if _hud != null and _hud.has_method("show_message"):
		_hud.call("show_message", block_message, 2.0)
	if body is CharacterBody3D:
		var back := body.global_position - global_position
		back.y = 0.0
		if back.length() < 0.001:
			back = Vector3(0, 0, 1)
		body.velocity = back.normalized() * push_strength
		body.move_and_slide()


func _disarm() -> void:
	_armed = false
	if _block != null and is_instance_valid(_block):
		_block.queue_free()
	if _sign != null and is_instance_valid(_sign):
		_sign.queue_free()
	queue_free()


func _find_hud() -> Node:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search(root, "show_message")


func _search(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _search(c, method)
		if f != null:
			return f
	return null
