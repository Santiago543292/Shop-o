extends "res://systems/interactable.gd"

## Food item — restores hunger when the player eats it.
##
## Found at the diner (map1). Interacting eats it: a short cutscene plays
## (the bite, the chew, the pause) so "eating" is a moment instead of a
## stat change, then hunger is restored and the prop disappears.
##
## Extends Interactable (Area3D + E-prompt) so it is walk-up-and-press-E
## like every other interactable — no StaticBody3D raycast lookup needed.
## The hunger system on the map is found by capability (has_method "eat").

@export var food_name := "APPLE"
@export var hunger_restore := 0.6
@export var is_free := true

var _mesh: MeshInstance3D
var _glow: OmniLight3D
var _tween: Tween = null
var _eaten := false


func _ready() -> void:
	super()
	prompt = "[E]  TAKE THE %s" % food_name.to_upper()
	_mesh = get_node_or_null("Mesh") as MeshInstance3D

	# Swap the placeholder sphere for a real apple mesh from the imported GLB.
	# Falls back to the sphere (food.tscn) if the asset/mesh is missing, so
	# eating never breaks on a missing asset.
	_apply_produce()

	# A warm glow so the food reads as interactive.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.5)
	_glow.light_energy = 0.8
	_glow.omni_range = 2.0
	_glow.position = Vector3(0, 0.3, 0)
	add_child(_glow)
	_pulse()


func _apply_produce() -> void:
	var ps := load("res://Assets/Vegetables/Vegetables/Veggies_glb.glb") as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate()
	var apple := inst.find_child("Apple_Red", true, false)
	if (apple is MeshInstance3D) and (apple as MeshInstance3D).mesh != null:
		var a := apple as MeshInstance3D
		_mesh.material_override = null
		_mesh.mesh = null
		inst.remove_child(a)
		_mesh.add_child(a)
		a.scale = Vector3(1.9, 1.9, 1.9)
		for s in a.mesh.get_surface_count():
			var mat := a.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	inst.queue_free()


func _pulse() -> void:
	if _glow == null:
		return
	if _tween != null:
		_tween.kill()
	var tw := create_tween().set_loops()
	tw.tween_property(_glow, "light_energy", 0.3, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "light_energy", 0.8, 0.9).set_trans(Tween.TRANS_SINE)
	_tween = tw


func interact() -> void:
	if _eaten:
		return
	_eaten = true
	var slides: Array[Dictionary] = [
		{"text": "you eat the %s.\nthe sharp hunger eases." % food_name, "min": 0.8, "auto": 1.2},
		{"text": "you feel stronger.\nready to keep moving.", "min": 0.6, "auto": 1.0},
	]
	var cut := get_node_or_null("/root/Cutscene")
	if cut != null and cut.has_method("play") and not cut.is_playing():
		cut.play(slides, Callable(self, "_finish_eat"))
	else:
		_finish_eat()


func _finish_eat() -> void:
	var hunger_system := _find_hunger()
	if hunger_system != null and hunger_system.has_method("eat"):
		hunger_system.call("eat", hunger_restore)
	if _hud != null:
		_hud.call("show_message", "You feel less hungry.", 2.0)
	if _mesh != null:
		_mesh.visible = false
	if _glow != null:
		if _tween != null:
			_tween.kill()
			_tween = null
		_glow.queue_free()
		_glow = null


## --- capability lookup (recursive, like Interactable) -----------------------

func _find_hunger() -> Node:
	var root := _scene_root()
	if root == null:
		return null
	for c in root.get_children():
		if c.has_method("eat"):
			return c
	return null


func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n
