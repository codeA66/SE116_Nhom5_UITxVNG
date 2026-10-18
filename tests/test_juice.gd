extends Node3D
## Test hiệu ứng "juice": rung màn hình, tia lửa trúng đòn, quái chết, vệt chém, viền đỏ, slow motion.
## Headless:  godot --headless --path . res://tests/test_juice.tscn
## Chụp ảnh: godot --path . --fixed-fps 60 --resolution 1280x720 res://tests/test_juice.tscn -- visual
## (ảnh lưu vào thư mục biến môi trường SHOT_DIR, mặc định user://shots). APPDATA nên trỏ vào .godot/...
## Không ghi save: player chỉ đứng yên.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/enemy_1/enemy_1.tscn")
const BEARER_SCENE: PackedScene = preload("res://entities/enemies/shield_bearer/shield_bearer.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SLASH_1: AttackData = preload("res://resources/attacks/sword_slash_1.tres")
const FLOOR_SIZE := Vector3(80.0, 1.0, 80.0)
const EPS := 0.0001

var _failed: bool = false
var _visual: bool = false
var _shot_dir: String = ""
var _floor_mesh: MeshInstance3D


func _ready() -> void:
	_visual = "visual" in OS.get_cmdline_user_args()
	_build_world()
	_run.call_deferred()


func _run() -> void:
	await get_tree().physics_frame
	if _visual:
		await _capture_all2()
	else:
		await _test_camera_shake()
		await _test_trauma_clamp()
		await _test_pool_hits()
		await _test_enemy_hit_and_block()
		await _test_blood()
		await _test_enemy_death()
		await _test_slow_motion()
		await _test_extreme()
		await _test_slash_and_vignette()
	print("JUICE_CHECK ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


# ---------- Rung camera ----------

func _test_camera_shake() -> void:
	var cam := Camera3D.new()
	cam.h_offset = 0.1
	cam.v_offset = -0.05
	cam.rotation.z = 0.02
	add_child(cam)
	var shake := CameraShake.new()
	cam.add_child(shake)
	await get_tree().process_frame
	_check(not shake.is_processing(), "chưa có trauma: CameraShake tắt process")
	ScreenShake.add_trauma(0.6)
	var max_dev := 0.0
	var frames := 0
	while ScreenShake.trauma > 0.0 and frames < 600:
		await get_tree().process_frame
		frames += 1
		max_dev = maxf(max_dev, absf(cam.h_offset - 0.1))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(max_dev > 0.005, "trauma 0.6: camera lệch thật (độ lệch lớn nhất %.3f)" % max_dev)
	_check(max_dev <= shake.max_offset + EPS, "độ lệch không vượt max_offset (%.3f <= %.2f)" % [max_dev, shake.max_offset])
	print("INFO trauma 0.6 giảm về 0 sau %d frame" % frames)
	_check(ScreenShake.trauma == 0.0, "trauma về 0")
	_check(is_equal_approx(cam.h_offset, 0.1) and is_equal_approx(cam.v_offset, -0.05) and is_equal_approx(cam.rotation.z, 0.02), "camera trở lại đúng offset gốc (bất đối xứng 0.1 / -0.05 / 0.02)")
	_check(not shake.is_processing() and not ScreenShake.is_processing(), "hết trauma: tắt process cả CameraShake lẫn ScreenShake")
	# Thông số cực đoan: offset rất lớn, tần số rất cao, roll lớn
	shake.max_offset = 5.0
	shake.max_roll_degrees = 45.0
	shake.frequency = 500.0
	ScreenShake.add_trauma(1.0)
	var worst_h := 0.0
	var worst_roll := 0.0
	var finite := true
	for i in 30:
		await get_tree().process_frame
		worst_h = maxf(worst_h, absf(cam.h_offset - 0.1))
		worst_roll = maxf(worst_roll, absf(cam.rotation.z - 0.02))
		finite = finite and is_finite(cam.h_offset) and is_finite(cam.rotation.z)
	_check(finite and worst_h <= 5.0 + EPS and worst_roll <= deg_to_rad(45.0) + EPS, "cực đoan (5 m, 45 độ, 500 Hz): hữu hạn, nằm trong biên (h %.2f, roll %.1f độ)" % [worst_h, rad_to_deg(worst_roll)])
	# Tắt hẳn rung
	shake.max_offset = 0.0
	shake.max_roll_degrees = 0.0
	ScreenShake.add_trauma(1.0)
	for i in 5:
		await get_tree().process_frame
	_check(is_equal_approx(cam.h_offset, 0.1) and is_equal_approx(cam.rotation.z, 0.02), "max_offset 0 và roll 0: camera đứng yên")
	ScreenShake.trauma = 0.0
	await get_tree().process_frame
	cam.queue_free()
	await get_tree().process_frame


func _test_trauma_clamp() -> void:
	ScreenShake.trauma = 0.0
	for i in 10:
		ScreenShake.add_trauma(1.0)
	_check(ScreenShake.trauma <= 1.0, "cộng 10 lần 1.0: trauma kẹp ≤ 1 (= %.2f)" % ScreenShake.trauma)
	ScreenShake.add_trauma(-5.0)
	ScreenShake.add_trauma(0.0)
	_check(ScreenShake.trauma == 1.0, "trauma âm / 0 bị bỏ qua")
	ScreenShake.trauma = 0.0
	await get_tree().process_frame


# ---------- Pool tia lửa ----------

func _test_pool_hits() -> void:
	var pool := CombatFx.get_hit_pool()
	var outside_before := _count_nodes_outside(CombatFx)
	var root_children := get_tree().root.get_child_count()
	for i in 30:
		CombatFx.spawn_hit(Vector3(i * 0.1, 1.0, 20.0), Vector3(1.0, 0.2, 0.0), Color(1.0, 0.7, 0.3))
		await get_tree().physics_frame
	_check(_count_nodes_outside(CombatFx) == outside_before, "30 hit liên tục: không thêm node nào ngoài pool (%d)" % outside_before)
	_check(get_tree().root.get_child_count() == root_children, "30 hit: không thêm con nào dưới root")
	var created := pool.get_total_created()
	print("INFO 30 hit liên tục (mỗi frame một cái): pool tạo tổng %d tia lửa, đang dùng %d" % [created, pool.get_active_count()])
	await _real_wait(1.0)
	_check(pool.get_active_count() == 0, "sau 1 s: mọi tia lửa đã tự nhả về pool qua finished (đang dùng %d)" % pool.get_active_count())
	# Đợt 2 cùng nhịp: pool dùng lại, không tạo thêm
	for i in 30:
		CombatFx.spawn_hit(Vector3(i * 0.1, 1.0, 20.0), Vector3.ZERO, Color.WHITE, 0.01)
		await get_tree().physics_frame
	_check(pool.get_total_created() <= created + 2, "đợt 2: pool dùng lại, tạo thêm tối đa 2 do lệch nhịp (%d so với %d)" % [pool.get_total_created(), created])
	# Thông số cực đoan
	CombatFx.spawn_hit(Vector3.ZERO, Vector3.ZERO, Color(10.0, 10.0, 10.0), 50.0)
	CombatFx.spawn_hit(Vector3.ZERO, Vector3.UP, Color(0.0, 0.0, 0.0, 0.0), 0.0)
	CombatFx.spawn_death(Vector3.ZERO, Color.WHITE, 0.0)
	CombatFx.spawn_death(Vector3.ZERO, Color(5.0, 5.0, 5.0), 30.0)
	await _real_wait(1.6)
	_check(pool.get_active_count() == 0 and CombatFx.get_death_pool().get_active_count() == 0, "scale 0 / 50, hướng 0, màu cực đoan: không lỗi, nhả hết về pool")


# ---------- Trúng đòn / bị đỡ ----------

func _test_enemy_hit_and_block() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(10.0, 0.0, 10.0)
	add_child(enemy)
	var bearer := BEARER_SCENE.instantiate() as ShieldBearer
	bearer.position = Vector3(-10.0, 0.0, 10.0)
	add_child(bearer)
	await _frames(3)
	ScreenShake.trauma = 0.0
	var hits_before := CombatFx.get_hit_pool().get_active_count()
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(5.0, 0.0, 0.0), null))
	_check(is_equal_approx(ScreenShake.trauma, 0.18), "quái trúng đòn: trauma 0.18 (= %.3f)" % ScreenShake.trauma)
	_check(CombatFx.get_hit_pool().get_active_count() == hits_before + 1, "quái trúng đòn: có 1 tia lửa")
	# Co dẹt: Visual đổi tỉ lệ ngay sau vài frame
	await _frames(3)
	var visual_scale: Vector3 = (enemy.get_node("Model/Visual") as Node3D).scale
	_check(not visual_scale.is_equal_approx(Vector3.ONE), "quái trúng đòn: model co dẹt (scale %s)" % visual_scale)
	ScreenShake.trauma = 0.0
	hits_before = CombatFx.get_hit_pool().get_active_count()
	# Quái đối diện +Z, đòn từ phía +Z đẩy về -Z: bị khiên đỡ
	bearer.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, -5.0), null))
	_check(is_equal_approx(ScreenShake.trauma, 0.1), "khiên đỡ đòn: trauma nhỏ 0.1 (= %.3f)" % ScreenShake.trauma)
	_check(CombatFx.get_hit_pool().get_active_count() == hits_before + 1, "khiên đỡ đòn: có tia lửa kim loại")
	_check(bearer.health.current_health == bearer.health.max_health, "khiên đỡ đòn: không mất máu")
	ScreenShake.trauma = 0.0
	# Đập khiên rung màn hình
	bearer.slammed.emit(bearer.global_position)
	_check(is_equal_approx(ScreenShake.trauma, bearer.slam_trauma), "đập khiên: trauma %.2f" % ScreenShake.trauma)
	ScreenShake.trauma = 0.0
	enemy.queue_free()
	bearer.queue_free()
	await _real_wait(0.6)


