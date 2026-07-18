extends UIButton


func _ready() -> void:
	super()
	SaveDataManager.progress_changed.connect(_update_visibility)
	_update_visibility()


func _update_visibility() -> void:
	visible = SaveDataManager.has_won