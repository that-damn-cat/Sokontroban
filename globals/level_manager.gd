extends Node

signal catalog_ready
signal levels_exhausted
signal level_cleared(previous_level_number: int)
signal level_loaded(level_number: int)
signal level_quit
signal turn_updated(turn: int)
signal level_reset(level_number: int)

var current_level: int = -1
var level_numbers: Array[int] = []
var turn: int = 0
var reset_enabled: bool = false

var _game: Game
var _level_scenes: Dictionary[int, PackedScene] = {}
var _level_titles: Dictionary[int, String] = {}
var _empty_level_scene: PackedScene = preload(Constants.EMPTY_LEVEL_FILE)
var _reset_held_time: float = 0.0
var _reset_triggered: bool = false
var _reset_waiting_for_release: bool = false

func _enter_tree() -> void:
	_discover_levels()

func _process(delta: float) -> void:
	var reset_is_pressed := Input.is_action_pressed(&"reset")

	# A reset held while leaving/re-entering gameplay must be released before it
	# can begin a new hold. This prevents invisible resets after closing a menu.
	if _reset_waiting_for_release:
		if not reset_is_pressed:
			_reset_waiting_for_release = false

		_reset_hold_state()
		return

	if not can_reset_current_level() or not reset_is_pressed:
		_reset_hold_state()
		return

	if _reset_triggered:
		return

	_reset_held_time += delta

	if _reset_held_time >= Constants.RESET_HOLD_TIME:
		_reset_triggered = true
		reset_current_level()

func set_game(game: Game) -> void:
	if _game == game:
		return

	_disconnect_game_signals()
	_game = game

	if not is_instance_valid(_game):
		return

	_game.turn_finished.connect(_turn_increase)
	_game.undo_finished.connect(_turn_decrease)
	_game.redo_finished.connect(_turn_increase)

	if is_instance_valid(_game.level):
		current_level = _game.level.level_number

	_set_turn(0)

func set_reset_enabled(enabled: bool) -> void:
	reset_enabled = enabled

	if not enabled:
		_reset_hold_state()
		_reset_waiting_for_release = Input.is_action_pressed(&"reset")
	elif Input.is_action_pressed(&"reset"):
		_reset_waiting_for_release = true

func can_reset_current_level() -> bool:
	return (
		reset_enabled
		and is_instance_valid(_game)
		and is_instance_valid(_game.level)
		and current_level >= 0
		and _game.gameplay_enabled
		and not _game.turn_in_process
		and _game.is_input_allowed(&"reset")
	)

func reset_current_level() -> bool:
	if not can_reset_current_level():
		return false

	var level_number := current_level
	_destroy_current_level(true)

	var loaded := load_level(level_number)
	if loaded:
		level_reset.emit(level_number)

	return loaded

func load_level(level_number: int) -> bool:
	if not is_instance_valid(_game):
		push_error("Cannot load level: Game has not been registered.")
		return false

	if not has_level(level_number):
		push_warning("Cannot load missing level %s" % level_number)
		return false

	if is_instance_valid(_game.level):
		_destroy_current_level(current_level >= 0)

	var level_scene: PackedScene = _level_scenes[level_number]
	var new_level := level_scene.instantiate() as Level

	if new_level == null:
		push_error("Level %s did not instantiate as Level." % level_number)
		_ensure_empty_level()
		return false

	current_level = level_number
	_game.set_level(new_level)
	_game.add_child(new_level)
	_game.move_child(new_level, 0)
	_game.update_allowed_inputs()

	SaveDataManager.unlock_level(level_number)
	level_loaded.emit(level_number)
	return true

func load_next_level() -> bool:
	var next_level := get_next_level_number(current_level)

	if next_level < 0:
		levels_exhausted.emit()
		return false

	return load_level(next_level)

func clear_level() -> void:
	if not is_instance_valid(_game):
		return

	_destroy_current_level(current_level >= 0)
	_ensure_empty_level()


func quit_level() -> void:
	clear_level()
	level_quit.emit()


