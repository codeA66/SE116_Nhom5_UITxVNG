class_name WindReactiveLeafPile
extends WindReactiveFoliage
## Đống lá tạm tan rồi rơi lại, phát sự kiện cho câu đố.

signal blown_away

var _remaining: float = 0.0


func _setup_visual() -> void:
	particle_color = Color(0.65, 0.42, 0.18)
	tint = Color(0.65, 0.42, 0.18)
	super._setup_visual()


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_model.visible = true
		set_process(false)


func _on_reacted(direction: Vector3, strength: float) -> void:
	super._on_reacted(direction, strength)
	_model.visible = false
	_remaining = data.recovery_seconds
	blown_away.emit()
	set_process(true)
