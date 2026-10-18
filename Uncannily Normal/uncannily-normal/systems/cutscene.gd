extends CanvasLayer

signal finished()

const UIStyle := preload("res://ui/ui_style.gd")
const DEFAULT_MIN := 1.8     
const DEFAULT_AUTO := 6.0    

var _active := false
var _slides: Array = []
var _index := 0
var _show_time := 0.0
var _min := 0.0
var _auto := 0.0
var _callback: Callable = Callable()
var _player: Node = null
var _saved: Dictionary = {}

var _bg: ColorRect
var _box: PanelContainer
var _label: Label
var _prompt: Label


func _ready() -> void:
	layer = 14
	_build()
	hide()


func _build() -> void:
	# Full dark sheet that also swallows mouse so the 3D view never reacts.
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.88)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Bottom-centre card: text, then a blinking "advance" prompt.
	_box = UIStyle.make_panel()
	_box.name = "Box"
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.anchor_left = 0.10
	_box.anchor_right = 0.90
	_box.anchor_top = 0.0
	_box.offset_top = -180
	_box.offset_bottom = -34
	add_child(_box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_box.add_child(col)

	_label = UIStyle.make_label("", UIStyle.SIZE_OSD, UIStyle.COL_TEXT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_label)

	_prompt = UIStyle.make_label(">  click to continue", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM)
	_prompt.name = "Prompt"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prompt)


## Slides: Array of {text: String, min: float, auto: float, sound: String}.
## `min` = seconds before it can be skipped; `auto` = seconds to advance on
## its own (0 = no auto, wait for input); `sound` = GameAudio key to play.
func play(slides: Array, cb: Callable = Callable()) -> void:
	if _active:
		push_warning("Cutscene.play: already playing, ignoring.")
		return
	if slides.is_empty():
		if cb.is_valid():
			cb.call()
		return
	_active = true
	_slides = slides
	_index = 0
	_show_time = 0.0
	_callback = cb
	show()
	_freeze_player()
	set_process(true)
	set_process_input(true)
	_show_slide(0)


func _show_slide(i: int) -> void:
	if i < 0 or i >= _slides.size():
		_finish()
		return
	var s := _slides[i] as Dictionary
	_label.text = str(s.get("text", ""))
	_min = float(s.get("min", DEFAULT_MIN))
	_auto = float(s.get("auto", DEFAULT_AUTO))
	_show_time = 0.0
	_prompt.modulate.a = 0.0 if _auto <= 0.0 else 1.0
	_prompt.visible = _auto > 0.0
	var snd := str(s.get("sound", ""))
	if snd != "":
		var g := get_node_or_null("/root/GameAudio")
		if g != null and g.has_method("play_sound"):
			g.play_sound(snd)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	# A slide can only be skipped after its minimum time.
	if _show_time < _min:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Any key advances (space / enter / click are the common ones).
		_advance()


func _process(delta: float) -> void:
	if not _active:
		return
	_show_time += delta
	# Blink the advance prompt so the player knows a click does something.
	if _prompt.visible:
		var h := 0.45 + 0.55 * sin(_show_time * 4.5)
		_prompt.modulate.a = h if _show_time >= _min else 0.0
	if _auto > 0.0 and _show_time >= _auto:
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= _slides.size():
		_finish()
	else:
		_show_slide(_index)


func _finish() -> void:
	_active = false
	set_process(false)
	set_process_input(false)
	_unfreeze_player()
	hide()
	finished.emit()
	var cb := _callback
	_callback = Callable()
	if cb.is_valid():
		cb.call()


## --- player freeze ----------------------------------------------------------
## The godoplayer exposes disable_* toggles that gate movement, mouse-look and
## jumping. Toggling them stops the player without pausing the whole tree (so
## background audio, the hum and the monster keep their timing intact).

func _freeze_player() -> void:
	_player = _find_player()
	if _player == null:
		return
	# The godoplayer exposes disable_* toggles that gate movement, mouse-look
	# and jumping. Toggling them stops the player without pausing the whole
	# tree (so background audio, the hum and the monster keep their timing).
	# These four are real exports on the godoplayer; set them directly.
	for k in ["disable_movement", "disable_mouse_control", "disable_jump", "disable_camera_look"]:
		_saved[k] = _player.get(k)
		_player.set(k, true)
	# Lock the velocity so the player doesn't slide on a slope while frozen.
	if "velocity" in _player:
		_player.velocity = Vector3.ZERO


func _unfreeze_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for k in _saved.keys():
		_player.set(k, _saved[k])
	_player = null
	_saved.clear()


func _find_player() -> Node:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search(root)


func _search(n: Node) -> Node:
	if n is CharacterBody3D and n != self and n.has_method("move_and_slide"):
		return n
	for c in n.get_children():
		var f := _search(c)
		if f != null:
			return f
	return null


func is_playing() -> bool:
	return _active
