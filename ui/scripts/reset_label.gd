extends Label

enum State {
	IDLE,
	HOLDING,
	COOLDOWN,
}

@export_range(1, 6) var max_dots: int = 3

var _state := State.IDLE
var _held_time: float = 0.0
var _num_dots: int = 0
var _dot_timing: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	LevelManager.level_reset.connect(_on_level_reset)
	LevelManager.level_cleared.connect(_on_level_cleared)
	_build_dot_timing()
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(&"reset"):
		if not LevelManager.can_reset_current_level():
			return

		show()
		_state = State.HOLDING
		_reset_progress()
	elif event.is_action_released(&"reset"):
		_state = State.IDLE
		hide()
		_reset_progress()


func _process(delta: float) -> void:
	if _state != State.HOLDING:
		return

	# A release can be missed while screens and input permissions change. Polling
	# the action prevents the indicator from retaining a stale holding state.
	if (
		not LevelManager.can_reset_current_level()
		or not Input.is_action_pressed(&"reset")
	):
		_state = State.IDLE
		hide()
		_reset_progress()
		return

	_held_time += delta

	while (
		_num_dots < _dot_timing.size()
		and _held_time >= _dot_timing[_num_dots]
	):
		_num_dots += 1
		_update_text()


func _build_dot_timing() -> void:
	_dot_timing.clear()

	for index in range(1, max_dots + 1):
		_dot_timing.append(
			(float(index) * Constants.RESET_HOLD_TIME)
			/ float(max_dots + 1)
		)


func _reset_progress() -> void:
	_held_time = 0.0
	_num_dots = 0
	_update_text()


func _update_text() -> void:
	text = "Resetting" + ".".repeat(_num_dots)


func _on_level_reset(_level_number: int) -> void:
	_state = State.COOLDOWN
	hide()
	_reset_progress()


func _on_level_cleared(_previous_level_number: int) -> void:
	_state = State.IDLE
	hide()
	_reset_progress()