extends EnemyState
## Đòn lướt rồi chém, 4 pha trong một state: lấy đà (bám hướng rồi khoá hướng, hiện báo trước) -> lướt thẳng
## -> chém (hitbox bật trong active frames của AttackData) -> hồi (đứng yên, cửa sổ phản công).
## Thông số lướt ở DashSlashData, đòn chém ở EnemyData.attack. Mọi đường thoát đều qua exit() nên dọn dẹp một chỗ.

signal phase_started(phase: Phase)

## Pha hồi nằm trong SLASH, sau active_end
enum Phase { WINDUP, DASH, SLASH }

## Sai số khi coi quãng còn lại là hết (m)
const STOP_EPSILON := 0.001
## Chặn chia cho 0 khi dash_speed bị chỉnh về 0
const MIN_DASH_SPEED := 0.01

@export var data: DashSlashData
@export_group("Nodes")
## Hộp quét chặn đòn chém xuyên tường / rào (tắt, chỉ quét bằng force_shapecast_update)
@export var clearance: ShapeCast3D
## Tia dò sàn phía trước khi lướt (tắt, chỉ quét bằng force_raycast_update)
@export var ledge_probe: RayCast3D
@export var dash_trail: GPUParticles3D
## Chỗ cắm âm thanh: stream trống thì bỏ qua
@export var windup_sfx: AudioStreamPlayer3D
@export var dash_sfx: AudioStreamPlayer3D
@export var slash_sfx: AudioStreamPlayer3D

var _phase: Phase = Phase.WINDUP
var _phase_time: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _dash_distance: float = 0.0
var _traveled: float = 0.0
var _last_position: Vector3
var _direction_locked: bool = false
var _hit_started: bool = false
var _aborted: bool = false
var _slash: AttackData
var _windup_time: float = 0.0
var _track_time: float = 0.0
## Mép trước và quãng quét của hộp chống chém xuyên, đọc một lần từ scene
var _clearance_front: float = 0.0
var _clearance_length: float = 0.0


func _ready() -> void:
	super()
	assert(data != null, "DashSlash chưa gán DashSlashData")
	if clearance:
		clearance.add_exception(enemy)
		clearance.enabled = false
		_clearance_length = clearance.target_position.z
		var box := clearance.shape as BoxShape3D
		_clearance_front = clearance.position.z + (box.size.z * 0.5 if box else 0.0)
	if ledge_probe:
		ledge_probe.add_exception(enemy)
		ledge_probe.enabled = false


func enter(_previous: StringName) -> void:
	_slash = enemy.data.attack
	_aborted = false
	_hit_started = false
	_direction_locked = false
	_windup_time = maxf(data.windup_time, 0.0)
	_track_time = clampf(data.track_time, 0.0, _windup_time)
	if data.require_clear_path and not _path_is_clear():
		# Huỷ ở frame sau: chuyển state ngay trong enter() làm signal state_changed phát sai thứ tự
		_aborted = true
		return
	var to_target := enemy.direction_to_target()
	if not to_target.is_zero_approx():
		enemy.face_instantly(to_target)
	_direction = enemy.get_facing_direction()
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.set_telegraph(true)
	_enter_phase(Phase.WINDUP)
	enemy.play_action(data.windup_animation)
	_play_sfx(windup_sfx)


func exit() -> void:
	enemy.set_telegraph(false)
	enemy.hitbox.deactivate()
	enemy.hitbox.set_reach(enemy.data.hitbox_reach)
	if dash_trail:
		dash_trail.emitting = false
	if clearance:
		clearance.target_position = Vector3(0.0, 0.0, _clearance_length)
	enemy.start_attack_cooldown()


func physics_update(delta: float) -> void:
	if _aborted:
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)
		return
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			_update_windup(delta)
		Phase.DASH:
			_update_dash(delta)
		Phase.SLASH:
			_update_slash(delta)


# ---------- Pha ----------

func _enter_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	phase_started.emit(phase)


