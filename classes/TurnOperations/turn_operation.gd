## A turn operation is one individual behavior that happened during a single turn (eg: this actor did x)
## It is composed of the forward action, a way to undo it, and the forward+reverse version of any visual effects/motion
@abstract
class_name TurnOperation
extends RefCounted

## Changes the game state forward
@abstract func apply(game: Game) -> void

## Changes the game state backwards
@abstract func revert(game: Game) -> void

## Starts forward animation and returns its Tween, or null if no animation
@abstract func play_forward(game: Game) -> Tween

## Starts reverse animation and returns its Tween, or null if no animation
@abstract func play_reverse(game: Game) -> Tween

## This can be overridden to record if an actor gets unregistered/detached
func register_history_references(_history: UndoRedo) -> void:
	pass