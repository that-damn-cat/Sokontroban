extends UIButton


func _ready() -> void:
	super()
	if OS.has_feature("web"):
		hide()
	else:
		show()