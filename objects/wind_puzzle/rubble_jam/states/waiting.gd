extends RubbleJamState
## Đủ nguồn nhưng chưa vỡ: chờ wait_source phát wait_signal (camera cắt cảnh đã tới khung hình) để người chơi
## kịp nhìn đá văng. Quá data.wait_timeout thì vỡ luôn, không bao giờ kẹt.

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	if jam.wait_source.has_signal(jam.wait_signal):
		jam.wait_source.connect(jam.wait_signal, _on_wait_signal, CONNECT_ONE_SHOT)
	else:
		push_warning("%s: wait_source không có signal '%s', vỡ sau wait_timeout" % [jam.get_path(), jam.wait_signal])
	jam.set_process(true)
	# Báo sau khi đã nối: camera nghe signal này để bay tới rồi báo lại
	jam.notify_unlock_started()


func exit() -> void:
	if jam.wait_source.is_connected(jam.wait_signal, _on_wait_signal):
		jam.wait_source.disconnect(jam.wait_signal, _on_wait_signal)


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= jam.data.wait_timeout:
		state_machine.transition_to(BURSTING)


func _on_wait_signal() -> void:
	state_machine.transition_to(BURSTING)
