extends VaneBridgeState
## Xoay êm (chậm ở hai đầu) tới góc đích trong turn_time giây, chong chóng quay theo.
## Thổi lúc đang xoay thì bỏ qua: xoay xong mới nhận cú tiếp.

var _from: float = 0.0
var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_from = bridge.angle_degrees
	_elapsed = 0.0
	if bridge.data.turn_trauma > 0.0:
		ScreenShake.add_trauma(bridge.data.turn_trauma)
	bridge.notify_turn_started()


func physics_update(delta: float) -> void:
	var d := bridge.data
	_elapsed += delta
	var t := clampf(_elapsed / maxf(d.turn_time, 0.001), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	bridge.angle_degrees = lerpf(_from, bridge.target_degrees, eased)
	bridge.set_deck_angle(bridge.angle_degrees)
	bridge.spin_vane(TAU * d.vane_turns * delta / maxf(d.turn_time, 0.001))
	if t >= 1.0:
		bridge.angle_degrees = bridge.target_degrees
		if not bridge.persistent_id.is_empty():
			GameState.set_flag(bridge.persistent_id)
		bridge.notify_turn_finished()
		state_machine.transition_to(IDLE)
