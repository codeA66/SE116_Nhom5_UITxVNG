extends PlayerState
## Chết: (nếu chết vì bẫy) nháy đỏ trước, rồi animation ngã, đứng yên, chờ rồi hồi sinh tại checkpoint với đầy máu.
## Không chuyển sang state khác: hồi sinh là tải lại khu, player mới sẽ bắt đầu từ Idle.

@export var respawn_delay: float = 1.5
## Độ hãm vận tốc còn lại lúc ngã (m/s mỗi giây)
@export var stop_friction: float = 30.0

var _elapsed: float = 0.0
var _respawn_requested: bool = false
## Thời gian nháy đỏ trước khi ngã; 0 = ngã ngay
var _flash_time: float = 0.0
var _fall_started: bool = false


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_respawn_requested = false
	_fall_started = false
	_flash_time = player.lethal_flash_time if player.consume_lethal_flash() else 0.0
	if _flash_time > 0.0:
		player.start_red_flash(_flash_time)
	else:
		_start_fall()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, stop_friction * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z

	if not _fall_started and _elapsed >= _flash_time:
		_start_fall()
	if _elapsed >= _flash_time + respawn_delay and not _respawn_requested:
		_respawn_requested = true
		GameState.reset_player_health()
		SceneManager.respawn_at_checkpoint()


func _start_fall() -> void:
	_fall_started = true
	player.play_action(Player.ANIM_DEATH)
