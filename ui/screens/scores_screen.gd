class_name ScoresScreen
extends MenuScreen

signal back_requested

var _score_list: VBoxContainer
var _back_button: Button


func _ready() -> void:
	build_shell("HI SCORES")

	var scroll := ScrollContainer.new()
	scroll.name = &"ScoreScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_container.add_child(scroll)

	_score_list = VBoxContainer.new()
	_score_list.name = &"ScoreList"
	_score_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_list.add_theme_constant_override(&"separation", 2)
	scroll.add_child(_score_list)

	_back_button = create_button("BACK")
	_back_button.pressed.connect(_on_back_pressed)
	footer_container.add_child(_back_button)

	SaveDataManager.progress_changed.connect(refresh)
	SaveDataManager.score_changed.connect(_on_score_changed)
	refresh()


func refresh() -> void:
	if not is_instance_valid(_score_list):
		return

	clear_container(_score_list)

	for level_number in LevelManager.get_level_numbers():
		if not SaveDataManager.is_level_unlocked(level_number):
			continue

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_score_list.add_child(row)

		var title := create_label(
			"%02d  %s" % [level_number, LevelManager.get_level_title(level_number)],
			10,
			HORIZONTAL_ALIGNMENT_LEFT,
			Constants.HIGHLIGHT_UI_COLOR
		)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.offset_transform_enabled = true
		title.offset_transform_position = Vector2(2.0, 5.0)
		row.add_child(title)

		var score := SaveDataManager.get_high_score(level_number)
		var score_text := "NOT COMPLETED" if score < 0 else "%d TURNS" % score
		var score_label := create_label(score_text, 10, HORIZONTAL_ALIGNMENT_RIGHT,
			Constants.DIM_UI_COLOR if score < 0 else Constants.HIGHLIGHT_UI_COLOR
		)
		score_label.offset_transform_enabled = true
		score_label.offset_transform_position = Vector2(2.0, 5.0)
		row.add_child(score_label)

	if _score_list.get_child_count() == 0:
		var empty_label := create_label(
			"No levels are currently unlocked.",
			10,
			HORIZONTAL_ALIGNMENT_CENTER,
			Constants.DIM_UI_COLOR
		)
		_score_list.add_child(empty_label)


func focus_default() -> void:
	focus_control(_back_button)


func _on_score_changed(_level_number: int) -> void:
	refresh()


func _on_back_pressed() -> void:
	SFXService.play("click")
	back_requested.emit()
