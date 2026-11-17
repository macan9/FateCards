extends SceneTree
## Run with a renderer, without --headless. Captures fresh test scenes only.

var failures: Array[String] = []
var capture_dir := "res://.godot/ui_previews/"
var table


func _initialize() -> void:
	_run.call_deferred()


func _capture(name: String, modal: Control = null) -> void:
	await create_timer(0.22).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if is_instance_valid(modal):
		var panels := modal.find_children("*", "PanelContainer", true, false)
		if not panels.is_empty():
			var bounds: Rect2 = panels[0].get_global_rect()
			var viewport := root.get_visible_rect().grow(2)
			if not viewport.encloses(bounds):
				failures.append("%s modal exceeds viewport: %s in %s" % [name, bounds, viewport])
	var result := root.get_texture().get_image().save_png(capture_dir + name + ".png")
	if result != OK:
		failures.append("Screenshot failed: " + name)
	print("[UI capture] ", name)


func _run() -> void:
	DisplayServer.window_set_title("命运占卜 · 自动界面检查")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	var menu: Control = load("res://control.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(0.7).timeout
	await _capture("01_menu")
	menu._show_collection()
	await _capture("02_collection", menu.modal)
	menu._close_dialog()
	DisplayServer.window_set_size(Vector2i(960, 600))
	await create_timer(0.2).timeout
	await _capture("16_minimum_menu")
	menu._show_collection()
	await _capture("17_minimum_collection", menu.modal)
	menu._close_dialog()
	menu._show_settings()
	await _capture("18_minimum_settings", menu.modal)
	menu._close_dialog()
	menu.queue_free()
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await process_frame
	table = load("res://scenes/game_table.tscn").instantiate()
	root.add_child(table)
	current_scene = table
	table.rng.seed = 1763
	table._new_run()
	await _capture("03_table")
	table._toggle_card(table.hand[0].id)
	table._toggle_card(table.hand[3].id)
	await _capture("19_hand_selected")
	table._sort_hand("color")
	await _capture("20_hand_color_sorted")
	table._sort_hand("type")
	await _capture("21_hand_type_sorted")
	var fan: HandFan = table.card_row
	var moved_id: int = table.hand[0].id
	var view: GameCard = fan._views[moved_id]
	var drag_start := view.get_transform() * Vector2(24, 80)
	fan._pointer_press(drag_start)
	var drag_end := drag_start + Vector2(fan._step * 4, -90)
	fan._pointer_move(drag_end)
	await _capture("22_hand_dragging")
	fan._pointer_release(drag_end)
	await _capture("23_hand_reordered")
	table.selected_ids.clear()
	table._update_score_preview()
	table._show_score_details()
	await _capture("04_score_details", table.modal)
	table._close_modal()
	table.stage_target = 1
	table.selected_ids.append(table.hand[0].id)
	table._play_selected()
	await _capture("05_result", table.modal)
	table._enter_intermission()
	await _capture("06_intermission", table.modal)
	table._show_shop()
	await _capture("07_shop", table.modal)
	table.tarot_inventory.assign(["delete"])
	table.tarot_cards = 1
	table._begin_tarot_action("delete")
	await _capture("08_picker", table.modal)
	table._cancel_card_selection()
	table._advance_stage()
	DisplayServer.window_set_size(Vector2i(960, 600))
	await create_timer(0.2).timeout
	await _capture("09_minimum_table")
	table.hand_bonus = 6
	table._new_stage()
	await _capture("24_expanded_hand")
	table._show_score_details()
	await _capture("10_minimum_details", table.modal)
	table._enter_intermission()
	table.stones.clear()
	for stone_id in ["rank_four_flush_mult", "utility_play_copy", "growth_round_power", "suit_星空_mult"]:
		table.stones.append(FateStones.by_id(stone_id))
	table.coins = 100
	table._buy_stone(FateStones.by_id("utility_play_delete"))
	await _capture("11_minimum_replacement", table.modal)
	table._show_origin_choice()
	await _capture("12_minimum_source", table.modal)
	table._show_boss_coupon()
	await _capture("13_minimum_coupon", table.modal)
	table._show_dream_choice()
	await _capture("14_minimum_dream", table.modal)
	table._dream_copy()
	await _capture("15_minimum_picker", table.modal)
	if failures.is_empty():
		print("UI_CAPTURE_PASS: 24 captures; all modal bounds fit")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
