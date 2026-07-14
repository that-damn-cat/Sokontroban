extends Node

# Graphics
const TILE_SIZE: int = 12
const TILE_CENTER_OFFSET := Vector2(6.0, 6.0)
const BG_COLOR := Color("#101010")
const RED_COLOR := Color("#da291c")
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

# Game Config
const TURN_TIME_SECONDS: float = 0.25

func _enter_tree() -> void:
	RenderingServer.set_default_clear_color(BG_COLOR)