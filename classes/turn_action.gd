## A turn action is composed of all of the turn operations that occurred. This is the "Turn" as a whole.
class_name TurnAction
extends RefCounted

signal playback_finished(is_undo: bool)

var action_name: String
var _operations: Array[TurnOperation] = []
var _pending_tween_count := 0
var _playback_generation := 0

func _init(new_action_name: String = "Turn") -> void:
	action_name = new_action_name

func add_operation(operation: TurnOperation) -> void:
	if operation == null:
		push_error("Cannot add a null TurnOperation")
		return

	_operations.append(operation)

func is_empty() -> bool:
	return _operations.is_empty()


func register_history_references(history: UndoRedo) -> void:
	for operation in _operations:
		operation.register_history_references(history)


## UndoRedo calls this via Game to perform immediate changes
## This starts every tween at the same time, then emits playback_finished once all actors are done performing tweens
func play(game: Game, is_undo: bool) -> void:
	_playback_generation += 1
	var generation := _playback_generation

	if is_undo:
		for index in range(_operations.size() - 1, -1, -1):
			_operations[index].revert(game)
	else:
		for operation in _operations:
			operation.apply(game)

	var tweens: Array[Tween] = []

	if is_undo:
		for index in range(_operations.size() - 1, -1, -1):
			var tween := _operations[index].play_reverse(game)
			if tween != null:
				tweens.append(tween)
	else:
		for operation in _operations:
			var tween := operation.play_forward(game)
			if tween != null:
				tweens.append(tween)

	_pending_tween_count = tweens.size()

	if _pending_tween_count == 0:
		_emit_playback_finished.call_deferred(generation, is_undo)
		return

	for tween in tweens:
		tween.finished.connect(_on_tween_finished.bind(generation, is_undo), CONNECT_ONE_SHOT)

func _on_tween_finished(generation: int, is_undo: bool) -> void:
	if generation != _playback_generation:
		return

	_pending_tween_count -= 1

	if _pending_tween_count <= 0:
		_emit_playback_finished.call_deferred(generation, is_undo)

func _emit_playback_finished(generation: int, is_undo: bool) -> void:
	if generation != _playback_generation:
		return

	_pending_tween_count = 0
	playback_finished.emit(is_undo)