extends Node

var is_paused := false
var pause_hidden_nodes: Array[CanvasItem]
var pause_shown_nodes: Array[CanvasItem]
var first_pause_focus: Control

var _game: Game

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("pause_hidden"):
		if node is Game:
			_game = node
			continue

		if node is CanvasItem:
			pause_hidden_nodes.append(node)
			continue

		for child in node.find_children("*", "CanvasItem", true):
			if child is CanvasItem:
				pause_hidden_nodes.append(child)

	for node in get_tree().get_nodes_in_group("pause_shown"):
		if node is CanvasItem:
			pause_shown_nodes.append(node)
			continue

		for child in node.find_children("*", "CanvasItem", true):
			if child is CanvasItem:
				pause_shown_nodes.append(child)

	for node in pause_shown_nodes:
		node.hide()

	process_mode = PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return

	if is_paused:
		unpause()
	else:
		pause()


func unpause() -> void:
	SaveDataManager.update_config()

	if is_instance_valid(_game.level):
		_game.level.show()

	for node in pause_hidden_nodes:
		if not is_instance_valid(node):
			pause_hidden_nodes.erase(node)
			continue
		node.show()

	for node in pause_shown_nodes:
		if not is_instance_valid(node):
			pause_shown_nodes.erase(node)
			continue
		node.hide()

	get_tree().paused = false
	is_paused = false

	SFXService.play(&"pause")

func pause() -> void:
	_game.level.hide()

	for node in pause_hidden_nodes:
		if not is_instance_valid(node):
			pause_hidden_nodes.erase(node)
			continue
		node.hide()

	for node in pause_shown_nodes:
		if not is_instance_valid(node):
			pause_shown_nodes.erase(node)
			continue
		node.show()

	if is_instance_valid(first_pause_focus):
		first_pause_focus.grab_focus()

	get_tree().paused = true
	is_paused = true

	SFXService.play(&"pause")

func register_first_pause_focus(control: Control) -> void:
	if is_instance_valid(control):
		first_pause_focus = control
