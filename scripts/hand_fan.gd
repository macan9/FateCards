class_name HandFan
extends Control
## Overlapping hand; mouse dragging changes order while keyboard buttons still work.

signal card_clicked(id: int)
signal card_reordered(id: int, target_index: int)

const DRAG_THRESHOLD := 8.0
const SELECTED_LIFT := 30.0
const HOVER_LIFT := 16.0

var _views: Dictionary = {}
var _ordered_ids: Array[int] = []
var _committed_ids: Array[int] = []
var _tweens: Dictionary = {}
var _interactive := true
var _hovered_id := -1
var _pressed_id := -1
var _dragged_id := -1
var _press_point := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _card_size := GameCard.CARD_SIZE
var _step := 1.0
var _start_x := 0.0
var _baseline := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = 300
	resized.connect(arrange.bind(false))
	mouse_exited.connect(_leave_hand)
	get_window().focus_exited.connect(cancel_drag)


func sync_hand(cards: Array[Dictionary], selected_ids: Array[int], interactive: bool) -> void:
	cancel_drag()
	_ordered_ids.clear()
	for card in cards:
		_ordered_ids.append(int(card.id))
	_committed_ids.assign(_ordered_ids)
	for id in _views.keys():
		if id not in _ordered_ids:
			_stop_tween(id)
			var removed: GameCard = _views[id]
			remove_child(removed)
			removed.queue_free()
			_views.erase(id)
	var incoming: Array[int] = []
	for index in range(cards.size()):
		var card: Dictionary = cards[index]
		var id := int(card.id)
		if not _views.has(id):
			var view := GameCard.new()
			view.name = "Card_%d" % id
			view.hand_display = true
			view.setup(card, id in selected_ids)
			view.pressed.connect(_keyboard_click.bind(id))
			add_child(view)
			# The fan owns mouse hit testing so overlap never creates two clicks.
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_views[id] = view
			incoming.append(id)
		else:
			_views[id].setup(card, id in selected_ids)
		move_child(_views[id], index)
	set_interaction_enabled(interactive)
	_measure()
	for id in incoming:
		var view: GameCard = _views[id]
		view.position = _slot_position(_ordered_ids.find(id)) + Vector2(75, 65)
		view.rotation = 0
		view.modulate.a = 0.0 if _animate() else 1.0
	arrange()


func set_interaction_enabled(enabled: bool) -> void:
	_interactive = enabled
	if not enabled:
		cancel_drag()
		_hovered_id = -1
	for view: GameCard in _views.values():
		view.disabled = not enabled


func _animate() -> bool:
	if not is_inside_tree():
		return false
	var preferences := get_node_or_null("/root/Preferences")
	return preferences == null or bool(preferences.get("animate_background"))


func _measure() -> void:
	# Six cards overlap by roughly one third; larger hands compress into the same row.
	var width := minf(176.0, maxf(110.0, size.x * 0.16))
	_card_size = Vector2(width, width * GameCard.CARD_SIZE.y / GameCard.CARD_SIZE.x)
	var available := maxf(_card_size.x, size.x - 70.0)
	_step = minf(_card_size.x * 0.66, (available - _card_size.x) / maxi(_ordered_ids.size() - 1, 1))
	_step = maxf(_step, 1.0)
	var total_width := _card_size.x + maxi(_ordered_ids.size() - 1, 0) * _step
	_start_x = (size.x - total_width) * 0.5
	_baseline = maxf(SELECTED_LIFT + 12, size.y - _card_size.y - 24)


func _slot_position(index: int) -> Vector2:
	var spread := (float(index) / maxf(_ordered_ids.size() - 1, 1)) * 2.0 - 1.0
	if _ordered_ids.size() <= 1:
		spread = 0
	var lift := 0.0
	var id: int = _ordered_ids[index]
	if _views.has(id) and _views[id].selected:
		lift += SELECTED_LIFT
	if id == _hovered_id and _interactive:
		lift += HOVER_LIFT
	return Vector2(_start_x + index * _step, _baseline + spread * spread * 9.0 - lift)


