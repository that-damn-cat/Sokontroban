class_name Player
extends Actor

enum InputState {WAITING, POLLING, MOVING}

@export_category("Camera")
@export var camera_target: Marker2D
@export var camera: Camera2D

@export_category("Visuals")
@export_range(0.0, 1.0, 0.05) var bump_ratio: float = 0.35

@export_category("Controls")
@export var input_polling_time: float = 0.06
var _poll_time_remaining = 0.0
var _input_state := InputState.WAITING

var _move_tween: Tween


func _enter_tree() -> void:
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

func _process(delta: float) -> void:
	if _game.turn_in_process:
		return

	match _input_state:
		InputState.WAITING:
			move_intent = _poll_direction()
			if move_intent == Vector2i.ZERO:
				return

			_input_state = InputState.POLLING
			_poll_time_remaining = input_polling_time

		InputState.POLLING:
			_poll_time_remaining -= delta
			move_intent = _poll_direction()
			if _poll_time_remaining <= 0.0:
				_input_state = InputState.MOVING

		InputState.MOVING:
			var target_actors := _game.get_actors_at_tile(tile_position + move_intent)

			for actor in target_actors:
				if not actor == self:
					actor.move_intent = move_intent

			_game.start_turn()

func _poll_direction() -> Vector2i:
	_game.update_allowed_inputs()

	var direction := move_intent

	if &"left" in _game.allowed_inputs and Input.is_action_pressed(&"left"):
		direction.x -= 1

	if &"right" in _game.allowed_inputs and Input.is_action_pressed(&"right"):
		direction.x += 1

	if &"up" in _game.allowed_inputs and Input.is_action_pressed(&"up"):
		direction.y -= 1

	if &"down" in _game.allowed_inputs and Input.is_action_pressed(&"down"):
		direction.y += 1

	direction.x = sign(direction.x)
	direction.y = sign(direction.y)

	return(direction)

func _do_turn() -> void:
	is_finished = false

	if move_intent.x > 0:
		flip_h = false
	elif move_intent.x < 0:
		flip_h = true

	_setup_tween()		# Tween setup ties tween complete to move_finished signal

	if _move_ok():
		tile_position = target_tile
		_tween_move()
		play("default")
	else:
		SFXService.play("bump")
		_emit_collided()
		_tween_bounce()

	move_intent = Vector2i.ZERO

func _on_move_finished() -> void:
	_move_tween.finished.disconnect(_on_move_finished)
	_move_tween.kill()
	stop()
	_input_state = InputState.WAITING
	is_finished = true
	_emit_turn_finished()

func _setup_tween() -> void:
	if _move_tween:
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.finished.connect(_on_move_finished)

func _tween_move() -> void:
	var new_position: Vector2 = global_position + (Vector2(move_intent) * Constants.TILE_SIZE)

	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.set_parallel()

	_move_tween.tween_property(self, "global_position", new_position, Constants.TURN_TIME_SECONDS)
	_move_tween.tween_property(camera_target, "global_position", new_position, Constants.TURN_TIME_SECONDS)

func _tween_bounce() -> void:
	var start_position = global_position
	var bump_end: Vector2 = start_position + (Vector2(move_intent) * Constants.TILE_SIZE * bump_ratio)

	_move_tween.set_trans(Tween.TRANS_ELASTIC)
	_move_tween.set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", bump_end, 0.4 * Constants.TURN_TIME_SECONDS)

	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "global_position", start_position, 0.6 * Constants.TURN_TIME_SECONDS)