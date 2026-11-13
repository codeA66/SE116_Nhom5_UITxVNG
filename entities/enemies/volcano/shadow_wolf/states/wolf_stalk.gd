extends EnemyState
## Rình (chase_state của Sói): ở xa thì chạy thẳng tới; vào gần thì đi vòng quanh player ở stalk_radius, người
## hạ thấp, tan vào bóng tối. Áp sát thì cắn; trong tầm vồ và giành được lượt của bầy thì vồ.
## Player cầm lửa: không vồ / cắn, giữ khoảng cách ít nhất light_fear_radius, hiện rõ (bị ánh sáng soi).

var wolf: ShadowWolf
## +1 / -1: chiều đi vòng
var _orbit_sign: float = 1.0


func _ready() -> void:
	super()
	wolf = owner as ShadowWolf
	assert(wolf != null, "WolfStalk chỉ dùng cho ShadowWolf")


func enter(_previous: StringName) -> void:
	# Cả bầy tách nhau ra: mỗi con đi vòng một chiều ngẫu nhiên
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0


func physics_update(delta: float) -> void:
	wolf.apply_gravity(delta)
	if wolf.should_give_up_chase():
		wolf.forget_target()
		wolf.fade_to(0.0)
		state_machine.transition_to(PATROL)
		return
	var data := wolf.wolf_data
	var distance := wolf.distance_to_target()
	var to_target := wolf.direction_to_target()
	var lit := wolf.is_target_lit()
	if not lit:
		if distance <= data.bite_range and wolf.can_attack():
			state_machine.transition_to(wolf.attack_state)
			return
		if distance >= data.pounce_range_min and distance <= data.pounce_range_max and wolf.try_start_pounce():
			state_machine.transition_to(wolf.pounce_state)
			return
	var radius := maxf(data.stalk_radius, data.light_fear_radius if lit else 0.0)
	if distance > radius + data.run_in_margin:
		# Còn xa: chạy thẳng tới, hiện rõ
		wolf.fade_to(0.0)
		wolf.move_toward_direction(to_target, delta)
		wolf.play_anim(&"Run")
		wolf.face_direction(to_target, delta)
		return
	# Vòng rình: đi tiếp tuyến, kéo dần về đúng bán kính
	wolf.fade_to(0.0 if lit else data.stalk_fade)
	if wolf.is_on_wall():
		_orbit_sign = -_orbit_sign
	var tangent := to_target.cross(Vector3.UP) * _orbit_sign
	var radial := to_target * clampf((distance - radius) / 2.0, -1.0, 1.0)
	var desired := (tangent + radial).normalized() * data.stalk_speed_scale
	wolf.move_toward_direction(desired, delta)
	wolf.play_anim(&"Stalk")
	# Mắt luôn dõi theo con mồi
	wolf.face_direction(to_target, delta)
