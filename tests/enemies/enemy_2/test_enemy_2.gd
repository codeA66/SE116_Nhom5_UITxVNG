extends Node3D
## Test Hộ Vệ Khiên (Quái 2): chặn đòn theo hướng, gió, đòn đập + sóng kích, thông số cực đoan.
## Chạy headless (nhanh hơn thời gian thật nhờ --fixed-fps):
##   godot --headless --path . --fixed-fps 60 res://tests/enemies/enemy_2/test_enemy_2.tscn
## Chụp ảnh vành sóng (cần cửa sổ thật):
##   godot --path . --fixed-fps 60 --resolution 960x540 res://tests/enemies/enemy_2/test_enemy_2.tscn -- visual
## Xoá savegame.json trước và sau khi chạy.

const BEARER_SCENE: PackedScene = preload("res://entities/enemies/palace/shield_bearer/shield_bearer.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const ARROW_SCENE: PackedScene = preload("res://objects/combat/projectiles/arrow/arrow.tscn")
const BEARER_DATA: ShieldBearerData = preload("res://resources/enemies/shield_bearer/shield_bearer.tres")
const BLAST_DATA: WindBlastData = preload("res://abilities/wind_blast/wind_blast.tres")
const UPDRAFT_DATA: WindData = preload("res://resources/world/wind/wind/wind_updraft.tres")
const ZONE_SCENE: PackedScene = preload("res://objects/wind_puzzle/wind_zone/wind_zone.tscn")

const TICK: float = 1.0 / 60.0
## Chỗ đậu player khi không dùng tới: ngoài tầm cảm biến của quái
const PARK := Vector3(0.0, 0.0, 30.0)
## Bán kính hurtbox player (capsule của Character)
const PLAYER_HURT_RADIUS := 0.4

var _failed: bool = false
var _tick: int = 0
var _player: Player
var _player_hurtbox: HurtboxComponent
var _hurt_ticks: Array[int] = []
## Quái đang được theo dõi nhịp hitbox
var _watch: ShieldBearer
var _active_tick: int = -1
var _min_time_scale: float = 1.0
var _visual: bool = false


func _ready() -> void:
	_visual = "visual" in OS.get_cmdline_user_args()
	_build_world()
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	_tick += 1
	_min_time_scale = minf(_min_time_scale, Engine.time_scale)
	if is_instance_valid(_watch) and _active_tick < 0 and _watch.hitbox.is_active():
		_active_tick = _tick


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_player = PLAYER_SCENE.instantiate() as Player
	_player.set(&"preview_sword", true)
	_player.set(&"preview_dash", true)
	_player.position = PARK
	add_child(_player)
	_player_hurtbox = _player.get_node("HurtboxComponent") as HurtboxComponent
	_player_hurtbox.hurt.connect(func(_info: DamageInfo, _taken: int) -> void: _hurt_ticks.append(_tick))
	await _frames(5)
	if _visual:
		await _visual_capture()
	else:
		await _test_load()
		await _test_block_arcs()
		await _test_block_projectiles_and_hazards()
		await _test_slam_phases_and_death()
		await _test_real_sword()
		await _test_wind()
		await _test_shockwave_timing()
		await _test_shockwave_dodges()
		await _test_shockwave_range_and_reuse()
		await _test_extreme_shockwave()
		await _test_extreme_enemy()
	if is_instance_valid(_player):
		_player.queue_free()
	print("ENEMY2_CHECK ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


# ---------- Tải scene ----------

func _test_load() -> void:
	var bearer := _spawn_bearer(Vector3.ZERO)
	await _frames(3)
	var hurtbox := bearer.get_node("HurtboxComponent")
	_check(hurtbox is GuardedHurtboxComponent, "script hurtbox là GuardedHurtboxComponent")
	_check(bearer.hurtbox.health == bearer.health, "đổi script hurtbox vẫn giữ property kế thừa (health)")
	_check(bearer.hurtbox.collision_layer == 4, "hurtbox giữ layer 4 kế thừa")
	_check(bearer.guarded_hurtbox.guards.size() == 1 and bearer.guarded_hurtbox.guards[0] == bearer.guard, "guards trỏ đúng ShieldGuard")
	_check(bearer.guard.facing_node == bearer.model, "facing_node = Model")
	_check(bearer.health.max_health == 4 and bearer.health.current_health == 4, "máu 4")
	_check(bearer.state_machine.current_state.name == &"Idle", "bắt đầu ở Idle")
	_check(bearer.chase_state == &"ShieldAdvance" and bearer.attack_state == &"ShieldSlam", "chase/attack state riêng")
	_check(bearer.wind_receiver.wind_multiplier == 0.0, "wind_multiplier = 0")
	_check(bearer.guard.arc_degrees == 120.0 and bearer.guard.enabled, "khiên 120 độ, đang bật")
	_check(is_equal_approx(bearer.movement.max_speed, 2.2), "movement của quái là shield_bearer_movement")
	bearer.queue_free()
	await _frames(2)


# ---------- Chặn đòn theo hướng ----------

func _test_block_arcs() -> void:
	var bearer := _spawn_bearer(Vector3.ZERO)
	bearer.set_physics_process(false)
	await _frames(3)
	bearer.face_instantly(Vector3.BACK)
	var r := _swing(bearer, 0.0)
	_check(r.blocked == 1 and r.hurt == 0 and r.hp == 4, "chém chính diện: chặn, HP 4, không phát hurt")
	r = _swing(bearer, 180.0)
	_check(r.blocked == 0 and r.hurt == 1 and r.hp == 3 and r.state == &"Idle", "chém sau lưng: HP 3, không vào Hurt")
	r = _swing(bearer, 90.0)
	_check(r.blocked == 0 and r.hurt == 1 and r.hp == 3 and r.state == &"Idle", "chém sườn +90: HP 3, không vào Hurt")
	r = _swing(bearer, -90.0)
	_check(r.blocked == 0 and r.hurt == 1, "chém sườn -90: trúng")
	var push_before := bearer.velocity
	_swing(bearer, 180.0)
	_check((bearer.velocity - push_before).length() > 0.5, "trúng đòn: chỉ bị đẩy nhẹ (velocity tăng)")
	# Biên cung: [arc, góc ngay trong biên, góc ngay ngoài biên]
	var cases: Array[Array] = [
		[120.0, 55.0, 65.0], [10.0, 4.0, 6.0], [180.0, 85.0, 95.0], [359.0, 178.0, 180.0],
	]
	for case in cases:
		bearer.guard.arc_degrees = case[0]
		for side in [1.0, -1.0]:
			var inside := _swing(bearer, case[1] * side)
			var outside := _swing(bearer, case[2] * side)
			_check(inside.blocked == 1 and inside.hurt == 0, "arc %d: %d độ (%s) bị chặn" % [case[0], case[1], "+" if side > 0.0 else "-"])
			_check(outside.blocked == 0 and outside.hurt == 1, "arc %d: %d độ (%s) trúng" % [case[0], case[2], "+" if side > 0.0 else "-"])
	bearer.guard.arc_degrees = 0.0
	_check(_swing(bearer, 0.0).hurt == 1 and _swing(bearer, 90.0).hurt == 1, "arc 0: không chặn gì (kể cả chính diện)")
	bearer.guard.arc_degrees = 360.0
	var all_blocked := true
	for angle in [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0]:
		all_blocked = all_blocked and _swing(bearer, angle).blocked == 1
	_check(all_blocked, "arc 360: chặn mọi hướng kể cả đúng sau lưng")
	bearer.guard.arc_degrees = 120.0
	# Không có hướng đẩy: dùng vị trí nguồn đòn
	var attacker := _make_attacker(bearer, 0.0)
	bearer.health.heal_full()
	var front := bearer.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, attacker))
	_check(not front and bearer.health.current_health == 4, "knockback 0: lấy hướng từ vị trí nguồn, chính diện bị chặn")
	attacker.global_position = bearer.global_position + Vector3(0.0, 0.0, -2.0)
	var back := bearer.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, attacker))
	_check(back and bearer.health.current_health == 3, "knockback 0: nguồn phía sau thì trúng")
	_check(bearer.hurtbox.receive_hit(DamageInfo.new(1)) and bearer.health.current_health == 2, "không có nguồn lẫn hướng: cho trúng")
	attacker.queue_free()
	# Đổi hướng quái: chặn theo hướng mới
	bearer.health.heal_full()
	bearer.face_instantly(Vector3.RIGHT)
	var rotated := _swing(bearer, 0.0)
	_check(rotated.blocked == 1 and rotated.hp == 4, "quái quay sang +X: chặn đòn từ +X")
	bearer.queue_free()
	await _frames(2)