# ---------- Máu ----------

func _test_blood() -> void:
	var stains := CombatFx.get_blood_stains()
	var spray_pool := CombatFx.get_blood_pool()
	stains.clear()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(20.0, 0.0, 10.0)
	add_child(enemy)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(20.0, 0.0, 14.0)
	add_child(player)
	await _frames(3)
	var sprays_before := spray_pool.get_active_count()
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, 3.0), null))
	_check(spray_pool.get_active_count() == sprays_before, "player bị đánh: KHÔNG bắn máu")
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(5.0, 0.0, 0.0), null))
	_check(spray_pool.get_active_count() == sprays_before + 1, "quái bị chém: bắn máu")
	await _real_wait(1.6)
	var count := stains.get_active_count()
	_check(count >= 1 and count <= 3, "quái bị chém để lại %d vết máu trên sàn (3 giọt dự kiến)" % count)
	_check(spray_pool.get_active_count() == 0, "tia máu tự nhả về pool")
	# Giới hạn vết: 12 đòn x 3 vết = 36 > 24
	for i in 12:
		enemy.hurtbox.set_invincible(0.0)
		enemy.health.heal_full()
		enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(5.0, 0.0, 0.0), null))
		await _real_wait(0.1)
	await _real_wait(0.5)
	_check(stains.get_active_count() <= stains.get_capacity(), "tối đa %d vết: đang có %d, tái dùng vết cũ nhất" % [stains.get_capacity(), stains.get_active_count()])
	_check(stains.get_child_count() == stains.max_stains, "số node vết cố định %d" % stains.get_child_count())
	# Mờ dần và biến mất
	var hold := stains.hold_time
	var fade := stains.fade_time
	stains.hold_time = 0.2
	stains.fade_time = 0.2
	stains.clear()
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(5.0, 0.0, 0.0), null))
	await _real_wait(2.4)
	_check(stains.get_active_count() == 0 and not stains.is_processing(), "vết mờ hết rồi tắt process")
	stains.hold_time = hold
	stains.fade_time = fade
	# Đòn kết liễu: nhiều giọt + vũng dưới xác
	stains.clear()
	enemy.hurtbox.set_invincible(0.0)
	enemy.health.heal_full()
	enemy.health.take_damage(enemy.health.current_health - 1)
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(5.0, 0.0, 0.0), null))
	await _real_wait(1.2)
	count = stains.get_active_count()
	_check(count >= 8, "đòn kết liễu + vũng: %d vết (>= 8)" % count)
	_check(enemy.get_node("DeathEffectComponent").data.puddle_size > 0.0, "có vũng máu lớn dưới xác")
	stains.clear()
	enemy.queue_free()
	player.queue_free()
	ScreenShake.trauma = 0.0
	await _real_wait(0.3)


