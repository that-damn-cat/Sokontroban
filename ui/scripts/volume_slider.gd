class_name VolumeSlider
extends HSlider

@export var audio_bus: StringName = &"Master"
@export var sample_play: StringName
@export var sample_debounce: float = 0.75

var _bus_index: int = -1
var _debounce_time: float = 0.0


func _ready() -> void:
	min_value = Constants.MIN_LINEAR_VOLUME
	step = 0.025
	max_value = 1.0

	value_changed.connect(_on_value_changed)
	drag_ended.connect(_on_drag_ended)
	SaveDataManager.config_reset.connect(_refresh_value)
	_refresh_value()


func _process(delta: float) -> void:
	_debounce_time = maxf(_debounce_time - delta, 0.0)


func _refresh_value() -> void:
	_bus_index = AudioServer.get_bus_index(audio_bus)

	if _bus_index < 0:
		push_warning("Audio bus not found: %s" % audio_bus)
		editable = false
		return

	editable = true
	var current_value := clampf(
		db_to_linear(AudioServer.get_bus_volume_db(_bus_index)),
		Constants.MIN_LINEAR_VOLUME,
		1.0
	)
	set_value_no_signal(current_value)


func _on_value_changed(new_value: float) -> void:
	if _bus_index < 0:
		return

	var safe_value := clampf(new_value, Constants.MIN_LINEAR_VOLUME, 1.0)
	AudioServer.set_bus_volume_db(_bus_index, linear_to_db(safe_value))

	if SFXService.has_sfx(sample_play) and _debounce_time <= 0.0:
		SFXService.play(sample_play)
		_debounce_time = sample_debounce


func _on_drag_ended(value_changed_during_drag: bool) -> void:
	if value_changed_during_drag:
		SaveDataManager.update_config()