func _test_block_projectiles_and_hazards() -> void:
	var bearer := _spawn_bearer(Vector3.ZERO)
	bearer.set_physics_process(false)
	await _frames(3)
	bearer.face_instantly(Vector3.BACK)
	var source := Node3D.new()
	add_child(source)
	var attack := AttackData.new()
	attack.damage = 1
	attack.knockback = 5.0
	var counts := {"blocked": 0, "hurt": 0}
	bearer.guarded_hurtbox.blocked.connect(func(_i: DamageInfo, _g: HitGuard) -> void: counts.blocked += 1)
	bearer.hurtbox.hurt.connect(func(_i: DamageInfo, _d: int) -> void: counts.hurt += 1)
	# Tên bắn trực diện (bay -Z, từ trước mặt tới)
	var arrow := _make_arrow(Vector3(0.0, 1.0, 5.0))
	arrow.launch(attack, 20.0, 3.0, Vector3(0.0, 0.0, -1.0), source, arrow.global_position)
	await _frames(30)
	_check(not is_instance_valid(arrow), "tên trực diện biến mất")
	_check(bearer.health.current_health == 4 and counts.blocked == 1 and counts.hurt == 0, "tên trực diện: HP không đổi, phát blocked")
	# Tên bắn từ sau lưng
	arrow = _make_arrow(Vector3(0.0, 1.0, -5.0))
	arrow.launch(attack, 20.0, 3.0, Vector3(0.0, 0.0, 1.0), source, arrow.global_position)
	await _frames(30)
	_check(not is_instance_valid(arrow), "tên sau lưng biến mất")
	_check(bearer.health.current_health == 3 and counts.hurt == 1, "tên sau lưng: HP giảm 1")
	# Gai thật (DamageArea bỏ qua bất tử) đứng phía trước
	bearer.health.heal_full()
	var spikes := DamageArea.new()
	spikes.collision_layer = 0
	spikes.collision_mask = 4
	spikes.ignore_invincibility = true
	spikes.damage = 1
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 6.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	spikes.add_child(shape)
	spikes.position = Vector3(0.0, 1.0, 3.0)
	add_child(spikes)
	await _frames(6)
	_check(counts.hurt == 2 and bearer.health.current_health == 3, "gai (ignore_invincibility) phía trước vẫn gây sát thương")
	_check(counts.blocked == 1, "khiên không chặn gai")
	spikes.queue_free()
	# Bẫy chặn được khi bật blocks_hazards
	var info := DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, -5.0), source)
	info.ignores_invincibility = true
	bearer.guard.blocks_hazards = true
	bearer.health.heal_full()
	_check(not bearer.hurtbox.receive_hit(info) and bearer.health.current_health == 4, "blocks_hazards = true: chặn cả bẫy")
	source.queue_free()
	bearer.queue_free()
	await _frames(2)


