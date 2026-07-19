class_name Game
extends Node

signal turn_started
signal turn_finished
signal undo_started
signal undo_finished
signal redo_started
signal redo_finished
signal history_changed(can_undo: bool, can_redo: bool)
signal level_completed(level_number: int, score: int)

enum PlaybackKind {
	NONE,
	NEW_TURN,
	UNDO,
	REDO,
}

@export var level: Level
@export var turn_cooldown_seconds: float = Constants.TURN_COOLDOWN_SECONDS
@export var max_history_steps: int = 250

var gameplay_enabled: bool = false
var turn_in_process: bool = false
var player: Player
var actors: Array[Actor] = []
var allowed_inputs: Array[StringName] = []

var _history: UndoRedo = UndoRedo.new()
var _playback_kind := PlaybackKind.NONE
var _playback_generation: int = 0
var _level_complete: bool = false
var _undo_held: bool = false
var _undo_repeat_remaining: float = 0.0

func _ready() -> void:
	_history.max_steps = max_history_steps
	set_level(level)
	LevelManager.set_game(self)
	update_allowed_inputs()

func _exit_tree() -> void:
	if is_instance_valid(_history):
		_history.clear_history(false)
		_history.free()

func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_enabled or _level_complete:
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(&"undo"):
		_start_undo_hold()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"undo"):
		_stop_undo_hold()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not gameplay_enabled or _level_complete:
		_stop_undo_hold()
		return

	if not _undo_held:
		return

	if not Input.is_action_pressed(&"undo"):
		_stop_undo_hold()
		return

	_undo_repeat_remaining -= delta

	if _undo_repeat_remaining <= 0.0:
		_undo_repeat_remaining += Constants.UNDO_REPEAT_INTERVAL
		undo_turn()

func set_level(new_level: Level) -> void:
	level = new_level

	if not is_instance_valid(level):
		return

	if not level.level_complete.is_connected(_on_level_complete):
		level.level_complete.connect(_on_level_complete)

func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled

	if not enabled:
		_reset_allowed_inputs()
		if is_instance_valid(player):
			player.reset_input_buffer()
		if is_instance_valid(level):
			level.clear_input_feedback()
	else:
		update_allowed_inputs()

func set_player(new_player: Player) -> void:
	player = new_player
	register_actor(new_player)

func register_actor(actor: Actor) -> void:
	if actor == null:
		return

	if actor not in actors:
		actors.append(actor)

	if actor is Player:
		player = actor as Player

func unregister_actor(actor: Actor) -> void:
	actors.erase(actor)

	if player == actor:
		player = null

func remove_actor(actor: Actor) -> void:
	if actor == null:
		return

	detach_actor(actor)

	if is_instance_valid(actor):
		actor.kill()

func remove_all_actors() -> void:
	for actor in actors.duplicate():
		remove_actor(actor)

	actors.clear()
	player = null

## Operations can detach an actor without freeing it for undo/redo
func detach_actor(actor: Actor) -> void:
	if actor == null:
		return

	unregister_actor(actor)

	var parent := actor.get_parent()
	if parent != null:
		parent.remove_child(actor)

## Attaches a previously detached actor. No new _ready() call for the actor
func attach_actor(actor: Actor, parent: Node, child_index: int = -1) -> void:
	if actor == null or parent == null:
		push_error("attach_actor() requires a valid actor and parent node")
		return

	if actor.get_parent() != null:
		push_error("attach_actor() received an actor that already has a parent!")
		return

	parent.add_child(actor)

	if child_index >= 0 and child_index < parent.get_child_count():
		parent.move_child(actor, child_index)

	register_actor(actor)
	actor.snap_visual_to_tile()

func get_actors_at_tile(tile: Vector2i) -> Array[Actor]:
	var result: Array[Actor] = []

	for actor in actors:
		if is_instance_valid(actor) and actor.tile_position == tile:
			result.append(actor)

	return result

