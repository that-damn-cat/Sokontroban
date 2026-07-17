extends Node

var is_paused: bool = false

@export_category("Pause Functions")
@export var pause_hidden_nodes: Array[CanvasItem]
@export var pause_shown_nodes: Array[CanvasItem]
@export var game_node: Game
@export var first_pause_focus: Control

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return

	is_paused = not is_paused

	if is_paused:
		game_node.level.hide()

		for node in pause_hidden_nodes:
			node.hide()

		for node in pause_shown_nodes:
			node.show()

		first_pause_focus.grab_focus()

	else:
		game_node.level.show()

		for node in pause_hidden_nodes:
			node.show()

		for node in pause_shown_nodes:
			node.hide()

	get_tree().paused = is_paused
	SFXService.play(&"pause")