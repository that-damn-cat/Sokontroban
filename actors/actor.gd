@abstract
class_name Actor
extends AnimatedSprite2D

## The actor should never mutate its own tile_position!
var tile_position: Vector2i
var _game: Game
var _move_tween: Tween

func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game") as Game
	if _game == null:
		push_error("Actor " + self.name + " could not find the Game node!")
		return

	_game.register_actor(self)
	tile_position = _game.get_level_position(global_position)


func _exit_tree() -> void:
	cancel_motion()

	if is_instance_valid(_game):
		_game.unregister_actor(self)


func capture_turn_state() -> Dictionary[StringName, Variant]:
	return {}

func restore_turn_state(_state: Dictionary[StringName, Variant]) -> void:
	pass

func face_direction(_direction: Vector2i) -> void:
	pass

func kill() -> void:
	cancel_motion()
	queue_free()

func cancel_motion() -> void:
	if is_instance_valid(_move_tween):
		_move_tween.kill()

	_move_tween = null

@abstract func play_move_animation(target_tile: Vector2i, is_undo: bool = false) -> Tween

@abstract func play_bump_animation(direction: Vector2i) -> Tween


func snap_visual_to_tile() -> void:
	if is_instance_valid(_game):
		global_position = _game.get_global_position(tile_position)

func _new_motion_tween() -> Tween:
	cancel_motion()
	_move_tween = create_tween()
	return _move_tween

## Returns the speed multiplier needed for `anim_name` to last `target_duration` seconds.
func _find_speed_mult(anim_name: StringName, target_duration: float) -> float:
	if target_duration <= 0.0 or sprite_frames == null:
		return 1.0

	if not sprite_frames.has_animation(anim_name):
		push_warning("Animation not found: %s" % anim_name)

	var anim_fps = sprite_frames.get_animation_speed(anim_name)
	if anim_fps <= 0.0:
		return 1.0

	var anim_duration: float = 0.0

	for frame_index in range(sprite_frames.get_frame_count(anim_name)):
		anim_duration += sprite_frames.get_frame_duration(anim_name, frame_index) / anim_fps

	if anim_duration <= 0.0:
		return 1.0

	return(anim_duration / target_duration)