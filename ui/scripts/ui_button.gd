class_name UIButton
extends Button

@export var button_label: Label
@export var dim_color := Constants.DIM_UI_COLOR
@export var hilight_color := Constants.HIGHLIGHT_UI_COLOR


func _ready() -> void:
	if button_label == null:
		button_label = _find_button_label()

	focus_entered.connect(_update_label_color)
	focus_exited.connect(_update_label_color)
	mouse_entered.connect(_update_label_color)
	mouse_exited.connect(_update_label_color)
	button_down.connect(_update_label_color)
	button_up.connect(_update_label_color)
	_update_label_color()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		_update_label_color()


func _update_label_color() -> void:
	if not is_instance_valid(button_label):
		return

	var should_highlight := not disabled and (has_focus() or is_hovered())
	button_label.add_theme_color_override(
		&"font_color",
		hilight_color if should_highlight else dim_color
	)


func _find_button_label() -> Label:
	for child in find_children("*", "Label", true, false):
		if child is Label:
			return child as Label

	return null