# ---------- Quái chết ----------

func _test_enemy_death() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(10.0, 0.0, -10.0)
	add_child(enemy)
	await _frames(3)
	ScreenShake.trauma = 0.0
	var model := enemy.get_node("Model") as Node3D
	var death_pool := CombatFx.get_death_pool()
	var data := enemy.get_node("DeathEffectComponent").data as DeathEffectData
	enemy.health.take_damage(enemy.health.max_health)
	_check(ScreenShake.trauma >= data.trauma - EPS, "quái chết: rung %.2f" % ScreenShake.trauma)
	_check(Engine.time_scale < 1.0, "quái chết: có hitstop (time_scale %.2f)" % Engine.time_scale)
	await _real_wait(data.kill_hitstop + 0.1)
	_check(Engine.time_scale == 1.0, "hitstop kết thúc, time_scale về 1")
	var peak := model.scale.x
	await _real_wait(data.grow_time + data.shrink_time + 0.15)
	_check(model.scale.x < 0.01, "model co về ~0 (scale %.4f; đỉnh phồng đã qua)" % model.scale.x)
	_check(death_pool.get_active_count() == 1, "có đúng 1 death burst đang chạy (%d)" % death_pool.get_active_count())
	await _real_wait(1.6)
	_check(death_pool.get_active_count() == 0, "death burst tự nhả về pool sau khi xong")
	# Màu riêng từng loại quái
	var bearer := BEARER_SCENE.instantiate() as ShieldBearer
	var bearer_data := bearer.get_node("DeathEffectComponent").data as DeathEffectData
	_check(bearer_data.color != data.color, "shield_bearer có màu chết riêng (%s khác %s)" % [bearer_data.color, data.color])
	bearer.free()
	ScreenShake.trauma = 0.0


