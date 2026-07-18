class_name Level
extends TileMapLayer

signal level_complete

var input_tiles: Dictionary[Vector2i, StringName]
var goal_tiles: Array[Vector2i]
var _game: Game

var player_direction: Array[StringName] = []
var undo_pressed := false
var reset_pressed := false

@export var camera_node: Camera2D
@export var level_number: int = 0

@warning_ignore("unused_private_class_variable")
var _has_camera: bool:
	get:
		return is_instance_valid(camera_node)

func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game") as Game
	if _game == null:
		push_error("Level could not find Game node!")
		return

	_game.undo_started.connect(_on_undo_started)
	_game.turn_finished.connect(_on_forward_turn_finished)
	_game.undo_finished.connect(_on_turn_undone)
	_game.redo_finished.connect(_on_forward_turn_finished)

	for cell in get_used_cells():
		var input_data: StringName = fetch_tile_data(cell, "input_name")
		var goal_data: bool = fetch_tile_data(cell, "is_goal")

		if input_data != &"":
			input_tiles[cell] = input_data

		if goal_data:
			goal_tiles.push_back(cell)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset"):
		reset_pressed = true
		notify_runtime_tile_data_update()
	elif event.is_action_released(&"reset"):
		reset_pressed = false
		notify_runtime_tile_data_update()

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return input_tiles.has(coords)

func _tile_data_runtime_update(_coords: Vector2i, tile_data: TileData) -> void:
	var default_color: Color = tile_data.get_custom_data("default_modulate")
	var input_name: StringName = tile_data.get_custom_data("input_name")

	if is_input_blocked(input_name):
		tile_data.modulate = Constants.RED_COLOR
		return

	var is_highlighted: bool = (
		input_name in player_direction
		or (input_name == &"undo" and undo_pressed)
		or (input_name == &"reset" and reset_pressed)
	)

	if is_highlighted:
		tile_data.modulate = Constants.HILIGHT_DICT.get(default_color, default_color)
	else:
		tile_data.modulate = default_color

func is_input_on_map(input_name: StringName) -> bool:
	return input_tiles.find_key(input_name) != null

func is_input_blocked(input_name: StringName) -> bool:
	# If the input isn't drawn on the map at all, it's OK
	if not is_input_on_map(input_name):
		return false

	# Filter the dict to get a list of cells that match this input
	var matching_cells := input_tiles.keys().filter(
		func(key): return input_tiles[key] == input_name
	)

	# For each match...
	for match in matching_cells:
		# Get the list of actors on the same tile
		for actor in _game.get_actors_at_tile(match):
			# If any of them are a crate, it's blocked
			if actor is Crate:
				return true

	# Otherwise it's OK
	return false

func is_goal_filled(cell) -> bool:
	if cell not in goal_tiles:
		return false

	for actor in _game.get_actors_at_tile(cell):
		if actor is Crate:
			return true

	return false

func is_level_complete() -> bool:
	for goal in goal_tiles:
		if not is_goal_filled(goal):
			return false

	return true

func is_tile_walkable(target_tile: Vector2i) -> bool:
	if not _is_tile_data_valid(target_tile):
		return false

	var walkable = fetch_tile_data(target_tile, "walkable")

	return walkable or walkable == null

func fetch_tile_data(target_tile: Vector2i, data_name: String) -> Variant:
	var tile_data: TileData = get_cell_tile_data(target_tile)

	if tile_data == null:
		return null

	if not tile_data.has_custom_data(data_name):
		push_warning("Tile missing %s data at %s" % [data_name, target_tile])
		return null

	return tile_data.get_custom_data(data_name)

func get_tilemap_position(global_pos: Vector2) -> Vector2i:
	var tilemap_local := to_local(global_pos)
	return local_to_map(tilemap_local)


func update_last_direction(direction: Vector2i) -> void:
	player_direction.clear()
	undo_pressed = false

	if direction.y < 0:
		player_direction.append(&"up")
	elif direction.y > 0:
		player_direction.append(&"down")

	if direction.x < 0:
		player_direction.append(&"left")
	elif direction.x > 0:
		player_direction.append(&"right")

	notify_runtime_tile_data_update()

func _is_tile_data_valid(target_tile: Vector2i) -> bool:
	var tile_data := get_cell_tile_data(target_tile)

	if tile_data == null:
		push_warning("No Tile Data at %s" % target_tile)
		return false

	return true

func _on_undo_started() -> void:
	player_direction.clear()
	undo_pressed = true
	notify_runtime_tile_data_update()

func _on_forward_turn_finished() -> void:
	player_direction.clear()
	notify_runtime_tile_data_update()

	if is_level_complete():
		level_complete.emit()

func _on_turn_undone() -> void:
	undo_pressed = false
	notify_runtime_tile_data_update()
