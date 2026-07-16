extends Label

enum State { IDLE, HOLDING, COOLDOWN }

var _state: State = State.IDLE
var _held_time: float = 0.0
var _num_dots: int = 0

var dot_timing: Array[float] = []

func _ready() -> void:
	LevelManager.level_reset.connect(_on_level_reset)
	_build_dot_timing()

func _build_dot_timing() -> void:
	var max_dots: int = 3
	var steps := max_dots + 1

	dot_timing.clear()

	for i in range(1, steps + 1):
		dot_timing.append((float(i) * Constants.RESET_HOLD_TIME) / float(steps))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset"):
		show()
		_state = State.HOLDING
		_reset_progress()

	elif event.is_action_released(&"reset"):
		hide()
		_state = State.IDLE
		_reset_progress()

func _process(delta: float) -> void:
	if _state != State.HOLDING:
		return

	_held_time += delta

	if _num_dots < dot_timing.size() and _held_time >= dot_timing[_num_dots]:
		text += "."
		_num_dots += 1

func _reset_progress() -> void:
	text = "Resetting"
	_held_time = 0.0
	_num_dots = 0

func _on_level_reset() -> void:
	_state = State.COOLDOWN
	hide()
	_reset_progress()