# ---------- Pha tụ lực / hồi, chết ----------

func _test_slam_phases_and_death() -> void:
	var bearer := _spawn_bearer(Vector3.ZERO, _data({"patrol_radius": 0.0}))
	var marker := Node3D.new()
	marker.position = Vector3(0.0, 0.0, 5.0)
	add_child(marker)
	await _frames(3)
	bearer.sensor.monitoring = false
	bearer.target = marker
	bearer.state_machine.transition_to(&"ShieldSlam")
	await _frames(1)
	_check(not bearer.guard.enabled, "vào ShieldSlam: tắt khiên")
	await _seconds(0.3)
	var r := _swing(bearer, 0.0, false)
	_check(r.blocked == 0 and r.hurt == 1 and r.hp == 3, "tụ lực: chém chính diện trúng")
	_check(bearer.state_machine.current_state.name == &"ShieldSlam", "chém lúc tụ lực không hủy đòn (không bị khựng)")
	await _seconds(1.5)
	r = _swing(bearer, 0.0, false)
	_check(r.blocked == 0 and r.hurt == 1 and r.hp == 2, "pha hồi: chém chính diện trúng")
	_check(bearer.state_machine.current_state.name == &"ShieldSlam", "pha hồi: vẫn ShieldSlam")
	await _seconds(0.6)
	_check(bearer.guard.enabled, "hết ShieldSlam: khiên bật lại")
	_check(bearer.state_machine.current_state.name != &"ShieldSlam", "ShieldSlam kết thúc đúng duration")
	# Chết sau 4 nhát
	bearer.health.heal_full()
	bearer.state_machine.transition_to(&"ShieldAdvance")
	var hits := 0
	for i in 4:
		hits += _swing(bearer, 180.0, false).hurt
	await _frames(2)
	_check(hits == 4 and bearer.is_dead(), "4 nhát trúng -> chết")
	_check(bearer.state_machine.current_state.name == &"Dead", "vào state Dead")
	_check(bearer.collision_layer == 0 and not bearer.hurtbox.monitorable, "chết: tắt va chạm / hurtbox")
	await _seconds(bearer.data.corpse_time + 0.3)
	_check(not is_instance_valid(bearer), "xác biến mất sau corpse_time")
	marker.queue_free()
	await _frames(2)


# ---------- Player thật chém khiên ----------

func _test_real_sword() -> void:
	var bearer := _spawn_bearer(Vector3.ZERO, _data({"patrol_radius": 0.0}))
	bearer.set_physics_process(false)
	await _frames(3)
	bearer.face_instantly(Vector3.BACK)
	var counts := {"blocked": 0, "hurt": 0}
	bearer.guarded_hurtbox.blocked.connect(func(_i: DamageInfo, _g: HitGuard) -> void: counts.blocked += 1)
	bearer.hurtbox.hurt.connect(func(_i: DamageInfo, _d: int) -> void: counts.hurt += 1)
	_player.teleport(Vector3(0.0, 0.05, 1.2), Vector3.FORWARD)
	await _frames(10)
	_min_time_scale = 1.0
	await _tap(&"attack")
	await _frames(30)
	_check(counts.blocked == 1 and counts.hurt == 0 and bearer.health.current_health == 4, "player chém thật chính diện: bị chặn, HP 4")
	_check(_min_time_scale < 1.0, "player vẫn hitstop khi chém trúng khiên (time_scale min %.3f)" % _min_time_scale)
	await _seconds(0.6)
	_player.teleport(Vector3(0.0, 0.05, -1.2), Vector3.BACK)
	await _frames(10)
	await _tap(&"attack")
	await _frames(30)
	_check(counts.hurt == 1 and bearer.health.current_health == 3, "player chém thật từ sau lưng: HP 3")
	_check(bearer.state_machine.current_state.name != &"Hurt", "chém sau lưng không vào Hurt")
	_park_player()
	bearer.queue_free()
	await _frames(2)


