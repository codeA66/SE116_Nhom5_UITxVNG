extends PlayerState
## Chết: (nếu chết vì bẫy) nháy đỏ trước, rồi animation ngã và màn chết (PlayerDeathPresentation: chậm, zoom, màn xám,
## tan thành hạt, tối màn); diễn xong mới hồi sinh tại checkpoint với đầy máu. Không gán presentation thì chờ
## respawn_delay như cũ. Phòng có hồi sinh riêng có thể đặt player về điểm đầu sau khi diễn xong.

## Chỉ dùng khi không có presentation
@export var respawn_delay: float = 1.5
## Độ hãm vận tốc còn lại lúc ngã (m/s mỗi giây)
@export var stop_friction: float = 30.0
## Màn chết (gán trong player.tscn); trống = ngã rồi chờ respawn_delay
@export var presentation: PlayerDeathPresentation

var _elapsed: float = 0.0
var _respawn_requested: bool = false
## Thời gian nháy đỏ trước khi ngã; 0 = ngã ngay
var _flash_time: float = 0.0
var _fall_started: bool = false
var _fall_at: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_respawn_requested = false
	_fall_started = false
	_flash_time = player.lethal_flash_time if player.consume_lethal_flash() else 0.0
	if _flash_time > 0.0:
		player.start_red_flash(_flash_time)
	else:
		_start_fall()


func exit() -> void:
	# Hồi sinh tại chỗ (không tải lại khu): thân hiện lại, màn hết xám, camera về khoảng cách thường
	if presentation:
		presentation.reset()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, stop_friction * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z

	if not _fall_started and _elapsed >= _flash_time:
		_start_fall()
	if _fall_started and not _respawn_requested and _ready_to_respawn():
		_respawn_requested = true
		if not player.request_local_respawn():
			GameState.reset_player_health()
			SceneManager.respawn_at_checkpoint()


func _ready_to_respawn() -> bool:
	if presentation:
		return presentation.is_finished()
	return _elapsed >= _fall_at + respawn_delay


func _start_fall() -> void:
	_fall_started = true
	_fall_at = _elapsed
	player.play_action(Player.ANIM_DEATH)
	if presentation:
		presentation.play()
