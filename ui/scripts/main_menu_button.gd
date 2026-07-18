extends UIButton

func _ready() -> void:
	super()

	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	PauseManager.unpause()
	LevelManager.quit_level()
