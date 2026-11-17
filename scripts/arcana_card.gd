@tool
class_name ArcanaCard
extends Control
## All card illustrations are drawn as editable, scalable vectors.

const CARD_SIZE := Vector2(232, 354)
const TITLES := ["月 · 银辉", "日 · 金耀", "星空 · 蓝影"]
const DESCRIPTIONS := ["基础 9 · 银月 ×5", "基础 10 · 金日 ×5", "基础 6 · 蓝星 ×3"]
const KINDS := ["月 相", "日 相", "星 相"]
const ACCENTS := [Color("c7d9e7"), Color("e5c17a"), Color("77b9e7")]

@export_range(0, 2) var kind: int = 0:
	set(value):
		kind = value
		queue_redraw()
var ink_font: Font = MenuTheme.font()


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var accent: Color = ACCENTS[kind]
	var panel := MenuTheme.box(Color("11292c"), accent, 12)
	panel.shadow_color = Color(0, 0, 0, 0.36)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 10)
	draw_style_box(panel, Rect2(Vector2.ZERO, CARD_SIZE))
	draw_style_box(MenuTheme.box(Color.TRANSPARENT, Color(accent, 0.25), 7), Rect2(9, 9, 214, 336))
	draw_circle(Vector2(27, 29), 15, Color("233b3b"))
	draw_arc(Vector2(27, 29), 15, 0, TAU, 48, accent, 1, true)
	_text(str(kind + 1), 13, 26, 35, 17, accent)
	_text("0%d  /  %s" % [kind + 1, KINDS[kind]], 55, 155, 34, 11, accent)
	var center := Vector2(116, 148)
	draw_circle(center, 77, Color("173336"))
	draw_arc(center, 78, 0, TAU, 100, Color(accent, 0.45), 1, true)
	draw_arc(center, 68, 0, TAU, 90, Color(accent, 0.14), 1, true)
	for i in range(12):
		var angle := float(i) * TAU / 12.0
		draw_line(center + Vector2.from_angle(angle) * 82, center + Vector2.from_angle(angle) * 87, Color(accent, 0.55), 1, true)
	match kind:
		0:
			draw_circle(Vector2(120, 117), 34, accent)
			draw_circle(Vector2(134, 105), 30, Color("173336"))
			draw_colored_polygon(PackedVector2Array([Vector2(70, 207), Vector2(111, 141), Vector2(128, 146), Vector2(165, 207)]), Color("285052"))
			draw_polyline(PackedVector2Array([Vector2(70, 207), Vector2(111, 141), Vector2(128, 146), Vector2(165, 207)]), accent, 1.5, true)
			draw_circle(Vector2(119, 145), 8, accent)
			draw_line(Vector2(119, 158), Vector2(119, 207), Color(accent, 0.55), 1, true)
			_star(Vector2(74, 107), 6, accent)
		1:
			draw_circle(center, 31, Color(accent, 0.16))
			draw_arc(center, 31, 0, TAU, 64, accent, 1.5, true)
			draw_circle(center, 22, accent)
			for ray in range(12):
				var direction := Vector2.from_angle(float(ray) * TAU / 12.0)
				draw_line(center + direction * 39, center + direction * 55, accent, 2, true)
			_star(Vector2(81, 198), 5, accent)
		2:
			var points := PackedVector2Array([center + Vector2(-44, 4), center + Vector2(-17, -42), center + Vector2(29, -26), center + Vector2(41, 27), center + Vector2(-12, 45), center + Vector2(-44, 4)])
			draw_polyline(points, Color(accent, 0.6), 1.5, true)
			for point in points:
				_star(point, 7, accent)
			_star(center, 17, accent)
			draw_arc(center, 52, 0.4, 2.7, 40, Color(accent, 0.4), 1, true)
	draw_line(Vector2(30, 243), Vector2(202, 243), Color(accent, 0.35), 1, true)
	_text(TITLES[kind], 10, 212, 279, 23, MenuTheme.IVORY)
	_text(DESCRIPTIONS[kind], 10, 212, 307, 13, Color("96b1a7"))
	_star(Vector2(116, 331), 4, accent)


func _text(value: String, x: float, width: float, baseline: float, font_size: int, color: Color) -> void:
	draw_string(ink_font, Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		points.append(center + Vector2.from_angle(float(i) * PI / 4.0) * (radius if i % 2 == 0 else radius * 0.25))
	draw_colored_polygon(points, color)
