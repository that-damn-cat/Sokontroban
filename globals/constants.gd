extends Node

# Graphics
const TILE_SIZE: int = 12
const INTERNAL_SIZE := Vector2i(384, 216)
const TILE_CENTER_OFFSET := Vector2(6.0, 6.0)
const BG_COLOR := Color("#101010")
const RED_COLOR := Color("#da291c")
const DIM_UI_COLOR := Color("#757882")
const HIGHLIGHT_UI_COLOR := Color("#fcfcf2")
const HILIGHT_DICT: Dictionary[Color, Color] = {
	Color("#1b1729"):  Color("#42133f"),
	Color("#18292e"):  Color("#376e49"),
	Color("#1773b8"):  Color("#00a2a8"),
	Color("#757882"):  Color("#d5dde4"),
	Color("#d5dde4"):  Color("#fcfcf2"),
	Color("#101010"):  Color("#757882")
}

# Audio
const SFX_LIBRARY: SfxLib = preload("res://resources/sfx_library.tres") as SfxLib
const MAX_PLAYERS_PER_SFX: int = 4
const SFX_BUS: StringName = &"SFX"
const BGM_BUS: StringName = &"Music"
const MIN_LINEAR_VOLUME: float = 0.0001
const DEFAULT_AUDIO_CONFIG: Dictionary[StringName, float] = {
	&"Master": 1.0,
	&"Music": 1.0,
	&"SFX": 1.0,
	&"BGFX": 0.5,
}

# Game Config
const TURN_TIME_SECONDS: float = 0.25
const TURN_COOLDOWN_SECONDS: float = 0.05
const RESET_HOLD_TIME: float = 1.25
const LEVEL_LOAD_DELAY: float = 1.2
const LEVEL_COMPLETE_DELAY: float = 1.5
const INPUT_LIST: Array[StringName] = [
	&"up",
	&"down",
	&"left",
	&"right",
	&"reset",
	&"undo",
]

# Files
const LEVEL_DIRECTORY: String = "res://scenes/levels"
const EMPTY_LEVEL_FILE: String = "res://scenes/levels/_empty_level.tscn"
const SAVE_DATA_FILE: String = "user://save_data.cfg"


func _enter_tree() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)