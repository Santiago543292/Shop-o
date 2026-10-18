extends Node

## Minimal shop capture — loads the shop, adds a bright camera, screenshots.
## No PSX shader, so we can see the raw scene.

const OUT := "user://captures/shop_raw.png"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var ps: PackedScene = load("res://shop/shop.tscn")
	if ps == null:
		print("CAPTURE: could not load shop")
		get_tree().quit(1)
		return

	var inst := ps.instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst

	# A bright camera looking down into the room.
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 14)
	cam.look_at_from_position(Vector3(0, 10, 14), Vector3(0, 0, -2), Vector3.UP)
	inst.add_child(cam)
	cam.make_current()

	# Second shot: close-up of a shelf run.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img0 := get_viewport().get_texture().get_image()
	if img0 != null:
		img0.save_png("user://captures/shop_wide.png")
		print("SHOT: ", ProjectSettings.globalize_path("user://captures/shop_wide.png"))

	cam.position = Vector3(-6.5, 2.2, 1.5)
	cam.look_at_from_position(Vector3(-6.5, 2.2, 1.5), Vector3(-6.5, 1.0, -4.0), Vector3.UP)
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# A bright ambient light so nothing is black.
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.15, 0.15, 0.18)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.8, 0.8, 0.8)
	amb.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = amb
	inst.add_child(we)

	for i in range(50):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://captures/shop_close.png")
		print("SHOT: ", ProjectSettings.globalize_path("user://captures/shop_close.png"))
	else:
		print("CAPTURE: no image")

	get_tree().quit(0)