# ---------- Cực đoan ----------

func _fx_node_count() -> int:
	return _count(CombatFx, null)


func _test_extreme() -> void:
	await _real_wait(0.5)
	var fx_nodes_before := _fx_node_count()
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	# 20 hit + 20 phun máu cùng một frame
	for i in 20:
		CombatFx.spawn_hit(Vector3(i * 0.2, 1.0, 30.0), Vector3(randf() - 0.5, 0.3, randf() - 0.5), Color(1.0, 0.7, 0.25), 1.0, 1.5 if i % 2 == 0 else 1.0)
		CombatFx.spawn_blood(Vector3(i * 0.2, 1.0, 30.0), Vector3(randf() - 0.5, 0.4, randf() - 0.5), Color(0.4, 0.02, 0.05), 0.0, 1.5, i % 3 == 0)
	# Có trần max_active_hits: vượt thì tái dùng hiệu ứng cũ nhất, số đang chạy không vượt trần
	var hit_cap := mini(20, CombatFx.max_active_hits)
	_check(CombatFx.get_hit_pool().get_active_count() == hit_cap, "20 hit cùng 1 frame: số tia lửa đang chạy = trần %d (%d)" % [hit_cap, CombatFx.get_hit_pool().get_active_count()])
	_check(CombatFx.get_blood_pool().get_active_count() <= CombatFx.max_active_blood, "20 phun máu cùng 1 frame: không vượt trần %d" % CombatFx.max_active_blood)
	await _real_wait(2.5)
	_check(CombatFx.get_hit_pool().get_active_count() == 0 and CombatFx.get_blood_pool().get_active_count() == 0, "20 hit + 20 máu cùng frame: nhả hết về pool")
	_check(CombatFx.get_blood_stains().get_active_count() <= CombatFx.get_blood_stains().get_capacity(), "vết máu không vượt giới hạn sau 20 phun")
	CombatFx.get_blood_stains().clear()
	# Quái chết khi đang bị gió thổi
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(30.0, 0.0, 30.0)
	add_child(enemy)
	await _frames(3)
	enemy.state_machine.transition_to(EnemyState.BLOWN)
	_check(enemy.state_machine.current_state.name == &"Blown", "quái đang ở trạng thái bị gió thổi")
	var deaths_before := CombatFx.get_death_pool().get_total_created()
	enemy.health.take_damage(enemy.health.max_health)
	await _real_wait(0.7)
	_check(CombatFx.get_death_pool().get_active_count() == 1 and (enemy.get_node("Model") as Node3D).scale.x < 0.01, "chết khi đang bị gió: vẫn co + nổ (death burst %d)" % CombatFx.get_death_pool().get_active_count())
	await _real_wait(1.5)
	# Quái chết rơi vực (KillZone gọi on_kill_zone_entered)
	var faller := ENEMY_SCENE.instantiate() as Enemy
	faller.position = Vector3(32.0, 0.0, 30.0)
	add_child(faller)
	await _frames(3)
	faller.on_kill_zone_entered()
	await _real_wait(0.7)
	_check(faller.is_dead() and CombatFx.get_death_pool().get_active_count() == 1, "chết rơi vực: có hiệu ứng chết (burst %d)" % CombatFx.get_death_pool().get_active_count())
	await _real_wait(1.5)
	# Hitstop chồng slow-mo chồng hitstop
	HitStop.stop(0.1)
	HitStop.slow_motion(0.3, 0.25)
	HitStop.stop(0.05)
	HitStop.slow_motion(0.2, 0.5)
	for i in 20:
		HitStop.stop(0.02)
	_check(Engine.time_scale < 1.0, "chồng hitstop / slow-mo: đang chậm (%.2f)" % Engine.time_scale)
	await _real_wait(0.6)
	_check(Engine.time_scale == 1.0, "chồng 24 lệnh hitstop / slow-mo: về đúng 1.0")
	# Đổi khu giữa lúc hiệu ứng đang chạy: khu bị xoá khi quái đang co / máu đang bay
	var zone := Node3D.new()
	add_child(zone)
	var victim := ENEMY_SCENE.instantiate() as Enemy
	victim.position = Vector3(34.0, 0.0, 30.0)
	zone.add_child(victim)
	await _frames(3)
	victim.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(5.0, 0.0, 0.0), null))
	victim.health.take_damage(victim.health.current_health)
	await _real_wait(0.1)
	zone.queue_free()
	await _real_wait(2.5)
	_check(not is_instance_valid(victim), "đổi khu: khu và quái đã bị giải phóng")
	_check(CombatFx.get_hit_pool().get_active_count() == 0 and CombatFx.get_blood_pool().get_active_count() == 0 and CombatFx.get_death_pool().get_active_count() == 0, "đổi khu giữa lúc hiệu ứng chạy: pool về 0 đang dùng, không lỗi")
	CombatFx.get_blood_stains().clear()
	for node in [enemy, faller]:
		if is_instance_valid(node):
			node.queue_free()
	await _real_wait(0.5)
	# Rò node: pool không tăng thêm node ngoài đợt đã tạo ở mục "20 hit cùng frame"
	var fx_nodes_after := _fx_node_count()
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("INFO node CombatFx: trước %d, sau %d (pool nở do 20 hit cùng frame); node cả cây: trước %d, sau %d; orphan: trước %d, sau %d" % [fx_nodes_before, fx_nodes_after, nodes_before, nodes_after, orphans_before, orphans_after])
	_check(orphans_after <= orphans_before, "không rò node mồ côi (orphan %d -> %d)" % [orphans_before, orphans_after])
	# Đợt lặp lại: pool đã nở thì không nở thêm nữa
	var stable := _fx_node_count()
	for i in 20:
		CombatFx.spawn_hit(Vector3(i * 0.2, 1.0, 30.0), Vector3.UP, Color.WHITE, 1.0, 1.5)
		CombatFx.spawn_blood(Vector3(i * 0.2, 1.0, 30.0), Vector3.UP, Color.RED, 0.0, 1.5, true)
	await _real_wait(2.5)
	_check(_fx_node_count() == stable, "lặp lại 20 hit cùng frame: số node pool không tăng (%d)" % stable)
	CombatFx.get_blood_stains().clear()


