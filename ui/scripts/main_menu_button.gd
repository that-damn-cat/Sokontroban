extends UIButton


func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	var controller := get_tree().get_first_node_in_group(&"main_controller")

	if controller == null or not controller.has_method(&"handle_pause_menu_return"):
		push_error("Main menu button could not find MainController.")
		return

	controller.call(&"handle_pause_menu_return")