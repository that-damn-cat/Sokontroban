extends Node

signal progress_changed
signal score_changed(level_number: int)
signal config_reset

var save_data := ConfigFile.new()
var unlocked_levels: Array[int] = [1]
var has_won: bool = false

# Key is the bus name, value is the linear representation of the volume
var audio_config: Dictionary[String, float] = {}

## Key is the level number, value is the score
var hi_scores: Dictionary[int, int] = {}


func _ready() -> void:
	var err: Error

	err = save_data.load(Constants.SAVE_DATA_FILE)

	if err != OK:
		init_all_data()

	audio_config["Master"] = save_data.get_value("Audio", "Master", 1.0)
	audio_config["Music"]  = save_data.get_value("Audio", "Music",  1.0)
	audio_config["SFX"]    = save_data.get_value("Audio", "SFX",    1.0)
	audio_config["BGFX"]   = save_data.get_value("Audio", "BGFX",   0.5)

	unlocked_levels = save_data.get_value("Progress", "unlocked_levels", [1] as Array[int]) as Array[int]
	has_won = save_data.get_value("Progress", "victory", false)

	hi_scores = save_data.get_value("Scores", "hi_scores", {} as Dictionary[int, int]) as Dictionary[int, int]

	_set_audio_buses()

func unlock_level(level_number: int) -> void:
	if level_number not in unlocked_levels:
		unlocked_levels.append(level_number)

	save_data.set_value("Progress", "unlocked_levels", unlocked_levels)
	save()

func update_score(level_number: int, score: int) -> void:
	var previous_score: int = hi_scores.get(level_number, -1)

	if previous_score >= 0 and score >= previous_score:
		return

	hi_scores[level_number] = score
	save_data.set_value("Scores", "hi_scores", hi_scores)
	save()
	score_changed.emit(level_number)

func update_config() -> void:
	save_data.set_value("Audio", "Master", _get_audio_value("Master"))
	save_data.set_value("Audio", "Music",  _get_audio_value("Music"))
	save_data.set_value("Audio", "SFX",    _get_audio_value("SFX"))
	save_data.set_value("Audio", "BGFX",   _get_audio_value("BGFX"))

	save()

func set_victory() -> void:
	has_won = true
	save_data.set_value("Progress", "victory", has_won)
	save()
	progress_changed.emit()

func save() -> void:
	save_data.save(Constants.SAVE_DATA_FILE)

func unset_victory() -> void:
	has_won = false
	save_data.set_value("Progress", "victory", has_won)
	save()
	progress_changed.emit()

func init_all_data() -> void:
	save_data.clear()
	reset_config()
	reset_progress()

func reset_config() -> void:
	save_data.set_value("Audio", "Master", 1.0)
	save_data.set_value("Audio", "Music",  1.0)
	save_data.set_value("Audio", "SFX",    1.0)
	save_data.set_value("Audio", "BGFX",   0.5)

	save()

	_set_audio_buses()
	config_reset.emit()

func reset_progress() -> void:
	unlocked_levels = [1]
	has_won = false
	hi_scores.clear()

	save_data.set_value("Progress", "unlocked_levels", unlocked_levels)
	save_data.set_value("Progress", "victory", has_won)
	save_data.set_value("Scores", "hi_scores", hi_scores)

	save()
	progress_changed.emit()

func _set_audio_buses() -> void:
	_update_audio_server("Master")
	_update_audio_server("Music")
	_update_audio_server("SFX")
	_update_audio_server("BGFX")

func _update_audio_server(bus_name: String) -> void:
	var index = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return

	var value = save_data.get_value("Audio", bus_name, 1.0)

	AudioServer.set_bus_volume_db(index, linear_to_db(value))

func _get_audio_value(bus_name: String) -> float:
	var index = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0

	return db_to_linear(AudioServer.get_bus_volume_db(index))