func get_level_position(world_position: Vector2) -> Vector2i:
	if not is_instance_valid(level):
		return Vector2i.ZERO

	return level.get_tilemap_position(world_position)

func get_global_position(tile: Vector2i) -> Vector2:
	if not is_instance_valid(level):
		return Vector2.ZERO

	return level.to_global(level.map_to_local(tile))

func is_tile_walkable(tile: Vector2i) -> bool:
	if not is_instance_valid(level) or not level.is_tile_walkable(tile):
		return false

	return get_actors_at_tile(tile).is_empty()

func is_goal_at_cell(tile: Vector2i) -> bool:
	if not is_instance_valid(level):
		return false

	return tile in level.goal_tiles

func is_input_at_cell(tile: Vector2i) -> bool:
	if not is_instance_valid(level):
		return false

	return tile in level.input_tiles

func is_input_allowed(input_name: StringName) -> bool:
	if not is_instance_valid(level):
		return false

	return not level.is_input_blocked(input_name)

func update_allowed_inputs() -> void:
	allowed_inputs.clear()

	if not is_instance_valid(level):
		return

	for input_name in Constants.INPUT_LIST:
		if is_input_allowed(input_name):
			allowed_inputs.append(input_name)

## Creates one UndoRedo action for one accepted player input. commit_action()
## invokes the registered forward callback.
func start_turn(direction: Vector2i) -> void:
	if (
		not gameplay_enabled
		or turn_in_process
		or direction == Vector2i.ZERO
		or not is_instance_valid(player)
		or not is_instance_valid(level)
		or _level_complete
		or not _is_direction_allowed(direction)
	):
		return

	var action := _build_player_turn(direction)
	if action.is_empty():
		return

	level.update_last_direction(direction)
	_begin_playback(PlaybackKind.NEW_TURN)
	turn_started.emit()

	_history.create_action(action.action_name, UndoRedo.MERGE_DISABLE)
	_history.add_do_method(_play_history_action.bind(action, false))
	_history.add_undo_method(_play_history_action.bind(action, true))
	action.register_history_references(_history)
	_history.commit_action()
	_emit_history_changed()

func undo_turn() -> void:
	if (
		not gameplay_enabled
		or _level_complete
		or turn_in_process
		or not _history.has_undo()
		or not is_input_allowed(&"undo")
	):
		return

	_begin_playback(PlaybackKind.UNDO)
	undo_started.emit()

	if not _history.undo():
		_abort_playback()
		return

	_emit_history_changed()

func redo_turn() -> void:
	if (
		not gameplay_enabled
		or _level_complete
		or turn_in_process
		or not _history.has_redo()
	):
		return

	_begin_playback(PlaybackKind.REDO)
	redo_started.emit()

	if not _history.redo():
		_abort_playback()
		return

	_emit_history_changed()

func can_undo() -> bool:
	return _history.has_undo()

func can_redo() -> bool:
	return _history.has_redo()

func get_undo_action_name() -> String:
	if not _history.has_undo():
		return ""

	return _history.get_current_action_name()

func get_redo_action_name() -> String:
	if not _history.has_redo():
		return ""

	var redo_index := _history.get_current_action() + 1
	return _history.get_action_name(redo_index)

func clear_turn_history() -> void:
	_history.clear_history()
	_emit_history_changed()

func prepare_for_level_change() -> void:
	_playback_generation += 1
	turn_in_process = false
	_playback_kind = PlaybackKind.NONE
	_level_complete = false

	for actor in actors:
		if is_instance_valid(actor):
			actor.cancel_motion()

	clear_turn_history()
	_reset_allowed_inputs()