# ---------- Gió ----------

func _test_wind() -> void:
	GameState.progress.abilities.append(BLAST_DATA)
	var heavy := _spawn_bearer(Vector3.ZERO, _data({"patrol_radius": 0.0}))
	var light_data := _data({"patrol_radius": 0.0, "wind_multiplier": 1.0, "stagger_on_wind": true})
	var light := _spawn_bearer(Vector3(10.0, 0.0, 0.0), light_data)
	await _frames(3)
	heavy.sensor.monitoring = false
	light.sensor.monitoring = false
	var heavy_start := heavy.global_position
	var light_start := light.global_position
	var seen_blown := false
	# Cú thổi thật: player đứng cách 2 m, hướng về quái
	for case in [[heavy, Vector3(0.0, 0.05, 2.0), Vector3.FORWARD], [light, Vector3(10.0, 0.05, 2.0), Vector3.FORWARD]]:
		_player.teleport(case[1], case[2])
		await _frames(10)
		await _tap(&"skill")
		for i in 60:
			await _step()
			if case[0] == light and (case[0] as ShieldBearer).state_machine.current_state.name == &"Blown":
				seen_blown = true
		_park_player()
		await _seconds(BLAST_DATA.cooldown + 0.3)
	_check(heavy.global_position.distance_to(heavy_start) < 0.05, "cú thổi thật: Hộ Vệ lệch %.4f m (< 0.05)" % heavy.global_position.distance_to(heavy_start))
	_check(light.global_position.distance_to(light_start) > 1.0 and seen_blown, "đối chứng: quái nhẹ bị thổi %.2f m và vào Blown (cú thổi có trúng thật)" % light.global_position.distance_to(light_start))
	_check(heavy.state_machine.current_state.name == &"Idle", "Hộ Vệ không đổi state khi bị thổi")
	# VFX gió tách: gọi push trực tiếp như cú thổi rồi xem hạt
	heavy.wind_receiver.push(Vector3(8.0, 0.0, 0.0))
	var deflect := heavy.get_node("Model/WindDeflect") as GPUParticles3D
	_check(deflect.emitting, "VFX gió tách chạy khi bị thổi")
	for i in 40:
		await _step()
	_check(heavy.global_position.distance_to(heavy_start) < 0.05, "push 8 m/s trực tiếp: vẫn lệch < 0.05 m")
	# Cột gió hướng lên
	var zone := ZONE_SCENE.instantiate() as WindZone
	zone.data = UPDRAFT_DATA
	zone.size = Vector3(6.0, 6.0, 8.0)
	zone.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(5.0, 4.0, 0.0))
	add_child(zone)
	var heavy2 := _spawn_bearer(Vector3(5.0, 0.0, 0.0), _data({"patrol_radius": 0.0}))
	var light2 := _spawn_bearer(Vector3(5.0, 0.0, -2.5), light_data)
	await _frames(3)
	heavy2.sensor.monitoring = false
	light2.sensor.monitoring = false
	var heavy_peak := 0.0
	var light_peak := 0.0
	for i in 70:
		await _step()
		heavy_peak = maxf(heavy_peak, heavy2.global_position.y)
		light_peak = maxf(light_peak, light2.global_position.y)
	_check(heavy_peak < 0.05, "cột gió hướng lên: Hộ Vệ không bị nâng (cao nhất %.3f m)" % heavy_peak)
	_check(light_peak > 0.3, "đối chứng: quái nhẹ bị nâng %.2f m (cột gió có hiệu lực)" % light_peak)
	GameState.progress.abilities.erase(BLAST_DATA)
	for node in [heavy, light, heavy2, light2, zone]:
		(node as Node).queue_free()
	await _frames(2)


# ---------- Sóng kích: thời điểm, né, tầm, tái dùng ----------

