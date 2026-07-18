class_name MenuScreen
extends Control

const PANEL_STYLE: StyleBox = preload("res://resources/menu_panel_style.tres")
const BUTTON_NORMAL_STYLE: StyleBox = preload("res://resources/button_normal_stylebox.tres")
const BUTTON_HIGHLIGHT_STYLE: StyleBox = preload("res://resources/button_hilight_stylebox.tres")
const TITLE_FONT: Font = preload("res://assets/fonts/Everyday_Typical_Bold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Everyday_Slight_Original.ttf")

var content_container: VBoxContainer
var footer_container: HBoxContainer
var title_label: Label


func build_shell(title_text: String, subtitle_text: String = "") -> void:
	if get_child_count() > 0:
		return

	var margin := MarginContainer.new()
	margin.name = &"ScreenMargin"
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 12)

	var panel := PanelContainer.new()
	panel.name = &"Panel"
	panel.add_theme_stylebox_override(&"panel", PANEL_STYLE)
	margin.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = &"RootVBox"
	root_vbox.add_theme_constant_override(&"separation", 6)
	panel.add_child(root_vbox)

	title_label = create_label(title_text, 15, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.name = &"Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(title_label)

	if not subtitle_text.is_empty():
		var subtitle := create_label(
			subtitle_text,
			8,
			HORIZONTAL_ALIGNMENT_CENTER,
			Constants.DIM_UI_COLOR
		)
		subtitle.name = &"Subtitle"
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(subtitle)

	content_container = VBoxContainer.new()
	content_container.name = &"Content"
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override(&"separation", 3)
	root_vbox.add_child(content_container)

	footer_container = HBoxContainer.new()
	footer_container.name = &"Footer"
	footer_container.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_container.add_theme_constant_override(&"separation", 12)
	root_vbox.add_child(footer_container)


func create_button(button_text: String, minimum_width: float = 96.0) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(minimum_width, 16.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override(&"font", TITLE_FONT)
	button.add_theme_font_size_override(&"font_size", 10)
	button.add_theme_color_override(&"font_color", Constants.DIM_UI_COLOR)
	button.add_theme_color_override(&"font_hover_color", Constants.HIGHLIGHT_UI_COLOR)
	button.add_theme_color_override(&"font_focus_color", Constants.HIGHLIGHT_UI_COLOR)
	button.add_theme_color_override(&"font_pressed_color", Constants.HIGHLIGHT_UI_COLOR)
	button.add_theme_stylebox_override(&"normal", BUTTON_NORMAL_STYLE)
	button.add_theme_stylebox_override(&"pressed", BUTTON_NORMAL_STYLE)
	button.add_theme_stylebox_override(&"disabled", BUTTON_NORMAL_STYLE)
	button.add_theme_stylebox_override(&"hover", BUTTON_HIGHLIGHT_STYLE)
	button.add_theme_stylebox_override(&"focus", BUTTON_HIGHLIGHT_STYLE)
	return button


func create_label(
	label_text: String,
	font_size: int = 10,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	font_color: Color = Constants.HIGHLIGHT_UI_COLOR
) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = alignment
	label.add_theme_font_override(&"font", BODY_FONT)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", font_color)
	return label


func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()


func focus_control(control: Control) -> void:
	if is_instance_valid(control) and control.visible and not control.is_queued_for_deletion():
		control.call_deferred(&"grab_focus")
