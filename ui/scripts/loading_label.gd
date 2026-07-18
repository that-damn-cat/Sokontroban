class_name LoadingLabel
extends Label

@export var dot_time: float = 0.33
@export_range(1, 6) var max_dots: int = 3

var _time_remaining: float = 0.0
var _dot_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stop_loading()


func _process(delta: float) -> void:
	if not visible:
		return

	_time_remaining -= delta

	while _time_remaining <= 0.0:
		_time_remaining += maxf(dot_time, 0.01)
		_dot_count = (_dot_count + 1) % (max_dots + 1)
		_update_text()


func start_loading() -> void:
	_dot_count = 0
	_time_remaining = maxf(dot_time, 0.01)
	_update_text()
	show()


func stop_loading() -> void:
	hide()
	_dot_count = 0
	_time_remaining = maxf(dot_time, 0.01)
	_update_text()


func _update_text() -> void:
	text = "Loading" + ".".repeat(_dot_count)