func _test_shockwave_timing() -> void:
	var trial := await _slam_trial(Vector3(0.0, 0.0, 1.0), 3.0)
	var attack := BEARER_DATA.attack
	var wave := BEARER_DATA.shockwave
	_check(absf(trial.active_time - attack.active_start) <= TICK * 1.5, "hitbox bật sau %.3f s (kỳ vọng %.2f ± 1 frame)" % [trial.active_time, attack.active_start])
	var predicted: float = attack.active_start + (trial.distance - wave.band_width * 0.5 - PLAYER_HURT_RADIUS - wave.start_radius) / wave.speed
	_check(trial.hits.size() == 1, "player đứng yên cách tâm sóng %.2f m: trúng đúng %d lần" % [trial.distance, trial.hits.size()])
	if trial.hits.size() >= 1:
		var measured: float = trial.hits[0]
		_check(absf(measured - predicted) <= TICK * 3.0, "thời điểm trúng %.3f s, tính theo vành+hurtbox %.3f s (công thức plan chỉ tính tâm: %.3f s)" % [measured, predicted, attack.active_start + (trial.distance - wave.start_radius) / wave.speed])
	_check(trial.finished_count == 1, "sóng phát `finished` đúng 1 lần")
	_check(trial.slam_count == 1, "mỗi lần đập chỉ 1 sóng (slammed phát %d lần)" % trial.slam_count)
	_check(not trial.wave_processing and not trial.wave_monitoring and not trial.wave_active, "hết sóng: tắt _physics_process, monitoring, is_active")


func _test_shockwave_dodges() -> void:
	var attack := BEARER_DATA.attack
	var wave := BEARER_DATA.shockwave
	var predicted := attack.active_start + (3.0 - wave.band_width * 0.5 - PLAYER_HURT_RADIUS - wave.start_radius) / wave.speed
	# Chân cao 0.5 m / 0.4 m (giả lập, player đứng yên): hit_height = 0.45
	var high := await _slam_trial(Vector3(0.0, 0.5, 1.0), 3.0)
	_check(high.hits.size() == 0, "chân cao 0.5 m: không trúng")
	var low := await _slam_trial(Vector3(0.0, 0.4, 1.0), 3.0)
	_check(low.hits.size() == 1, "chân cao 0.4 m: trúng")
	# Dash xuyên vòng: bấm dash để đang i-frame lúc vành tới
	var dash := await _slam_trial(Vector3(0.0, 0.0, 1.0), 3.0, {"input": &"dash", "press_at": predicted - 0.1, "unfreeze": true, "face": Vector3.FORWARD})
	_check(dash.hits.size() == 0, "dash xuyên vành (i-frame): không trúng (player đang dash %.2f..%.2f s)" % [dash.press_time, dash.press_time + 0.18])
	var no_dash := await _slam_trial(Vector3(0.0, 0.0, 1.0), 3.0, {"unfreeze": true, "face": Vector3.FORWARD})
	_check(no_dash.hits.size() == 1, "đối chứng dash: không dash thì trúng")
	# Nhảy thật: bấm jump ở các mốc so với lúc vành tới
	var results := {}
	for lead in [0.8, 0.42, 0.25, 0.1, 0.0]:
		var jump := await _slam_trial(Vector3(0.0, 0.0, 1.0), 3.0, {"input": &"jump", "press_at": predicted - lead, "unfreeze": true, "face": Vector3.FORWARD})
		results[lead] = jump.hits.size()
	print("INFO nhảy thật (bấm trước lúc vành tới bao nhiêu giây -> số lần trúng): ", results)
	_check(results[0.25] == 0 and results[0.1] == 0, "nhảy thật bấm trước 0.25 s và 0.1 s: né được")
	_check(results[0.8] == 1 and results[0.0] == 1, "nhảy quá sớm (0.8 s) hoặc quá muộn (0 s): trúng")
	# Tường chắn
	var wall := _make_box(Vector3(2.5, 1.5, 0.0), Vector3(0.4, 3.0, 8.0))
	var behind := await _slam_trial(Vector3(1.0, 0.0, 0.0), 3.0)
	_check(behind.hits.size() == 0, "đứng sau tường: không trúng")
	var open := await _slam_trial(Vector3(-1.0, 0.0, 0.0), 3.0)
	_check(open.hits.size() == 1, "đối chứng tường: phía không có tường trúng")
	var no_block := _data({})
	no_block.shockwave = BEARER_DATA.shockwave.duplicate() as ShockwaveData
	no_block.shockwave.blocked_by_world = false
	var through := await _slam_trial(Vector3(1.0, 0.0, 0.0), 3.0, {"data": no_block})
	_check(through.hits.size() == 1, "blocked_by_world = false: sóng xuyên tường")
	wall.queue_free()
	# Bục cao 1 m
	var platform := _make_box(Vector3(0.0, 0.5, -4.5), Vector3(3.0, 1.0, 3.0))
	var on_platform := await _slam_trial(Vector3(0.0, 1.0, -1.0), 3.0)
	_check(on_platform.hits.size() == 0, "đứng trên bục 1 m: không trúng")
	var on_platform_open := await _slam_trial(Vector3(0.0, 1.0, -1.0), 3.0, {"data": no_block})
	_check(on_platform_open.hits.size() == 0, "đứng trên bục 1 m, bỏ chặn tường: vẫn không trúng (do độ cao)")
	platform.queue_free()
	await _frames(2)


