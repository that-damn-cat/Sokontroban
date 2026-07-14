class_name Crate
extends Actor

@export_category("Visuals")
@export_range(0.0, 1.0, 0.05) var bump_ratio: float = 0.25

var _move_tween: Tween

func _do_turn() -> void:
	is_finished = false

	if move_intent == Vector2i.ZERO:
		await get_tree().process_frame
		is_finished = true
		_emit_turn_finished()
		return

	_setup_tween()

	z_index = 1		# Boxes that are animating should have higher z index

	if _move_ok():
		tile_position = target_tile
		SFXService.play("slide")
		_tween_move()
	else:
		_tween_bounce()

	move_intent = Vector2i.ZERO

func _setup_tween() -> void:
	if _move_tween:
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.finished.connect(_on_move_finished)

func _tween_move() -> void:
	var new_position: Vector2 = global_position + (Vector2(move_intent) * Constants.TILE_SIZE)

	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "global_position", new_position, Constants.TURN_TIME_SECONDS)

func _tween_bounce() -> void:
	var start_position = global_position
	var bump_end: Vector2 = start_position + (Vector2(move_intent) * Constants.TILE_SIZE * bump_ratio)

	_move_tween.set_trans(Tween.TRANS_ELASTIC)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", global_position, 0.25 * Constants.TURN_TIME_SECONDS)
	_move_tween.tween_property(self, "global_position", bump_end, 0.5 * Constants.TURN_TIME_SECONDS)

	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "global_position", start_position, 0.25 * Constants.TURN_TIME_SECONDS)

func _on_move_finished() -> void:
	_move_tween.finished.disconnect(_on_move_finished)
	_move_tween.kill()

	_update_animation()

	z_index = 0				# Reset z index for next turn
	is_finished = true
	_emit_turn_finished()

func _update_animation() -> void:
	if _game.is_goal_at_cell(tile_position):
		animation = &"on_goal"
	else:
		animation = &"default"

	if _game.is_input_at_cell(tile_position):
		frame = 1
		play()
	else:
		frame = 0
		stop()
