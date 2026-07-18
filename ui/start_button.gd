extends UIButton

func _ready() -> void:
	super()

	SaveDataManager.progress_changed.connect(_update_label)
	_update_label()

func _update_label():
	if SaveDataManager.unlocked_levels.has(2):
		button_label.text = "Continue"
