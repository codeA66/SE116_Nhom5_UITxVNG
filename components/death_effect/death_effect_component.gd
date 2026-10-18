class_name DeathEffectComponent
extends Node
## Cảnh chết: dừng hình + rung màn hình, model phồng nhẹ rồi co về ~0, xong thì nổ mảnh vỡ + hồn (CombatFx).
## Nghe health.died, không quét mỗi frame. Không đụng state Dead: model co trước khi xác biến mất.

## Co tới mức này (không về đúng 0) để tránh basis suy biến
const MIN_SCALE := 0.001

@export var health: HealthComponent
## Phần cần co (thường Model); cũng là gốc xoay nên hitbox co theo, không sao vì quái đã chết
@export var model: Node3D
@export var data: DeathEffectData
## Tuỳ chọn: lấy màu máu cho vũng dưới xác (không gán hoặc không chảy máu thì không có vũng)
@export var feedback: HitFeedbackComponent

var _tween: Tween


func _ready() -> void:
	if health == null or model == null or data == null:
		push_error("%s cần health, model và data" % get_path())
		return
	health.died.connect(_on_died)


func _on_died() -> void:
	HitStop.stop(data.kill_hitstop)
	ScreenShake.add_trauma(data.trauma)
	var base := model.scale
	_tween = create_tween()
	_tween.tween_property(model, "scale", base * data.grow_scale, data.grow_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(model, "scale", base * MIN_SCALE, data.shrink_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_spawn_burst)


func _spawn_burst() -> void:
	var body := owner as Node3D
	var feet := body.global_position if body else model.global_position
	CombatFx.spawn_death(feet, data.color, data.effect_scale)
	if feedback and feedback.get_data().bleeds and data.puddle_size > 0.0:
		CombatFx.spawn_puddle(feet, data.puddle_size, feedback.get_data().blood_color)