# ---------- Slow motion ----------

func _test_slow_motion() -> void:
	HitStop.slow_motion(0.2, 0.25)
	_check(is_equal_approx(Engine.time_scale, 0.25), "slow_motion: time_scale = 0.25")
	await _real_wait(0.4)
	_check(Engine.time_scale == 1.0, "slow_motion hết giờ: time_scale về 1")
	HitStop.slow_motion(0.3, 0.25)
	HitStop.stop(0.05)
	await _real_wait(0.5)
	_check(Engine.time_scale == 1.0, "slow_motion bị stop() ghi đè rồi vẫn về 1")
	HitStop.slow_motion(0.0, 0.25)
	_check(Engine.time_scale == 1.0, "slow_motion thời gian 0: bỏ qua")
	HitStop.slow_motion(0.1, 0.0)
	await _real_wait(0.3)
	_check(Engine.time_scale == 1.0, "slow_motion scale 0 (cực đoan): vẫn trả về 1")


# ---------- Vệt chém + viền đỏ ----------

func _test_slash_and_vignette() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(0.0, 0.2, -30.0)
	add_child(player)
	await _frames(3)
	# Quy đổi h_offset ra pixel trên camera game thật (để biết rung bao nhiêu pixel)
	var game_cam := player.get_node("CameraRig/Camera3D") as Camera3D
	var probe := player.global_position
	var px0 := game_cam.unproject_position(probe)
	game_cam.h_offset = 1.0
	var px1 := game_cam.unproject_position(probe)
	game_cam.h_offset = 0.0
	var px_per_m := absf(px1.x - px0.x)
	var shake_node := game_cam.get_node("CameraShake") as CameraShake
	print("INFO camera game: 1 m h_offset = %.1f px; max_offset %.2f m = %.1f px ở trauma 1; player bị đánh (trauma 0.45) cỡ %.1f px đỉnh" % [px_per_m, shake_node.max_offset, shake_node.max_offset * px_per_m, shake_node.max_offset * 0.45 * 0.45 * px_per_m])
	_check(px_per_m > 5.0, "h_offset có tác dụng lên hình (%.1f px / m)" % px_per_m)
	var trail := player.get_node("SlashTrail") as SlashTrail
	var arc_material := trail.get_node("Arc").material_override as ShaderMaterial
	var hitbox := player.get_node("Model/Hitbox") as HitboxComponent
	_check(not trail.is_sweeping() and not trail.is_processing(), "chưa chém: vệt ẩn, tắt process")
	hitbox.activate(SLASH_1)
	var d1: float = arc_material.get_shader_parameter(&"direction")
	_check(trail.is_sweeping() and trail.is_processing() and trail.get_node("Arc").visible, "hitbox bật: vệt quét")
	await _real_wait(trail.sweep_time * 0.5)
	var mid: float = arc_material.get_shader_parameter(&"head")
	_check(mid > 0.0 and mid <= 1.0, "giữa lúc quét: head %.2f" % mid)
	await _real_wait(trail.total_time() + 0.1)
	_check(not trail.is_sweeping() and not trail.is_processing() and not trail.get_node("Arc").visible, "quét xong: ẩn và tắt process")
	hitbox.deactivate()
	hitbox.activate(SLASH_1)
	var d2: float = arc_material.get_shader_parameter(&"direction")
	_check(d1 != d2 and absf(d1) == 1.0 and absf(d2) == 1.0, "đòn sau đổi chiều quét (%.0f -> %.0f)" % [d1, d2])
	hitbox.deactivate()
	# Bán kính vệt khớp tầm hitbox thực tế (đổi tầm thì vệt đổi theo)
	for reach in [1.65, 3.0, 0.4]:
		hitbox.set_reach(reach)
		hitbox.activate(SLASH_1)
		_check(absf(trail.get_outer_radius() - hitbox.get_reach() * trail.reach_ratio) < 0.001 and absf(hitbox.get_reach() - reach) < 0.001, "tầm %.2f m: vệt ngoài %.3f m = tầm x %.2f" % [reach, trail.get_outer_radius(), trail.reach_ratio])
		await _real_wait(trail.total_time() + 0.05)
		hitbox.deactivate()
	# Đòn cuối combo: to hơn
	var slash3 := load("res://resources/attacks/sword_slash_3.tres") as AttackData
	hitbox.activate(slash3)
	_check(is_equal_approx(trail.scale.x, trail.finisher_scale), "đòn 3: vệt to hơn (scale %.2f)" % trail.scale.x)
	await _real_wait(trail.total_time() + 0.1)
	hitbox.deactivate()
	hitbox.activate(SLASH_1)
	_check(is_equal_approx(trail.scale.x, 1.0), "đòn 1: vệt cỡ thường")
	await _real_wait(trail.total_time() + 0.1)
	hitbox.deactivate()
	# Cực đoan: bán kính, góc, thời gian
	trail.reach_ratio = 1.5; trail.inner_ratio = 0.0
	trail.arc_degrees = 359.0
	trail.sweep_time = 0.001
	trail.fade_time = 0.001
	trail.segments = 1
	trail.rebuild()
	hitbox.activate(SLASH_1)
	await _real_wait(0.1)
	_check(not trail.is_sweeping() and trail.get_node("Arc").mesh != null, "cung cực đoan (r 0..30, 359 độ, 0.001 s, 1 đoạn): không lỗi")
	hitbox.deactivate()
	# Viền đỏ
	var vignette := player.get_node("HUD/HurtVignette") as HurtVignette
	_check(not vignette.visible, "chưa bị đánh: viền đỏ ẩn")
	var shader_material := vignette.material as ShaderMaterial
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, 3.0), null))
	_check(vignette.visible, "bị đánh: viền đỏ hiện")
	await _real_wait(vignette.attack_time + 0.1)
	var strength: float = shader_material.get_shader_parameter(&"strength")
	_check(strength > 0.05, "viền đỏ đang sáng (strength %.2f)" % strength)
	await _real_wait(vignette.fade_time + 0.2)
	_check(not vignette.visible and float(shader_material.get_shader_parameter(&"strength")) == 0.0, "viền đỏ tan hết và ẩn")
	_check(is_equal_approx(ScreenShake.trauma, 0.0) or ScreenShake.trauma < 0.45, "player bị đánh có rung (đã giảm dần còn %.2f)" % ScreenShake.trauma)
	player.queue_free()
	await _frames(2)


