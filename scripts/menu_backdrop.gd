@tool
extends Control
## Lightweight vector atmosphere: no textures or external art required.

var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and not Preferences.animate_background:
		return
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b181b"))
	var center := size * Vector2(0.77, 0.45)
	for i in range(32, 0, -1):
		var radius := float(i) * size.y / 35.0
		draw_circle(center, radius, Color(0.05, 0.20, 0.19, 0.017))
	for x in range(0, int(size.x), 6):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.5, 0.65, 0.6, 0.012))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319
	for i in range(65):
		var point := Vector2(rng.randf_range(0.02, 0.98), rng.randf_range(0.08, 0.95)) * size
		var alpha := 0.10 + 0.15 * (sin(elapsed * 0.65 + float(i)) + 1.0) * 0.5
		draw_circle(point, rng.randf_range(0.6, 1.7), Color(0.8, 0.72, 0.46, alpha))
	draw_line(Vector2(28, 28), Vector2(86, 28), Color("51614e"), 1, true)
	draw_line(Vector2(28, 28), Vector2(28, 86), Color("51614e"), 1, true)
	draw_line(size - Vector2(28, 28), size - Vector2(86, 28), Color("51614e"), 1, true)
	draw_line(size - Vector2(28, 28), size - Vector2(28, 86), Color("51614e"), 1, true)
