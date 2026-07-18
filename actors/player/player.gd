class_name Player
extends Actor

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
	if _game.level._has_camera:
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
	_game.set_player(self)

	_game.turn_finished.connect(_on_turn_ended)
	_game.undo_finished.connect(_on_turn_ended)
	_game.redo_finished.connect(_on_turn_ended)

func _process(delta: float) -> void:
	if _game == null or _game.turn_in_process:
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
			_input_direction = Vector2i.ZERO

			if requested_direction == Vector2i.ZERO:
				_input_state = InputState.WAITING
				return

			_game.start_turn(requested_direction)

func _poll_direction() -> Vector2i:
	_game.update_allowed_inputs()

	var direction := _input_direction

	if &"left" in _game.allowed_inputs and (
		Input.is_action_pressed(&"left")
	):
		direction.x -= 1

	if &"right" in _game.allowed_inputs and (
		Input.is_action_pressed(&"right")
	):
		direction.x += 1

	if &"up" in _game.allowed_inputs and (
		Input.is_action_pressed(&"up")
	):
		direction.y -= 1

	if &"down" in _game.allowed_inputs and (
		Input.is_action_pressed(&"down")
	):
		direction.y += 1

	direction.x = sign(direction.x)
	direction.y = sign(direction.y)

	return(direction)

func capture_turn_state() -> Dictionary[StringName, Variant]:
	return {&"flip_h": flip_h}

func restore_turn_state(state: Dictionary[StringName, Variant]) -> void:
	flip_h = state.get(&"flip_h", flip_h)

func face_direction(direction: Vector2i) -> void:
	if direction.x > 0:
		flip_h = false
	elif direction.x < 0:
		flip_h = true

func play_move_animation(target_tile: Vector2i, _is_undo: bool = false) -> Tween:
	var tween := _new_motion_tween()
	var target_position = _game.get_global_position(target_tile)

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
	var bump_end := start_position + Vector2(direction) * Constants.TILE_SIZE * bump_ratio

	SFXService.play("bump")

	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"global_position",
		bump_end,
		0.4 * Constants.TURN_TIME_SECONDS
	)

	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"global_position",
		start_position,
		0.6 * Constants.TURN_TIME_SECONDS
	)

	tween.finished.connect(_on_motion_finished, CONNECT_ONE_SHOT)

	return tween

func _on_motion_finished() -> void:
	_move_tween = null
	stop()

func _on_turn_ended() -> void:
	_input_direction = Vector2i.ZERO
	_input_state = InputState.WAITING
