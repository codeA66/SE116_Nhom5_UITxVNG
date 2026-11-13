extends EnemyState
## Nhảy dậm (attack_state của Slime Mẹ): thu mình báo trước (phình + nháy), nhảy vòng cung tới chỗ player đứng lúc
## bật nhảy (tối đa slam_max_distance), chạm đất thì sóng chấn, đứng thở slam_recovery giây rồi quay lại nảy đuổi.
## Bay theo đường parabol tự tính (không dùng trọng lực) để đúng slam_air_time / slam_height với mọi thông số.

enum Phase { WINDUP, AIR, RECOVER }

const ANIM_SWELL := &"Swell"
const ANIM_DEFLATE := &"Deflate"
## Bay quá thời gian dự tính mà chưa chạm đất (đáp xuống chỗ thấp hơn) thì rơi tự do tối đa chừng này rồi vẫn dậm
const MAX_EXTRA_FALL := 1.0

var mother: SlimeMother
var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _horizontal: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()
	mother = owner as SlimeMother
	assert(mother != null, "MotherSlam chỉ dùng cho SlimeMother")


func enter(_previous: StringName) -> void:
	_phase = Phase.WINDUP
	_elapsed = 0.0
	mother.velocity = Vector3.ZERO
	mother.set_telegraph(true)
	var length := mother.get_animation_length(ANIM_SWELL)
	mother.play_action(ANIM_SWELL, length / mother.mother_data.slam_windup if length > 0.0 else 1.0)


func exit() -> void:
	mother.set_telegraph(false)


func physics_update(delta: float) -> void:
	var d := mother.mother_data
	_elapsed += delta
	match _phase:
		Phase.WINDUP:
			mother.apply_gravity(delta)
			mother.velocity.x = 0.0
			mother.velocity.z = 0.0
			if mother.has_target():
				mother.face_direction(mother.direction_to_target(), delta)
			if _elapsed >= d.slam_windup:
				_take_off()
		Phase.AIR:
			var t := _elapsed
			if t < d.slam_air_time:
				# Đạo hàm của y = 4h·t(T - t)/T²
				mother.velocity.y = 4.0 * d.slam_height / d.slam_air_time * (1.0 - 2.0 * t / d.slam_air_time)
				mother.velocity.x = _horizontal.x
				mother.velocity.z = _horizontal.z
			else:
				mother.velocity.x = 0.0
				mother.velocity.z = 0.0
				mother.apply_gravity(delta)
				if mother.is_on_floor() or t >= d.slam_air_time + MAX_EXTRA_FALL:
					_land()
		Phase.RECOVER:
			mother.apply_gravity(delta)
			mother.move_toward_direction(Vector3.ZERO, delta)
			if _elapsed >= d.slam_recovery:
				state_machine.transition_to(mother.chase_state if mother.has_target() else IDLE)


func _take_off() -> void:
	var d := mother.mother_data
	_phase = Phase.AIR
	_elapsed = 0.0
	mother.set_telegraph(false)
	var offset := Vector3.ZERO
	if mother.has_target():
		offset = mother.target.global_position - mother.global_position
		offset.y = 0.0
		if offset.length() > d.slam_max_distance:
			offset = offset.normalized() * d.slam_max_distance
	_horizontal = offset / maxf(d.slam_air_time, 0.01)


func _land() -> void:
	_phase = Phase.RECOVER
	_elapsed = 0.0
	mother.velocity = Vector3.ZERO
	mother.slam()
	mother.start_attack_cooldown()
	mother.play_action(ANIM_DEFLATE)
