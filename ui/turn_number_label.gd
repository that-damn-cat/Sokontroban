extends Label

func _ready() -> void:
	LevelManager.turn_updated.connect(_update)
	LevelManager.level_cleared.connect(hide)
	LevelManager.level_loaded.connect(show)

	_update()

func _update():
	text = "Turn " + str(LevelManager.turn)