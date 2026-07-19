extends RichTextLabel

func _ready() -> void:
	var min_offset := Vector2(0.0, -4.0)
	var max_offset := Vector2(0.0, 5.0)

	offset_transform_position = min_offset

	var hover_tween := create_tween()
	hover_tween.set_loops()
	hover_tween.set_trans(Tween.TRANS_SINE)
	hover_tween.set_ease(Tween.EASE_IN_OUT)
	hover_tween.tween_property(self, "offset_transform_position", max_offset, 1.5)
	hover_tween.tween_property(self, "offset_transform_position", min_offset, 1.5)

