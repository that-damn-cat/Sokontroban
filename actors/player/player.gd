class_name Player
extends Actor

const STATE_FLIP_H: StringName = &"flip_h"

enum InputState {
	WAITING,
	POLLING,
	MOVING,
}

@export_category("Camera")
@export var camera_target: Marker2D
@export var camera: Camera2D

@export_category("Visuals")
@export_range(0.0, 1.0, 0.05) var bump_ratio: float = 0.35

@export_category("Controls")
@export var input_polling_time: float = 0.06

var _poll_time_remaining := 0.0
var _input_state := InputState.WAITING
var _input_direction := Vector2i.ZERO


func _enter_tree() -> void:
	_game = get_tree().get_first_node_in_group("game") as Game

	if not is_instance_valid(_game) or not is_instance_valid(_game.level):
		push_error("Player entered tree without Game/Level!")
		return

	if _game.level.has_level_camera():
		if is_instance_valid(camera):
			camera.free()
		return

	# Setup camera before it enters the tree to avoid visual glitch
	if camera == null or camera_target == null:
		push_error("Player Camera Missing!")
		return

	camera_target.global_position = global_position
	camera.position_smoothing_enabled = false
	camera.global_position = global_position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = Constants.TILE_SIZE

func _ready() -> void:
	super()

	if not is_instance_valid(_game):
		return

	_game.set_player(self)
	_game.turn_finished.connect(_on_turn_ended)
	_game.undo_finished.connect(_on_turn_ended)
	_game.redo_finished.connect(_on_turn_ended)

func _process(delta: float) -> void:
	if (
		not is_instance_valid(_game)
		or not _game.gameplay_enabled
		or _game.turn_in_process
	):
		_reset_input_polling()
		return

	match _input_state:
		InputState.WAITING:
			_input_direction = _poll_direction()
			if _input_direction == Vector2i.ZERO:
				return

			_input_state = InputState.POLLING
			_poll_time_remaining = input_polling_time

		InputState.POLLING:
			_poll_time_remaining -= delta
			_input_direction = _poll_direction()
			if _poll_time_remaining <= 0.0:
				_input_state = InputState.MOVING

		InputState.MOVING:
			var requested_direction := _input_direction
			_reset_input_polling()

			if requested_direction != Vector2i.ZERO:
				_game.start_turn(requested_direction)


func reset_input_buffer() -> void:
	_reset_input_polling()

func capture_turn_state() -> Dictionary[StringName, Variant]:
	return {STATE_FLIP_H: flip_h}

func restore_turn_state(state: Dictionary[StringName, Variant]) -> void:
	flip_h = bool(state.get(STATE_FLIP_H, flip_h))

func face_direction(direction: Vector2i) -> void:
	if direction.x > 0:
		flip_h = false
	elif direction.x < 0:
		flip_h = true

func play_move_animation(target_tile: Vector2i, _is_undo: bool = false) -> Tween:
	var tween := _new_motion_tween()
	var target_position := _game.get_global_position(target_tile)

	play(&"default")
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel()

	tween.tween_property(
		self,
		"global_position",
		target_position,
		Constants.TURN_TIME_SECONDS
	)

	if is_instance_valid(camera_target):
		tween.tween_property(
			camera_target,
			"global_position",
			target_position,
			Constants.TURN_TIME_SECONDS
		)

	tween.finished.connect(_on_motion_finished, CONNECT_ONE_SHOT)
	return tween

func play_bump_animation(direction: Vector2i) -> Tween:
	var tween := _new_motion_tween()
	var start_position := global_position
	var bump_end := (start_position	+ Vector2(direction) * Constants.TILE_SIZE * bump_ratio)

	SFXService.play(&"bump")

	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"global_position",
		bump_end,
		0.4 * Constants.TURN_TIME_SECONDS
	)

	tween.tween_property(
		self,
		"global_position",
		start_position,
		0.6 * Constants.TURN_TIME_SECONDS
	)

	tween.finished.connect(_on_motion_finished, CONNECT_ONE_SHOT)
	return tween

func _poll_direction() -> Vector2i:
	var direction := Vector2i.ZERO

	if _game.is_input_allowed(&"left") and Input.is_action_pressed(&"left"):
		direction.x -= 1

	if _game.is_input_allowed(&"right") and Input.is_action_pressed(&"right"):
		direction.x += 1

	if _game.is_input_allowed(&"up") and Input.is_action_pressed(&"up"):
		direction.y -= 1

	if _game.is_input_allowed(&"down") and Input.is_action_pressed(&"down"):
		direction.y += 1

	#if (
	#	Input.is_action_pressed(&"up_left")
	#	and _is_direction_input_allowed(Vector2i(-1, -1))
	#):
	#	direction += Vector2i(-1, -1)
	#if (
	#	Input.is_action_pressed(&"up_right")
	#	and _is_direction_input_allowed(Vector2i(1, -1))
	#):
	#	direction += Vector2i(1, -1)
	#if (
	#	Input.is_action_pressed(&"down_left")
	#	and _is_direction_input_allowed(Vector2i(-1, 1))
	#):
	#	direction += Vector2i(-1, 1)
	#if (
	#	Input.is_action_pressed(&"down_right")
	#	and _is_direction_input_allowed(Vector2i(1, 1))
	#):
	#	direction += Vector2i(1, 1)

	direction.x = signi(direction.x)
	direction.y = signi(direction.y)
	return direction

func _is_direction_input_allowed(direction: Vector2i) -> bool:
	if direction.x < 0 and not _game.is_input_allowed(&"left"):
		return false
	if direction.x > 0 and not _game.is_input_allowed(&"right"):
		return false
	if direction.y < 0 and not _game.is_input_allowed(&"up"):
		return false
	if direction.y > 0 and not _game.is_input_allowed(&"down"):
		return false

	return true

func _on_motion_finished() -> void:
	_move_tween = null
	stop()

func _on_turn_ended() -> void:
	_reset_input_polling()

func _reset_input_polling() -> void:
	_input_direction = Vector2i.ZERO
	_input_state = InputState.WAITING
	_poll_time_remaining = 0.0