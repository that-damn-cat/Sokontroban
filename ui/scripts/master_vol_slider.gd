extends VolumeSlider


func _ready() -> void:
	super()
	PauseManager.register_first_pause_focus(self)