extends Node3D

## Screenshot survey harness — renders every level with a probe camera and
## writes PNGs + mean-luminance / environment measurements, so we can SEE the
## generated scenes instead of only asserting they load.
##
## Run WINDOWED (no --headless; there is no renderer under --headless, so frame
## grabs come back blank):
##
##   godot --path "C:/Users/Santi/Uncannily Normal/uncannily-normal" --scene res://tools/survey_scene.tscn
##
## Per the godot-ai-game-dev visual_verification recipe:
##  - aims at REAL node positions found at runtime (no hardcoded/guesstimated
##    viewpoints — those produce empty-ground shots and "broken harness" reports)
##  - frees the player body so the probe camera owns the view (a player-carried
##    light/listener would render from the wrong place)
##  - hides the HUD CanvasLayer so title cards don't cover every shot
##  - waits RenderingServer.frame_post_draw, reads pixels via Image.get_image()
##    (NOT the Godot 3.x .get_data())
##  - measures mean luminance (< ~0.15 means detail can't read no matter the texture)
@export var level_scenes: Array[String] = [
	"res://scenes/map0.tscn",
	"res://scenes/map1.tscn",
	"res://scenes/map2.tscn",
]
@export var output_dir := "C:/Users/Santi/AppData/Local/hermes/cache/scratch/shots"
@export var targets_per_scene := 8   # props to aim at in each level
@export var warmup_frames := 60

var _cam: Camera3D
var _level: Node3D
var _labels: Dictionary = {}


func _ready() -> void:
	print("survey start -> %d levels" % level_scenes.size())
	DirAccess.make_dir_recursive_absolute(output_dir)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70
	_cam.near = 0.1
	_cam.far = 120
	add_child(_cam)
	# let the project's first render clear its black splash frame
	for _i in range(warmup_frames):
		await get_tree().process_frame
	for scene in level_scenes:
		_survey_scene(scene)
	print("survey done -> %s" % output_dir)
	get_tree().quit(0)


func _survey_scene(scene_path: String) -> void:
	var tag := scene_path.get_file().get_basename()
	print("--- %s ---" % tag)
	if _level != null:
		_level.queue_free()
		await get_tree().process_frame
	var ps := load(scene_path) as PackedScene
	if ps == null:
		push_error("survey: level_scene not found: %s" % scene_path)
		print("  [FAIL] %s: not found" % tag)
		return
	_level = ps.instantiate() as Node3D
	add_child(_level)
	# Probe camera owns the view: free the player body, disable any attached
	# camera, and hide the HUD CanvasLayer so it doesn't cover the shots.
	for n in _collect(_level):
		if n is CharacterBody3D:
			(n as CharacterBody3D).queue_free()
		elif n is Camera3D and (n as Camera3D) != _cam:
			(n as Camera3D).current = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
	# Let the level's lights + NightEnvironment settle before shooting.
	for _i in range(3):
		await get_tree().process_frame
	var targets := _pick_targets(_level)
	if targets.is_empty():
		print("  [WARN] %s: no prop targets found" % tag)
		return
	var centroid := Vector3.ZERO
	for t in targets:
		centroid += (t as Node3D).global_position
	centroid /= float(targets.size())
	# one high floor-plan shot aimed at the level centroid
	_aim_and_capture("%s_overhead" % tag, centroid + Vector3(0, 55, 18), centroid, Vector3.UP)
	for i in range(min(targets_per_scene, targets.size())):
		var t: Node3D = targets[i]
		var owner: String = _owner_name(t)
		var here := t.global_position
		_aim_and_capture("%s_%s_eye" % [tag, owner], here + Vector3(1.6, 1.75, 1.7), here + Vector3(0, 1.6, 0), Vector3.UP)
		_aim_and_capture("%s_%s_wide" % [tag, owner], here + Vector3(5.0, 4.0, 5.5), here, Vector3.UP)
	_measure_env(tag)


func _owner_name(n: Node) -> String:
	# MeshInstance3D children inside an Area3D/StaticBody3D are often just "Mesh";
	# use the owning prop's name so labels are meaningful and unique.
	var name := n.get_name()
	var low := name.to_lower()
	if low == "mesh" or low.ends_with("mesh"):
		if n.get_parent() != null:
			return n.get_parent().get_name()
	return name


func _pick_targets(root: Node) -> Array:
	var out: Array = []
	for n in _collect(root):
		if not (n is MeshInstance3D):
			continue
		if (n as MeshInstance3D).mesh == null:
			continue
		var name: String = str(n.get_name()).to_lower()
		# skip shell geometry — floor / ceiling / walls / ground / building
		if name.contains("floor") or name.contains("ceil") or name.contains("wall") \
			or name.contains("ground") or name.contains("build") or name.contains("_col"):
			continue
		out.append(n)
	return out


func _aim_and_capture(label: String, cam_pos: Vector3, look_at_pos: Vector3, up: Vector3) -> void:
	# de-dupe labels (two props can resolve to the same owner name)
	if label in _labels:
		label = "%s_%d" % [label, _labels.size()]
	_labels[label] = true
	_cam.global_position = cam_pos
	# look_at is an instance method in 4.7; (target, up) — up to Vector3.UP.
	_cam.look_at(look_at_pos, up)
	await RenderingServer.frame_pre_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("  [FAIL] %s: no image" % label)
		return
	img.flip_y()
	var path := "%s/%s.png" % [output_dir, label]
	img.save_png(path)
	var mean := _mean_lum(img)
	print("  [OK] %s -> mean_lum=%.4f" % [label, mean])


func _measure_env(tag: String) -> void:
	var env = get_world_3d().environment
	if env == null:
		print("  %s env: none" % tag)
		return
	var total := 0
	var lit := 0
	for n in _collect(_level):
		if n is OmniLight3D:
			total += 1
			if (n as OmniLight3D).light_energy > 0.0:
				lit += 1
	print("  %s env: ambient=%.2f fog=%.3f tonemap=%s exp=%.2f lights:omni=%d(lit %d)" % [
		tag, env.ambient_light_energy, env.fog_density,
		str(env.tonemap_mode), env.tonemap_exposure, total, lit,
	])


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
	var mean := total / n
	print("  LUMA: mean=%.4f max=%.4f over %d samples" % [mean, brightest, n])
	return mean


func _collect(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_collect(c))
	return out