func _test_shockwave_range_and_reuse() -> void:
	var edge := await _slam_trial(Vector3(0.0, 0.0, 1.0), 6.3)
	var outside := await _slam_trial(Vector3(0.0, 0.0, 1.0), 6.5)
	var wave := BEARER_DATA.shockwave
	var limit := wave.max_radius + PLAYER_HURT_RADIUS
	_check(edge.hits.size() == 1, "player cách tâm 6.3 m (< max_radius + hurtbox = %.1f): trúng" % limit)
	_check(outside.hits.size() == 0, "player cách tâm 6.5 m (> %.1f): không trúng" % limit)
	_check(not outside.wave_processing and not outside.wave_monitoring, "sóng tắt _physics_process và monitoring sau khi hết")
	# Tái dùng: để AI tự đập nhiều lần, đếm node con và số sóng
	var bearer := _spawn_bearer(Vector3.ZERO, _data({"patrol_radius": 0.0, "attack_cooldown": 0.5}))
	await _frames(3)
	var children_before := bearer.get_child_count()
	var wave_children := bearer.shockwave.get_child_count()
	var slams := {"count": 0}
	bearer.slammed.connect(func(_p: Vector3) -> void: slams.count += 1)
	var finished := {"count": 0}
	bearer.shockwave.finished.connect(func() -> void: finished.count += 1)
	var dummy := Node3D.new()
	dummy.position = Vector3(0.0, 0.0, 3.0)
	add_child(dummy)
	bearer.sensor.monitoring = false
	bearer.target = dummy
	var max_active := 0
	for i in 60 * 9:
		await _step()
		max_active = maxi(max_active, 1 if bearer.shockwave.is_active() else 0)
	_check(slams.count >= 2, "AI tự đập nhiều lần (%d lần trong 9 s)" % slams.count)
	_check(finished.count >= slams.count - 1 and finished.count <= slams.count, "mỗi lần đập 1 `finished` (%d/%d)" % [finished.count, slams.count])
	_check(bearer.get_child_count() == children_before and bearer.shockwave.get_child_count() == wave_children, "đập nhiều lần không tạo node mới (con quái %d -> %d)" % [children_before, bearer.get_child_count()])
	dummy.queue_free()
	bearer.queue_free()
	await _frames(2)


# ---------- Cực đoan ----------

func _test_extreme_shockwave() -> void:
	var cases: Array[Dictionary] = [
		{"label": "speed 0.5", "values": {"speed": 0.5}, "stop_at": 1.6},
		{"label": "speed 60", "values": {"speed": 60.0}},
		{"label": "band_width 0.05", "values": {"band_width": 0.05}},
		{"label": "band_width 3", "values": {"band_width": 3.0}},
		{"label": "max_radius 0.6 (= start)", "values": {"max_radius": 0.6}},
		{"label": "max_radius 30", "values": {"max_radius": 30.0}},
		{"label": "hit_height 0", "values": {"hit_height": 0.0}},
		{"label": "hit_height 3", "values": {"hit_height": 3.0}},
		{"label": "speed 60 + band 0.05", "values": {"speed": 60.0, "band_width": 0.05}},
	]
	for case in cases:
		var data := _data({})
		var wave := BEARER_DATA.shockwave.duplicate() as ShockwaveData
		for key in case.values:
			wave.set(key, case.values[key])
		data.shockwave = wave
		var trial := await _slam_trial(Vector3(0.0, 0.0, 1.0), 3.0, {"data": data, "stop_after": float(case.get("stop_at", 3.5))})
		var expected_hits := 1
		match case.label:
			"speed 0.5", "max_radius 0.6 (= start)":
				expected_hits = 0
			"hit_height 0":
				# Chân đúng bằng mặt đất: ranh giới, chỉ ghi nhận không kiểm
				expected_hits = -1
		if expected_hits >= 0:
			_check(trial.hits.size() == expected_hits, "cực đoan ShockwaveData %s: số lần trúng %d (kỳ vọng %d)" % [case.label, trial.hits.size(), expected_hits])
		else:
			print("INFO cực đoan ShockwaveData %s: số lần trúng %d (ranh giới, không kiểm)" % [case.label, trial.hits.size()])
		_check(trial.finished_count == 1 and not trial.wave_active, "cực đoan ShockwaveData %s: sóng kết thúc sạch" % case.label)


