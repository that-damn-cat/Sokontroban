class_name MoveActorOperation
extends TurnOperation

var _actor: Actor
var _from_tile: Vector2i
var _to_tile: Vector2i
var _state_before: Dictionary

func _init(actor: Actor, to_tile: Vector2i) -> void:
	_actor = actor
	_from_tile = actor.tile_position
	_to_tile = to_tile
	_state_before = actor.capture_turn_state().duplicate(true)


func apply(_game: Game) -> void:
	if not is_instance_valid(_actor):
		push_error("MoveActorOperation lost its actor before apply()!")
		return

	_actor.face_direction(_to_tile - _from_tile)
	_actor.tile_position = _to_tile


func revert(_game: Game) -> void:
	if not is_instance_valid(_actor):
		push_error("MoveActorOperation lost its actor before revert()!")
		return

	_actor.tile_position = _from_tile
	_actor.restore_turn_state(_state_before)

func play_forward(_game: Game) -> Tween:
	if not is_instance_valid(_actor):
		return null

	return _actor.play_move_animation(_to_tile, false)

func play_reverse(_game: Game) -> Tween:
	if not is_instance_valid(_actor):
		return null

	return _actor.play_move_animation(_from_tile, true)