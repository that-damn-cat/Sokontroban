extends UIButton


func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)
	SaveDataManager.progress_changed.connect(_update_visibility)
	_update_visibility()


func _update_visibility() -> void:
	visible = SaveDataManager.has_progress()

func _on_button_pressed() -> void:
	SFXService.play("click")
	SaveDataManager.reset_progress()