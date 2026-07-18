class_name Game
extends Node

signal turn_started
signal turn_finished
signal undo_started
signal undo_finished
signal redo_started
signal redo_finished
signal history_changed(can_undo: bool, can_redo: bool)

enum PlaybackKind {
	NONE,
	NEW_TURN,
	UNDO,
	REDO,
}

@export var level: Level
@export var turn_cooldown_seconds: float = 0.05
@export var max_history_steps: int = 250
@export_range(0, 50) var starting_level: int = 0

var turn_in_process: bool = false
var player: Player
var actors: Array[Actor] = []

var _history: UndoRedo = UndoRedo.new()
var _playback_kind := PlaybackKind.NONE
var _level_complete: bool = false

var _input_list: Array[StringName] = [
	&"up",
	&"down",
	&"left",
	&"right",
	&"reset",
	&"undo",
]

var allowed_inputs: Array[StringName] = [
	&"up",
	&"down",
	&"left",
	&"right",
	&"reset",
	&"undo",
]

func _ready() -> void:
	LevelManager.set_game(self)
	LevelManager.levels_exhausted.connect(_on_levels_exhausted)
	LevelManager.current_level = starting_level - 1
	LevelManager.load_next_level(false)
	await LevelManager.level_loaded

	_history.max_steps = max_history_steps

func _exit_tree() -> void:
	if is_instance_valid(_history):
		_history.clear_history(false)
		_history.free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(&"undo"):
		undo_turn()
		get_viewport().set_input_as_handled()
		return


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
	for actor in actors:
		remove_actor(actor)

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
	return level.get_tilemap_position(world_position)

func get_global_position(tile: Vector2i) -> Vector2:
	return level.to_global(level.map_to_local(tile))

func is_tile_walkable(tile: Vector2i) -> bool:
	if not level.is_tile_walkable(tile):
		return false

	return get_actors_at_tile(tile).is_empty()

func is_goal_at_cell(tile: Vector2i) -> bool:
	return tile in level.goal_tiles

func is_input_at_cell(tile: Vector2i) -> bool:
	return tile in level.input_tiles

## Creates one UndoRedo action for one accepted player input. commit_action()
## invokes the registered forward callback.
func start_turn(direction: Vector2i) -> void:
	if turn_in_process or direction == Vector2i.ZERO or player == null or _level_complete:
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
	if turn_in_process or not _history.has_undo():
		return

	_begin_playback(PlaybackKind.UNDO)
	undo_started.emit()

	if not _history.undo():
		_abort_playback()
		return

	_emit_history_changed()

func redo_turn() -> void:
	if turn_in_process or not _history.has_redo():
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
	if turn_in_process:
		return

	_history.clear_history()
	_emit_history_changed()

func update_allowed_inputs():
	allowed_inputs = []

	for input_name in _input_list:
		if not level.is_input_blocked(input_name):
			allowed_inputs.append(input_name)


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
	action.playback_finished.connect(_on_action_playback_finished.bind(action), CONNECT_ONE_SHOT)
	action.play(self, is_undo)

func _on_action_playback_finished(_is_undo: bool, _action: TurnAction) -> void:
	var completed_kind := _playback_kind

	if turn_cooldown_seconds > 0.0:
		await get_tree().create_timer(turn_cooldown_seconds).timeout

	_playback_kind = PlaybackKind.NONE
	turn_in_process = false

	match completed_kind:
		PlaybackKind.NEW_TURN:
			turn_finished.emit()
		PlaybackKind.UNDO:
			undo_finished.emit()
		PlaybackKind.REDO:
			redo_finished.emit()

	if _level_complete:
		await get_tree().create_timer(1.5).timeout
		SFXService.stop_all()
		LevelManager.load_next_level()
		_level_complete = false

func _begin_playback(kind: PlaybackKind) -> void:
	turn_in_process = true
	_playback_kind = kind

func _abort_playback() -> void:
	_playback_kind = PlaybackKind.NONE
	turn_in_process = false

func _emit_history_changed() -> void:
	history_changed.emit(_history.has_undo(), _history.has_redo())

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

	var result := ""
	for part in parts:
		if not result.is_empty():
			result += "-"
		result += part

	return result

func _on_level_complete() -> void:
	SFXService.stop("goal")
	SFXService.play("level_win")
	SaveDataManager.update_score(level.level_number, LevelManager.turn)
	_level_complete = true

func _on_levels_exhausted() -> void:
	SaveDataManager.set_victory()
	get_tree().quit()
