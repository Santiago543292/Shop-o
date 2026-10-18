extends CanvasLayer

## The HUD — objective, list, tasks, hunger, money, prompt and messages.
##
## Clean layout, nothing floating in the middle:
##   top-left      objective + shopping list + tasks (one panel)
##   top-right     money, always visible
##   bottom-left   hunger bar
##   bottom-centre interact prompt and the message banner (only when active)

const UIStyle := preload("res://ui/ui_style.gd")

var _objective: Label
var _list_box: VBoxContainer
var _task_box: VBoxContainer
var _prompt: Label
var _message: Label
var _message_panel: PanelContainer
var _hunger_bar: ProgressBar
var _money_label: Label
var _last_money := -1
var _last_hunger_bucket := -1
var _last_task_sig := ""


func _ready() -> void:
	layer = 10
	_build()
	# The map id must match the scene that ACTUALLY loaded, not whatever the
	# save file last recorded — otherwise starting a fresh run shows the tasks
	# of the map you quit on.
	_sync_map_from_scene()
	call_deferred("_sync_map_from_scene")

## Point GameState at the map whose scene is currently loaded.
func _sync_map_from_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path == "":
		return
	for m in GameState.MAPS:
		if str(m.get("scene", "")) == path:
			GameState.current_map = str(m.get("id", ""))
			_refresh_all()
			return

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# top-left: one panel with objective, list and tasks
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.add_theme_constant_override("margin_left", 24)
	top.add_theme_constant_override("margin_top", 20)
	root.add_child(top)

	var panel := UIStyle.make_panel()
	top.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	_objective = UIStyle.make_label("Note Pad", UIStyle.SIZE_SUB, UIStyle.COL_REC)
	col.add_child(_objective)

	col.add_child(UIStyle.make_rule())

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 2)
	col.add_child(_list_box)

	col.add_child(UIStyle.make_rule())

	_task_box = VBoxContainer.new()
	_task_box.add_theme_constant_override("separation", 2)
	col.add_child(_task_box)

	#  top-right: money
	var money_panel := UIStyle.make_panel()
	money_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_panel.anchor_left = 1.0
	money_panel.anchor_right = 1.0
	money_panel.offset_left = -170
	money_panel.offset_right = -20
	money_panel.offset_top = 20
	money_panel.offset_bottom = 68
	root.add_child(money_panel)

	var money_col := VBoxContainer.new()
	money_col.add_theme_constant_override("separation", 2)
	money_panel.add_child(money_col)

	var money_title := UIStyle.make_label("MONEY", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM)
	money_col.add_child(money_title)

	_money_label = UIStyle.make_label("$0", UIStyle.SIZE_SUB, UIStyle.COL_TEXT_BRIGHT)
	money_col.add_child(_money_label)

	# - bottom-left: hunger 
	var hunger_panel := UIStyle.make_panel()
	hunger_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hunger_panel.anchor_left = 0.0
	hunger_panel.anchor_right = 0.0
	hunger_panel.offset_left = 24
	hunger_panel.offset_top = -70
	hunger_panel.offset_bottom = -20
	root.add_child(hunger_panel)

	var hunger_col := VBoxContainer.new()
	hunger_col.add_theme_constant_override("separation", 4)
	hunger_panel.add_child(hunger_col)

	var hunger_title := UIStyle.make_label("HUNGER", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM)
	hunger_col.add_child(hunger_title)

	_hunger_bar = ProgressBar.new()
	_hunger_bar.min_value = 0.0
	_hunger_bar.max_value = 1.0
	_hunger_bar.value = 0.6
	_hunger_bar.custom_minimum_size = Vector2(160, 12)
	_hunger_bar.show_percentage = false
	# Style the bar so the fill is actually visible against the dark panel.
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.11, 0.13, 1.0)
	bg_style.border_color = Color(1, 1, 1, 0.25)
	bg_style.set_border_width_all(1)
	_hunger_bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.42, 0.72, 0.50, 1.0)
	_hunger_bar.add_theme_stylebox_override("fill", fill_style)
	hunger_col.add_child(_hunger_bar)

	#  bottom-centre: interact prompt 
	_prompt = UIStyle.make_label("", UIStyle.SIZE_SUB, UIStyle.COL_TEXT_BRIGHT)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = -120
	_prompt.offset_bottom = -86
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt)

	# bottom-centre: message banner 
	_message_panel = UIStyle.make_panel()
	_message_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message_panel.anchor_left = 0.2
	_message_panel.anchor_right = 0.8
	_message_panel.offset_top = -210
	_message_panel.offset_bottom = -140
	_message_panel.visible = false
	root.add_child(_message_panel)

	_message = UIStyle.make_label("", UIStyle.SIZE_OSD, UIStyle.COL_TEXT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message)

	_refresh_all()

