extends EnemyState
## Bỏ chạy vì sợ lửa: hiện rõ, chạy ngược hướng player trong fear_time giây (đụng tường thì trượt dọc tường),
## rồi quay lại rình.

var wolf: ShadowWolf
var _elapsed: float = 0.0


func _ready() -> void:
	super()
	wolf = owner as ShadowWolf
	assert(wolf != null, "WolfFlee chỉ dùng cho ShadowWolf")


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	wolf.fade_to(0.0, 0.0)
	wolf.play_anim(&"Run")


func physics_update(delta: float) -> void:
	_elapsed += delta
	wolf.apply_gravity(delta)
	var away := -wolf.direction_to_target() if wolf.has_target() else wolf.get_facing_direction()
	if wolf.is_on_wall():
		away = away.slide(wolf.get_wall_normal()).normalized()
	wolf.move_toward_direction(away * wolf.wolf_data.flee_speed_scale, delta)
	wolf.face_direction(away, delta)
	if _elapsed >= wolf.wolf_data.fear_time:
		state_machine.transition_to(wolf.chase_state if wolf.has_target() else IDLE)
