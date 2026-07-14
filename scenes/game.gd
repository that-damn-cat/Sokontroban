class_name Game
extends Node

signal turn_started
signal turn_finished

@export var level: Level
@export var turn_cooldown_seconds: float = 0.05
var _turn_time_remaining: float = 0.0

var turn_in_process: bool = false
var player: Player
var actors: Array[Actor]

var _input_list: Array[StringName] = [&"up", &"down", &"left", &"right", &"reset"]
var allowed_inputs := _input_list

func _ready() -> void:
	level.level_complete.connect(_on_level_complete)

func _process(_delta: float) -> void:
	if not turn_in_process:
		return

	if _get_actors_finished() >= actors.size():
		end_turn()

func set_player(new_player: Player) -> void:
	player = new_player

	if player not in actors:
		add_actor(player)

func add_actor(actor: Actor) -> void:
	actors.push_back(actor)

func remove_actor(actor: Actor) -> void:
	actors.erase(actor)

	if player == actor:
		print("Ope!")

	actor.kill()

func get_actors_at_tile(tile_position: Vector2i) -> Array[Actor]:
	var result: Array[Actor]
	for actor in actors:
		if actor.tile_position == tile_position:
			result.push_back(actor)

	return result

func get_level_position(global_position: Vector2) -> Vector2i:
	return level.get_tilemap_position(global_position)

func is_tile_walkable(tile_position: Vector2i) -> bool:
	if not level.is_tile_walkable(tile_position):
		return false

	for actor in actors:
		if tile_position == actor.tile_position:
			return false

	return true

func is_goal_at_cell(tile_position: Vector2i) -> bool:
	if tile_position in level.goal_tiles:
		return true

	return false

func is_input_at_cell(tile_position: Vector2i) -> bool:
	if tile_position in level.input_tiles.keys():
		return true

	return false

func start_turn() -> void:
	if turn_in_process:
		return

	turn_in_process = true
	_turn_time_remaining = Constants.TURN_TIME_SECONDS + turn_cooldown_seconds
	turn_started.emit()

func update_allowed_inputs():
	allowed_inputs = []
	for input in _input_list:
		if not level.is_input_blocked(input):
			allowed_inputs.push_back(input)

func end_turn() -> void:
	_turn_time_remaining = 0.0
	turn_in_process = false
	turn_finished.emit()

func _get_actors_finished() -> int:
	var count: int = 0
	for actor in actors:
		if actor.is_finished:
			count += 1

	return count

func _on_level_complete() -> void:
	SFXService.play("level_win")
	print("COMPLETE")
