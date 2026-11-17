extends SceneTree
## Sends mouse events through the real viewport, including the overlapping hit test.

var checks := 0
var failures: Array[String] = []
var table
var fan: HandFan


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _hand_ids() -> Array:
	return table.hand.map(func(card: Dictionary) -> int: return card.id)


func _point(id: int) -> Vector2:
	var view: GameCard = fan._views[id]
	return view.get_transform() * Vector2(24, 80)


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = fan.get_global_transform_with_canvas() * point
	event.global_position = event.position
	root.push_input(event, true)


func _motion(point: Vector2, down: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = fan.get_global_transform_with_canvas() * point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)


func _sorted(mode: String) -> bool:
	var last := -1
	for card: Dictionary in table.hand:
		var suit := FateRules.SUITS.find(card.suit)
		var color := FateRules.COLORS.find(card.color)
		var key := color * 10 + suit if mode == "color" else suit * 10 + color
		if key < last:
			return false
		last = key
	return true


func _run() -> void:
	var preferences: Node = root.get_node("Preferences")
	var original_animation: bool = preferences.animate_background
	preferences.animate_background = false
	table = load("res://scenes/game_table.tscn").instantiate()
	root.add_child(table)
	current_scene = table
	await process_frame
	await process_frame
	fan = table.card_row
	table.rng.seed = 1763
	table._new_run()
	table.stage_target = 99999999
	fan.arrange(false)
	_check(fan.get_child_count() == 6, "Fan creates exactly one view per hand card")
	_check(fan._step > 0 and fan._step < fan._card_size.x, "Six hand cards overlap horizontally")
	var original_order := _hand_ids()
	var first_id: int = original_order[0]
	var first_view: GameCard = fan._views[first_id]
	var first_point := _point(first_id)
	_mouse(first_point, true)
	_check(fan._pressed_id == first_id, "Viewport mouse press reaches the exposed overlapping card")
	_mouse(first_point, false)
	_check(first_id in table.selected_ids and table.selected_ids.size() == 1, "Click selects a card exactly once")
	_check(fan._views[first_id] == first_view, "Selecting preserves the card node")
	var selected_y: float = first_view.position.y
	first_point = _point(first_id)
	_mouse(first_point, true)
	_mouse(first_point, false)
	_check(table.selected_ids.is_empty() and first_view.position.y > selected_y, "Second click deselects and lowers the card")

	first_point = _point(first_id)
	_mouse(first_point, true)
	_motion(first_point + Vector2(3, 1))
	_mouse(first_point + Vector2(3, 1), false)
	_check(table.selected_ids.size() == 1 and _hand_ids() == original_order, "Small mouse jitter remains a click")
	first_point = _point(first_id)
	var right_drop := first_point + Vector2(fan._step * 5, -55)
	_mouse(first_point, true)
	_motion(right_drop)
	_check(fan._dragged_id == first_id and first_view.z_index == 1000, "Dragged card follows pointer above all neighbors")
	_mouse(right_drop, false)
	_check(table.hand.back().id == first_id, "Dragging first card to the right moves it to the last slot")
	_check(table.selected_ids.size() == 1 and first_id in table.selected_ids, "Dragging preserves selection without toggling")
	_check(fan._pressed_id == -1 and fan._dragged_id == -1, "Releasing clears pointer capture")
	_check(_hand_ids().size() == 6 and table.seen_count == 6 and table.plays_left == 2, "Reordering changes neither cards nor game resources")
	first_point = _point(first_id)
	var left_drop := first_point - Vector2(fan._step * 5, 0)
	_mouse(first_point, true)
	_motion(left_drop)
	_mouse(left_drop, false)
	_check(_hand_ids() == original_order, "Last card can be dragged back into the first slot")

	table.selected_ids.assign([table.hand[3].id, table.hand[0].id])
	table._update_score_preview()
	var selected: Array = table.selected_ids.duplicate()
	_check(table._selected_cards()[0].id == table.hand[0].id, "Scoring follows left-to-right hand order rather than click order")
	table.sort_color_button.pressed.emit()
	_check(_sorted("color"), "Color button groups color first and type second")
	_check(table.selected_ids == selected and table.master_deck.size() == 27, "Color sort preserves selected cards and deck")
	table.sort_type_button.pressed.emit()
	_check(_sorted("type"), "Type button groups type first and color second")
	var sorted_order := _hand_ids()
	table.sort_type_button.pressed.emit()
	_check(_hand_ids() == sorted_order, "Repeated sorting is deterministic")
	_check(table._selected_cards()[0].id == table.hand.filter(func(card: Dictionary) -> bool: return card.id in selected)[0].id, "Sorting immediately updates selected-card scoring order")

	# Opening a modal mid-drag must cancel the visual preview without committing it.
	fan._set_hover(-1)
	var dragged_id: int = table.hand[0].id
	first_point = _point(dragged_id)
	_mouse(first_point, true)
	_motion(first_point + Vector2(fan._step * 3, -20))
	table._show_score_details()
	_check(fan._pressed_id == -1 and _hand_ids() == sorted_order, "Opening modal cancels an unfinished drag")
	table._sort_hand("color")
	_check(_hand_ids() == sorted_order, "Modal blocks sorting the underlying hand")
	_mouse(first_point, true)
	_mouse(first_point, false)
	_check(table.selected_ids == selected, "Modal blocks clicking underlying hand")
	table._close_modal()
	_check(fan._interactive, "Closing modal restores hand input")

	fan._set_hover(-1)
	first_point = _point(dragged_id)
	_mouse(first_point, true)
	var outside := Vector2(fan.size.x + 400, -100)
	_motion(outside)
	_mouse(outside, false)
	_check(table.hand.back().id == dragged_id and fan._pressed_id == -1, "Releasing outside the hand clamps to the end and unsticks dragging")
	table.selected_ids.clear()
	table.selected_ids.append(table.hand[0].id)
	table._discard_selected()
	_check(table.hand.size() == 6 and fan._views.size() == 6 and fan.get_child_count() == 6, "Redraw removes the departed view and inserts exactly one new card")
	table.hand_bonus = 6
	table._new_stage()
	fan.arrange(false)
	_check(table.hand.size() == 12 and fan._step < fan._card_size.x, "Expanded hands stay in a single overlapping row")
	_check(fan._start_x >= 0 and fan._start_x + 11 * fan._step + fan._card_size.x <= fan.size.x, "Expanded hand fits within horizontal bounds")

	preferences.animate_background = true
	table.hand_bonus = 0
	table._new_stage()
	await create_timer(0.25).timeout
	var animated_id: int = table.hand[0].id
	_motion(_point(animated_id), false)
	await create_timer(0.2).timeout
	var animated_start := _point(animated_id)
	_mouse(animated_start, true)
	var animated_end := animated_start + Vector2(fan._step * 5, -25)
	_motion(animated_end)
	await create_timer(0.06).timeout
	_mouse(animated_end, false)
	await create_timer(0.25).timeout
	_check(table.hand.back().id == animated_id and fan._dragged_id == -1, "Hover and animation enabled still allow correct drag-and-drop")
	_check(fan._views[animated_id].position.distance_to(fan._slot_position(5)) < 1.0, "Dropped card settles into its assigned slot")

	# The rightmost selected card must really receive the repeat-last effect.
	preferences.animate_background = false
	table._retry_run()
	table.stage_target = 99999999
	var sun: Dictionary = table.master_deck.filter(func(card: Dictionary) -> bool: return card.suit == "日")[0].duplicate(true)
	var forest: Dictionary = table.master_deck.filter(func(card: Dictionary) -> bool: return card.suit == "森林")[0].duplicate(true)
	sun.color = "金"
	forest.color = "无色"
	table.hand.assign([sun, forest])
	table.stones.append(FateStones.by_id("repeat_last_card"))
	table.selected_ids.assign([sun.id, forest.id])
	table._update_score_preview()
	_check(table.latest_result.score == 390, "Rightmost forest receives the initial repeat-last trigger")
	table._reorder_hand_card(sun.id, 1)
	_check(table.latest_result.score == 7425, "Moving gold sun rightmost immediately updates repeat-last score preview")
	table._play_selected()
	_check(table.round_score == 7425, "Played score matches the preview after reordering")
	preferences.animate_background = original_animation
	if failures.is_empty():
		print("HAND_INTERACTION_PASS: %d checks" % checks)
		quit(0)
	else:
		push_error("HAND_INTERACTION_FAIL: %d of %d checks failed." % [failures.size(), checks])
		quit(1)
