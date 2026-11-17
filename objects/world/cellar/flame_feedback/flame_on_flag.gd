class_name FlameOnFlag
extends Node
## Ngọn lửa bừng lên khi GameState có cờ (ví dụ lò cao khi tháp mở). Có cờ sẵn lúc vào khu thì đốt ngay không hiệu ứng,
## chưa có cờ thì chờ tới khi cờ bật rồi gọi FlameFeedback.ignite(). Tách khỏi FlagReveal vì FlagReveal không gọi lại khi cờ đã có sẵn.
## Hiệu năng: chỉ nghe GameState.progress_changed tới khi có cờ rồi ngắt, không có _process.

@export var flag: StringName
@export var flame: FlameFeedback


func _ready() -> void:
	if flame == null or flag.is_empty():
		return
	if GameState.has_flag(flag):
		flame.start_quiet()
		return
	GameState.progress_changed.connect(_on_progress_changed)


func _on_progress_changed() -> void:
	if not GameState.has_flag(flag):
		return
	GameState.progress_changed.disconnect(_on_progress_changed)
	flame.ignite()
