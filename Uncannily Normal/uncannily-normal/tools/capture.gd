extends Node

## Capture harness — loads each scene, screenshots it, quits.
## Windowed only (there is no renderer under --headless).

const OUT_DIR := "user://captures"
const SCENES := [
	["menu", "res://ui/main_menu.tscn"],
	["map0", "res://scenes/map0.tscn"],
	["map1", "res://scenes/map1.tscn"],
	["map2", "res://scenes/map2.tscn"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await get_tree().process_frame

	for entry in SCENES:
		var label: String = entry[0]
		var path: String = entry[1]
		var ps: PackedScene = load(path)
		if ps == null:
			print("CAPTURE: could not load ", path)
			continue
		var inst := ps.instantiate()
		get_tree().root.add_child(inst)
		get_tree().current_scene = inst
		for i in range(50):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var f := "%s/%s.png" % [OUT_DIR, label]
			img.save_png(f)
			print("SHOT: ", ProjectSettings.globalize_path(f))
		else:
			print("CAPTURE: no image for ", label)
		inst.queue_free()
		await get_tree().process_frame

	get_tree().quit(0)
