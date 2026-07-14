extends Node

var sfx_players: Dictionary[StringName, Array] = {}
var sfx_data: Dictionary[StringName, SfxData] = {}

func _enter_tree() -> void:
	var lib := Constants.SFX_LIBRARY.library as Dictionary[StringName, SfxData]

	for key in lib.keys():
		var data: SfxData = lib[key]
		sfx_data[key] = data

		var player_array: Array[AudioJitterPlayer] = []
		player_array.append(_create_player(data))

		sfx_players[key] = player_array

func play(sfx_name: StringName) -> void:
	if sfx_name not in sfx_players:
		push_warning("SFX %s not found!" % sfx_name)
		return

	var target_player: AudioJitterPlayer = _get_free_player(sfx_name)

	if target_player == null:
		push_warning("SFX %s exceeded max polyphony" % sfx_name)
		return

	target_player.play_jitter()

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
		if sfx_name not in sfx_players:
			push_warning("SFX %s not found!" % sfx_name)
			return

		array_list = [sfx_players[sfx_name] as Array[AudioJitterPlayer]]
	else:
		array_list = sfx_players.values()

	for player_array: Array[AudioJitterPlayer] in array_list:
		for player in player_array:
			action.call(player)

func _pause_player(player: AudioJitterPlayer) -> void:
	player.stream_paused = true

func _unpause_player(player: AudioJitterPlayer) -> void:
	player.stream_paused = false

func _stop_player(player: AudioJitterPlayer) -> void:
	player.stop()

func _get_free_player(sfx_name: StringName) -> AudioJitterPlayer:
	if sfx_name not in sfx_data:
		push_warning("SfxData missing for %s" % sfx_name)
		return null

	var player_array: Array[AudioJitterPlayer] = sfx_players[sfx_name]

	for player in player_array:
		if not player.playing:
			return(player)

	if player_array.size() >= Constants.MAX_PLAYERS_PER_SFX:
		return(null)

	var new_player: AudioJitterPlayer = _create_player(sfx_data[sfx_name])
	player_array.append(new_player)

	return(new_player)

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
