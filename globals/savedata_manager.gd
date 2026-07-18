extends Node

signal progress_changed
signal score_changed(level_number: int)
signal config_reset

var save_data := ConfigFile.new()
var unlocked_levels: Array[int] = []
var has_won: bool = false

## Key is the bus name, value is its linear volume value.
var audio_config: Dictionary[StringName, float] = {}

## Key is the level number, value is the lowest recorded turn count.
var hi_scores: Dictionary[int, int] = {}


func _ready() -> void:
	var error := save_data.load(Constants.SAVE_DATA_FILE)

	if error != OK:
		_init_all_data()

	_load_cached_values()
	_set_audio_buses()


func unlock_level(level_number: int) -> void:
	if level_number < 0 or level_number in unlocked_levels:
		return

	if not LevelManager.has_level(level_number):
		push_warning("Cannot unlock missing level %s." % level_number)
		return

	unlocked_levels.append(level_number)
	unlocked_levels.sort()
	_write_progress()
	_save()
	progress_changed.emit()

func is_level_unlocked(level_number: int) -> bool:
	return level_number in unlocked_levels

func has_progress() -> bool:
	return has_won or not hi_scores.is_empty() or unlocked_levels.size() > 1

func get_continue_level(available_levels: Array[int]) -> int:
	for level_number in available_levels:
		if is_level_unlocked(level_number) and not has_high_score(level_number):
			return level_number

	for index in range(available_levels.size() - 1, -1, -1):
		var level_number := available_levels[index]
		if is_level_unlocked(level_number):
			return level_number

	if available_levels.is_empty():
		return -1

	return available_levels[0]

func update_score(level_number: int, score: int) -> bool:
	if level_number < 0 or score < 0:
		return false

	if not LevelManager.has_level(level_number):
		push_warning("Cannot save a score for missing level %s." % level_number)
		return false

	var previous_score: int = hi_scores.get(level_number, -1)

	if previous_score >= 0 and score >= previous_score:
		return false

	hi_scores[level_number] = score
	save_data.set_value("Scores", "hi_scores", hi_scores)
	_save()
	score_changed.emit(level_number)
	return true

func has_high_score(level_number: int) -> bool:
	return hi_scores.has(level_number)

func get_high_score(level_number: int) -> int:
	return hi_scores.get(level_number, -1)

func update_config() -> void:
	for bus_name in Constants.DEFAULT_AUDIO_CONFIG:
		var value := _get_audio_value(bus_name)
		audio_config[bus_name] = value
		save_data.set_value("Audio", String(bus_name), value)

	_save()

func get_saved_audio_value(bus_name: StringName) -> float:
	return audio_config.get(bus_name, Constants.DEFAULT_AUDIO_CONFIG.get(bus_name, 1.0))

func set_victory() -> void:
	if has_won:
		return

	has_won = true
	_write_progress()
	_save()
	progress_changed.emit()

func unset_victory() -> void:
	if not has_won:
		return

	has_won = false
	_write_progress()
	_save()
	progress_changed.emit()

func reset_config() -> void:
	audio_config = Constants.DEFAULT_AUDIO_CONFIG.duplicate()

	for bus_name in audio_config:
		save_data.set_value("Audio", String(bus_name), audio_config[bus_name])

	_save()
	_set_audio_buses()
	config_reset.emit()

func reset_progress() -> void:
	unlocked_levels = _get_default_unlocked_levels()
	has_won = false
	hi_scores.clear()

	_write_progress()
	save_data.set_value("Scores", "hi_scores", hi_scores)
	_save()
	progress_changed.emit()


func _init_all_data() -> void:
	save_data.clear()

	audio_config = Constants.DEFAULT_AUDIO_CONFIG.duplicate()
	for bus_name in audio_config:
		save_data.set_value("Audio", String(bus_name), audio_config[bus_name])

	unlocked_levels = _get_default_unlocked_levels()
	has_won = false
	hi_scores.clear()

	_write_progress()
	save_data.set_value("Scores", "hi_scores", hi_scores)
	_save()

