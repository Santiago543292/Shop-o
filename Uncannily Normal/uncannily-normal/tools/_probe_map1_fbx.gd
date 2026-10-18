# map1 + Walking.fbx probe: confirms the full DemoGate->demo_blocker load path
# instantiates under the real engine, and dumps the FBX node tree so NPC
# animation can be wired against the actual imported AnimationPlayer/anims.
extends SceneTree

func _init() -> void:
	print("probe: starting map1+fbx probe on %s" % Engine.get_version_info().string)
	for p in [
		"res://scenes/map0.tscn",
		"res://scenes/map1.tscn",
		"res://scenes/map2.tscn",
	]:
		_probe_map(p)
	_probe_fbx("res://Assets/animations/Walking.fbx")
	quit(0)


func _probe_map(path: String) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		printerr("PROBE: %s FAIL load(null)" % path)
		return
	var inst := ps.instantiate()
	if inst == null:
		printerr("PROBE: %s FAIL instantiate (see stderr for parse errors)" % path)
		return
	var dg := inst.find_child("DemoGate", true, false)
	var db := inst.find_child("DemoBlocker", true, false) if dg else null
	print("PROBE: %s OK top_children=%d DemoGate=%s DemoBlocker=%s" % [
		path, inst.get_child_count(), dg != null, db != null])
	inst.queue_free()


func _probe_fbx(path: String) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		printerr("PROBE FBX: %s FAIL (not imported?)" % path)
		return
	var inst := ps.instantiate()
	print("PROBE FBX: root=%s" % inst.get_class())
	_dump(inst, 0)
	inst.queue_free()


func _dump(n: Node, depth: int) -> void:
	if depth > 6:
		return
	var p := "  ".repeat(depth)
	if n is AnimationPlayer:
		print("%sAP anims=%s" % [p, (n as AnimationPlayer).get_animation_list()])
	elif n is Skeleton3D:
		print("%sSkeleton3D bones=%d" % [p, (n as Skeleton3D).get_bone_count()])
	elif n is MeshInstance3D:
		print("%sMeshInstance3D" % p)
	elif n is Node3D:
		print("%s%s (%s)" % [p, n.get_name(), n.get_class()])
	for c in n.get_children():
		_dump(c, depth + 1)
