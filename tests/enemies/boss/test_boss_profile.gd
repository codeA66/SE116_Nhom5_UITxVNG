extends Node3D
## Kiểm tra model, các clip tương thích và VFX húc của Ngưu Vương Huyết Diệm.

const BOSS_PATH: String = "res://entities/bosses/boss_1/boss_1.tscn"
const VISUAL_PATH: String = "res://assets/models/bosses/boss_1/boss_profile/boss.tscn"
const VFX_PATH: String = "res://assets/models/bosses/boss_1/boss_profile/vfx/charge_vfx/charge_vfx.tscn"
const HIPS_PATH: NodePath = ^"Armature/Skeleton3D:mixamorig_Hips"
const POSITION_TOLERANCE: float = 0.0001
## GLB chưa tối ưu và thư viện nhập có sai số nội suy khoảng 1 mm theo hệ model.
const SOURCE_POSITION_TOLERANCE: float = 0.002
const REQUIRED_CLIPS: Array[StringName] = [&"Idle", &"Walk", &"FireballCast", &"JumpSlam", &"Roar", &"MagmaStomp", &"Death", &"Charge"]

var _failures: int = 0
var _impact_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(BOSS_PATH) as PackedScene
	_check(packed != null, "Nạp được scene boss")
	if packed == null:
		get_tree().quit(1)
		return
	var boss: Node3D = packed.instantiate() as Node3D
	(boss.get_node("ChargeController") as Node).set("enabled", false)
	add_child(boss)
	boss.set_physics_process(false)
	var player: AnimationPlayer = boss.get_node("AnimationPlayer") as AnimationPlayer
	_check(player.get_animation_list().size() == REQUIRED_CLIPS.size(), "Chỉ có 8 clip gameplay, không còn alias và Normal Attack")
	_check(not boss.has_node("StateMachine/Melee") and not boss.has_node("Model/MeleeHitbox"), "Không còn state/hitbox Melee")
	var model: Node3D = boss.get_node("Model/Visual/BossModel") as Node3D
	var skeleton: Skeleton3D = model.get_node("Armature/Skeleton3D") as Skeleton3D
	var vfx: Node3D = boss.get_node("Model/Visual/ChargeVFX") as Node3D
	_check(skeleton.get_bone_count() == 34, "Skeleton có 34 xương")
	_check(player.get_node(player.root_node) == model, "Animation điều khiển đúng visual")
	_test_in_place(model, player, skeleton)
	for clip: StringName in REQUIRED_CLIPS:
		_check(player.has_animation(clip), "Có clip " + String(clip))
		if not player.has_animation(clip):
			continue
		var animation: Animation = player.get_animation(clip)
		var should_loop: bool = clip in [&"Idle", &"Walk"]
		_check((animation.loop_mode == Animation.LOOP_LINEAR) == should_loop, "Chế độ lặp " + String(clip))
		for track: int in animation.get_track_count():
			var path: NodePath = animation.track_get_path(track)
			_check(model.has_node(NodePath(String(path).get_slice(":", 0))), "Đường dẫn track " + String(path))
			if path.get_subname_count() > 0 and animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				_check(skeleton.find_bone(path.get_subname(0)) >= 0, "Đích xương " + String(path.get_subname(0)))
		player.play(clip, 0.0)
		for sample: int in range(9):
			player.seek(animation.length * float(sample) / 8.0, true)
			for bone: int in skeleton.get_bone_count():
				_check(skeleton.get_bone_global_pose(bone).origin.is_finite(), "Pose hữu hạn " + String(clip))
	player.play(&"Idle", 0.0)
	player.advance(0.0)
	_check(not vfx.is_processing(), "Charge VFX nghỉ khi Idle")
	player.play(&"Charge", 0.0)
	player.advance(0.8)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(vfx.is_processing(), "Charge VFX tự kích hoạt")
	_check((vfx.get_node("WindAtHorns") as Node3D).visible, "Gió hiện trong khoảng húc")
	vfx.connect("impact", _on_impact)
	var impact_time: float = float(vfx.get("impact_time"))
	vfx.call("set_charge_time", impact_time - 0.05)
	vfx.call("set_charge_time", impact_time + 0.01)
	vfx.call("set_charge_time", impact_time + 0.02)
	_check(_impact_count == 1, "Impact phát đúng một lần mỗi lượt")
	vfx.call("set_charge_time", 0.0)
	vfx.call("set_charge_time", impact_time + 0.01)
	_check(_impact_count == 2, "Impact hoạt động khi phát lại")
	vfx.call("stop_charge")
	_check(not vfx.is_processing(), "VFX dừng xử lý sau stop")
	for size: float in [0.1, 4.0]:
		vfx.set("effect_scale", size)
		vfx.call("set_charge_time", 0.8)
		var wind: Node3D = vfx.get_node("WindAtHorns") as Node3D
		_check(wind.scale.is_equal_approx(Vector3.ONE * size), "Tỉ lệ VFX " + str(size))
		var head: int = skeleton.find_bone("mixamorig_Head")
		var head_position: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(head).origin)
		_check(wind.global_position.distance_to(head_position) < 0.001, "VFX bám xương đầu " + str(size))
	vfx.set("effect_scale", 1.0)
	vfx.set("forward_positive_z", false)
	vfx.call("set_charge_time", 0.8)
	_check((vfx.get_node("WindAtHorns") as Node3D).scale.is_equal_approx(Vector3(1.0, 1.0, -1.0)), "VFX hỗ trợ hướng -Z")
	vfx.set("forward_positive_z", true)
	vfx.call("stop_charge")
	player.play(&"Idle", 0.0)
	player.advance(0.0)
	for count: int in [1, 24]:
		var effect: Node3D = (load(VFX_PATH) as PackedScene).instantiate() as Node3D
		effect.set("animation_player_path", player.get_path())
		effect.set("skeleton_path", skeleton.get_path())
		effect.set("wind_streak_count", count)
		effect.set("foot_particle_count", 1 if count == 1 else 48)
		effect.set("impact_particle_count", 1 if count == 1 else 64)
		add_child(effect)
		_check(effect.get_node("WindAtHorns").get_child_count() == count, "Số vệt gió " + str(count))
		_check((effect.get_node("FootDust0") as CPUParticles3D).amount == (1 if count == 1 else 48), "Giới hạn bụi chân " + str(count))
		_check((effect.get_node("ImpactDust") as CPUParticles3D).amount == (1 if count == 1 else 64), "Giới hạn bụi va chạm " + str(count))
		effect.set("auto_sync", false)
		effect.set("charge_duration", 0.1)
		effect.set("impact_time", 0.05)
		effect.call("play_charge")
		await get_tree().create_timer(0.18).timeout
		_check(not effect.is_processing(), "VFX thủ công dừng theo thời lượng riêng")
		effect.free()
	var standalone: Node3D = (load(VISUAL_PATH) as PackedScene).instantiate() as Node3D
	add_child(standalone)
	var standalone_player: AnimationPlayer = standalone.get_node("AnimationPlayer") as AnimationPlayer
	_check(standalone_player.has_animation(&"Charge"), "Visual độc lập có Charge")
	_check(standalone.has_node("ChargeVFX"), "Visual độc lập giữ Charge VFX")
	_check(ResourceLoader.exists("res://assets/models/bosses/boss_1/boss_profile/vfx/fireball_vfx/scene.gltf"), "Giữ VFX fireball")
	standalone.queue_free()
	await _test_action_timing(boss, player)
	await _test_jump_alignment(boss, player, model, skeleton)
	_test_health_gates(boss, player)
	boss.queue_free()
	print("BOSS_PROFILE_RESULT failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _on_impact() -> void:
	_impact_count += 1

func _test_in_place(model: Node3D, player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	var source_player: AnimationPlayer = model.get_node("AnimationPlayer") as AnimationPlayer
	var source_idle: Animation = source_player.get_animation(&"Idle")
	var idle_track: int = source_idle.find_track(HIPS_PATH, Animation.TYPE_POSITION_3D)
	var skeleton_to_model: Transform3D = model.global_transform.affine_inverse() * skeleton.global_transform
	var reference: Vector3 = skeleton_to_model * source_idle.position_track_interpolate(idle_track, 0.0)
	var hips: int = skeleton.find_bone("mixamorig_Hips")
	_check(skeleton.get_bone_parent(hips) == -1, "Hips là xương gốc của rig nguồn")
	var maximum_source_drift: float = 0.0
	var maximum_gameplay_drift: float = 0.0
	for clip: StringName in source_player.get_animation_list():
		if clip == &"RESET":
			continue
		var source: Animation = source_player.get_animation(clip)
		var names: Dictionary[StringName, StringName] = {&"Cast_Fireball": &"FireballCast", &"Jump_Attack": &"JumpSlam", &"Roaring": &"Roar", &"Taunt": &"MagmaStomp", &"Dying": &"Death"}
		var gameplay_clip: StringName = names.get(clip, clip)
		if not player.has_animation(gameplay_clip):
			_check(clip in [&"Normal_Attack_1", &"Normal_Attack_2"], "Chỉ bỏ hai clip cận chiến")
			continue
		var output: Animation = player.get_animation(gameplay_clip)
		var source_track: int = source.find_track(HIPS_PATH, Animation.TYPE_POSITION_3D)
		_check(is_equal_approx(source.length, output.length), "Giữ thời lượng " + String(clip))
		player.play(gameplay_clip, 0.0)
		var samples: int = ceili(source.length * 30.0)
		for sample: int in range(samples + 1):
			var time: float = minf(float(sample) / 30.0, source.length - 0.0001)
			player.seek(time, true)
			var actual: Vector3 = model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hips).origin))
			var original: Vector3 = skeleton_to_model * source.position_track_interpolate(source_track, time)
			var original_drift: float = Vector2(original.x - reference.x, original.z - reference.z).length()
			var actual_drift: float = Vector2(actual.x - reference.x, actual.z - reference.z).length()
			maximum_source_drift = maxf(maximum_source_drift, original_drift * model.scale.x)
			maximum_gameplay_drift = maxf(maximum_gameplay_drift, actual_drift * model.scale.x)
			_check(actual_drift < POSITION_TOLERANCE, "Hips bám thân va chạm " + String(clip))
			if clip == &"Jump_Attack":
				_check(actual.y <= reference.y + POSITION_TOLERANCE, "Không cộng độ cao nhảy từ animation")
				if original.y < reference.y - 0.001:
					_check(absf(actual.y - original.y) < SOURCE_POSITION_TOLERANCE, "Giữ cúi người lúc đáp")
			else:
				_check(absf(actual.y - original.y) < SOURCE_POSITION_TOLERANCE, "Giữ nhún, cúi và ngã " + String(clip))
	_check(maximum_source_drift > 1.0, "GLB vẫn chứa chuyển vị gốc")
	print("IN_PLACE source_max_horizontal_m=", maximum_source_drift, " gameplay_max_horizontal_m=", maximum_gameplay_drift)
	player.play(&"Idle", 0.0)
	player.advance(0.0)
	player.play(&"JumpSlam", 0.15)
	for frame: int in range(12):
		player.advance(1.0 / 60.0)
		var actual: Vector3 = model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hips).origin))
		_check(Vector2(actual.x - reference.x, actual.z - reference.z).length() < POSITION_TOLERANCE, "Không trôi Hips khi blend clip")

