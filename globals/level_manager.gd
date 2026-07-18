extends Node

signal levels_exhausted
signal level_cleared
signal level_loaded
signal turn_updated
signal level_reset

var _game: Game
var current_level: int = -1
var level_list: Array[PackedScene] = []
var load_delay: float = 1.2
var empty_level_scene: PackedScene = preload(Constants.EMPTY_LEVEL_FILE)
var turn: int = 0

var _reset_held_time: float = 0.0

func _ready() -> void:
	var dir := DirAccess.open("res://scenes/levels")

	if dir == null:
		push_error("Could not open level directory")
		return

	var levels: Array[Dictionary] = []
	var highest_level_number := -1

	for file_name in dir.get_files():
		if not file_name.ends_with(".tscn"):
			continue

		var scene_path := "res://scenes/levels/" + file_name
		var scene := load(scene_path) as PackedScene

		if scene == null:
			push_warning("Could not load level scene: " + scene_path)
			continue

		var level := scene.instantiate()

		if not level is Level:
			push_warning("Scene is not a level: " + scene_path)
			level.free()
			continue

		var level_number: int = level.level_number
		level.free()

		if level_number < 0:
			continue

		levels.append({
			"level_number": level_number,
			"scene": scene
		})

		highest_level_number = maxi(highest_level_number, level_number)

	level_list.resize(highest_level_number + 1)

	for level_data in levels:
		var level_number: int = level_data["level_number"]
		level_list[level_number] = level_data["scene"]

func _process(delta: float) -> void:
	if Input.is_action_pressed(&"reset"):
		_reset_held_time += delta
	else:
		_reset_held_time = 0.0
		return

	if _reset_held_time >= Constants.RESET_HOLD_TIME:
		clear_level()
		_load_level(current_level)
		level_reset.emit()


func set_game(game: Game) -> void:
	_game = game
	game.turn_finished.connect(turn_increase)
	game.undo_finished.connect(turn_decrease)
	game.redo_finished.connect(turn_increase)

func turn_increase() -> void:
	turn += 1
	turn_updated.emit()

func turn_decrease() -> void:
	turn -= 1
	turn_updated.emit()

func load_next_level(with_delay: bool = true) -> void:
	if _game == null:
		push_error("Cannot load level: Game has not been set.")
		return

	if with_delay:
		SFXService.play("floppy")

	if is_instance_valid(_game.level):
		clear_level()

	if with_delay:
		await get_tree().create_timer(load_delay).timeout   # Delay between blank and load next, for visual distinction between levels

	while true:
		current_level += 1

		if current_level >= level_list.size():
			var level = empty_level_scene.instantiate()
			_game.add_child(level)
			_game.move_child(level, 0)
			levels_exhausted.emit()
			return

		if _load_level(current_level):
			return

func clear_level() -> void:
	_game.remove_all_actors()
	_game.clear_turn_history()

	for connection in _game.level.level_complete.get_connections():
		connection["signal"].disconnect(connection["callable"])

	_game.level.free()

	turn = 0
	turn_updated.emit()

	level_cleared.emit()

func _load_level(level_number: int) -> bool:

	if _game == null:
		push_error("Cannot load level: Game has not been set.")
		return false

	if level_number < 0 or level_number >= level_list.size():
		return false

	var level_scene: PackedScene = level_list[level_number]

	if level_scene == null:
		return false

	var level: Level = level_scene.instantiate()
	_game.add_child(level)
	_game.move_child(level, 0)
	_game.level = level
	SaveDataManager.unlock_level(level.level_number)
	level.level_complete.connect(_game._on_level_complete)
	level_loaded.emit()
	return true