func _build_player_turn(direction: Vector2i) -> TurnAction:
	var direction_name := _direction_name(direction)
	var player_target := player.tile_position + direction

	if not level.is_tile_walkable(player_target):
		var wall_bump := TurnAction.new("Bump %s" % direction_name)
		wall_bump.add_operation(BumpActorOperation.new(player, direction))
		return wall_bump

	var target_actors := get_actors_at_tile(player_target)
	target_actors.erase(player)

	if target_actors.is_empty():
		var move := TurnAction.new("Move %s" % direction_name)
		move.add_operation(MoveActorOperation.new(player, player_target))
		return move

	if target_actors.size() == 1 and target_actors[0] is Crate:
		var crate := target_actors[0] as Crate
		var crate_target := crate.tile_position + direction

		if is_tile_walkable(crate_target):
			var push := TurnAction.new("Push %s" % direction_name)
			push.add_operation(MoveActorOperation.new(crate, crate_target))
			push.add_operation(MoveActorOperation.new(player, player_target))
			return push

		var blocked_push := TurnAction.new("Blocked push %s" % direction_name)
		blocked_push.add_operation(BumpActorOperation.new(crate, direction))
		blocked_push.add_operation(BumpActorOperation.new(player, direction))
		return blocked_push

	# Fallback, if no interaction defined, block the player
	var actor_bump := TurnAction.new("Bump Actor %s" % direction_name)
	actor_bump.add_operation(BumpActorOperation.new(player, direction))
	return actor_bump

## UndoRedo calls this method, but cannot do awaits, so TurnAction handles Tweens
func _play_history_action(action: TurnAction, is_undo: bool) -> void:
	var generation := _playback_generation
	action.playback_finished.connect(_on_action_playback_finished.bind(generation),	CONNECT_ONE_SHOT)
	action.play(self, is_undo)

func _on_action_playback_finished(_is_undo: bool, generation: int) -> void:
	if generation != _playback_generation:
		return

	var completed_kind := _playback_kind

	if turn_cooldown_seconds > 0.0:
		await get_tree().create_timer(turn_cooldown_seconds, false).timeout

	if generation != _playback_generation:
		return

	_playback_kind = PlaybackKind.NONE
	turn_in_process = false

	match completed_kind:
		PlaybackKind.NEW_TURN:
			turn_finished.emit()
		PlaybackKind.UNDO:
			undo_finished.emit()
		PlaybackKind.REDO:
			redo_finished.emit()

	if gameplay_enabled:
		update_allowed_inputs()
	else:
		_reset_allowed_inputs()

func _begin_playback(kind: PlaybackKind) -> void:
	_playback_generation += 1
	turn_in_process = true
	_playback_kind = kind

func _abort_playback() -> void:
	_playback_kind = PlaybackKind.NONE
	turn_in_process = false

func _emit_history_changed() -> void:
	history_changed.emit(_history.has_undo(), _history.has_redo())

func _is_direction_allowed(direction: Vector2i) -> bool:
	if direction.x < 0 and not is_input_allowed(&"left"):
		return false
	if direction.x > 0 and not is_input_allowed(&"right"):
		return false
	if direction.y < 0 and not is_input_allowed(&"up"):
		return false
	if direction.y > 0 and not is_input_allowed(&"down"):
		return false

	return true

func _direction_name(direction: Vector2i) -> String:
	var parts: Array[String] = []

	if direction.y < 0:
		parts.append("up")
	elif direction.y > 0:
		parts.append("down")

	if direction.x < 0:
		parts.append("left")
	elif direction.x > 0:
		parts.append("right")

	if parts.is_empty():
		return "neutral"

	return "-".join(PackedStringArray(parts))

func _on_level_complete() -> void:
	if _level_complete or not is_instance_valid(level):
		return

	_level_complete = true
	SFXService.stop(&"goal")
	SFXService.play(&"level_win")

	var level_number := level.level_number
	var score := LevelManager.turn
	SaveDataManager.update_score(level_number, score)
	level_completed.emit(level_number, score)

func _reset_allowed_inputs() -> void:
	allowed_inputs.clear()

func _start_undo_hold() -> void:
	if _undo_held:
		return

	_undo_held = true
	_undo_repeat_remaining = Constants.UNDO_REPEAT_DELAY
	undo_turn()

func _stop_undo_hold() -> void:
	_undo_held = false
	_undo_repeat_remaining = 0.0