func _test_action_timing(boss: Node3D, player: AnimationPlayer) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(20.0, 0.2, 20.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.position.y = -0.1
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 20
	add_child(health)
	var target: HurtboxComponent = HurtboxComponent.new()
	target.health = health
	target.collision_layer = 2
	target.collision_mask = 0
	var target_shape: CollisionShape3D = CollisionShape3D.new()
	var target_box: BoxShape3D = BoxShape3D.new()
	target_box.size = Vector3(0.5, 0.5, 0.5)
	target_shape.shape = target_box
	target.add_child(target_shape)
	add_child(target)
	target.position = Vector3(0.0, 1.5, 1.2)
	var machine: StateMachine = boss.get_node("StateMachine") as StateMachine
	var pool: ObjectPool = boss.get_node("FireballPool") as ObjectPool
	target.position = Vector3(8.0, 1.5, 8.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	pool.release_all()
	boss.set("current_phase", 1)
	boss.set_physics_process(true)
	machine.transition_to(&"CastFireball")
	var cast: Node = machine.get_node("CastFireball")
	var shoot_time: float = float(cast.get("shoot_time")) / float(boss.call("get_current_anim_speed"))
	var elapsed: float = 0.0
	var first_projectile: float = -1.0
	while elapsed < shoot_time + 0.15:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if first_projectile < 0.0 and pool.get_active_count() > 0:
			first_projectile = elapsed
		if elapsed < shoot_time - 0.06:
			_check(pool.get_active_count() == 0, "Chưa phóng đạn khi tay còn tụ lực")
	boss.set_physics_process(false)
	_check(absf(first_projectile - shoot_time) < 0.06, "Cầu lửa thật xuất hiện đúng mốc chưởng")
	_check(pool.get_active_count() == 1, "Mỗi lần chưởng chỉ phóng một cầu lửa")
	print("FIREBALL first_spawn=", first_projectile, " expected=", shoot_time)
	pool.release_all()
	machine.transition_to(&"Idle")
	target.queue_free()
	health.queue_free()
	floor_body.queue_free()

func _test_health_gates(boss: Node3D, player: AnimationPlayer) -> void:
	for setting: String in ["phase2_grunt_count", "phase2_shield_count", "phase2_caster_count", "phase3_grunt_count", "phase3_shield_count", "phase3_caster_count"]:
		(boss.get_node("Minions") as BossMinionController).set(setting, 0)
	var health: HealthComponent = boss.get_node("HealthComponent") as HealthComponent
	var hurtbox: HurtboxComponent = boss.get_node("HurtboxComponent") as HurtboxComponent
	var max_health: int = health.max_health
	var first: DamageInfo = DamageInfo.new(int(max_health * 0.5), DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	first.ignores_invincibility = true
	hurtbox.receive_hit(first)
	_check(bool(boss.get("is_shielded")) and int(boss.get("current_phase")) == 2, "Khóa máu 50% và bật khiên")
	_check(player.current_animation == &"Roar", "Chuyển phase phát alias Buff mới")
	boss.call("on_fireball_hit", null)
	_check(player.current_animation == &"Idle", "Phá khiên trở lại Idle như gameplay hiện tại")
	var second: DamageInfo = DamageInfo.new(int(max_health * 0.3), DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	second.ignores_invincibility = true
	hurtbox.receive_hit(second)
	_check(int(boss.get("current_phase")) == 3 and int(boss.get("shield_stacks")) == 2, "Khóa máu 20% và bật hai lớp khiên")
	boss.call("on_fireball_hit", null)
	boss.call("on_fireball_hit", null)
	_check(not bool(boss.get("is_shielded")) and is_zero_approx(hurtbox.invincibility_time), "Phá khiên phase cuối")
	var kill: DamageInfo = DamageInfo.new(health.current_health, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	kill.ignores_invincibility = true
	hurtbox.receive_hit(kill)
	_check(health.is_dead() and player.current_animation == &"Death", "Boss chết bằng animation mới")

func _test_jump_alignment(boss: Node3D, player: AnimationPlayer, model: Node3D, skeleton: Skeleton3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(40.0, 0.2, 40.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.position.y = -0.1
	var target: Marker3D = Marker3D.new()
	add_child(target)
	var machine: StateMachine = boss.get_node("StateMachine") as StateMachine
	var hips: int = skeleton.find_bone("mixamorig_Hips")
	player.play(&"Idle", 0.0)
	player.seek(0.0, true)
	var reference: Vector3 = model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hips).origin))
	var original_scale: Vector3 = boss.scale
	var maximum_drift: float = 0.0
	for phase: int in [1, 3]:
		boss.set("current_phase", phase)
		boss.scale = original_scale * (0.5 if phase == 1 else 2.0)
		boss.position = Vector3.ZERO
		boss.set("velocity", Vector3.ZERO)
		target.position = Vector3(8.0, 0.0, 0.0) if phase == 1 else Vector3(0.0, 0.0, -8.0)
		boss.set("target_player", target)
		boss.set_physics_process(true)
		machine.transition_to(&"JumpSlam")
		var speed: float = float(boss.call("get_current_anim_speed"))
		var duration: float = player.get_animation(&"JumpSlam").length / speed + 0.1
		var elapsed: float = 0.0
		var highest_body: float = 0.0
		while elapsed < duration:
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
			highest_body = maxf(highest_body, boss.global_position.y)
			var actual: Vector3 = model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hips).origin))
			var drift: float = Vector2(actual.x - reference.x, actual.z - reference.z).length()
			maximum_drift = maxf(maximum_drift, drift)
			_check(drift < POSITION_TOLERANCE, "Nhảy thật không trôi khỏi thân khi xoay hoặc đổi scale")
			_check(actual.y <= reference.y + POSITION_TOLERANCE, "Nhảy thật không bị nâng thêm bởi Hips")
			if machine.current_state.name != &"JumpSlam":
				break
		boss.set_physics_process(false)
		_check(highest_body > 0.1, "Controller vẫn đưa boss bay lên ở phase " + str(phase))
		_check(boss.global_position.distance_to(target.global_position) < 0.3, "Boss đáp đúng vị trí mục tiêu ở phase " + str(phase))
		print("JUMP phase=", phase, " scale=", boss.scale.x, " body_peak_m=", highest_body, " landing=", boss.global_position, " max_hips_drift_model=", maximum_drift)
		machine.transition_to(&"Idle")
	boss.scale = original_scale
	boss.position = Vector3.ZERO
	boss.set("target_player", null)
	boss.set("current_phase", 1)
	target.queue_free()
	floor_body.queue_free()

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		if _failures <= 10:
			push_error("FAIL: " + description)
