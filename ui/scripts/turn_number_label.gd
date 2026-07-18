extends Label


func _ready() -> void:
	LevelManager.turn_updated.connect(_update)
	LevelManager.level_cleared.connect(_on_level_cleared)
	LevelManager.level_loaded.connect(_on_level_loaded)
	_update(LevelManager.turn)


func _update(new_turn: int) -> void:
	text = "Turn %d" % new_turn


func _on_level_cleared(_previous_level_number: int) -> void:
	hide()


func _on_level_loaded(_level_number: int) -> void:
	show()