func _update_windup(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	if not _direction_locked:
		if _phase_time < _track_time:
			enemy.face_direction(enemy.direction_to_target(), delta)
		else:
			_lock_direction()
	if _phase_time >= _windup_time:
		_enter_dash()


## Chốt hướng và quãng lướt: từ đây player chỉ còn phản xạ để né
func _lock_direction() -> void:
	_direction_locked = true
	_direction = enemy.get_facing_direction()
	_dash_distance = clampf(enemy.distance_to_target() - data.stop_distance, 0.0, data.dash_max_distance)


func _enter_dash() -> void:
	if not _direction_locked:
		_lock_direction()
	enemy.set_telegraph(false)
	# dash_speed ~0 thì không lướt được: chém tại chỗ thay vì đứng chờ hết giờ
	if _dash_distance <= STOP_EPSILON or data.dash_speed <= MIN_DASH_SPEED:
		_enter_slash()
		return
	_enter_phase(Phase.DASH)
	_traveled = 0.0
	_last_position = enemy.global_position
	enemy.play_action(data.dash_animation)
	if dash_trail:
		dash_trail.emitting = true
	_play_sfx(dash_sfx)


func _update_dash(delta: float) -> void:
	enemy.apply_gravity(delta)
	# Đo bằng độ dời thật, không phải speed * delta, vì tường có thể chặn giữa chừng
	var moved := enemy.global_position - _last_position
	moved.y = 0.0
	_traveled += moved.length()
	_last_position = enemy.global_position
	# Quãng còn được phép đi: hết quãng đã chốt, hoặc tới sát player (vị trí hiện tại)
	var allowed := minf(_dash_distance - _traveled, enemy.distance_to_target() - data.stop_distance)
	var timeout := data.dash_max_distance / maxf(data.dash_speed, MIN_DASH_SPEED) + data.dash_timeout_extra
	if allowed <= STOP_EPSILON or enemy.is_on_wall() or _phase_time >= timeout or _ledge_ahead():
		_enter_slash()
		return
	# Không đi quá quãng còn lại trong một frame (dash_speed lớn không làm vượt đích)
	var speed := minf(data.dash_speed, allowed / delta)
	enemy.velocity.x = _direction.x * speed
	enemy.velocity.z = _direction.z * speed


func _enter_slash() -> void:
	_enter_phase(Phase.SLASH)
	_hit_started = false
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	if dash_trail:
		dash_trail.emitting = false
	enemy.hitbox.set_reach(_safe_reach())
	enemy.play_action(_slash.animation, _slash.anim_speed)
	_play_sfx(slash_sfx)


func _update_slash(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	if _phase_time >= _slash.active_start and not _hit_started:
		_hit_started = true
		# Hộp chém rộng: đứng chéo với rào thì góc hộp thò qua rào. Có vật chắn giữa quái và player thì
		# vẫn vung (có hình) nhưng không bật hộp, để không trúng xuyên tường / rào
		if not _target_blocked():
			enemy.hitbox.activate(_slash)
	if _phase_time >= _slash.active_end and enemy.hitbox.is_active():
		enemy.hitbox.deactivate()
	if _phase_time >= _slash.duration:
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)


# ---------- Kiểm tra môi trường (chỉ quét khi cần, probe/clearance luôn tắt ngoài các lần này) ----------

## Có vật chắn giữa quái và player không (tính tới cách player path_block_tolerance)
func _path_is_clear() -> bool:
	if clearance == null or not enemy.has_target():
		return true
	var to_target := enemy.direction_to_target()
	if to_target.is_zero_approx():
		return true
	enemy.face_instantly(to_target)
	var length := enemy.distance_to_target() - data.path_block_tolerance - _clearance_front
	if length <= 0.0:
		return true
	# Quét thẳng tới ngang ngực player (kể cả chênh cao): player đứng trên dốc thì quét ngang đâm vào mặt dốc
	var aim := enemy.target.global_position + Vector3.UP * (clearance.global_position.y - enemy.global_position.y)
	_aim_clearance(aim - clearance.global_position, length)
	clearance.force_shapecast_update()
	var blocked := clearance.is_colliding()
	clearance.target_position = Vector3(0.0, 0.0, _clearance_length)
	return not blocked


## Tia từ ngực quái tới ngực player có trúng tường / khối chặn (world + player_blocker) không. Chỉ bắn 1 lần mỗi đòn
func _target_blocked() -> bool:
	if not enemy.has_target():
		return false
	var from := enemy.global_position + Vector3.UP * data.los_height
	var to := enemy.target.global_position + Vector3.UP * data.los_height
	var query := PhysicsRayQueryParameters3D.create(from, to, data.los_mask)
	query.exclude = [enemy.get_rid()]
	return not enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Tầm hộp chém sau khi trừ phần bị tường / rào chắn phía trước
func _safe_reach() -> float:
	var reach := enemy.data.hitbox_reach
	if clearance == null:
		return reach
	# Quét dọc theo mặt sàn đang đứng: trên dốc, quét ngang coi mặt dốc là tường và cắt cụt tầm chém
	var forward := enemy.get_facing_direction()
	if enemy.is_on_floor():
		forward = forward.slide(enemy.get_floor_normal())
	_aim_clearance(forward, _clearance_length)
	clearance.force_shapecast_update()
	if clearance.is_colliding():
		var safe := _clearance_front + clearance.get_closest_collision_safe_fraction() * _clearance_length
		reach = minf(reach, safe)
	clearance.target_position = Vector3(0.0, 0.0, _clearance_length)
	return reach


## Đặt hướng quét (toạ độ thế giới) cho hộp clearance; hộp vẫn giữ xoay theo Model
func _aim_clearance(global_direction: Vector3, length: float) -> void:
	if global_direction.is_zero_approx():
		clearance.target_position = Vector3(0.0, 0.0, length)
		return
	clearance.target_position = clearance.global_transform.basis.inverse() * (global_direction.normalized() * length)


func _ledge_ahead() -> bool:
	if not data.stop_at_ledge or ledge_probe == null:
		return false
	ledge_probe.force_raycast_update()
	return not ledge_probe.is_colliding()


func _play_sfx(player: AudioStreamPlayer3D) -> void:
	if player and player.stream:
		player.play()
