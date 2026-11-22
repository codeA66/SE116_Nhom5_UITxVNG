extends EnemyState
## Chiêu Phase 2 mới #2: Furious Cross-Claw & Magma Fissures (Phẫn Nộ Song Trảo & Khe Nứt 30s).
## Tái sử dụng animation Raged (vồ 2 lần trước mặt):
## 1. Cảnh báo 3 vết cào ngang (vết giữa bự hơn) 0.5s dưới chân player -> cào trái sang phải gây sát thương + nứt sàn + khói/đất đá văng lên trời.
## 2. Nghỉ 1 nhịp -> chạy nhịp cào thứ 2 theo chiều dọc tương tự.
## 3. Cả 2 bộ vết nứt tồn tại 30 giây, cứ mỗi 2 giây sáng dần rồi phun lửa từ khe nứt lên gây sát thương!

enum Stage { SWIPE1_WARN, SWIPE1_STRIKE, PAUSE_BEAT, SWIPE2_WARN, SWIPE2_STRIKE, REPEAT_GAP }

const RAGED_HIT1_START := 0.94
const RAGED_HIT1_END := 1.24
const RAGED_PAUSE_END := 1.32
const RAGED_HIT2_START := 1.54
const RAGED_END := 2.667
const REPEAT_GAP_DURATION := 0.34

var _actor: FireSabretooth
var _stage: Stage = Stage.SWIPE1_WARN
var _time: float = 0.0
var _repeat_index: int = 0
var _spot: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.RIGHT
var _anim_len: float = RAGED_END


func _ready() -> void:
	super()
	_actor = enemy as FireSabretooth


func enter(_previous: StringName) -> void:
	_repeat_index = 0
	_actor.hitbox.cancel()
	_actor.velocity = Vector3.ZERO
	_actor.phase.show_flame_form()
	_start_repeat()


func _start_repeat() -> void:
	_stage = Stage.SWIPE1_WARN
	_time = 0.0
	if _actor.has_target():
		_actor.face_instantly(_actor.direction_to_target())
	_actor.motion.play(&"Raged", 0.0)
	_anim_len = maxf(_actor.motion.content_length(), 1.8)
	_actor.animation_player().pause()
	_seek_raged(0.0)
	_lock_swipe_zone(true)


func exit() -> void:
	_actor.p2_combat.hide_claw_warning()
	_actor.animation_player().speed_scale = 1.0


func physics_update(delta: float) -> void:
	_actor.apply_gravity(delta)
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	_time += delta
	var config := _actor.profile
	var warn_dur := maxf(config.cross_claw_warn_time, 0.10)
	var pause_dur := maxf(config.cross_claw_pause_time, 0.08)

	match _stage:
		Stage.SWIPE1_WARN:
			var p := clampf(_time / warn_dur, 0.0, 1.0)
			_seek_raged(lerpf(0.0, RAGED_HIT1_START, p))
			_actor.p2_combat.show_claw_warning(_spot, _dir, config.cross_claw_length, config.cross_claw_width, p)
			if p >= 1.0:
				_stage = Stage.SWIPE1_STRIKE
				_time = 0.0
				_actor.p2_combat.trigger_claw_swipe(_spot, _dir, config.cross_claw_length, config.cross_claw_width)
		Stage.SWIPE1_STRIKE:
			var p := clampf(_time / 0.26, 0.0, 1.0)
			_seek_raged(lerpf(RAGED_HIT1_START, RAGED_HIT1_END, p))
			if p >= 1.0:
				_stage = Stage.PAUSE_BEAT
				_time = 0.0
		Stage.PAUSE_BEAT:
			# Nghỉ 1 nhịp đầy uy lực giữa 2 cú cào, xoay nhẹ hướng về vị trí mới của player.
			if _actor.has_target():
				_actor.face_direction(_actor.direction_to_target(), delta)
			var p := clampf(_time / pause_dur, 0.0, 1.0)
			_seek_raged(lerpf(RAGED_HIT1_END, RAGED_PAUSE_END, p))
			if p >= 1.0:
				_stage = Stage.SWIPE2_WARN
				_time = 0.0
				_lock_swipe_zone(false)
		Stage.SWIPE2_WARN:
			var p := clampf(_time / warn_dur, 0.0, 1.0)
			_seek_raged(lerpf(RAGED_PAUSE_END, RAGED_HIT2_START, p))
			_actor.p2_combat.show_claw_warning(_spot, _dir, config.cross_claw_length, config.cross_claw_width, p)
			if p >= 1.0:
				_stage = Stage.SWIPE2_STRIKE
				_time = 0.0
				_actor.p2_combat.trigger_claw_swipe(_spot, _dir, config.cross_claw_length, config.cross_claw_width)
		Stage.SWIPE2_STRIKE:
			var p := clampf(_time / 0.72, 0.0, 1.0)
			_seek_raged(lerpf(RAGED_HIT2_START, _anim_len, p))
			if p >= 1.0:
				_repeat_index += 1
				if _repeat_index < maxi(config.cross_claw_repeats, 1):
					_stage = Stage.REPEAT_GAP
					_time = 0.0
				else:
					_finish()
		Stage.REPEAT_GAP:
			if _actor.has_target():
				_actor.face_direction(_actor.direction_to_target(), delta)
			if _time >= REPEAT_GAP_DURATION:
				_start_repeat()


func _lock_swipe_zone(horizontal: bool) -> void:
	var forward := _actor.direction_to_target() if _actor.has_target() else _actor.get_facing_direction()
	forward = forward.slide(Vector3.UP)
	if forward.length_squared() < 0.001:
		forward = Vector3.BACK
	else:
		forward = forward.normalized()
	_spot = _actor.target.global_position if _actor.has_target() else (_actor.global_position + forward * 4.5)
	_spot = _actor.p2_combat.floor_at(_spot)
	# Cú 1: ngang (trái -> phải vuông góc hướng nhìn); Cú 2: dọc (dọc trục từ boss -> player, vuông góc cú 1!).
	if horizontal:
		_dir = Vector3.UP.cross(forward).normalized()
	else:
		_dir = forward


func _seek_raged(clip_t: float) -> void:
	_actor.animation_player().seek(_actor.motion.bridge_duration + clampf(clip_t, 0.0, _anim_len), true)


func _finish() -> void:
	_actor.p2_combat.hide_claw_warning()
	if _actor.manual_skill:
		_actor.finish_phase_two_move()
	else:
		_actor.finish_attack(true)
		_actor.rest_then_phase_two(&"TigerFireBeam")
