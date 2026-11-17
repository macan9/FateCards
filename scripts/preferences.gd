extends Node
## Settings are stored outside the project, in Godot's user:// directory.

signal fullscreen_changed(enabled: bool)

const SAVE_PATH := "user://settings.cfg"
var master_volume: float = 0.65
var fullscreen: bool = false
var animate_background: bool = true


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "volume", 0.65)), 0.0, 1.0)
		fullscreen = bool(config.get_value("display", "fullscreen", false))
		animate_background = bool(config.get_value("display", "animation", true))
	apply()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, is_zero_approx(master_volume))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	fullscreen_changed.emit(fullscreen)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "animation", animate_background)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("无法保存设置：%s" % error_string(error))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		fullscreen = not fullscreen
		apply()
		save()
		get_viewport().set_input_as_handled()
