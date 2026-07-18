class_name BumpActorOperation
extends TurnOperation

var _actor: Actor
var _direction: Vector2i
var _state_before: Dictionary[StringName, Variant]


func _init(actor: Actor, direction: Vector2i) -> void:
	_actor = actor
	_direction = direction
	_state_before = actor.capture_turn_state().duplicate(true)


func apply(_game: Game) -> void:
	if not is_instance_valid(_actor):
		push_error("BumpActorOperation lost its actor before apply()!")
		return

	_actor.face_direction(_direction)

func revert(_game: Game) -> void:
	if not is_instance_valid(_actor):
		push_error("BumpActorOperation lost its actor before revert()!")
		return

	_actor.restore_turn_state(_state_before)

func play_forward(_game: Game) -> Tween:
	if not is_instance_valid(_actor):
		return null

	return _actor.play_bump_animation(_direction)

func play_reverse(_game: Game) -> Tween:
	return null