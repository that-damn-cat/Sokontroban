class_name UIButton
extends Button

@export var button_label: Label
@export var dim_color := Color("#757882")
@export var hilight_color := Color("#fcfcf2")

func _ready() -> void:
	focus_entered.connect(_update_label_color)
	focus_exited.connect(_update_label_color)
	mouse_entered.connect(_update_label_color)
	mouse_exited.connect(_update_label_color)
	button_down.connect(_update_label_color)
	button_up.connect(_update_label_color)

	_update_label_color()

func _update_label_color() -> void:
	if (has_focus() or is_hovered()) and not button_pressed:
		button_label.set("theme_override_colors/font_color", hilight_color)
	else:
		button_label.set("theme_override_colors/font_color", dim_color)
