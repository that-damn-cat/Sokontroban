extends Node

enum MenuState {
	MAIN_MENU,
	OPTIONS,
	LOADING,
	GAME,
	PAUSED,
	CREDITS,
}

var state: MenuState = MenuState.MAIN_MENU