func _test_extreme_enemy() -> void:
	var cases: Array[Dictionary] = [
		{"label": "rotation_speed 0.5", "movement": {"rotation_speed": 0.5}},
		{"label": "rotation_speed 30", "movement": {"rotation_speed": 30.0}},
		{"label": "preferred_distance 0", "data": {"preferred_distance": 0.0}},
		{"label": "preferred_distance 10", "data": {"preferred_distance": 10.0}},
		{"label": "attack_range 1.0 < preferred_distance 3.0", "data": {"attack_range": 1.0, "preferred_distance": 3.0}},
		{"label": "attack_cooldown 0", "data": {"attack_cooldown": 0.0}},
	]
	for case in cases:
		var values: Dictionary = case.get("data", {})
		values["patrol_radius"] = 0.0
		var data := _data(values)
		var move_values: Dictionary = case.get("movement", {})
		if not move_values.is_empty():
			var movement := data.movement.duplicate() as MovementStats
			for key in move_values:
				movement.set(key, move_values[key])
			data.movement = movement
		var bearer := _spawn_bearer(Vector3.ZERO, data)
		var dummy := Node3D.new()
		dummy.position = Vector3(5.0, 0.0, 5.0)
		add_child(dummy)
		await _frames(3)
		bearer.sensor.monitoring = false
		bearer.target = dummy
		var slams := {"count": 0}
		bearer.slammed.connect(func(_p: Vector3) -> void: slams.count += 1)
		for i in 60 * 14:
			await _step()
			if slams.count >= 2:
				break
		_check(slams.count >= 1, "cực đoan quái %s: đập được %d lần (không kẹt)" % [case.label, slams.count])
		bearer.queue_free()
		dummy.queue_free()
		await _frames(2)


# ---------- Chụp ảnh (chế độ visual) ----------

func _visual_capture() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	camera.position = Vector3(0.0, 30.0, 0.75)
	camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(camera)
	camera.make_current()
	var pixels_per_meter := get_viewport().get_visible_rect().size.y / camera.size
	var bearer := _spawn_bearer(Vector3.ZERO, _data({"patrol_radius": 0.0}))
	await _frames(3)
	bearer.sensor.monitoring = false
	var wave := BEARER_DATA.shockwave
	var attack := BEARER_DATA.attack
	_ensure_dir("res://.godot/enemy2_shots")
	for distance in [1.8, 3.0, 4.8]:
		_player.set_physics_process(false)
		bearer.face_instantly(Vector3.BACK)
		bearer.target = _player
		_player.teleport(Vector3(0.0, 0.0, 0.75 + distance), Vector3.FORWARD)
		_hurt_ticks.clear()
		var enter_tick := _tick
		bearer.state_machine.transition_to(&"ShieldSlam")
		while _hurt_ticks.is_empty() and _tick - enter_tick < 200:
			await _step()
		await RenderingServer.frame_post_draw
		var hit_time := float(_tick - enter_tick) * TICK
		var radius_now := wave.start_radius + wave.speed * (hit_time - attack.active_start)
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://.godot/enemy2_shots/ring_%.1f.png" % distance))
		var center := Vector2(image.get_width() * 0.5, image.get_height() * 0.5)
		# Quét theo -X (player nằm trên +Z nên không che): tìm điểm xa nhất mang màu vành
		var front_px := 0
		for px in range(int(wave.max_radius * pixels_per_meter * 1.2)):
			var pixel := image.get_pixelv(center + Vector2(-px, 0))
			if pixel.r > pixel.b + 0.25 and pixel.r > 0.55:
				front_px = px
		var front_m := float(front_px) / pixels_per_meter
		var expected_front := radius_now + wave.band_width * 0.5
		var collision_front: float = distance - PLAYER_HURT_RADIUS
		print("INFO ảnh d=%.1f: mép trước vành trên ảnh %.2f m | tính từ thời gian %.2f m | mép chạm hurtbox player %.2f m (t=%.3f s)" % [distance, front_m, expected_front, collision_front, hit_time])
		_check(absf(front_m - collision_front) <= 0.35, "ảnh d=%.1f: mép vành trên hình khớp điểm bắt đầu gây sát thương (lệch %.2f m)" % [distance, front_m - collision_front])
		await _seconds(2.5)
	bearer.queue_free()


# ---------- Hỗ trợ ----------