func arrange(animate: bool = true) -> void:
	if not is_inside_tree():
		return
	_measure()
	for index in range(_ordered_ids.size()):
		var id: int = _ordered_ids[index]
		var view: GameCard = _views[id]
		view.custom_minimum_size = _card_size
		view.size = _card_size
		view.pivot_offset = _card_size * 0.5
		view.z_index = 1000 if id == _dragged_id else (100 + index if id == _hovered_id else index)
		if id == _dragged_id:
			continue
		var target := _slot_position(index)
		var spread := float(index) / maxf(_ordered_ids.size() - 1, 1) * 2.0 - 1.0
		var angle := deg_to_rad(spread * 2.5) if _ordered_ids.size() > 1 else 0.0
		_stop_tween(id)
		if animate and _animate():
			var tween := create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "position", target, 0.18)
			tween.tween_property(view, "rotation", angle, 0.18)
			tween.tween_property(view, "modulate:a", 1.0, 0.15)
			_tweens[id] = tween
		else:
			view.position = target
			view.rotation = angle
			view.modulate.a = 1
		view.queue_redraw()


func _stop_tween(id: int) -> void:
	if _tweens.has(id):
		var tween: Tween = _tweens[id]
		if tween.is_valid():
			tween.kill()
		_tweens.erase(id)


func _hit_card(point: Vector2) -> int:
	var best_id := -1
	var best_z := -1
	for id in _ordered_ids:
		var view: GameCard = _views[id]
		var local := view.get_transform().affine_inverse() * point
		if Rect2(Vector2.ZERO, view.size).has_point(local) and view.z_index >= best_z:
			best_z = view.z_index
			best_id = id
	return best_id


func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pointer_press(event.position)
		if _pressed_id >= 0:
			accept_event()
	elif event is InputEventMouseMotion and _pressed_id < 0:
		_set_hover(_hit_card(event.position))


func _input(event: InputEvent) -> void:
	if _pressed_id < 0:
		return
	if event is InputEventMouseMotion:
		_pointer_move(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_pointer_release(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func _pointer_press(point: Vector2) -> void:
	if not _interactive:
		return
	_pressed_id = _hit_card(point)
	if _pressed_id < 0:
		return
	_press_point = point
	_grab_offset = point - (_views[_pressed_id] as GameCard).position
	(_views[_pressed_id] as GameCard).grab_focus()


func _pointer_move(point: Vector2) -> void:
	if _pressed_id < 0 or not _interactive:
		return
	if _dragged_id < 0 and point.distance_to(_press_point) >= DRAG_THRESHOLD:
		_dragged_id = _pressed_id
		_stop_tween(_dragged_id)
	if _dragged_id < 0:
		return
	var view: GameCard = _views[_dragged_id]
	view.position = point - _grab_offset
	view.rotation = 0
	view.z_index = 1000
	var center_x := point.x - _grab_offset.x + _card_size.x * 0.5
	var target := clampi(roundi((center_x - _start_x - _card_size.x * 0.5) / _step), 0, _ordered_ids.size() - 1)
	var current := _ordered_ids.find(_dragged_id)
	if target != current:
		_ordered_ids.remove_at(current)
		_ordered_ids.insert(target, _dragged_id)
		arrange()


func _pointer_release(point: Vector2) -> void:
	if _pressed_id < 0:
		return
	var id := _pressed_id
	var was_dragging := _dragged_id >= 0
	var target := _ordered_ids.find(id)
	var released_on_card := _hit_card(point) == id
	_pressed_id = -1
	_dragged_id = -1
	if was_dragging:
		_committed_ids.assign(_ordered_ids)
		_hovered_id = id
		card_reordered.emit(id, target)
	elif released_on_card:
		card_clicked.emit(id)
	arrange()


func cancel_drag() -> void:
	if _pressed_id < 0:
		return
	_pressed_id = -1
	_dragged_id = -1
	_ordered_ids.assign(_committed_ids)
	arrange()


func _set_hover(id: int) -> void:
	if id == _hovered_id:
		return
	_hovered_id = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id >= 0 else Control.CURSOR_ARROW
	tooltip_text = (_views[id] as GameCard).tooltip_text if id >= 0 else ""
	arrange()


func _leave_hand() -> void:
	if _pressed_id < 0:
		_set_hover(-1)


func _keyboard_click(id: int) -> void:
	if _interactive:
		card_clicked.emit(id)
