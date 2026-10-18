extends Control

## Main menu — shop-themed horror title screen.
##
## A cold, flickering convenience store at 5 AM. The "STORE OPEN" sign
## hums. The lights flicker. Something is wrong.

const UIStyle := preload("res://ui/ui_style.gd")

const START_SCENE := "res://scenes/map0.tscn"

var _rows: Array[HBoxContainer] = []
var _title: Label
var _pulse: Label
var _flicker_rect: ColorRect
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if not _rows.is_empty():
		UIStyle.button_of(_rows[0]).grab_focus()


func _build() -> void:
	# --- dark store interior background ---
	var bg := ColorRect.new()
	bg.color = Color(0.004, 0.006, 0.010)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# --- cold fluorescent glow from above ---
	var glow := ColorRect.new()
	glow.color = Color(0.03, 0.04, 0.06, 0.6)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(glow)

	# --- "STORE OPEN" sign ---
	var sign_panel := PanelContainer.new()
	sign_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sign_panel.anchor_left = 0.35
	sign_panel.anchor_right = 0.65
	sign_panel.offset_top = 60
	sign_panel.offset_bottom = 140
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.9)
	sb.border_color = Color(0.3, 0.35, 0.4, 0.8)
	sb.set_border_width_all(2)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 15.0
	sb.content_margin_bottom = 15.0
	sign_panel.add_theme_stylebox_override("panel", sb)
	add_child(sign_panel)

	var sign_col := VBoxContainer.new()
	sign_col.alignment = BoxContainer.ALIGNMENT_CENTER
	sign_panel.add_child(sign_col)

	var sign_text := UIStyle.make_label("STORE  OPEN", 42, Color(0.9, 0.95, 0.85))
	sign_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	sign_text.add_theme_constant_override("shadow_offset_x", 3)
	sign_text.add_theme_constant_override("shadow_offset_y", 3)
	sign_col.add_child(sign_text)

	var sign_sub := UIStyle.make_label("24 HOURS", 16, Color(0.5, 0.55, 0.55))
	sign_col.add_child(sign_sub)

	# --- content ---
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 200)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(col)

	# --- title ---
	_title = UIStyle.make_label("UNCANNILY NORMAL", UIStyle.SIZE_TITLE, UIStyle.COL_TEXT_BRIGHT)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(_title)

	# Tagline
	var tag := UIStyle.make_label("5:00 AM.  The store is open.", UIStyle.SIZE_SUB, UIStyle.COL_TEXT)
	col.add_child(tag)

	# Animated separator
	var sep := UIStyle.make_rule()
	sep.modulate.a = 0.0
	col.add_child(sep)

	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(sep, "modulate:a", 1.0, 0.6)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)

	# --- menu items ---
	_add_item(col, "START", _on_start)
	_add_item(col, "CREDITS", _on_credits)
	_add_item(col, "QUIT", _on_quit)

	# --- pulse prompt ---
	_pulse = UIStyle.make_label("PRESS  ENTER", UIStyle.SIZE_OSD, UIStyle.COL_TEXT_DIM)
	_pulse.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pulse.anchor_left = 0.0
	_pulse.anchor_right = 1.0
	_pulse.offset_top = -60
	_pulse.offset_bottom = -40
	_pulse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_pulse)

	var pulse_tw := create_tween().set_loops()
	pulse_tw.tween_property(_pulse, "modulate:a", 0.3, 1.2)
	pulse_tw.tween_property(_pulse, "modulate:a", 1.0, 1.2)

	# --- footer ---
	var foot := UIStyle.make_label(
		"W A S D  move     E  interact     Q  inventory     ESC  back", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.anchor_left = 1.0
	foot.anchor_right = 1.0
	foot.offset_left = -400
	foot.offset_right = -20
	foot.offset_top = -40
	foot.offset_bottom = -20
	add_child(foot)

	var ver := UIStyle.make_label("v1.0", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.offset_left = -60
	ver.offset_right = -20
	ver.offset_top = -20
	ver.offset_bottom = -5
	add_child(ver)

	# Flicker the sign
	_flicker_sign()


func _add_item(parent: Node, text: String, cb: Callable) -> void:
	var row := UIStyle.make_menu_item(text)
	var btn := UIStyle.button_of(row)
	btn.pressed.connect(cb)
	btn.focus_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "modulate:a", 0.8, 0.15)
	)
	btn.focus_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "modulate:a", 1.0, 0.15)
	)
	parent.add_child(row)
	_rows.append(row)


func _flicker_sign() -> void:
	# The store lights flicker — something is wrong
	await get_tree().create_timer(randf() * 3 + 1).timeout
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 0.3, 0.05)
	tw.tween_property(_title, "modulate:a", 1.0, 0.1)
	tw.tween_interval(randf() * 0.1 + 0.05)
	tw.tween_property(_title, "modulate:a", 0.0, 0.05)
	tw.tween_property(_title, "modulate:a", 1.0, 0.3)
	_flicker_sign()


func _on_start() -> void:
	# START always begins a fresh run. Without this the previous session's
	# money and flags survive — the player would open with $132 and the bus
	# stop already ticked, which is the same as having "already played".
	GameState.reset()
	_wipe_save()
	get_tree().change_scene_to_file(START_SCENE)


## Delete the on-disk save so nothing from a previous session can leak in.
func _wipe_save() -> void:
	const SAVE_PATH := "user://progress.cfg"
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _on_credits() -> void:
	get_tree().change_scene_to_file("res://ui/credits.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_quit()
