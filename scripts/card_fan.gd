@tool
extends Control

var elapsed: float = 0.0
var cards: Array[ArcanaCard] = []
var ink_font: Font = MenuTheme.font()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind in [1, 2, 0]:
		var card := ArcanaCard.new()
		card.kind = kind
		add_child(card)
		cards.append(card)
	resized.connect(_arrange)
	_arrange()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and not Preferences.animate_background:
		return
	elapsed += delta
	_arrange()
	queue_redraw()


func _arrange() -> void:
	if cards.size() != 3:
		return
	var center := size * Vector2(0.50, 0.49)
	var offsets := [Vector2(-110, 18), Vector2(102, 12), Vector2(0, -24)]
	var angles := [-18.0, 17.0, -5.0]
	for i in range(3):
		cards[i].pivot_offset = ArcanaCard.CARD_SIZE * 0.5
		cards[i].position = center - ArcanaCard.CARD_SIZE * 0.5 + offsets[i] + Vector2(0, sin(elapsed * 0.7 + i) * 5)
		cards[i].rotation_degrees = angles[i]


func _draw() -> void:
	var center := size * Vector2(0.5, 0.49)
	for radius in [216.0, 231.0, 265.0]:
		draw_arc(center, radius, 0, TAU, 180, Color(0.72, 0.65, 0.43, 0.16), 1, true)
	for i in range(48):
		var angle := float(i) * TAU / 48.0
		draw_line(center + Vector2.from_angle(angle) * 258, center + Vector2.from_angle(angle) * (272 if i % 4 == 0 else 264), Color(0.72, 0.65, 0.43, 0.28), 1, true)
	draw_string(ink_font, Vector2(0, center.y + 302), "✦   三种力量，无数种可能   ✦", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("8b9d85"))