func has_level(level_number: int) -> bool:
	return _level_scenes.has(level_number)


func get_level_numbers() -> Array[int]:
	return level_numbers.duplicate()


func get_first_level_number() -> int:
	if level_numbers.is_empty():
		return -1

	return level_numbers[0]


func get_level_title(level_number: int) -> String:
	return _level_titles.get(level_number, "Level %02d" % level_number)


func get_next_level_number(previous_level_number: int) -> int:
	var index := level_numbers.find(previous_level_number)

	if index < 0:
		return get_first_level_number()

	if index + 1 >= level_numbers.size():
		return -1

	return level_numbers[index + 1]


func _discover_levels() -> void:
	_level_scenes.clear()
	_level_titles.clear()
	level_numbers.clear()

	var directory := DirAccess.open(Constants.LEVEL_DIRECTORY)
	if directory == null:
		push_error("Could not open level directory: %s" % Constants.LEVEL_DIRECTORY)
		catalog_ready.emit()
		return

	for file_name in directory.get_files():
		if not file_name.ends_with(".tscn"):
			continue

		var scene_path := Constants.LEVEL_DIRECTORY.path_join(file_name)
		var scene := load(scene_path) as PackedScene

		if scene == null:
			push_warning("Could not load level scene: %s" % scene_path)
			continue

		var instance := scene.instantiate()
		if instance is not Level:
			push_warning("Scene is not a Level: %s" % scene_path)
			instance.free()
			continue

		var level := instance as Level
		var level_number := level.level_number
		var level_title := level.level_title.strip_edges()
		level.free()

		if level_number < 0:
			continue

		if _level_scenes.has(level_number):
			push_warning("Duplicate level number %s in %s" % [level_number, scene_path])
			continue

		if level_title.is_empty():
			level_title = _title_from_file_name(file_name)

		_level_scenes[level_number] = scene
		_level_titles[level_number] = level_title
		level_numbers.append(level_number)

	level_numbers.sort()
	catalog_ready.emit()


func _title_from_file_name(file_name: String) -> String:
	var stem := file_name.get_basename()
	var separator := stem.find("_")

	if separator >= 0:
		var prefix := stem.substr(0, separator)
		if prefix.is_valid_int():
			stem = stem.substr(separator + 1)

	return stem.replace("_", " ").capitalize()


func _destroy_current_level(emit_cleared: bool) -> void:
	if not is_instance_valid(_game):
		return

	var previous_level_number := current_level

	_game.prepare_for_level_change()
	_game.remove_all_actors()

	var old_level := _game.level
	_game.set_level(null)
	current_level = -1

	if is_instance_valid(old_level):
		old_level.free()

	_set_turn(0)

	if emit_cleared:
		level_cleared.emit(previous_level_number)


func _ensure_empty_level() -> void:
	if not is_instance_valid(_game) or is_instance_valid(_game.level):
		return

	var empty_level := _empty_level_scene.instantiate() as Level
	if empty_level == null:
		push_error("Empty level scene is not a Level.")
		return

	current_level = -1
	_game.set_level(empty_level)
	_game.add_child(empty_level)
	_game.move_child(empty_level, 0)


func _turn_increase() -> void:
	_set_turn(turn + 1)


func _turn_decrease() -> void:
	_set_turn(maxi(turn - 1, 0))


func _set_turn(new_turn: int) -> void:
	turn = maxi(new_turn, 0)
	turn_updated.emit(turn)


func _reset_hold_state() -> void:
	_reset_held_time = 0.0
	_reset_triggered = false


func _disconnect_game_signals() -> void:
	if not is_instance_valid(_game):
		return

	if _game.turn_finished.is_connected(_turn_increase):
		_game.turn_finished.disconnect(_turn_increase)
	if _game.undo_finished.is_connected(_turn_decrease):
		_game.undo_finished.disconnect(_turn_decrease)
	if _game.redo_finished.is_connected(_turn_increase):
		_game.redo_finished.disconnect(_turn_increase)