class_name GameCard
extends Button
## Compact interactive version of a physical fortune card.

const CARD_SIZE := Vector2(164, 224)
var card: Dictionary = {}
var selected: bool = false
var hand_display: bool = false
var ink_font: Font = MenuTheme.font()


func setup(data: Dictionary, is_selected: bool) -> void:
	card = data
	selected = is_selected
	custom_minimum_size = CARD_SIZE
	button_pressed = selected
	text = ""
	tooltip_text = _description()
	queue_redraw()


func _ready() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var color_name: String = card.get("color", "无色")
	var tint: Color = FateRules.COLOR_TINTS.get(color_name, FateRules.COLOR_TINTS["无色"])
	var panel := MenuTheme.box(Color("12282b"), tint if selected or has_focus() else Color(tint, 0.55), 8)
	panel.set_border_width_all(2 if selected or has_focus() else 1)
	if hand_display:
		panel.shadow_color = Color(0, 0, 0, 0.3)
		panel.shadow_size = 5
		panel.shadow_offset = Vector2(2, 4)
	draw_set_transform(Vector2.ZERO, 0, size / CARD_SIZE)
	draw_style_box(panel, Rect2(Vector2.ZERO, CARD_SIZE))
	var left := 14.0
	var width := CARD_SIZE.x - 28.0
	var suit: String = card.get("suit", "?")
	var short_name: String = FateRules.SHORT_SUITS[FateRules.SUITS.find(suit)] if FateRules.SUITS.has(suit) else "?"
	if hand_display:
		_draw_text(short_name, 9, 26, 24, 18, tint)
		_draw_text(str(int(card.get("base", 0)) + int(card.get("value_bonus", 0))), 9, 26, 42, 12, tint)
	_draw_text(short_name, left, width, 92, 56, tint)
	draw_line(Vector2(left, 111), Vector2(CARD_SIZE.x - left, 111), Color(tint, 0.42), 1, true)
	_draw_text("%s色 %s" % [color_name, FateRules.COLOR_GLYPHS.get(color_name, "○")], left, width, 137, 14, tint)
	var value := int(card.get("base", 0)) + int(card.get("value_bonus", 0))
	_draw_text(str(value), left, width, 184, 36, MenuTheme.IVORY)
	if int(card.get("value_bonus", 0)) > 0:
		_draw_text("基础 +%d" % int(card.value_bonus), left, width, 207, 11, MenuTheme.GOLD)
	var tag: String = card.get("tag", "")
	if not tag.is_empty():
		draw_rect(Rect2(Vector2(0, CARD_SIZE.y - 28), Vector2(CARD_SIZE.x, 28)), Color("263c37"))
		var tag_text: String = str({"economy": "金运", "origin": "原初", "tarot": "塔罗"}.get(tag, tag))
		_draw_text(tag_text, left, width, CARD_SIZE.y - 9, 13, MenuTheme.GOLD)
	if selected:
		_draw_text("已选", 88 if hand_display else 12, 60 if hand_display else 140, 22, 12, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_text(value: String, x: float, width: float, baseline: float, font_size: int, color: Color) -> void:
	draw_string(ink_font, Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _description() -> String:
	var tags := {"economy": "打出获得 10 金币", "origin": "获胜后提升对应牌型", "tarot": "弃掉时获得一张塔罗牌"}
	var extra := "\n%s" % tags.get(card.get("tag", ""), "") if card.get("tag", "") != "" else ""
	return "%s牌 · %d 基础值 · %s色%s" % [card.get("suit", "未知"), int(card.get("base", 0)) + int(card.get("value_bonus", 0)), card.get("color", "无色"), extra]
