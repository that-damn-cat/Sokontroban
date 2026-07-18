extends UIButton

func _ready() -> void:
	super()

	SaveDataManager.progress_changed.connect(_update_label)
	_update_label()

func _update_label():
	if SaveDataManager.unlocked_levels.size() > 1:
		show()
	else:
		hide()