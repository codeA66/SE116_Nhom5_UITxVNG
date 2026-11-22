extends EnemyState
## Chuyển pha Hổ Phase 1 -> Phase 2:
## Ngã gục (Collapse) -> nằm bất động 3 giây -> đứng bật dậy (GetUp2) -> gầm biến hình lửa Phase 2.
## Tách rõ từng giai đoạn để dễ ghép thêm góc quay camera cinematic sau này.

enum Stage { COLLAPSE, DOWN_HOLD, GET_UP, ROAR_TRANSFORM }

var _actor: FireSabretooth
var _stage: Stage = Stage.COLLAPSE
var _timer: float = 0.0
var _roar_done: bool = false


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth
	(_actor.get_node("Phase") as SabretoothPhase).finished.connect(_on_transformed)


func enter(_previous: StringName) -> void:
	_stage = Stage.COLLAPSE
	_timer = 0.0
	_roar_done = false
	_actor.hitbox.cancel()
	_actor.fire_vfx.cancel()
	if _actor.p2_combat:
		_actor.p2_combat.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.hurtbox.invulnerable = true
	_actor.model.rotation.x = 0.0
	(_actor.get_node("Model/Visual") as Node3D).position = Vector3.ZERO
	_actor.phase.set_portal_clip(false)
	_actor.phase.show_phase_one_form()
	_actor.motion.play(&"Collapse", 0.12)


func exit() -> void:
	_actor.hurtbox.invulnerable = false
	_actor.animation_player().speed_scale = 1.0
	if _stage == Stage.ROAR_TRANSFORM and not _roar_done:
		_actor.phase.cancel_preview()


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_timer += delta
	match _stage:
		Stage.COLLAPSE:
			if _actor.motion.finished():
				_stage = Stage.DOWN_HOLD
				_timer = 0.0
				_actor.animation_player().pause()
		Stage.DOWN_HOLD:
			if _timer >= maxf(_actor.profile.phase_two_down_time, 0.0):
				_stage = Stage.GET_UP
				_timer = 0.0
				# Khớp 100% với pose cuối của Collapse và chạy chậm lại cho cảm giác gượng dậy từ tốn dramatic.
				_actor.motion.play(&"GetUp2", 0.04)
				_actor.animation_player().speed_scale = clampf(_actor.profile.phase_two_getup_speed, 0.25, 1.0)
		Stage.GET_UP:
			if _actor.motion.finished():
				_stage = Stage.ROAR_TRANSFORM
				_timer = 0.0
				_actor.animation_player().speed_scale = 1.0
				_actor.phase.preview(_actor.target as Player)
		Stage.ROAR_TRANSFORM:
			if _roar_done:
				_actor.hurtbox.invulnerable = false
				state_machine.transition_to(&"TigerFireBeam")


func _on_transformed() -> void:
	if state_machine.current_state == self and _stage == Stage.ROAR_TRANSFORM:
		_roar_done = true
