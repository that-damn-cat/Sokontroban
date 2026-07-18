class_name MainController
extends Node

enum AppState {
	MAIN_MENU,
	LEVEL_SELECT,
	SCORES,
	OPTIONS,
	LOADING,
	PLAYING,
	PAUSED,
	CREDITS,
}

signal state_changed(new_state: AppState)

@export var level_complete_delay: float = Constants.LEVEL_COMPLETE_DELAY
@export var subviewport_container: SubViewportContainer
@export var retro_fx: ColorRect

@onready var game: Game = $SubViewportContainer/GameViewport/Game
@onready var hud: Control = $SubViewportContainer/GameViewport/CanvasLayer/HUD
@onready var loading_screen: Control = $SubViewportContainer/GameViewport/CanvasLayer/LoadingScreen
@onready var loading_label: LoadingLabel = $SubViewportContainer/GameViewport/CanvasLayer/LoadingScreen/LoadingLabel
@onready var main_menu: MainMenuScreen = $SubViewportContainer/GameViewport/CanvasLayer/MainMenu
@onready var level_select: LevelSelectScreen = $SubViewportContainer/GameViewport/CanvasLayer/LevelSelect
@onready var scores_screen: ScoresScreen = $SubViewportContainer/GameViewport/CanvasLayer/ScoresScreen
@onready var pause_menu: Control = $SubViewportContainer/GameViewport/CanvasLayer/PauseMenu
@onready var pause_first_focus: Control = $SubViewportContainer/GameViewport/CanvasLayer/PauseMenu/PauseMenuPanel/VBoxContainer/MenuCenter/VolumeSliders/MasterVolumeContainer/VolSlider
@onready var pause_return_label: Label = $SubViewportContainer/GameViewport/CanvasLayer/PauseMenu/PauseMenuPanel/VBoxContainer/HBoxContainer/MainMenuButton/MainMenuButton
@onready var pause_title_label: Label = $SubViewportContainer/GameViewport/CanvasLayer/PauseMenu/PauseMenuPanel/VBoxContainer/PauseLabel

var state := AppState.MAIN_MENU
var _transition_generation: int = 0
var _transition_in_progress: bool = false
var _completion_pending: bool = false
var _ignore_pause_signal: bool = false


func _ready() -> void:
	add_to_group(&"main_controller")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_screen_signals()
	PauseManager.pause_changed.connect(_on_pause_changed)
	PauseManager.register_first_pause_focus(pause_first_focus)
	game.level_completed.connect(_on_level_completed)

	_force_unpause()
	_set_state(AppState.MAIN_MENU)

	get_window().size_changed.connect(_update_integer_scaling)
	call_deferred("_update_integer_scaling")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not event.is_action_pressed(&"pause"):
		return

	match state:
		AppState.LEVEL_SELECT, AppState.SCORES, AppState.CREDITS:
			show_main_menu()
			get_viewport().set_input_as_handled()
		AppState.OPTIONS:
			show_main_menu()
			get_viewport().set_input_as_handled()


func request_level(level_number: int) -> void:
	if _transition_in_progress:
		return

	if not LevelManager.has_level(level_number):
		push_warning("Requested level does not exist: %s" % level_number)
		return

	if not SaveDataManager.is_level_unlocked(level_number):
		push_warning("Requested level is locked: %s" % level_number)
		return

	_transition_to_level(level_number)


func show_main_menu() -> void:
	if _transition_in_progress:
		return

	if state in [AppState.PAUSED, AppState.OPTIONS]:
		SaveDataManager.update_config()

	if LevelManager.current_level >= 0 or state == AppState.PAUSED:
		_transition_to_main_menu()
		return

	_force_unpause()
	_completion_pending = false
	_set_state(AppState.MAIN_MENU)


func handle_pause_menu_return() -> void:
	show_main_menu()


func _connect_screen_signals() -> void:
	main_menu.start_requested.connect(_on_start_requested)
	main_menu.level_select_requested.connect(_show_level_select)
	main_menu.scores_requested.connect(_show_scores)
	main_menu.options_requested.connect(_show_options)
	main_menu.quit_requested.connect(_quit_game)

	level_select.level_selected.connect(request_level)
	level_select.back_requested.connect(show_main_menu)

	scores_screen.back_requested.connect(show_main_menu)


func _on_start_requested() -> void:
	var level_number := SaveDataManager.get_continue_level(LevelManager.get_level_numbers())

	if level_number < 0:
		push_error("No playable levels were discovered.")
		return

	# A missing/corrupt save may not contain the first level yet.
	if not SaveDataManager.is_level_unlocked(level_number):
		SaveDataManager.unlock_level(level_number)

	request_level(level_number)


func _show_level_select() -> void:
	if _transition_in_progress:
		return

	_force_unpause()
	level_select.refresh()
	_set_state(AppState.LEVEL_SELECT)


func _show_scores() -> void:
	if _transition_in_progress:
		return

	_force_unpause()
	scores_screen.refresh()
	_set_state(AppState.SCORES)


func _show_options() -> void:
	if _transition_in_progress:
		return

	_force_unpause()
	_set_state(AppState.OPTIONS)


func _quit_game() -> void:
	SaveDataManager.update_config()
	get_tree().quit()