func _load_cached_values() -> void:
	audio_config.clear()
	for bus_name in Constants.DEFAULT_AUDIO_CONFIG:
		var default_value: float = Constants.DEFAULT_AUDIO_CONFIG[bus_name]
		var loaded_value := float(save_data.get_value("Audio", String(bus_name), default_value))
		audio_config[bus_name] = clampf(loaded_value, Constants.MIN_LINEAR_VOLUME, 1.0)

	var default_unlocked := _get_default_unlocked_levels()
	unlocked_levels = _read_int_array(
		save_data.get_value("Progress", "unlocked_levels", default_unlocked)
	)

	if unlocked_levels.is_empty():
		unlocked_levels = default_unlocked.duplicate()

	unlocked_levels.sort()
	has_won = bool(save_data.get_value("Progress", "victory", false))
	hi_scores = _read_score_dictionary(
		save_data.get_value("Scores", "hi_scores", {})
	)
	_normalize_progress_against_catalog()

	_write_progress()
	save_data.set_value("Scores", "hi_scores", hi_scores)
	for bus_name in audio_config:
		save_data.set_value("Audio", String(bus_name), audio_config[bus_name])
	_save()

func _normalize_progress_against_catalog() -> void:
	var available_levels := LevelManager.get_level_numbers()

	if available_levels.is_empty():
		unlocked_levels.clear()
		hi_scores.clear()
		has_won = false
		return

	var first_level := available_levels[0]
	var normalized_unlocked: Array[int] = []
	for level_number in unlocked_levels:
		if level_number in available_levels and level_number not in normalized_unlocked:
			normalized_unlocked.append(level_number)

	if first_level not in normalized_unlocked:
		normalized_unlocked.append(first_level)

	var normalized_scores: Dictionary[int, int] = {}

	for level_number in hi_scores:
		if level_number in available_levels:
			normalized_scores[level_number] = hi_scores[level_number]

	hi_scores = normalized_scores

	for level_number in available_levels:
		if not hi_scores.has(level_number):
			continue

		if level_number not in normalized_unlocked:
			normalized_unlocked.append(level_number)

		var next_level := LevelManager.get_next_level_number(level_number)

		if next_level >= 0 and next_level not in normalized_unlocked:
			normalized_unlocked.append(next_level)

	var final_level := available_levels[available_levels.size() - 1]

	if hi_scores.has(final_level):
		has_won = true

	normalized_unlocked.sort()
	unlocked_levels = normalized_unlocked

func _get_default_unlocked_levels() -> Array[int]:
	var result: Array[int] = []
	var first_level := LevelManager.get_first_level_number()

	if first_level >= 0:
		result.append(first_level)

	return result

func _read_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []

	if value is not Array:
		return result

	for item in value:
		var parsed := _variant_to_int(item)

		if parsed >= 0 and parsed not in result:
			result.append(parsed)

	return result

func _read_score_dictionary(value: Variant) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}

	if value is not Dictionary:
		return result

	for key in value:
		var level_number := _variant_to_int(key)
		var score := _variant_to_int(value[key])

		if level_number >= 0 and score >= 0:
			result[level_number] = score

	return result

func _variant_to_int(value: Variant) -> int:
	if value is int:
		return value

	if value is float:
		return int(value)

	if value is String or value is StringName:
		var string_value := String(value)

		if string_value.is_valid_int():
			return string_value.to_int()

	return -1

func _write_progress() -> void:
	save_data.set_value("Progress", "unlocked_levels", unlocked_levels)
	save_data.set_value("Progress", "victory", has_won)

func _set_audio_buses() -> void:
	for bus_name in audio_config:
		_update_audio_server(bus_name, audio_config[bus_name])

func _update_audio_server(bus_name: StringName, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)

	if index < 0:
		push_warning("Audio bus not found: %s" % bus_name)
		return

	var safe_value := clampf(linear_value, Constants.MIN_LINEAR_VOLUME, 1.0)

	AudioServer.set_bus_volume_db(index, linear_to_db(safe_value))

func _get_audio_value(bus_name: StringName) -> float:
	var index := AudioServer.get_bus_index(bus_name)

	if index < 0:
		return Constants.DEFAULT_AUDIO_CONFIG.get(bus_name, 1.0)

	return clampf(
		db_to_linear(AudioServer.get_bus_volume_db(index)),
		Constants.MIN_LINEAR_VOLUME,
		1.0
	)

func _save() -> void:
	var error := save_data.save(Constants.SAVE_DATA_FILE)

	if error != OK:
		push_error("Could not save data to %s (error %s)" % [Constants.SAVE_DATA_FILE, error])