# ---------- Chụp ảnh ----------

func _capture_all() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir.is_empty():
		_shot_dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0.0, 1.5, 3.4)
	cam.look_at(Vector3(0.0, 0.95, 0.0))
	cam.make_current()
	await _frames(3)
	# Cận cảnh tia lửa: 3 mốc ~ 0, 1/3, 2/3 vòng đời (0.42 s = 25 frame)
	CombatFx.spawn_hit(Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.25, 0.0), Color(1.0, 0.78, 0.35))
	await _shoot_at([2, 8, 16], "hit_spark_a")
	await _frames(40)
	CombatFx.spawn_hit(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.3, 0.0), Color(1.0, 0.2, 0.15), 1.2)
	await _shoot_at([2, 8, 16], "hit_spark_red")
	await _frames(40)
	# Cận cảnh chết (1.1 s = 66 frame)
	cam.position = Vector3(0.0, 2.2, 5.2)
	cam.look_at(Vector3(0.0, 0.8, 0.0))
	CombatFx.spawn_death(Vector3.ZERO, Color(1.0, 0.5, 0.15))
	await _shoot_at([4, 22, 44], "death_orange")
	await _frames(80)
	CombatFx.spawn_death(Vector3.ZERO, Color(0.72, 0.35, 1.0), 1.3)
	await _shoot_at([4, 22, 44], "death_purple")
	await _frames(80)
	# Cảnh game: camera player, quái trước mặt
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(0.0, 0.0, 1.8)
	add_child(enemy)
	await _frames(20)
	# Cận cảnh vệt chém (cam nhìn từ trên-trước)
	cam.make_current()
	cam.position = Vector3(2.6, 3.4, 3.6)
	cam.look_at(Vector3(0.0, 0.9, 0.9))
	player.get_node("Model/Hitbox").activate(SLASH_1)
	await _shoot_at([3, 8, 14], "slash_close_a")
	player.get_node("Model/Hitbox").deactivate()
	await _frames(30)
	player.get_node("Model/Hitbox").activate(SLASH_1)
	await _shoot_at([3, 8, 14], "slash_close_b")
	player.get_node("Model/Hitbox").deactivate()
	await _frames(30)
	var player_cam := player.get_node("CameraRig/Camera3D") as Camera3D
	player_cam.make_current()
	# Quy đổi h_offset ra pixel trên camera game thật (để biết rung bao nhiêu pixel)
	var game_cam := player.get_node("CameraRig/Camera3D") as Camera3D
	var probe := player.global_position
	var px0 := game_cam.unproject_position(probe)
	game_cam.h_offset = 1.0
	var px1 := game_cam.unproject_position(probe)
	game_cam.h_offset = 0.0
	var px_per_m := absf(px1.x - px0.x)
	var shake_node := game_cam.get_node("CameraShake") as CameraShake
	print("INFO camera game: 1 m h_offset = %.1f px; max_offset %.2f m = %.1f px ở trauma 1; player bị đánh (trauma 0.45) cỡ %.1f px đỉnh" % [px_per_m, shake_node.max_offset, shake_node.max_offset * px_per_m, shake_node.max_offset * 0.45 * 0.45 * px_per_m])
	_check(px_per_m > 5.0, "h_offset có tác dụng lên hình (%.1f px / m)" % px_per_m)
	var trail := player.get_node("SlashTrail") as SlashTrail
	player.get_node("Model/Hitbox").activate(SLASH_1)
	await _shoot_at([3, 8, 14], "game_slash")
	player.get_node("Model/Hitbox").deactivate()
	await _frames(30)
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, 5.0), player))
	await _shoot_at([2, 6, 12], "game_hit")
	await _frames(30)
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, -3.0), enemy))
	await _shoot_at([4, 12, 24], "game_hurt")
	await _frames(40)
	enemy.health.take_damage(enemy.health.max_health)
	await _shoot_at([8, 22, 40], "game_kill")
	trail = null
	cam.queue_free()


