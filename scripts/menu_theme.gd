class_name MenuTheme
extends RefCounted

const GOLD := Color("c6a86d")
const INK := Color("0b181b")
const IVORY := Color("eee5cf")
const MUTED := Color("8baba3")


static func font() -> SystemFont:
	var result := SystemFont.new()
	result.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "sans-serif"])
	return result


static func box(color: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 22
	result.content_margin_right = 22
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result


static func create() -> Theme:
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 18
	result.set_color("font_color", "Label", IVORY)
	result.set_color("font_color", "Button", IVORY)
	result.set_color("font_hover_color", "Button", Color("fff2cd"))
	result.set_color("font_focus_color", "Button", Color("fff2cd"))
	result.set_color("font_pressed_color", "Button", GOLD)
	result.set_stylebox("normal", "Button", box(Color("102529"), Color("304c48")))
	result.set_stylebox("hover", "Button", box(Color("1c3738"), GOLD))
	result.set_stylebox("pressed", "Button", box(Color("0b1d21"), GOLD))
	var focus := box(Color.TRANSPARENT, Color("efd098"))
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("disabled", "Button", box(Color("132225"), Color("263a38")))
	var line := StyleBoxLine.new()
	line.color = Color(0.6, 0.7, 0.62, 0.16)
	line.thickness = 1
	result.set_stylebox("separator", "HSeparator", line)
	result.set_stylebox("panel", "PanelContainer", box(Color("102428"), Color("47615a"), 12))
	result.set_stylebox("slider", "HSlider", box(Color("213b3b"), Color.TRANSPARENT, 3))
	result.set_stylebox("grabber_area", "HSlider", box(GOLD, GOLD, 3))
	return result


static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(GOLD, Color("e1c38a")))
	button.add_theme_stylebox_override("hover", box(Color("e0c18a"), Color("f5ddad")))
	button.add_theme_stylebox_override("pressed", box(Color("aa8955"), GOLD))
	button.add_theme_color_override("font_color", Color("152326"))
	button.add_theme_color_override("font_hover_color", Color("152326"))
	button.add_theme_color_override("font_focus_color", Color("152326"))
	button.add_theme_color_override("font_pressed_color", Color("152326"))


static func label(text: String, font_size: int = 18, color: Color = IVORY) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 50
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	return result
