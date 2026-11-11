extends EnemyState
## Vồ: (1) gồng người crouch_time giây, hiện rõ, nháy báo trước, xoay theo player; (2) chốt hướng rồi lao
## pounce_speed tới hết pounce_distance (hoặc đụng tường), hitbox bật suốt cú lao, mỗi cú chỉ trúng một lần;
## (3) đứng sững recover_time giây: khoảng hở cho player đánh. Bị đánh giữa chừng thì state khác chen vào,
## exit() vẫn trả lượt cho bầy và tính hồi chiêu.

enum Phase { CROUCH, LEAP, RECOVER }

var wolf: ShadowWolf
var phase: Phase = Phase.CROUCH
var _elapsed: float = 0.0
var _travelled: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _hit: bool = false


func _ready() -> void:
	super()
	wolf = owner as ShadowWolf
	assert(wolf != null, "WolfPounce chỉ dùng cho ShadowWolf")


func enter(_previous: StringName) -> void:
	phase = Phase.CROUCH
	_elapsed = 0.0
	_travelled = 0.0
	_hit = false
	wolf.velocity.x = 0.0
	wolf.velocity.z = 0.0
	wolf.fade_to(0.0, 0.15)
	wolf.set_telegraph(true)
	wolf.play_action(&"Crouch")
	if not wolf.hitbox.hit.is_connected(_on_hit):
		wolf.hitbox.hit.connect(_on_hit)
	wolf.pounce_started.emit()


func exit() -> void:
	wolf.set_telegraph(false)
	wolf.hitbox.deactivate()
	wolf.end_pounce()


func physics_update(delta: float) -> void:
	_elapsed += delta
	wolf.apply_gravity(delta)
	var data := wolf.wolf_data
	match phase:
		Phase.CROUCH:
			wolf.move_toward_direction(Vector3.ZERO, delta)
			wolf.face_direction(wolf.direction_to_target(), delta)
			if _elapsed >= data.crouch_time:
				_start_leap()
		Phase.LEAP:
			wolf.velocity.x = _direction.x * data.pounce_speed
			wolf.velocity.z = _direction.z * data.pounce_speed
			_travelled += data.pounce_speed * delta
			if _travelled >= data.pounce_distance or (_travelled > 0.3 and wolf.is_on_wall()):
				_land()
		Phase.RECOVER:
			wolf.move_toward_direction(Vector3.ZERO, delta)
			if _elapsed >= data.recover_time:
				state_machine.transition_to(wolf.chase_state if wolf.has_target() else IDLE)


func _start_leap() -> void:
	phase = Phase.LEAP
	_elapsed = 0.0
	_direction = wolf.direction_to_target()
	if _direction.is_zero_approx():
		_direction = wolf.get_facing_direction()
	wolf.face_instantly(_direction)
	wolf.set_telegraph(false)
	wolf.hitbox.activate(wolf.wolf_data.pounce_attack)
	wolf.play_action(&"Pounce")


func _land() -> void:
	phase = Phase.RECOVER
	_elapsed = 0.0
	wolf.hitbox.deactivate()
	wolf.velocity.x = 0.0
	wolf.velocity.z = 0.0
	wolf.pounce_landed.emit(_hit)


func _on_hit(_hurtbox: HurtboxComponent) -> void:
	if phase == Phase.LEAP:
		_hit = true
