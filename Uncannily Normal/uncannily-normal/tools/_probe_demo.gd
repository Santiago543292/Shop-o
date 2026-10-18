# Headless instance-check for demo_blocker.tscn + map1 deps.
# Loads every ext_resource-referenced system scene the survey can't reach,
# so the map1 parse error is resolved under the real engine, not inferred.
extends SceneTree

const SCENES_TO_PROBE := [
	"res://systems/demo_blocker.tscn",
	"res://systems/npc.tscn",
	"res://systems/shopkeeper.tscn",
	"res://systems/locked_door.tscn",
	"res://systems/bus_exit.tscn",
	"res://systems/food.tscn",
]

func _init() -> void:
	print("probe: starting instance check on v%s" % Engine.get_version_info().string)
	var root := get_root()
	var ok := 0
	var fail := 0
	for p in SCENES_TO_PROBE:
		var ps := load(p) as PackedScene
		if ps == null:
			printerr("probe: FAIL load (null) %s" % p)
			fail += 1
			continue
		var inst := ps.instantiate()
		# give autoloads (GameState etc.) a frame so _ready() can run
		root.add_child(inst)
		await process_frame
		# if instantiation reached here, the scene graph parsed OK
		print("probe: OK %s -> %s" % [p, inst.name])
		inst.queue_free()
		ok += 1
	print("probe: done ok=%d fail=%d" % [ok, fail])
	if fail > 0:
		quit(1)
	else:
		quit(0)