func _slam_trial(player_pos: Vector3, distance_from_origin: float, options: Dictionary = {}) -> Dictionary:
	## player_pos.xz = hướng đặt player quanh quái (chuẩn hoá), y = độ cao chân; khoảng cách tính từ tâm sóng (ShockwaveOrigin)
	var data: ShieldBearerData = options.get("data", _data({"patrol_radius": 0.0}))
	var bearer := _spawn_bearer(Vector3.ZERO, data)
	await _frames(3)
	bearer.sensor.monitoring = false
	var dir := Vector3(player_pos.x, 0.0, player_pos.z).normalized()
	var wave_origin_offset := 0.75
	var position := dir * (distance_from_origin + wave_origin_offset)
	position.y = player_pos.y
	_player.set_physics_process(options.get("unfreeze", false))
	_player.teleport(position, options.get("face", dir))
	_player.health.heal_full()
	_player_hurtbox.invincibility_time = 0.0
	if options.get("unfreeze", false):
		await _frames(8)
		_player.teleport(position, options.get("face", dir))
		await _frames(2)
	var finished := {"count": 0}
	var slams := {"count": 0}
	bearer.shockwave.finished.connect(func() -> void: finished.count += 1)
	bearer.slammed.connect(func(_p: Vector3) -> void: slams.count += 1)
	bearer.target = _player
	_watch = bearer
	_active_tick = -1
	_hurt_ticks.clear()
	var enter_tick := _tick
	bearer.state_machine.transition_to(&"ShieldSlam")
	var press_tick := -1
	var pressed := false
	var limit_ticks := int(float(options.get("stop_after", 3.0)) / TICK)
	var input: StringName = options.get("input", &"")
	for i in limit_ticks:
		await _step()
		if input != &"" and not pressed and float(_tick - enter_tick) * TICK >= float(options.get("press_at", 0.0)):
			pressed = true
			press_tick = _tick
			Input.action_press(input)
		# Giữ nút như người chơi thật: nhảy giữ 0.3 s (nhả sớm thì cú nhảy bị cắt ngắn), dash chỉ cần nhấn
		elif pressed and _tick - press_tick >= (18 if input == &"jump" else 2):
			Input.action_release(input)
			input = &""
			pressed = false
	if options.has("stop_after") and bearer.shockwave.is_active():
		bearer.shockwave.stop()
		await _frames(2)
	await _frames(3)
	var result := {
		"hits": _hurt_ticks.map(func(t: int) -> float: return float(t - enter_tick) * TICK),
		"active_time": float(_active_tick - enter_tick) * TICK,
		"distance": distance_from_origin,
		"finished_count": finished.count,
		"slam_count": slams.count,
		"wave_processing": bearer.shockwave.is_physics_processing(),
		"wave_monitoring": (bearer.shockwave.get_node("DetectArea") as Area3D).monitoring,
		"wave_active": bearer.shockwave.is_active(),
		"press_time": float(press_tick - enter_tick) * TICK,
	}
	Input.action_release(&"jump")
	Input.action_release(&"dash")
	_watch = null
	_park_player()
	bearer.queue_free()
	await _frames(2)
	return result


func _spawn_bearer(pos: Vector3, data: ShieldBearerData = null) -> ShieldBearer:
	var bearer := BEARER_SCENE.instantiate() as ShieldBearer
	if data:
		bearer.data = data
	bearer.position = pos
	add_child(bearer)
	return bearer


## Bản sao dữ liệu quái để chỉnh riêng từng test (Resource gốc giữ nguyên)
func _data(overrides: Dictionary) -> ShieldBearerData:
	var data := BEARER_DATA.duplicate() as ShieldBearerData
	for key in overrides:
		data.set(key, overrides[key])
	return data


func _park_player() -> void:
	_player.set_physics_process(true)
	_player.teleport(PARK, Vector3.FORWARD)
	_player.health.heal_full()


func _make_attacker(bearer: ShieldBearer, angle_deg: float) -> Node3D:
	var attacker := Node3D.new()
	add_child(attacker)
	attacker.global_position = bearer.global_position + _offset_at(bearer, angle_deg) * 1.5
	return attacker


## Hướng từ quái tới chỗ đòn tới, lệch angle_deg so với mặt trước (dương = về bên phải quái)
func _offset_at(bearer: ShieldBearer, angle_deg: float) -> Vector3:
	var facing := bearer.get_facing_direction()
	return facing.rotated(Vector3.UP, deg_to_rad(angle_deg))


func _swing(bearer: ShieldBearer, angle_deg: float, heal_first: bool = true) -> Dictionary:
	var attacker := _make_attacker(bearer, angle_deg)
	var to_target := _offset_at(bearer, angle_deg)
	var counts := {"blocked": 0, "hurt": 0}
	var on_blocked := func(_i: DamageInfo, _g: HitGuard) -> void: counts.blocked += 1
	var on_hurt := func(_i: DamageInfo, _d: int) -> void: counts.hurt += 1
	bearer.guarded_hurtbox.blocked.connect(on_blocked)
	bearer.hurtbox.hurt.connect(on_hurt)
	if heal_first:
		bearer.health.heal_full()
	bearer.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, -to_target * 8.0, attacker))
	bearer.guarded_hurtbox.blocked.disconnect(on_blocked)
	bearer.hurtbox.hurt.disconnect(on_hurt)
	attacker.queue_free()
	return {"blocked": counts.blocked, "hurt": counts.hurt, "hp": bearer.health.current_health, "state": bearer.state_machine.current_state.name}


func _make_box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	body.add_child(mesh)
	body.position = pos
	add_child(body)
	return body


func _build_world() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = box.size
	mesh.mesh = plane
	mesh.position = shape.position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.5, 0.48)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


func _ensure_dir(path: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return path


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failed = true
		print("FAIL ", label)


func _step() -> void:
	await get_tree().physics_frame


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	for index in int(ceil(duration / TICK)):
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _make_arrow(pos: Vector3) -> ArrowProjectile:
	var arrow := ARROW_SCENE.instantiate() as ArrowProjectile
	arrow.position = pos
	add_child(arrow)
	return arrow
