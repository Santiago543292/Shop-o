extends CanvasLayer

## Inventory — press Q to toggle.
##
## Shows the things you are carrying: food and items. Money is NOT shown here —
## it lives permanently in the HUD corner, so there is only one money display
## in the game and it can never disagree with itself.
##
## All data comes from GameState, the single source of truth.

const UIStyle := preload("res://ui/ui_style.gd")

var _panel: PanelContainer
var _open := false
var _t := 0.0
var _food_box: VBoxContainer
var _items_box: VBoxContainer


func _ready() -> void:
	layer = 11
	_build()
	GameState.inventory_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The panel sits on the right, clear of the HUD's money corner.
	_panel = UIStyle.make_panel()
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -330
	_panel.offset_right = -20
	_panel.offset_top = -260
	_panel.offset_bottom = 40
	_panel.modulate.a = 0.0
	_panel.visible = false
	root.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	var title := UIStyle.make_label("CARRYING", UIStyle.SIZE_SUB, UIStyle.COL_REC)
	col.add_child(title)

	col.add_child(UIStyle.make_rule())

	# --- food (click to pick, E to eat) ---
	col.add_child(UIStyle.make_label("FOOD  —  click an item, then press E to eat it", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM))
	_food_box = VBoxContainer.new()
	_food_box.add_theme_constant_override("separation", 2)
	col.add_child(_food_box)

	# --- items ---
	col.add_child(UIStyle.make_label("ITEMS", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM))
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 2)
	col.add_child(_items_box)

	var hint := UIStyle.make_label("Q  close  |  click a food  |  E  eat", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM)
	col.add_child(hint)


func _input(event: InputEvent) -> void:
	# Eat directly from here rather than relying on player_interact to forward
	# the key, so E works no matter how the input is wired.
	if _open and event.is_action_pressed("interact"):
		eat_selected()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var target := 1.0 if _open else 0.0
	_t = lerpf(_t, target, clampf(delta * 10.0, 0.0, 1.0))
	_panel.modulate.a = _t
	_panel.visible = _t > 0.01
	# Safety net: keep the cursor free for as long as the panel is up, even if
	# the controller was never found and keeps re-capturing it.
	if _open and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle() -> void:
	_open = not _open
	# Free the cursor while the panel is up so the food rows are clickable;
	# the first-person controller re-captures the mouse every physics frame.
	_set_cursor(_open)
	# The beep is the UI talking back — same pitch on open and close so it reads
	# as one control rather than two.
	GameAudio.play_beep()
	if _open:
		_refresh()


func is_open() -> bool:
	return _open


func _set_cursor(free: bool) -> void:
	# The first-person controller re-captures the mouse every physics frame, so
	# showing the cursor is not enough — it has to be told to stop. Find it by
	# property (not by name) and set the flag; also set the mode directly so the
	# cursor is free even if the controller is never found.
	var pc := _find_player_controller()
	if pc != null:
		pc.set("disable_mouse_control", free)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED


func _find_player_controller() -> Node:
	# The first-person controller is the only node of this class in the scene.
	# Look it up by class (not by name) so it is found no matter how the player
	# scene is arranged.
	var r := get_tree().current_scene
	if r == null:
		r = get_tree().root
	var found := r.find_children("*", "PlayerController3D", true, false)
	if found.size() > 0:
		return found[0]
	return _search_prop(r, "disable_mouse_control")


func _search_prop(n: Node, prop: String) -> Node:
	if n.get(prop) != null:
		return n
	for c in n.get_children():
		var f := _search_prop(c, prop)
		if f != null:
			return f
	return null


var _selected_food: String = ""


func _refresh() -> void:
	_fill_food()
	_fill(_items_box, GameState.items)


## Eat the currently-picked food (driven by the E key in player_interact).
## Returns false when nothing is picked or the item isn't eatable food.
func eat_selected() -> bool:
	# Nothing picked yet? Fall back to the first thing in the bag, so E always
	# eats something instead of silently doing nothing.
	if _selected_food == "" and not GameState.food.is_empty():
		_selected_food = GameState.food[0]
	if _selected_food == "":
		GameAudio.play_beep()
		return false
	if GameState.eat(_selected_food):
		GameAudio.play_beep()
		_selected_food = ""
		_refresh()
		return true
	GameAudio.play_beep()
	return false


func _fill_food() -> void:
	if _food_box == null:
		return
	for c in _food_box.get_children():
		c.queue_free()
	if GameState.food.is_empty():
		_food_box.add_child(UIStyle.make_label("(nothing)", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM))
		return
	for f in GameState.food:
		var btn := UIStyle.make_button(_food_label(f))
		btn.pressed.connect(_on_food_pressed.bind(f))
		if f == _selected_food:
			btn.add_theme_color_override("font_color", UIStyle.COL_REC)
			btn.add_theme_color_override("font_color_hover", UIStyle.COL_TEXT_BRIGHT)
		_food_box.add_child(btn)


func _food_label(f: String) -> String:
	var entry := GameState.FOOD.get(f, {}) as Dictionary
	var name := entry.get("label", f) as String
	var pct := int(float(entry.get("food", 0.0)) * 100.0)
	return "%s  +%d%%   (click, then E)" % [name, pct]


func _on_food_pressed(f: String) -> void:
	_selected_food = f
	GameAudio.play_beep()
	_refresh()  # rebuild so the picked row stays highlighted


func _fill(box: VBoxContainer, entries: Array) -> void:
	if box == null:
		return
	for c in box.get_children():
		c.queue_free()
	if entries.is_empty():
		box.add_child(UIStyle.make_label("(nothing)", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM))
		return
	for e in entries:
		box.add_child(UIStyle.make_label(str(e), UIStyle.SIZE_SMALL, UIStyle.COL_TEXT))
