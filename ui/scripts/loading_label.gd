extends Label

@export var dot_time: float = 0.33
@export_range(1, 6) var max_dots: int = 3

var _time_remaining = dot_time
var _dot_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	LevelManager.level_cleared.connect(start_loading)
	LevelManager.level_loaded.connect(stop_loading)
	LevelManager.level_quit.connect(stop_loading)

	stop_loading()

func _process(delta: float) -> void:
	if not visible:
		return

	_time_remaining -= delta

	if _time_remaining > 0.0:
		return

	_time_remaining += dot_time
	_dot_count = (_dot_count + 1) % (max_dots + 1)
	_update_text()

func start_loading() -> void:
	_dot_count = 0
	_time_remaining = dot_time
	_update_text()
	show()

func stop_loading() -> void:
	hide()
	_dot_count = 0
	_time_remaining = dot_time
	_update_text()

func _update_text() -> void:
	text = "Loading" + ".".repeat(_dot_count)