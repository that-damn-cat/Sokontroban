class_name SfxData
extends Resource

@export var stream: AudioStream
@export_range(-80.0, 24.0, 0.001) var volume_db: float = 0.0
@export_range(0.0, 0.5, 0.01) var pitch_jitter: float = 0.0
@export_range(0.01, 4.0, 0.01) var pitch_scale: float = 1.0

func _init(new_stream: AudioStream = null, volume: float = 0.0, jitter: float = 0.0, pitch: float = 1.0) -> void:
	stream = new_stream
	volume_db = volume
	pitch_jitter = jitter
	pitch_scale = pitch