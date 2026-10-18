extends Node

## Audio test — the behaviour the user asked for:
##   * footsteps vary in order, and never the same one twice in a row
##   * the hum follows proximity to a light
##   * the UI beep, the search sound and the bus arrival all fire
##   * ambience starts once and keeps running

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame

	# --- GameAudio must be an autoload ---
	_check("GameAudio autoload exists", GameAudio != null)
	if GameAudio == null:
		_finish()
		return

	# --- footsteps: never the same sound twice in a row ---
	var last := ""
	var repeats := 0
	var seen := {}
	for i in range(60):
		GameAudio.play_footstep()
		var s := GameAudio._oneshot.stream
		var name := "" if s == null else s.resource_path
		if name != "":
			seen[name] = true
			if name == last:
				repeats += 1
		last = name
	print("  [INFO] distinct footstep sounds used: ", seen.size())
	print("  [INFO] back-to-back repeats over 60 steps: ", repeats)
	_check("footsteps use all three sounds", seen.size() == 3)
	_check("footsteps never repeat back to back", repeats == 0)

	# --- one-shots all fire ---
	GameAudio.play_beep()
	await _wait(3)
	_check("beep plays", GameAudio._oneshot.playing)

	GameAudio.play_search()
	await _wait(3)
	_check("search plays", GameAudio._oneshot.playing)

	GameAudio.play_bus_arrive()
	await _wait(3)
	_check("bus arrival plays", GameAudio._oneshot.playing)

	# --- hum follows proximity ---
	GameAudio.set_hum_proximity(0.0)
	await _wait(3)
	var far := GameAudio._hum.volume_db
	GameAudio.set_hum_proximity(1.0)
	await _wait(3)
	var near := GameAudio._hum.volume_db
	print("  [INFO] hum volume far=", far, " near=", near)
	_check("hum is quiet when far from a light", far < -30.0)
	_check("hum is audible when at a light", near > -20.0)
	_check("hum gets louder as you approach", near > far)

	# --- ambience ---
	GameAudio.start_ambience()
	await _wait(3)
	_check("ambience started", GameAudio._ambience.playing)
	var before := GameAudio._ambience.volume_db
	print("  [INFO] ambience volume = ", before)
	_check("ambience is a low bed, not a wall of sound", before <= -1.0)
	GameAudio.start_ambience()   # second call must not restart or double it
	await _wait(3)
	_check("ambience does not double up", GameAudio._ambience.volume_db == before)

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
