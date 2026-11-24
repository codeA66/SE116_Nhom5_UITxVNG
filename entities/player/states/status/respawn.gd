extends PlayerState
## Hồi sinh: cáo nằm (khung cuối clip ngã), hiện dần từ đầu xuống chân, rồi đứng dậy (clip ngã chạy ngược);
## màn hết xám, camera lùi về, xong thì về Idle và bất tử ngắn. Trình diễn do PlayerDeathPresentation lo
## (play_revive), state chỉ giữ cáo đứng yên, không nhận điều khiển, và chạy animation theo signal của trình diễn.
## Không gán presentation thì về Idle ngay.

## Độ hãm vận tốc còn lại (m/s mỗi giây)
@export var stop_friction: float = 30.0
@export var presentation: PlayerDeathPresentation

var _done: bool = false


func enter(_previous: StringName) -> void:
	_done = false
	player.velocity = Vector3.ZERO
	if presentation == null or presentation.data == null:
		_done = true
		return
	# Không ai đánh trúng được trong lúc đang hiện lại (hết cảnh thì đặt lại thời gian bất tử thật)
	player.grant_invincibility(presentation.data.get_revive_duration(), false)
	player.play_action_reversed(Player.ANIM_DEATH, 0.0)
	if not presentation.revive_get_up.is_connected(_on_get_up):
		presentation.revive_get_up.connect(_on_get_up)
	if not presentation.revive_finished.is_connected(_on_finished):
		presentation.revive_finished.connect(_on_finished)
	presentation.play_revive(player.consume_revive_anchor())


func exit() -> void:
	if presentation and presentation.is_reviving():
		presentation.reset()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, stop_friction * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	if _done:
		state_machine.transition_to(IDLE)


func _on_get_up(speed: float) -> void:
	if state_machine.current_state == self:
		player.play_action_reversed(Player.ANIM_DEATH, speed, 0.0)


func _on_finished() -> void:
	if state_machine.current_state != self:
		return
	player.grant_invincibility(presentation.data.invincible_time)
	_done = true
