extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var menu: Control = load("res://control.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_check(menu.get_node("%StartButton").text.contains("开启牌局"), "Menu loads the start button")
	menu._show_collection()
	await process_frame
	var cards: Array = menu.modal.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return node is GameCard)
	_check(cards.size() == 6, "Collection shows all six actual card suits")
	_check(menu.get_node("%StartButton").focus_mode == Control.FOCUS_NONE, "Collection blocks background keyboard focus")
	menu._close_dialog()
	_check(menu.get_node("%StartButton").focus_mode == Control.FOCUS_ALL, "Closing collection restores focus")
	menu._show_settings()
	await process_frame
	_check(menu.modal.find_children("VolumeSlider", "HSlider", true, false).size() == 1, "Settings contains a volume slider")
	menu._close_dialog()
	menu._show_quit()
	_check(is_instance_valid(menu.modal), "Quit confirmation opens")
	menu._close_dialog()
	menu._start_game()
	await create_timer(0.4).timeout
	_check(current_scene.scene_file_path == "res://scenes/game_table.tscn", "Start transitions to the playable table")
	_check(current_scene.hand.size() == 6, "Started game deals six cards")
	if failures.is_empty():
		print("MENU_SMOKE_PASS: %d checks" % checks)
		quit(0)
	else:
		push_error("MENU_SMOKE_FAIL: %d of %d checks failed." % [failures.size(), checks])
		quit(1)
