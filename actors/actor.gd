@abstract
class_name Actor
extends AnimatedSprite2D

signal turn_finished(actor: Actor)
signal collided(collided_tile: Vector2i)

var move_intent := Vector2i.ZERO
var tile_position: Vector2i
var target_tile: Vector2i:
	get:
		return move_intent + tile_position

var is_finished: bool

var _game: Game


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	_game.add_actor(self)
	_game.turn_started.connect(_do_turn)

	tile_position = _game.get_level_position(global_position)


## _do_turn MUST result in _emit_turn_finished() being called!
@abstract func _do_turn() -> void

func kill() -> void:
	queue_free()


## Returns the speed multiplier needed for the
## animation `anim_name` to last `target_duration` seconds.
func _find_speed_mult(anim_name: StringName, target_duration: float) -> float:
	return(_get_anim_duration(anim_name) / target_duration)

func _get_anim_duration(anim_name: StringName) -> float:
	var anim_fps = sprite_frames.get_animation_speed(anim_name)

	var total: float = 0.0
	for i in range(sprite_frames.get_frame_count(anim_name)):
		var frame_duration: float = sprite_frames.get_frame_duration(anim_name, i)
		total += frame_duration / anim_fps

	return(total)

func _move_ok() -> bool:
	if move_intent == Vector2i.ZERO:
		return true

	return _game.is_tile_walkable(target_tile)

func _emit_turn_finished() -> void:
	turn_finished.emit(self)

func _emit_collided() -> void:
	collided.emit(target_tile)