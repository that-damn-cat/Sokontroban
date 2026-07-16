extends Label

@export var dot_time: float = 0.33
var time_remaining = dot_time

func _ready() -> void:
	LevelManager.level_cleared.connect(show)
	LevelManager.level_loaded.connect(hide)

func _process(delta: float) -> void:
	if not visible:
		text = "Loading"
		time_remaining = dot_time
		return

	time_remaining -= delta

	if time_remaining <= 0:
		text += "."
		time_remaining = dot_time