func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n


func _process(_delta: float) -> void:
	# Hunger
	_hunger_bar.value = GameState.hunger
	if GameState.hunger < 0.3:
		_hunger_bar.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	else:
		_hunger_bar.modulate.a = 1.0

	# Money — read from the singleton, the one place it lives.
	_money_label.text = "$%d" % GameState.money
	_refresh_tasks_if_needed()

func set_prompt(text: String) -> void:
	_prompt.text = text

func show_message(text: String, seconds: float = 3.5) -> void:
	_message.text = text
	_message_panel.visible = true
	_message_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_message_panel, "modulate:a", 1.0, 0.2)
	if seconds > 0.0:
		var hide := create_tween()
		hide.tween_interval(seconds)
		hide.tween_property(_message_panel, "modulate:a", 0.0, 0.35)
		hide.tween_callback(func() -> void: _message_panel.visible = false)

func clear_message() -> void:
	_message_panel.visible = false

# internals 

func _refresh_all() -> void:
	_refresh_list()
	_refresh_tasks()

func _refresh_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	_objective.text = str(GameState.map_record(GameState.current_map).get("objective", ""))

	# The shopping list only matters where there is one to buy.
	if GameState.current_map == "map2":
		for e in GameState.list():
			var id := str(e["id"])
			var is_trap := bool(e.get("trap", false))
			var got := GameState.has_collected(id)
			var row := UIStyle.make_label("", UIStyle.SIZE_OSD)
			row.text = ("[x] " if got else "[  ] ") + str(e["label"])
			if got:
				row.add_theme_color_override("font_color", UIStyle.COL_DONE)
			elif is_trap and GameState.has_flag("warned"):
				row.add_theme_color_override("font_color", UIStyle.COL_REC)
				row.text += "   <-- DO NOT BUY"
			else:
				row.add_theme_color_override("font_color", UIStyle.COL_TEXT_DIM)
			_list_box.add_child(row)

func _refresh_tasks_if_needed() -> void:
	# Only rebuild when the rendered list would actually change — rebuilding on
	# every hunger tick made the checklist flicker and overlap itself.
	var sig := _task_signature()
	if sig != _last_task_sig:
		_last_task_sig = sig
		_refresh_tasks()


func _task_signature() -> String:
	var parts: Array[String] = []
	for c in _task_box.get_children():
		parts.append(str(c.text))
	return "|".join(parts)

func _refresh_tasks() -> void:
	for c in _task_box.get_children():
		c.queue_free()
	match GameState.current_map:
		"map0":
			_add_task("Get $150 from something smelly", GameState.money >= 150)
			_add_task("Find the bus stop", GameState.has_flag("at_bus_stop"))
			_add_task("Take the bus", false)
		"map1":
			_add_task("Find the diner", GameState.has_flag("found_diner"))
			_add_task("Eat something", GameState.hunger > 0.6)
			_add_task("Take the bus to the shop", false)
		"map2":
			_add_task("Buy everything on the list", GameState.all_normal_collected())
			_add_task("Do not buy the last one", false)
			_add_task("Read the fine print", GameState.has_flag("read_the_fine_print"))
			_add_task("Serve the customers", GameState.customers_served > 0)
			_add_task("Escape when night falls", GameState.is_escape_unlocked())

func _add_task(text: String, done: bool) -> void:
	var label := UIStyle.make_label(("[x] " if done else "[  ] ") + text, UIStyle.SIZE_SMALL)
	label.add_theme_color_override("font_color",
		UIStyle.COL_DONE if done else UIStyle.COL_TEXT_DIM)
	_task_box.add_child(label)
