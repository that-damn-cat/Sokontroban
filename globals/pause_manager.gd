extends Node

signal pause_changed(is_paused: bool)

var is_paused: bool = false
var pause_allowed: bool = false
var first_pause_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not event.is_action_pressed(&"pause"):
		return

	if is_paused:
		unpause()
	elif pause_allowed:
		pause()
	else:
		return

	get_viewport().set_input_as_handled()


func set_pause_allowed(allowed: bool) -> void:
	pause_allowed = allowed

func pause(play_sound: bool = true) -> void:
	if is_paused or not pause_allowed:
		return

	SFXService.pause_all()
	is_paused = true
	get_tree().paused = true
	pause_changed.emit(true)

	if is_instance_valid(first_pause_focus):
		first_pause_focus.call_deferred(&"grab_focus")

	if play_sound:
		SFXService.play(&"pause")

func unpause(play_sound: bool = true, save_audio: bool = true) -> void:
	if not is_paused:
		get_tree().paused = false
		SFXService.unpause_all()
		return

	is_paused = false
	get_tree().paused = false
	SFXService.unpause_all()

	if save_audio:
		SaveDataManager.update_config()

	pause_changed.emit(false)

	if play_sound:
		SFXService.play(&"pause")

func force_unpause() -> void:
	unpause(false, false)

func register_first_pause_focus(control: Control) -> void:
	if is_instance_valid(control):
		first_pause_focus = control