extends EnemyState
## Chiêu Phase 2 mới #1: Blazing Fang Snap (Cắn Bổ Hỏa Nanh Truy Đuổi).
## Tái sử dụng animation Bite (Cắn bổ xuống từ từ) -> đúng khung ngoạm xuống phóng đầu hổ răng kiếm lửa cỡ lớn
## truy đuổi liên tục player trong 7 giây (chậm hơn tốc độ player, bị đẩy xa bởi chiêu E gió, chạm player/tường thì nổ!).
## Sau khi kết thúc động tác cắn, Hổ tiếp tục chạy AI đánh các chiêu khác song song trong khi đầu lửa vẫn rượt player.

const BITE_FIRE_TIME := 0.74

var _actor: FireSabretooth
var _skeleton: Skeleton3D
var _jaw: int = -1
var _fired: bool = false


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	_skeleton = _actor.get_node("Model/Visual/Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	_jaw = _skeleton.find_bone(&"Sabrecat_Head_jaw_")


func enter(_previous: StringName) -> void:
	_fired = false
	_actor.hitbox.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.phase.show_flame_form()
	if _actor.has_target():
		_actor.face_instantly(_actor.direction_to_target())
	_actor.motion.play(&"Bite", _actor.profile.bridge_duration)
	_actor.animation_player().speed_scale = 1.0


func exit() -> void:
	_actor.animation_player().speed_scale = 1.0


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	var t := _actor.motion.elapsed()
	if not _fired and t < 0.62 and _actor.has_target():
		_actor.face_direction(_actor.direction_to_target(), delta)
	if not _fired and t >= BITE_FIRE_TIME:
		_fired = true
		_skeleton.force_update_all_bone_transforms()
		var dir := _actor.direction_to_target() if _actor.has_target() else _actor.get_facing_direction()
		if dir.length_squared() < 0.001:
			dir = _actor.get_facing_direction()
		var mouth := _actor.global_position + Vector3.UP * 1.15 + dir * 1.75
		if _jaw >= 0:
			var jaw_pos := _skeleton.to_global(_skeleton.get_bone_global_pose(_jaw).origin) + dir * 0.75
			mouth = Vector3(jaw_pos.x, clampf(jaw_pos.y, _actor.global_position.y + 0.92, _actor.global_position.y + 1.28), jaw_pos.z)
		_actor.p2_combat.launch_fang_snap(mouth, dir, _actor.target)
		ScreenShake.add_trauma_at(0.30, mouth, 8.0, 20.0)
	if _actor.motion.finished():
		_finish()


func _finish() -> void:
	_actor.animation_player().speed_scale = 1.0
	if _actor.phase_two_chain or not _actor.manual_skill:
		if not _actor.manual_skill:
			_actor.finish_attack(true)
		_actor.rest_then_phase_two(&"TigerCrossClaw")
	else:
		_actor.finish_phase_two_move()
