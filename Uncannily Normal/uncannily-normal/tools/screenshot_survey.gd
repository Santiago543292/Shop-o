extends Node3D

## Screenshot survey harness — renders a level with a probe camera and writes
## PNGs + a mean-luminance measurement, so we can SEE a generated scene instead
## of only asserting it loads. Run WINDOWED (no --headless; there is no renderer
## under --headless, so frame grabs come back blank).
##
##   godot --path <proj> --scene res://tools/survey_scene.tscn
##
## Per the godot-ai-game-dev visual_verification recipe: aim at real nodes, hide
## the HUD, drive the CharacterBody3D (here we just free the player and fly a
## probe camera), and measure mean luminance (below ~0.15 = detail can't read).

@export var level_scene := "res://scenes/map2.tscn"
@export var output_dir := "C:/Users/Santi/AppData/Local/hermes/cache/scratch/shots"

var _cam: Camera3D
var _level: Node3D


# (name, from, to, up) — aim at the shop's real layout (W=22,D=18: front z=+9,
# counter z=-6.6, back exit z=-9).
var _views: Array = [
	["01_entrance",  Vector3(0, 1.7, 6.5),  Vector3(0, 1.7, -2),  Vector3.UP],
	["02_counter",    Vector3(0, 1.9, -4.0), Vector3(0, 1.7, -7),  Vector3.UP],
	["03_shelf_left", Vector3(-9.5, 1.9, -1.0), Vector3(-5, 1.7, -1), Vector3.UP],
	["04_shelf_right",Vector3(9.5, 1.9, -1.0),  Vector3(5, 1.7, -1),  Vector3.UP],
	["05_back_exit",  Vector3(0, 1.9, -7.8), Vector3(0, 1.7, -5),  Vector3.UP],
	["06_overhead",   Vector3(0, 14.0, 0),  Vector3(0, 0, 0),     Vector3.FORWARD],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)

	var ps := load(level_scene) as PackedScene
	if ps == null:
		push_error("survey: level_scene not found: " + level_scene)
		get_tree().quit(1)
		return
	_level = ps.instantiate() as Node3D
	add_child(_level)

	# The player's godoplayer camera would fight our probe — free the body so we
	# own the view. Systems that look up the player will simply find none (fine
	# for a static survey; lights + environment still render).
	for n in _collect(_level):
		if n is CharacterBody3D:
			n.queue_free()
		if n is Camera3D:
			(n as Camera3D).current = false
		if n is CanvasLayer and n.has_method("show_message"):
			n.set("visible", false)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70
	_cam.near = 0.1
	_cam.far = 60
	add_child(_cam)

	# Let the level + its NightEnvironment settle a couple of frames.
	await get_tree().process_frame
	await get_tree().process_frame

	var name := _safe_name(level_scene)
	await _survey_all()
	print("survey done -> %s" % output_dir)
	get_tree().quit(0)


func _survey_all() -> void:
	for v in _views:
		var label: String = v[0]
		var from: Vector3 = v[1]
		var to: Vector3 = v[2]
		var up: Vector3 = v[3]
		_cam.position = from
		_cam.look_at(to, up)
		await RenderingServer.frame_pre_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		if img == null:
			print("  [FAIL] %s: no image" % label)
			continue
		img.flip_y()
		var path := "%s/%s_%s.png" % [output_dir, _safe_name(level_scene), label]
		img.save_png(path)
		var mean := _mean_lum(img)
		print("  [OK] %s -> %s  mean_lum=%.4f" % [label, path, mean])
	_measure_env()


func _measure_env() -> void:
	var w : World3D = get_world_3d()
	var env = w.environment
	if env == null:
		print("  env: none")
		return
	print("  ambient_energy=%.2f ambient_color=%s fog=%.3f tonemap=%s exp=%.2f" % [
		env.ambient_light_energy,
		str(env.ambient_light_color),
		env.fog_density,
		str(env.tonemap_mode),
		env.tonemap_exposure,
	])
	var omnis := 0
	var total := 0
	for n in _collect(_level):
		if n is OmniLight3D:
			total += 1
			if (n as OmniLight3D).light_energy > 0.0:
				omnis += 1
	var dir := 0
	for n in _collect(_level):
		if n is DirectionalLight3D and (n as DirectionalLight3D).light_energy > 0.0:
			dir += 1
	print("  lights: omni=%d (lit %d) directional=%d" % [total, omnis, dir])


func _mean_lum(img: Image) -> float:
	var total := 0.0
	var n := 0
	var brightest := 0.0
	var step: int = int(max(1, img.get_width() / 120))
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			var lum := (c.r + c.g + c.b) / 3.0
			total += lum
			n += 1
			if lum > brightest:
				brightest = lum
	if n == 0:
		return 0.0
	print("  LUMA: mean=%.4f max=%.4f over %d samples" % [total / n, brightest, n])
	return total / n


func _safe_name(path: String) -> String:
	return path.get_file().get_basename()


func _collect(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_collect(c))
	return out
