extends UIButton


func _ready() -> void:
	super()
	SaveDataManager.progress_changed.connect(_update_label)
	SaveDataManager.score_changed.connect(_on_score_changed)
	_update_label()


func _update_label() -> void:
	if not is_instance_valid(button_label):
		return

	button_label.text = "CONTINUE" if SaveDataManager.has_progress() else "START"


func _on_score_changed(_level_number: int) -> void:
	_update_label()