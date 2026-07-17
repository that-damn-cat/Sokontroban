class_name VolumeSlider
extends HSlider

@export var audio_bus: StringName
@export var sample_play: StringName
@export var sample_debounce: float = 0.75

var _sfx_index: int = 0
var _debounce_time := 0.0

func _ready() -> void:
	min_value = 0.0001
	step = 0.025
	max_value = 1.0

	_sfx_index = AudioServer.get_bus_index(audio_bus)
	value = db_to_linear(AudioServer.get_bus_volume_db(_sfx_index))

	value_changed.connect(_on_value_changed)

func _process(delta: float) -> void:
	if _debounce_time >= 0.0:
		_debounce_time -= delta

func _on_value_changed(new_value: float):
	AudioServer.set_bus_volume_db(_sfx_index, linear_to_db(new_value))

	if SFXService.has_sfx(sample_play):
		print(_debounce_time)
		if _debounce_time <= 0:
			SFXService.play(sample_play)
			_debounce_time = sample_debounce