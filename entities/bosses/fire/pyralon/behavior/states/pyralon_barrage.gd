extends PyralonAttackState

enum Stage { LAUNCH, FIRE, LAND }

var _stage: Stage
var _next_white: float
var _shots: int
var _landings: PackedVector3Array
var _gold_sent: int
var _aim_point: Vector3
var _is_p2: bool = false
var _duration: float = 6.0


func enter(previous: StringName) -> void:
	super(previous)
	_stage = Stage.LAUNCH
	_next_white = 0.0
	_shots = 0
	_gold_sent = 0
	_is_p2 = bird.is_phase_two()
	_duration = bird.profile.p2_barrage_duration if _is_p2 else bird.profile.barrage_duration
	# Giữ nguyên số lông vàng mức Phase 1 (20 lông) cho chiêu mưa lông để không kéo dài thời gian xử lý chiêu hiệu lệnh sau đó.
	var gold_count := bird.profile.barrage_gold_count
	var spacing := bird.profile.gold_spacing
	_landings = bird.field.gold_spots(gold_count, spacing)
	_aim_point = bird.target.global_position + Vector3.UP * 0.64 if bird.has_target() else bird.global_position + bird.get_facing_direction() * 6.0


func physics_update(delta: float) -> void:
	tick_pose(delta)
	if bird.has_target() and _stage != Stage.LAND:
		bird.face_direction((bird.target.global_position - bird.global_position).slide(Vector3.UP).normalized(), delta)
	stay_in_place(delta, bird.pose.displacement().y > 0.14)
	match _stage:
		Stage.LAUNCH:
			if bird.has_target():
				_aim_point = bird.target.global_position + Vector3.UP * 0.64
			if elapsed >= animator.current_animation_length:
				_play_stage(Stage.FIRE, PyralonRig.BARRAGE)
		Stage.FIRE:
			_fire_barrage(delta)
			if elapsed >= _duration:
				if _is_p2:
					# Vừa hết 5s mưa lông đỏ -> kích hoạt bứng dần từng lông đỏ cắm sàn bắn lại song song trong lúc Pyralon đáp đất đánh tiếp!
					bird.field.queue_ground_crimson_uproot()
				_play_stage(Stage.LAND, PyralonRig.LAND)
		Stage.LAND:
			if elapsed >= animator.current_animation_length:
				bird.finish_move(skill)


func _play_stage(stage: Stage, clip: StringName) -> void:
	_stage = stage
	elapsed = 0.0
	bird.play_action(clip, 1.0, 0.08)


func _fire_barrage(delta: float) -> void:
	if bird.has_target():
		var target_pos := bird.target.global_position + Vector3.UP * 0.64
		# Điểm ngắm bám đuổi mượt theo vị trí thật của player: đứng im sẽ ăn trọn chùm lông, chạy/dash liên tục mới né kịp.
		_aim_point = _aim_point.move_toward(target_pos, bird.profile.barrage_track_speed * delta)
		var interval := maxf(bird.profile.barrage_shot_interval, 0.025)
		var speed := bird.player_speed() * bird.profile.barrage_speed_ratio
		if _is_p2:
			speed *= bird.profile.crimson_speed_mult
		var radius := maxf(bird.profile.barrage_cluster_radius, 0.0)
		while elapsed >= _next_white:
			var muzzle := bird.pose.wing_point(_shots % 2, true)
			var angle := randf() * TAU
			var spread := sqrt(randf()) * radius
			var aim := _aim_point + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
			if _is_p2:
				var crimson := bird.field.new_crimson_ground(muzzle)
				crimson.fire_crimson_ground((aim - muzzle).normalized(), speed)
			else:
				var white := bird.field.new_white(muzzle)
				white.fire((aim - muzzle).normalized(), speed)
			_next_white += interval
			_shots += 1
	while _gold_sent < _landings.size() and elapsed >= (_gold_sent + 0.5) * _duration / _landings.size():
		bird.field.drop_gold(bird.pose.wing_point(_gold_sent % 2, false), _landings[_gold_sent])
		_gold_sent += 1
