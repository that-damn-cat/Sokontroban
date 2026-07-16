extends Label

var _held_time: float = 0.0
var _recent_reset: bool = false
var _is_held: bool = false

var max_dots: int = 3
var dot_timing: Array[float]
var num_dots: int = 0

func _ready() -> void:
	LevelManager.level_reset.connect(_on_level_reset)

	for i in range(max_dots):
		dot_timing.append(((float(i) + 1) * Constants.RESET_HOLD_TIME) / (float(max_dots) + 1.0))

	dot_timing.append(Constants.RESET_HOLD_TIME)

func _input(event: InputEvent) -> void:
	if event.is_action_released(&"reset"):
		_recent_reset = false
		_is_held = false
		reset_state()

	if event.is_action_pressed(&"reset"):
		show()
		_is_held = true


func _process(delta: float) -> void:
	if not _is_held or _recent_reset:
		return


	print(dot_timing)
	_held_time += delta

	if _held_time >= dot_timing[num_dots]:
		text += "."
		num_dots += 1

func reset_state() -> void:
	hide()
	text = "Resetting"
	_held_time = 0.0
	num_dots = 0

func _on_level_reset() -> void:
	_recent_reset = true
	reset_state()
