class_name MainMenuScreen
extends Control

signal start_requested
signal level_select_requested
signal scores_requested
signal options_requested
signal quit_requested

@export var start_button: Button
@export var level_select_button: Button
@export var scores_button: Button
@export var options_button: Button
@export var quit_button: Button


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	scores_button.pressed.connect(_on_scores_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func focus_default() -> void:
	for button in _get_buttons():
		if button.visible and not button.disabled:
			button.call_deferred(&"grab_focus")
			return


func _get_buttons() -> Array[Button]:
	return [
		start_button,
		level_select_button,
		scores_button,
		options_button,
		quit_button,
	]


func _on_start_pressed() -> void:
	SFXService.play("click")
	start_requested.emit()

func _on_level_select_pressed() -> void:
	SFXService.play("click")
	level_select_requested.emit()

func _on_scores_pressed() -> void:
	SFXService.play("click")
	scores_requested.emit()

func _on_options_pressed() -> void:
	SFXService.play("click")
	options_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()
