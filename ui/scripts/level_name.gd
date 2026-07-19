extends Label

func _ready() -> void:
	LevelManager.level_cleared.connect(_on_level_cleared)
	LevelManager.level_loaded.connect(_on_level_loaded)
	_update()


func _update() -> void:
	text = str(LevelManager.current_level).pad_zeros(2) + ": " + LevelManager.get_level_title(LevelManager.current_level)


func _on_level_cleared(_previous_level_number: int) -> void:
	hide()


func _on_level_loaded(_level_number: int) -> void:
	_update()
	show()