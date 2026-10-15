extends PlayerState
## Chết: animation ngã, đứng yên, chờ rồi hồi sinh tại checkpoint với đầy máu.
## Không chuyển sang state khác: hồi sinh là tải lại khu, player mới sẽ bắt đầu từ Idle.

@export var respawn_delay: float = 1.5
## Độ hãm vận tốc còn lại lúc ngã (m/s mỗi giây)
@export var stop_friction: float = 30.0

var _elapsed: float = 0.0
var _respawn_requested: bool = false


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_respawn_requested = false
	player.play_action(Player.ANIM_DEATH)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, stop_friction * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z

	if _elapsed >= respawn_delay and not _respawn_requested:
		_respawn_requested = true
		GameState.reset_player_health()
		SceneManager.respawn_at_checkpoint()