func _transition_to_level(level_number: int) -> void:
	var generation := _begin_transition()
	_force_unpause()
	_set_state(AppState.LOADING)

	_play_transition_audio()
	LevelManager.clear_level()

	await get_tree().create_timer(Constants.LEVEL_LOAD_DELAY, true).timeout

	if generation != _transition_generation:
		return

	var loaded := LevelManager.load_level(level_number)
	_transition_in_progress = false

	if loaded:
		_set_state(AppState.PLAYING)
	else:
		push_error("Failed to load level %s." % level_number)
		_set_state(AppState.MAIN_MENU)


func _transition_to_main_menu() -> void:
	var generation := _begin_transition()
	_force_unpause()
	_set_state(AppState.LOADING)

	_play_transition_audio()
	LevelManager.quit_level()

	await get_tree().create_timer(Constants.LEVEL_LOAD_DELAY, true).timeout

	if generation != _transition_generation:
		return

	_transition_in_progress = false
	_set_state(AppState.MAIN_MENU)


func _on_level_completed(level_number: int, _score: int) -> void:
	if state != AppState.PLAYING or _completion_pending:
		return

	var next_level := LevelManager.get_next_level_number(level_number)

	if next_level >= 0:
		SaveDataManager.unlock_level(next_level)
	else:
		SaveDataManager.set_victory()

	_completion_pending = true
	_sync_runtime_permissions()

	_transition_generation += 1
	var generation := _transition_generation

	# This timer pauses with the game, so the next screen cannot load behind the
	# pause menu. Returning to the main menu invalidates the generation.
	await get_tree().create_timer(level_complete_delay, false).timeout

	if generation != _transition_generation:
		return

	_completion_pending = false

	if next_level >= 0:
		_transition_to_level(next_level)
	else:
		_transition_to_main_menu()


func _on_pause_changed(is_paused: bool) -> void:
	if _ignore_pause_signal:
		return

	if is_paused:
		if state != AppState.PLAYING:
			_force_unpause()
			return

		_set_state(AppState.PAUSED)
	elif state == AppState.PAUSED:
		_set_state(AppState.PLAYING)


func _begin_transition() -> int:
	_transition_generation += 1
	_transition_in_progress = true
	_completion_pending = false
	return _transition_generation


func _force_unpause() -> void:
	_ignore_pause_signal = true
	PauseManager.force_unpause()
	_ignore_pause_signal = false


func _set_state(new_state: AppState) -> void:
	state = new_state

	main_menu.visible = state == AppState.MAIN_MENU
	level_select.visible = state == AppState.LEVEL_SELECT
	scores_screen.visible = state == AppState.SCORES
	pause_menu.visible = state in [AppState.PAUSED, AppState.OPTIONS]
	hud.visible = state == AppState.PLAYING
	loading_screen.visible = state == AppState.LOADING

	if state == AppState.LOADING:
		loading_label.start_loading()
	else:
		loading_label.stop_loading()

	if state == AppState.PAUSED:
		pause_title_label.text = "Paused"
		pause_return_label.text = "Main Menu"
	elif state == AppState.OPTIONS:
		pause_title_label.text = "Options"
		pause_return_label.text = "Back"

	_set_level_visible(state == AppState.PLAYING)
	_sync_runtime_permissions()
	call_deferred(&"_focus_current_screen")
	state_changed.emit(state)


func _play_transition_audio() -> void:
	SFXService.stop_all()
	SFXService.play(&"floppy")


func _sync_runtime_permissions() -> void:
	var is_playing := state == AppState.PLAYING
	var accepts_gameplay := (
		is_playing
		and not _transition_in_progress
		and not _completion_pending
	)

	game.set_gameplay_enabled(accepts_gameplay)
	LevelManager.set_reset_enabled(accepts_gameplay)
	PauseManager.set_pause_allowed(is_playing and not _transition_in_progress)


func _set_level_visible(should_show: bool) -> void:
	if not is_instance_valid(game.level):
		return

	if should_show:
		game.level.show()
	else:
		game.level.hide()


func _focus_current_screen() -> void:
	match state:
		AppState.MAIN_MENU:
			main_menu.focus_default()
		AppState.LEVEL_SELECT:
			level_select.focus_default()
		AppState.SCORES:
			scores_screen.focus_default()
		AppState.PAUSED, AppState.OPTIONS:
			if is_instance_valid(pause_first_focus):
				pause_first_focus.grab_focus()

func _update_integer_scaling() -> void:
	var available_size := get_window().size

	var scale_factor := floori(minf(
		float(available_size.x) / float(Constants.INTERNAL_SIZE.x),
		float(available_size.y) / float(Constants.INTERNAL_SIZE.y)
	))

	scale_factor = maxi(scale_factor, 1)

	var displayed_size := Constants.INTERNAL_SIZE * scale_factor
	var displayed_position := Vector2(available_size - displayed_size) * 0.5

	subviewport_container.position = displayed_position
	subviewport_container.size = Vector2(displayed_size)
	subviewport_container.stretch = true
	subviewport_container.stretch_shrink = scale_factor

	retro_fx.position = displayed_position
	retro_fx.size = Vector2(displayed_size)