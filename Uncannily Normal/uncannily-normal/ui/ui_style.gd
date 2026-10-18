extends RefCounted

## Shared visual language for the Uncannily Normal front-end.
##
## Cold, desaturated camcorder-OSD palette. Everything is built in code so
## the whole look can be retuned from this one file.

# --- Palette: cold, readable, high contrast on dark ---
const COL_TEXT        := Color(0.82, 0.86, 0.90)
const COL_TEXT_DIM    := Color(0.52, 0.56, 0.62)
const COL_TEXT_BRIGHT := Color(1.00, 1.00, 1.00)
const COL_REC         := Color(0.90, 0.22, 0.18)
const COL_DONE        := Color(0.38, 0.78, 0.48)
const COL_LINE        := Color(1.00, 1.00, 1.00, 0.18)
const COL_PANEL_BG    := Color(0.03, 0.035, 0.045, 0.88)

# --- Type scale ---
const SIZE_TITLE  := 64
const SIZE_SUB    := 20
const SIZE_BUTTON := 30
const SIZE_OSD    := 18
const SIZE_SMALL  := 14


static func make_label(text: String, font_size: int, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_menu_item(base_text: String, font_size: int = SIZE_BUTTON) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var marker := Label.new()
	marker.text = ">"
	marker.add_theme_font_size_override("font_size", font_size)
	marker.add_theme_color_override("font_color", COL_REC)
	marker.custom_minimum_size = Vector2(20, 0)
	marker.modulate.a = 0.0
	row.add_child(marker)

	var b := Button.new()
	b.text = base_text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TEXT_BRIGHT)
	b.add_theme_color_override("font_focus_color", COL_TEXT_BRIGHT)
	b.add_theme_color_override("font_pressed_color", COL_REC)
	b.add_theme_color_override("font_disabled_color", COL_TEXT_DIM)
	b.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.9, 0.22, 0.18, 0.20)))
	b.add_theme_stylebox_override("focus", _flat(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("disabled", _flat(Color(0, 0, 0, 0)))
	row.add_child(b)

	row.set_meta("button", b)
	row.set_meta("marker", marker)

	b.mouse_entered.connect(func() -> void: marker.modulate.a = 1.0)
	b.mouse_exited.connect(func() -> void: marker.modulate.a = 0.0)
	b.focus_entered.connect(func() -> void: marker.modulate.a = 1.0)
	b.focus_exited.connect(func() -> void: marker.modulate.a = 0.0)

	return row


static func button_of(row: HBoxContainer) -> Button:
	return row.get_meta("button") as Button


static func make_rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = COL_LINE
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", SIZE_BUTTON)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TEXT_BRIGHT)
	b.add_theme_color_override("font_focus_color", COL_TEXT_BRIGHT)
	b.add_theme_color_override("font_pressed_color", COL_REC)
	b.add_theme_color_override("font_disabled_color", COL_TEXT_DIM)
	b.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _flat(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.9, 0.22, 0.18, 0.20)))
	b.add_theme_stylebox_override("focus", _flat(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("disabled", _flat(Color(0, 0, 0, 0)))
	return b


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL_BG
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.border_color = COL_LINE
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _flat(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb
