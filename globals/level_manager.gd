extends Node

signal levels_exhausted
signal level_cleared
signal level_loaded

var _game: Game
var current_level: int = -1
var level_list: Array[PackedScene] = []
var load_delay: float = 1.2
var empty_level_scene: PackedScene = preload(Constants.EMPTY_LEVEL_FILE)

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


func set_game(game: Game) -> void:
	_game = game

func load_next_level(with_delay: bool = true) -> void:
	if _game == null:
		push_error("Cannot load level: Game has not been set.")
		return

	if with_delay:
		SFXService.play("floppy")

	clear_level()

	if with_delay:
		await get_tree().create_timer(load_delay).timeout   # Delay between blank and load next, for visual distinction between levels

	while true:
		current_level += 1

		if current_level >= level_list.size():
			_game.add_child(empty_level_scene.instantiate())
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
	_game.level = level
	level.level_complete.connect(_game._on_level_complete)
	level_loaded.emit()
	return true
