extends Control

## Credits — built from the table below so adding a pack is one row.
##
## The asset packs in this project carry different licences. Those that require
## attribution are marked `required: true` and rendered with the exact credit
## line the author asks for, because dropping it is a licence breach, not a
## discourtesy.

const UIStyle := preload("res://ui/ui_style.gd")

const CREDITS: Array[Dictionary] = [
	{
		"name": "Elbolilloduro",
		"made": "BurgerPiz, PSX model packs",
		"url": "https://elbolilloduro.itch.io",
		"required": false,
	},
	{
		"name": "valsekamerplant / Hexnut Studios",
		"made": "PSX urban stacked pack, barriers, walls & fences, vents",
		"url": "https://valsekamerplant.itch.io",
		"required": false,
	},
	{
		"name": "imaginais (Isaac)",
		"made": "Retro PSX monsters and characters",
		"url": "https://imaginais.itch.io",
		"required": false,
	},
	{
		"name": "Swag",
		"made": "PSX Scrap Weapon Constructor",
		"url": "https://swagtopus.itch.io/psx-scrap-weapon-constructor",
		"required": false,
	},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.014, 0.018)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := UIStyle.make_label("CREDITS", 46, UIStyle.COL_TEXT_BRIGHT)
	col.add_child(title)

	var sub := UIStyle.make_label(
		"Uncannily Normal is built with other people's work. Thank you.",
		UIStyle.SIZE_OSD, UIStyle.COL_TEXT_DIM)
	col.add_child(sub)

	col.add_child(UIStyle.make_rule())

	for c in CREDITS:
		col.add_child(_row(c))

	var back_row := UIStyle.make_menu_item("BACK", UIStyle.SIZE_BUTTON)
	UIStyle.button_of(back_row).pressed.connect(_back)
	col.add_child(back_row)


func _row(c: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var name := UIStyle.make_label(str(c.get("name", "")), 22, UIStyle.COL_TEXT)
	box.add_child(name)

	var made := UIStyle.make_label(str(c.get("made", "")), UIStyle.SIZE_OSD, UIStyle.COL_TEXT_DIM)
	box.add_child(made)

	var url := str(c.get("url", ""))
	if url != "":
		var link := LinkButton.new()
		link.text = url
		link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		link.uri = url
		link.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
		link.add_theme_color_override("font_color", UIStyle.COL_TEXT_DIM)
		box.add_child(link)

	if bool(c.get("required", false)):
		var must := UIStyle.make_label("attribution required by licence", UIStyle.SIZE_SMALL, UIStyle.COL_REC)
		box.add_child(must)

	return box


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _back() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
