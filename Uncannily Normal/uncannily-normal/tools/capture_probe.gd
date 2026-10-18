extends Node3D

## Single-frame offscreen render probe. Run with `--no-window` (NOT --headless
## per the godot-ai-game-dev skill; --headless has no renderer on this build):
##
##   Godot.exe --path <proj> --no-window --scene res://tools/probe_scene.tscn
##
## If offscreen capture works, this writes a 1024x640 png to scratch/shots
## and prints PROBE mean_lum=<non-zero>. If `--no-window` still yields a black
## framebuffer, mean_lum will be 0.0 (the recipe's "no renderer to capture").

@export var level_scene := "res://scenes/map2.tscn"
@export var output_dir := "C:/Users/Santi/AppData/Local/hermes/cache/scratch/shots"
@export var out_name := "probe_map2_entrance.png"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var ps := load(level_scene) as PackedScene
	if ps == null:
		print("PROBE FAIL no scene")
		get_tree().quit(1)
		return
	var level := ps.instantiate()
	add_child(level)

	# Free the player body so it can't fight our probe camera, and disable any
	# in-level cameras.
	for n in _collect(level):
		if n is CharacterBody3D:
			n.queue_free()
		if n is Camera3D:
			(n as Camera3D).current = false
		if n is CanvasLayer and (n.has_method("show_message") or n.has_method("set_objective")):
			n.visible = false

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 70
	cam.near = 0.1
	cam.far = 60
	add_child(cam)
	cam.position = Vector3(0, 1.7, 6.5)
	cam.look_at(Vector3(0, 1.7, -2), Vector3.UP)

	# Force a drawn frame.
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("PROBE FAIL no image (offscreen? )")
		get_tree().quit(1)
		return
	img.flip_y()
	var path := "%s/%s" % [output_dir, out_name]
	img.save_png(path)

	# Luminance + a "non-blank" pixel count.
	var total := 0.0
	var brightest := 0.0
	var nonzero := 0
	var step := 4
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			var lum := (c.r + c.g + c.b) / 3.0
			total += lum
			if lum > brightest:
				brightest = lum
			if lum > 0.005:
				nonzero += 1
	var n := ((img.get_height() + step - 1) / step) * ((img.get_width() + step - 1) / step)
	print("PROBE %s %dx%d mean_lum=%.4f max=%.4f nonzero=%d/%d" % [
		path, img.get_width(), img.get_height(), total / n, brightest, nonzero, int(n)
	])
	get_tree().quit(0)


func _collect(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_collect(c))
	return out
