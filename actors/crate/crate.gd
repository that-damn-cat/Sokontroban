class_name Crate
extends Actor

@export_category("Visuals")
@export_range(0.0, 1.0, 0.05) var bump_ratio: float = 0.25

func play_move_animation(target_tile: Vector2i, is_undo: bool = false) -> Tween:
	var tween := _new_motion_tween()
	var target_position := _game.get_global_position(target_tile)

	z_index = 1

	if not is_undo:
		SFXService.play("slide")

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		self,
		"global_position",
		target_position,
		Constants.TURN_TIME_SECONDS
	)

	tween.finished.connect(_on_motion_finished, CONNECT_ONE_SHOT)

	return tween

func play_bump_animation(direction: Vector2i) -> Tween:
	var tween := _new_motion_tween()
	var start_position := global_position
	var bump_end := start_position + Vector2(direction) * Constants.TILE_SIZE * bump_ratio

	z_index = 1

	tween.tween_interval(0.25 * Constants.TURN_TIME_SECONDS)

	_move_tween.set_trans(Tween.TRANS_ELASTIC)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(
		self,
		"global_position",
		bump_end,
		0.5 * Constants.TURN_TIME_SECONDS
	)

	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(
		self,
		"global_position",
		start_position,
		0.25 * Constants.TURN_TIME_SECONDS
	)

	tween.finished.connect(_on_motion_finished, CONNECT_ONE_SHOT)

	return tween

func _on_motion_finished() -> void:
	_move_tween.kill()
	z_index = 0
	_update_animation()

func _update_animation() -> void:
	if _game.is_goal_at_cell(tile_position):
		animation = &"on_goal"
		SFXService.play("goal")
	else:
		animation = &"default"

	if _game.is_input_at_cell(tile_position):
		frame = 1
		play()
	else:
		frame = 0
		stop()
