extends EnemyState
## Dịch chuyển 3 pha: Vanish (co lại, vẫn đánh được) → Hidden (không đánh được, dấu hiệu ở chỗ sắp hiện)
## → Appear (hiện ra, đánh được, chưa bắn: khoảng hở). Không tìm được điểm hợp lệ thì hiện lại chỗ cũ.
## exit() luôn bật lại hurtbox / va chạm / model để bị Hurt / Blown chen ngang không bao giờ kẹt tàng hình.

enum Phase { VANISH, HIDDEN, APPEAR }

var caster: WispCaster
var _phase: Phase = Phase.VANISH
var _elapsed: float = 0.0
var _point: Vector3


func _ready() -> void:
	super()
	caster = owner as WispCaster
	assert(caster != null, "Teleport chỉ dùng cho WispCaster")


func enter(_previous: StringName) -> void:
	_phase = Phase.VANISH
	_elapsed = 0.0
	caster.set_telegraph(true)
	caster.play_vanish_fx(caster.caster_data.teleport.vanish_time)
	caster.play_action(&"Vanish")


func exit() -> void:
	caster.set_telegraph(false)
	caster.set_hidden(false)
	caster.hide_appear_marker()
	caster.reset_model_fx()


func physics_update(delta: float) -> void:
	_elapsed += delta
	caster.apply_gravity(delta)
	caster.move_toward_direction(Vector3.ZERO, delta)
	var timing := caster.caster_data.teleport
	match _phase:
		Phase.VANISH:
			if _elapsed >= timing.vanish_time:
				_begin_hidden()
		Phase.HIDDEN:
			if _elapsed >= timing.hidden_time:
				_begin_appear()
		Phase.APPEAR:
			if _elapsed >= timing.appear_time:
				state_machine.transition_to(caster.chase_state if caster.has_target() else IDLE)


func _begin_hidden() -> void:
	_phase = Phase.HIDDEN
	_elapsed = 0.0
	caster.set_telegraph(false)
	caster.set_hidden(true)
	# Chọn điểm một lần ở đầu pha ẩn; thất bại thì finder trả về chỗ cũ
	_point = caster.find_teleport_point()
	caster.show_appear_marker(_point)


func _begin_appear() -> void:
	_phase = Phase.APPEAR
	_elapsed = 0.0
	var from := caster.global_position
	var facing := caster.direction_to_target()
	caster.teleport(_point, facing)
	caster.set_hidden(false)
	caster.play_appear_fx(caster.caster_data.teleport.appear_time)
	caster.fade_appear_marker(caster.caster_data.teleport.appear_time)
	# Tính hồi chiêu ngay lúc dịch chuyển để bị đánh chen ngang pha Appear cũng không dịch lại liên tục
	caster.notify_teleported()
	caster.teleported.emit(from, _point)
