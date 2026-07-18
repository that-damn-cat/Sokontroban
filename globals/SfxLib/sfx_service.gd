extends Node

var sfx_players: Dictionary[StringName, Array] = {}
var sfx_data: Dictionary[StringName, SfxData] = {}

func _enter_tree() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	sfx_players.clear()
	sfx_data.clear()

	if Constants.SFX_LIBRARY == null:
		push_error("SFX Library resource is missing!")
		return

	for key in Constants.SFX_LIBRARY.library:
		var data: SfxData = Constants.SFX_LIBRARY.library[key]
		if data == null or data.stream == null:
			push_warning("SFX %s has no audio stream!" % key)
			continue

		sfx_data[key] = data
		sfx_players[key] = [_create_player(data)]

func play(sfx_name: StringName) -> void:
	if not has_sfx(sfx_name):
		if sfx_name != &"":
			push_warning("SFX %s not found!" % sfx_name)
		return

	var target_player := _get_free_player(sfx_name)

	if target_player == null:
		push_warning("SFX %s exceeded max polyphony" % sfx_name)
		return

	target_player.stream_paused = false
	target_player.play_jitter()

func has_sfx(sfx_name: StringName) -> bool:
	return sfx_name != &"" and sfx_players.has(sfx_name)

func pause(sfx_name: StringName) -> void:
	_for_each_player(_pause_player, sfx_name)

func unpause(sfx_name: StringName) -> void:
	_for_each_player(_unpause_player, sfx_name)

func stop(sfx_name: StringName) -> void:
	_for_each_player(_stop_player, sfx_name)

func pause_all() -> void:
	_for_each_player(_pause_player)

func unpause_all() -> void:
	_for_each_player(_unpause_player)

func stop_all() -> void:
	_for_each_player(_stop_player)

func _for_each_player(action: Callable, sfx_name: StringName = &"") -> void:
	var array_list: Array = []

	if sfx_name != &"":
		if not has_sfx(sfx_name):
			push_warning("SFX %s not found!" % sfx_name)
			return

		array_list.append(sfx_players[sfx_name])
	else:
		array_list = sfx_players.values()

	for player_array_variant in array_list:
		var player_array: Array = player_array_variant

		for player_variant in player_array:
			var player := player_variant as AudioJitterPlayer
			if is_instance_valid(player):
				action.call(player)

func _pause_player(player: AudioJitterPlayer) -> void:
	player.stream_paused = true

func _unpause_player(player: AudioJitterPlayer) -> void:
	player.stream_paused = false

func _stop_player(player: AudioJitterPlayer) -> void:
	player.stop()

func _get_free_player(sfx_name: StringName) -> AudioJitterPlayer:
	if not sfx_data.has(sfx_name):
		return null

	var player_array: Array = sfx_players[sfx_name]

	for player_variant in player_array:
		var player := player_variant as AudioJitterPlayer
		if is_instance_valid(player) and not player.playing:
			return player

	if player_array.size() >= Constants.MAX_PLAYERS_PER_SFX:
		return null

	var new_player := _create_player(sfx_data[sfx_name])
	player_array.append(new_player)
	return new_player

func _create_player(data: SfxData) -> AudioJitterPlayer:
	var new_player := AudioJitterPlayer.new()
	new_player.stream = data.stream
	new_player.volume_db = data.volume_db
	new_player.jitter = data.pitch_jitter
	new_player.pitch_scale = data.pitch_scale
	new_player.max_polyphony = 1
	new_player.bus = Constants.SFX_BUS

	add_child(new_player)

	return(new_player)
