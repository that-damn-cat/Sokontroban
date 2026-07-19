class_name LevelSelectScreen
extends MenuScreen

signal level_selected(level_number: int)
signal back_requested

var _level_list: VBoxContainer
var _back_button: Button
var _first_level_button: Button


func _ready() -> void:
	build_shell("LEVEL SELECT")

	var scroll := ScrollContainer.new()
	scroll.name = &"LevelScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_container.add_child(scroll)

	_level_list = VBoxContainer.new()
	_level_list.name = &"LevelList"
	_level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_list.add_theme_constant_override(&"separation", 3)
	scroll.add_child(_level_list)

	_back_button = create_button("BACK")
	_back_button.pressed.connect(_on_back_pressed)
	footer_container.add_child(_back_button)

	SaveDataManager.progress_changed.connect(refresh)
	SaveDataManager.score_changed.connect(_on_score_changed)
	refresh()


func refresh() -> void:
	if not is_instance_valid(_level_list):
		return

	clear_container(_level_list)
	_first_level_button = null

	for level_number in LevelManager.get_level_numbers():
		if not SaveDataManager.is_level_unlocked(level_number):
			continue

		var button_text := "%02d  %s" % [
			level_number,
			LevelManager.get_level_title(level_number).to_upper(),
		]

		var button := create_button(button_text, 288.0)
		button.custom_maximum_size = Vector2(288.0, 18.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_level_button_pressed.bind(level_number))
		_level_list.add_child(button)

		if _first_level_button == null:
			_first_level_button = button

	if _first_level_button == null:
		var empty_label := create_label(
			"No levels are currently unlocked.",
			10,
			HORIZONTAL_ALIGNMENT_CENTER,
			Constants.DIM_UI_COLOR
		)
		_level_list.add_child(empty_label)


func focus_default() -> void:
	if is_instance_valid(_first_level_button):
		focus_control(_first_level_button)
	else:
		focus_control(_back_button)


func _on_level_button_pressed(level_number: int) -> void:
	SFXService.play("click")
	level_selected.emit(level_number)


func _on_score_changed(_level_number: int) -> void:
	refresh()


func _on_back_pressed() -> void:
	SFXService.play("click")
	back_requested.emit()