## Chụp ở các frame (đếm từ lúc gọi); mỗi ảnh lưu thành <name>_<chỉ số>.png
func _shoot_at(frames: Array[int], shot_name: String) -> void:
	var passed := 0
	for i in frames.size():
		while passed < frames[i]:
			await get_tree().process_frame
			passed += 1
		await RenderingServer.frame_post_draw
		var path := _shot_dir.path_join("%s_%d.png" % [shot_name, i])
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)


func _capture_all2() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir.is_empty():
		_shot_dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0.0, 1.5, 3.4)
	cam.look_at(Vector3(0.0, 0.95, 0.0))
	cam.make_current()
	await _frames(3)
	# Cận cảnh chém trúng thường / mạnh: khung 0, 2, 5, 10 (frame 60 Hz)
	CombatFx.spawn_hit(Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.25, 0.0), Color(1.0, 0.7, 0.25))
	await _shoot_at([1, 3, 6, 11], "hit_normal")
	await _frames(40)
	CombatFx.spawn_hit(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.3, 0.0), Color(1.0, 0.7, 0.25), 1.6, 1.5)
	await _shoot_at([1, 3, 6, 11], "hit_strong")
	await _frames(40)
	# Cận cảnh máu: phun rồi vết trên sàn
	cam.position = Vector3(0.5, 3.2, 4.6)
	cam.look_at(Vector3(0.8, 0.0, 0.0))
	CombatFx.spawn_blood(Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.4, 0.0), Color(0.42, 0.02, 0.05), 0.0, 1.5, true)
	await _shoot_at([4, 12, 30, 120], "blood_kill")
	CombatFx.get_blood_stains().clear()
	await _frames(20)
	# Cận cảnh chết
	cam.position = Vector3(0.0, 2.2, 5.2)
	cam.look_at(Vector3(0.0, 0.8, 0.0))
	CombatFx.spawn_death(Vector3.ZERO, Color(1.0, 0.5, 0.15), 1.9)
	CombatFx.spawn_puddle(Vector3.ZERO, 2.2, Color(0.42, 0.02, 0.05))
	await _shoot_at([4, 22, 44, 100], "death_orange")
	await _frames(80)
	CombatFx.get_blood_stains().clear()
	# Cảnh game
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(0.0, 0.0, 1.8)
	add_child(enemy)
	enemy.health.max_health = 50
	enemy.health.heal_full()
	await _frames(20)
	var hitbox := player.get_node("Model/Hitbox") as HitboxComponent
	var slash3 := load("res://resources/attacks/sword_slash_3.tres") as AttackData
	# Cận cảnh vệt chém trên nền sáng và nền tối
	cam.make_current()
	cam.position = Vector3(2.8, 4.0, 4.4)
	cam.look_at(Vector3(0.0, 0.3, 0.8))
	hitbox.activate(SLASH_1)
	await _shoot_at([2, 5, 9, 16], "slash_light")
	hitbox.deactivate()
	await _frames(30)
	hitbox.activate(slash3)
	await _shoot_at([2, 5, 9, 16], "slash3_light")
	hitbox.deactivate()
	await _frames(30)
	_set_floor_color(Color(0.1, 0.28, 0.12))
	hitbox.activate(SLASH_1)
	await _shoot_at([2, 5, 9, 16], "slash_dark")
	hitbox.deactivate()
	await _frames(30)
	_set_floor_color(Color(0.3, 0.32, 0.36))
	# Camera game: chém trúng trong hitstop và sau đó
	var player_cam := player.get_node("CameraRig/Camera3D") as Camera3D
	player_cam.make_current()
	hitbox.activate(SLASH_1)
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, 9.0), player))
	HitStop.stop(0.07)
	await _shoot_at([1, 3, 8, 14, 26], "game_hit")
	hitbox.deactivate()
	await _frames(60)
	var hurtbox := player.get_node("HurtboxComponent") as HurtboxComponent
	hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, -3.0), null))
	await _shoot_at([4, 16], "game_hurt")
	await _frames(40)
	enemy.health.take_damage(enemy.health.current_health - 1)
	enemy.hurtbox.set_invincible(0.0)
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, 9.0), player))
	await _shoot_at([3, 10, 22, 45, 90], "game_kill")
	cam.queue_free()


func _set_floor_color(color: Color) -> void:
	((_floor_mesh.mesh as PlaneMesh).material as StandardMaterial3D).albedo_color = color


# ---------- Tiện ích ----------

func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FLOOR_SIZE
	shape.shape = box
	shape.position.y = -FLOOR_SIZE.y * 0.5
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE.x, FLOOR_SIZE.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.36)
	plane.material = mat
	mesh.mesh = plane
	_floor_mesh = mesh
	floor_body.add_child(mesh)
	add_child(floor_body)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.16, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.7
	# Giống Level 1: glow + AgX để HDR của hiệu ứng bung sáng
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Chờ theo thời gian thật (bỏ qua time_scale của hitstop)
func _real_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Đếm node trong cả cây trừ nhánh của `excluded`
func _count_nodes_outside(excluded: Node) -> int:
	return _count(get_tree().root, excluded)


func _count(node: Node, excluded: Node) -> int:
	if node == excluded:
		return 0
	var total := 1
	for child in node.get_children():
		total += _count(child, excluded)
	return total


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failed = true
