class_name Level
extends TileMapLayer

signal level_complete

@export var camera_node: Camera2D
@export var level_number: int = 0
@export var level_title: String = ""

var input_tiles: Dictionary[Vector2i, StringName] = {}
var goal_tiles: Array[Vector2i] = []
var player_direction: Array[StringName] = []
var undo_pressed := false
var reset_pressed := false

var _game: Game


func _enter_tree() -> void:
	_refresh_tile_metadata()
	_game = get_tree().get_first_node_in_group("game") as Game

func _ready() -> void:
	if _game == null:
		push_error("Level could not find Game node!")
		return

	_game.undo_started.connect(_on_undo_started)
	_game.turn_finished.connect(_on_forward_turn_finished)
	_game.undo_finished.connect(_on_turn_undone)
	_game.redo_finished.connect(_on_forward_turn_finished)

	call_deferred("_activate_camera")

func _input(event: InputEvent) -> void:
	if not LevelManager.reset_enabled:
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(&"reset"):
		reset_pressed = true
		notify_runtime_tile_data_update()
	elif event.is_action_released(&"reset"):
		reset_pressed = false
		notify_runtime_tile_data_update()


func has_level_camera() -> bool:
	return is_instance_valid(camera_node)

func get_display_title() -> String:
	if not level_title.strip_edges().is_empty():
		return level_title.strip_edges()

	return "Level %02d" % level_number

func clear_input_feedback() -> void:
	player_direction.clear()
	undo_pressed = false
	reset_pressed = false
	notify_runtime_tile_data_update()

func is_input_on_map(input_name: StringName) -> bool:
	return input_tiles.find_key(input_name) != null

func is_input_blocked(input_name: StringName) -> bool:
	if not is_instance_valid(_game):
		return false

	# Inputs not represented on the map are unrestricted.
	if not is_input_on_map(input_name):
		return false

	for cell in input_tiles:
		if input_tiles[cell] != input_name:
			continue

		for actor in _game.get_actors_at_tile(cell):
			if actor is Crate:
				return true

	return false

func is_goal_filled(cell: Vector2i) -> bool:
	if cell not in goal_tiles or not is_instance_valid(_game):
		return false

	for actor in _game.get_actors_at_tile(cell):
		if actor is Crate:
			return true

	return false

func is_level_complete() -> bool:
	if goal_tiles.is_empty():
		return false

	for goal in goal_tiles:
		if not is_goal_filled(goal):
			return false

	return true

func is_tile_walkable(target_tile: Vector2i) -> bool:
	if not _is_tile_data_valid(target_tile):
		return false

	var walkable : bool = fetch_tile_data(target_tile, "walkable", true)
	return walkable == null or bool(walkable)

func fetch_tile_data(
	target_tile: Vector2i,
	data_name: String,
	default_value: Variant = null
) -> Variant:
	var tile_data := get_cell_tile_data(target_tile)

	if tile_data == null:
		return default_value

	if not tile_data.has_custom_data(data_name):
		push_warning("Tile missing %s data at %s" % [data_name, target_tile])
		return default_value

	return tile_data.get_custom_data(data_name)

func get_tilemap_position(global_pos: Vector2) -> Vector2i:
	return local_to_map(to_local(global_pos))

func update_last_direction(direction: Vector2i) -> void:
	player_direction.clear()
	undo_pressed = false
	reset_pressed = false

	if direction.y < 0:
		player_direction.append(&"up")
	elif direction.y > 0:
		player_direction.append(&"down")

	if direction.x < 0:
		player_direction.append(&"left")
	elif direction.x > 0:
		player_direction.append(&"right")

	notify_runtime_tile_data_update()


func _refresh_tile_metadata() -> void:
	input_tiles.clear()
	goal_tiles.clear()

	for cell in get_used_cells():
		var input_data := StringName(fetch_tile_data(cell, "input_name", &""))
		var goal_data := bool(fetch_tile_data(cell, "is_goal", false))

		if input_data != &"":
			input_tiles[cell] = input_data

		if goal_data:
			goal_tiles.append(cell)

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return input_tiles.has(coords)

func _tile_data_runtime_update(_coords: Vector2i, tile_data: TileData) -> void:
	var default_color: Color = tile_data.get_custom_data("default_modulate")
	var input_name: StringName = tile_data.get_custom_data("input_name")

	if is_input_blocked(input_name):
		tile_data.modulate = Constants.RED_COLOR
		return

	var is_highlighted := (
		input_name in player_direction
		or (input_name == &"undo" and undo_pressed)
		or (input_name == &"reset" and reset_pressed)
	)

	if is_highlighted:
		tile_data.modulate = Constants.HILIGHT_DICT.get(default_color, default_color)
	else:
		tile_data.modulate = default_color

func _is_tile_data_valid(target_tile: Vector2i) -> bool:
	var tile_data := get_cell_tile_data(target_tile)

	if tile_data == null:
		return false

	return true

func _on_undo_started() -> void:
	player_direction.clear()
	reset_pressed = false
	undo_pressed = true
	notify_runtime_tile_data_update()

func _on_forward_turn_finished() -> void:
	clear_input_feedback()

	if is_level_complete():
		level_complete.emit()

func _on_turn_undone() -> void:
	clear_input_feedback()

func _activate_camera() -> void:
	var active_camera: Camera2D = camera_node

	# Levels without a dedicated camera use the player's camera.
	if (
		not is_instance_valid(active_camera)
		and is_instance_valid(_game)
		and is_instance_valid(_game.player)
	):
		active_camera = _game.player.camera

	if not is_instance_valid(active_camera):
		return

	active_camera.enabled = true
	active_camera.make_current()

	# Reset drag-margin and smoothing state to the camera's current target.
	active_camera.align()
	active_camera.reset_smoothing()
	active_camera.force_update_scroll()