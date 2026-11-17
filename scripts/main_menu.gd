extends Control
## Entry scene for the Fortune run, card collection, and preferences.

const GAME_SCENE := "res://scenes/game_table.tscn"
var modal: Control
var previous_focus: Control
var changing_scene: bool = false
var click_player: AudioStreamPlayer
@onready var menu_buttons: Array[Button] = [%StartButton, %CollectionButton, %SettingsButton, %QuitButton]


func _ready() -> void:
	theme = MenuTheme.create()
	MenuTheme.primary(%StartButton)
	%StartButton.pressed.connect(_start_game)
	%CollectionButton.pressed.connect(_show_collection)
	%SettingsButton.pressed.connect(_show_settings)
	%QuitButton.pressed.connect(_show_quit)
	for button in menu_buttons:
		button.pressed.connect(_play_click)
	_setup_click_sound()
	%StartButton.grab_focus()
	resized.connect(_update_layout)
	_update_layout()
	$PageMargin.modulate.a = 0.0
	create_tween().tween_property($PageMargin, "modulate:a", 1.0, 0.55)
	print("[主菜单] 场景已加载。开始按钮：_start_game()")


func _update_layout() -> void:
	# canvas_items keeps the design readable at 960×600 and larger.
	var wide := size.x > 1500
	$PageMargin.add_theme_constant_override("margin_left", 110 if wide else 80)
	$PageMargin.add_theme_constant_override("margin_right", 110 if wide else 80)


func _start_game() -> void:
	if changing_scene:
		return
	changing_scene = true
	print("[主菜单] 开启牌局 -> ", GAME_SCENE)
	var tween := create_tween()
	tween.tween_property($PageMargin, "modulate:a", 0.0, 0.2)
	await tween.finished
	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error != OK:
		changing_scene = false
		$PageMargin.modulate.a = 1.0
		push_error("牌桌场景加载失败：%s" % error_string(error))


func _open_dialog(title: String, subtitle: String, width: float = 640) -> VBoxContainer:
	previous_focus = get_viewport().gui_get_focus_owner()
	for button in menu_buttons:
		button.focus_mode = Control.FOCUS_NONE
	modal = Control.new()
	modal.name = "Modal"
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.035, 0.04, 0.88)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var heading_label := MenuTheme.label(title, 30)
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_label)
	var close := MenuTheme.button("×", _close_dialog)
	close.tooltip_text = "关闭（Esc）"
	heading.add_child(close)
	close.grab_focus()
	var sub := MenuTheme.label(subtitle, 15, MenuTheme.MUTED)
	content.add_child(sub)
	content.add_child(HSeparator.new())
	return content


func _close_dialog() -> void:
	if not is_instance_valid(modal):
		return
	modal.queue_free()
	modal = null
	for button in menu_buttons:
		button.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()
	else:
		%StartButton.grab_focus()


func _show_collection() -> void:
	var content := _open_dialog("命运牌图鉴", "27 张基础牌  ·  日×1 / 月×1 / 星×3 / 地×6 / 海×8 / 森×8", 780)
	var cards := GridContainer.new()
	cards.columns = 3
	cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards.add_theme_constant_override("h_separation", 24)
	cards.add_theme_constant_override("v_separation", 12)
	content.add_child(cards)
	for index in range(FateRules.SUITS.size()):
		var suit: String = FateRules.SUITS[index]
		var view := GameCard.new()
		view.setup({"id": index, "suit": suit, "base": FateRules.SUIT_VALUES[suit], "color": "无色"}, false)
		view.disabled = true
		view.custom_minimum_size = Vector2(150, 205)
		cards.add_child(view)
	content.add_child(MenuTheme.label("黑 / 蓝 / 绿：+5 基础    金 / 银 / 彩：×3 命运之力", 14, MenuTheme.GOLD))
	content.add_child(MenuTheme.button("返回主菜单", _close_dialog))


func _show_settings() -> void:
	var content := _open_dialog("设置", "调整你的牌桌，让长夜更舒适。")
	var volume_row := HBoxContainer.new()
	content.add_child(volume_row)
	var volume_label := MenuTheme.label("主音量", 18)
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(volume_label)
	var volume_value := MenuTheme.label("%d%%" % roundi(Preferences.master_volume * 100), 16, MenuTheme.GOLD)
	volume_row.add_child(volume_value)
	var slider := HSlider.new()
	slider.name = "VolumeSlider"
	slider.max_value = 100
	slider.step = 1
	slider.value = Preferences.master_volume * 100
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value: float) -> void:
		Preferences.master_volume = value / 100.0
		Preferences.apply()
		Preferences.save()
		volume_value.text = "%d%%" % roundi(value)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void: _play_click())
	content.add_child(slider)
	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏显示                                      F11"
	fullscreen.button_pressed = Preferences.fullscreen
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		Preferences.fullscreen = enabled
		Preferences.apply()
		Preferences.save()
	)
	# Keep the check button in sync when F11 is used in this dialog.
	Preferences.fullscreen_changed.connect(fullscreen.set_pressed_no_signal)
	content.add_child(fullscreen)
	var animation := CheckButton.new()
	animation.text = "背景与卡牌动态"
	animation.button_pressed = Preferences.animate_background
	animation.toggled.connect(func(enabled: bool) -> void:
		Preferences.animate_background = enabled
		Preferences.save()
	)
	content.add_child(animation)
	content.add_child(MenuTheme.label("设置会自动保存。音量可通过按钮提示音试听。", 13, MenuTheme.MUTED))
	var done := MenuTheme.button("完 成", _close_dialog)
	MenuTheme.primary(done)
	content.add_child(done)


func _show_quit() -> void:
	var content := _open_dialog("暂别星夜？", "下次相逢，命运仍会为你留一张牌。", 600)
	content.add_child(MenuTheme.button("继续停留", _close_dialog))
	var quit := MenuTheme.button("退出游戏", func() -> void: get_tree().quit())
	MenuTheme.primary(quit)
	content.add_child(quit)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or changing_scene:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			_close_dialog()
		else:
			_show_quit()
		get_viewport().set_input_as_handled()
	elif not is_instance_valid(modal) and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up")):
		var index := menu_buttons.find(get_viewport().gui_get_focus_owner())
		var direction := 1 if event.is_action_pressed("ui_down") else -1
		menu_buttons[posmod(index + direction, menu_buttons.size())].grab_focus()
		get_viewport().set_input_as_handled()


func _setup_click_sound() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(2205 * 2)
	for i in range(2205):
		var time := float(i) / 22050.0
		var envelope := sin(PI * float(i) / 2205.0) * exp(-time * 45.0)
		data.encode_s16(i * 2, int(sin(time * TAU * 660.0) * envelope * 4200))
	stream.data = data
	click_player = AudioStreamPlayer.new()
	click_player.stream = stream
	add_child(click_player)


func _play_click() -> void:
	click_player.play()
