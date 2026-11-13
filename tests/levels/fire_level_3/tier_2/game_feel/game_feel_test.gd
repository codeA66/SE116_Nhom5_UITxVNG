extends Node
## Đo "game feel" tier 2 map Lửa bằng input thật (không nhảy: chỉ chạy, đánh, dash).
## 1. Di chuyển: số khung tăng tốc / dừng / đảo chiều trên sàn phẳng.
## 2. Đánh một mục tiêu đứng yên: độ trễ bấm đánh -> bật hitbox, hitstop, rung màn hình, hất lùi, nối combo.
## 3. Giao tranh: "người chơi máy" chạy tới quái gần nhất và giữ nút đánh; đo thời gian hạ, máu mất, khoảng cách giữa hai lần trúng đòn.
##    Trận: bầy 3 sói (06), 2 Quỷ Xương Lửa + 2 sói (Hub), 5 tầng tháp (T1 đến T5, T4 là Slime Mẹ), boss tạm (tầng boss).
## 4. Leo cầu thang tới phòng boss: tốc độ trên dốc so với sàn phẳng.
## Chỉ đo và in số, không sửa gì. Không ghi save thật.
## Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/game_feel/game_feel_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const FIGHT_TIME_LIMIT: float = 45.0

var _player: Player
var _level: ZoneRoot
var _fights: Node3D
var _failed: int = 0
var _checks: int = 0
## Mốc đo cho trận hiện tại
var _hurt_times: Array[float] = []
var _hit_times: Array[float] = []
## Tốc độ chạy tối đa đo ở bước 1, dùng làm mốc cho cầu thang
var _flat_top: float = 0.0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(560.0, true, true).timeout.connect(func() -> void:
		print("GAME FEEL RESULT: TIMEOUT")
		get_tree().quit(2))
	GameState.replace_progress(PlayerProgress.new())
	for flag: StringName in [&"level_3.boss_defeated", &"level_3.t2_exit_vines"]:
		GameState.set_flag(flag)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	var tide := _level.get_node_or_null(^"Tier2Mechanics/LavaTide")
	if tide:
		tide.free()
	_player.health.max_health = 40
	_player.health.heal_full()
	_fights = _level.get_node(^"Tier2Fights") as Node3D
	_player.health.damaged.connect(func(_a: int) -> void: _hurt_times.append(_now()))
	_player.hitbox.hit.connect(func(_t: HurtboxComponent) -> void: _hit_times.append(_now()))
	await _t_movement()
	await _t_single_target()
	await _t_fight_encounter(&"T2DarkForgePack", "bầy 3 sói (06)")
	await _t_fight_encounter(&"T2HubAmbush", "Hub: 2 Quỷ Xương Lửa + 2 sói")
	await _t_fight_encounter(&"TowerT1Wolves", "tháp T1: 4 sói")
	await _t_fight_encounter(&"TowerT2Casters", "tháp T2: 1 Quỷ Xương Lửa + 3 slime")
	await _t_fight_encounter(&"TowerT3Slimes", "tháp T3: 5 slime + 3 sói")
	await _t_tower_mother()
	await _t_fight_encounter(&"TowerT5Mixed", "tháp T5: 2 Quỷ Xương Lửa + 3 sói")
	await _t_boss()
	await _t_stairs()
	print("GAME FEEL RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Di chuyển ----------

func _t_movement() -> void:
	print("--- 1. Di chuyển (sàn phẳng phòng 01) ---")
	_teleport(Vector3(206, 4.42, 55), Vector3.RIGHT)
	await _frames(20)
	var speeds: Array[float] = []
	for _i: int in range(60):
		_press_towards(Vector3.RIGHT)
		await get_tree().physics_frame
		speeds.append(_planar_speed())
	var top := speeds.max() as float
	_flat_top = top
	var to90 := _first_at_least(speeds, top * 0.9)
	print("INFO tốc độ tối đa %.2f m/s, tới 90%% sau %d khung (%.2f s)" % [top, to90, to90 / 60.0])
	_check(top > 1.0 and to90 <= 20, "tăng tốc tới 90%% tốc độ trong <= 20 khung (%d)" % to90)
	# Dừng
	_release()
	var stop_frames := 0
	for i: int in range(60):
		await get_tree().physics_frame
		if _planar_speed() < top * 0.05:
			stop_frames = i + 1
			break
	print("INFO dừng hẳn sau %d khung (%.2f s)" % [stop_frames, stop_frames / 60.0])
	_check(stop_frames > 0 and stop_frames <= 20, "thả phím: dừng trong <= 20 khung (%d)" % stop_frames)
	# Đảo chiều: đang chạy phải thì quay trái, đo tới khi vận tốc đổi dấu
	_teleport(Vector3(206, 4.42, 55), Vector3.RIGHT)
	await _frames(10)
	for _i: int in range(40):
		_press_towards(Vector3.RIGHT)
		await get_tree().physics_frame
	var right_dir := _horizontal(_player.velocity).normalized()
	var flip := 0
	for i: int in range(60):
		_press_towards(Vector3.LEFT)
		await get_tree().physics_frame
		if _horizontal(_player.velocity).dot(right_dir) < 0.0:
			flip = i + 1
			break
	_release()
	print("INFO đảo chiều (phải -> trái) đổi dấu vận tốc sau %d khung (%.2f s)" % [flip, flip / 60.0])
	_check(flip > 0 and flip <= 15, "đảo chiều đổi hướng trong <= 15 khung (%d)" % flip)
	await _frames(20)


# ---------- 2. Đánh một mục tiêu ----------

func _t_single_target() -> void:
	print("--- 2. Đánh một mục tiêu đứng yên (sói ngủ) ---")
	var wolf := (load("res://entities/enemies/volcano/shadow_wolf/shadow_wolf.tscn") as PackedScene).instantiate() as Enemy
	_level.add_child(wolf)
	_teleport(Vector3(206, 4.42, 55), Vector3.RIGHT)
	wolf.global_position = Vector3(208.0, 4.42, 55)
	await _frames(20)
	var wolf_start := wolf.global_position
	var press_t := [0.0]
	var active_t := [0.0]
	var hit_t := [0.0]
	var min_scale := [1.0]
	var peak_trauma := [0.0]
	_player.hitbox.activated.connect(func(_a: AttackData) -> void:
		if active_t[0] == 0.0:
			active_t[0] = _now(), CONNECT_ONE_SHOT)
	_player.hitbox.hit.connect(func(_t: HurtboxComponent) -> void:
		if hit_t[0] == 0.0:
			hit_t[0] = _now(), CONNECT_ONE_SHOT)
	var hp0 := wolf.health.current_health
	press_t[0] = _now()
	Input.action_press(&"attack")
	for _i: int in range(40):
		await get_tree().physics_frame
		min_scale[0] = minf(min_scale[0], Engine.time_scale)
		peak_trauma[0] = maxf(peak_trauma[0], ScreenShake.trauma)
		if _i == 1:
			Input.action_release(&"attack")
	Input.action_release(&"attack")
	await _frames(30)
	var latency: float = (active_t[0] - press_t[0]) * 1000.0
	var to_hit: float = (hit_t[0] - press_t[0]) * 1000.0
	var knock := (wolf.global_position - wolf_start).length()
	print("INFO trễ bấm -> bật hitbox %.0f ms, bấm -> trúng %.0f ms" % [latency, to_hit])
	print("INFO hitstop: time_scale thấp nhất %.2f; rung màn hình đỉnh %.2f; sói mất %d máu, bị đẩy %.2f m" % [min_scale[0], peak_trauma[0], hp0 - wolf.health.current_health, knock])
	_check(active_t[0] > 0.0 and latency <= 150.0, "bấm đánh -> hitbox bật trong <= 150 ms (%.0f)" % latency)
	_check(hit_t[0] > 0.0, "nhát đầu trúng mục tiêu đứng trước mặt 2 m")
	_check(min_scale[0] < 1.0, "có hitstop khi trúng (time_scale thấp nhất %.2f)" % min_scale[0])
	_check(peak_trauma[0] > 0.0, "có rung màn hình khi trúng (%.2f)" % peak_trauma[0])
	_check(knock > 0.05, "mục tiêu bị hất / đẩy lùi (%.2f m)" % knock)
	# Combo: giữ nút đánh 2,4 s, đếm số đòn bật hitbox
	if is_instance_valid(wolf):
		wolf.health.heal_full()
	var swings: Array[float] = []
	var counter := func(_a: AttackData) -> void: swings.append(_now())
	_player.hitbox.activated.connect(counter)
	for f: int in range(int(2.4 * 60.0)):
		_tap_attack(f)
		await get_tree().physics_frame
	Input.action_release(&"attack")
	_player.hitbox.activated.disconnect(counter)
	var gaps: Array[float] = []
	for i: int in range(1, swings.size()):
		gaps.append((swings[i] - swings[i - 1]) * 1000.0)
	print("INFO bấm liên tục 2,4 s: %d đòn, khoảng cách giữa các đòn (ms): %s" % [swings.size(), str(gaps.map(func(g: float) -> int: return int(g)))])
	_check(swings.size() >= 3, "bấm đánh liên tục thì nối combo (%d đòn / 2,4 s)" % swings.size())
	if is_instance_valid(wolf):
		wolf.free()
	await _frames(10)


# ---------- 3. Giao tranh ----------

func _t_fight_encounter(enc_name: StringName, label: String) -> void:
	print("--- 3. Giao tranh: %s ---" % label)
	var enc := _fights.get_node(NodePath(String(enc_name))) as Encounter
	_player.health.heal_full()
	_teleport(enc.global_position + Vector3.UP * 0.1, Vector3.FORWARD)
	await _frames(int((enc.spawn_interval * 4 + 0.5) * 60.0))
	await _auto_fight("Encounter " + label, func() -> bool: return enc.is_running() == false and GameState.has_flag(enc.persistent_id))
	_teleport(Vector3(212, 4.42, 52), Vector3.RIGHT)
	await _frames(20)


func _t_tower_mother() -> void:
	print("--- 3. Giao tranh: tháp T4, Slime Mẹ (phòng 16 x 16) ---")
	var fight := _fights.get_node(^"TowerT4MotherFight") as BossFight
	var ref := [null]
	fight.started.connect(func(b: Node3D) -> void: ref[0] = b, CONNECT_ONE_SHOT)
	_player.health.heal_full()
	_teleport(Vector3(208, 20.42, 10), Vector3.FORWARD)
	await _frames(20)
	var mother := ref[0] as SlimeMother
	if mother == null:
		_check(false, "Slime Mẹ tầng 4 xuất hiện")
		return
	await _auto_fight("Slime Mẹ tầng 4", func() -> bool: return mother.is_dead())
	_teleport(Vector3(212, 4.42, 52), Vector3.RIGHT)
	await _frames(20)


func _t_boss() -> void:
	print("--- 3. Giao tranh: boss tạm phòng 12 ---")
	var fight := _fights.get_node(^"T2BossFight") as BossFight
	var ref := [null]
	fight.started.connect(func(b: Node3D) -> void: ref[0] = b, CONNECT_ONE_SHOT)
	_player.health.heal_full()
	_teleport(Vector3(256, 28.42, 12), Vector3.FORWARD)
	await _frames(30)
	var boss := ref[0] as Boss1
	if boss == null:
		_check(false, "boss tạm xuất hiện")
		return
	await _auto_fight("Boss tạm", func() -> bool: return boss.health.is_dead(), 40.0)
	print("INFO boss sau trận: máu %d / %d, trạng thái %s" % [boss.health.current_health, boss.health.max_health, str(boss.get("state_machine").current_state.name) if boss.get("state_machine") != null and boss.get("state_machine").get("current_state") != null else "?"])


## Người chơi máy: chạy về quái sống gần nhất, bấm đánh (nhịp 10 khung) khi trong tầm 2,2 m. Đo đến khi done() hoặc hết giờ.
func _auto_fight(label: String, done: Callable, limit_seconds: float = FIGHT_TIME_LIMIT) -> void:
	_hurt_times.clear()
	_hit_times.clear()
	var hp0 := _player.health.current_health
	var start := _now()
	var frames := 0
	var limit := int(limit_seconds * 60.0)
	var died := false
	while frames < limit and not done.call():
		var target := _nearest_enemy()
		if target == null:
			_release()
			Input.action_release(&"attack")
			await get_tree().physics_frame
			frames += 1
			continue
		var to := target.global_position - _player.global_position
		to.y = 0.0
		if to.length() > 1.8:
			_press_towards(to.normalized())
		else:
			_release()
		if to.length() < 2.6:
			_tap_attack(frames)
		else:
			Input.action_release(&"attack")
		await get_tree().physics_frame
		frames += 1
		if _player.health.is_dead():
			died = true
			break
	_release()
	Input.action_release(&"attack")
	var secs := _now() - start
	var lost := hp0 - _player.health.current_health
	var min_gap := 99.0
	for i: int in range(1, _hurt_times.size()):
		min_gap = minf(min_gap, _hurt_times[i] - _hurt_times[i - 1])
	print("INFO %s: %s sau %.1f s, mất %d máu, bị trúng %d lần (khoảng cách ngắn nhất giữa 2 lần bị trúng %.2f s), trúng đòn %d lần (%.1f lần/s)" % [
			label, "XONG" if done.call() else "CHƯA XONG", secs, lost, _hurt_times.size(),
			min_gap if _hurt_times.size() > 1 else -1.0, _hit_times.size(), _hit_times.size() / maxf(secs, 0.1)])
	_check(not died, "%s: người chơi máy không chết (máu tối đa 40)" % label)
	if label.begins_with("Boss"):
		# Boss tạm khóa máu ở 50% tới khi phản đòn (chưa chốt cách hạ boss): chỉ báo, không tính lỗi
		print("INFO %s: %s bằng đánh thường trong %.0f s (cần phản đòn nếu chưa xong)" % [label, "hạ được" if done.call() else "CHƯA hạ được", limit_seconds])
	else:
		_check(done.call(), "%s: hạ được trong %.0f s bằng đánh thường" % [label, limit_seconds])
	await _frames(20)


# ---------- 4. Cầu thang ----------

func _t_stairs() -> void:
	print("--- 4. Leo cầu thang phòng 02 -> phòng boss ---")
	_teleport(Vector3(250, 4.42, 42), Vector3.FORWARD)
	await _frames(20)
	var y0 := _player.global_position.y
	var samples: Array[float] = []
	var gain_speed := 0.0
	var last_y := y0
	var stuck_at := -1
	for i: int in range(480):
		_press_towards(Vector3.FORWARD)
		await get_tree().physics_frame
		var y := _player.global_position.y
		# Chỉ tính các khung đang leo: sau khi tới đỉnh bị tường chặn là chuyện khác
		if y > last_y + 0.001:
			samples.append(_planar_speed())
		elif stuck_at < 0 and gain_speed > 3.0:
			stuck_at = i
		last_y = maxf(last_y, y)
		gain_speed = maxf(gain_speed, y - y0)
		if gain_speed >= 3.0:
			break
	_release()
	var flat := _flat_top
	var avg := 0.0
	for s: float in samples:
		avg += s
	avg /= maxf(samples.size(), 1)
	# Bỏ 10 khung đầu: đang tăng tốc từ đứng yên ngay trên bậc
	var min_s := samples.slice(10).min() as float
	print("INFO leo: cao thêm %.2f m, tốc độ ngang trung bình %.2f m/s, thấp nhất %.2f m/s (sàn phẳng %.2f)" % [gain_speed, avg, min_s, flat])
	_check(gain_speed > 3.0, "đi bộ từ phòng 02 lên cao hơn 3 m (%.2f)" % gain_speed)
	_check(min_s > 0.5 * flat, "không bị khựng trên cầu thang: tốc độ thấp nhất > 50%% sàn phẳng (%.2f / %.2f)" % [min_s, flat])


# ---------- Tiện ích ----------

## Người chơi thật bấm nút chứ không giữ: bấm 2 khung, nhả 8 khung
func _tap_attack(frame: int) -> void:
	var phase := frame % 10
	if phase == 0:
		Input.action_press(&"attack")
	elif phase == 2:
		Input.action_release(&"attack")


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node: Node in get_tree().get_nodes_in_group(HurtboxComponent.GROUP):
		var owner_node := (node as HurtboxComponent).owner as Node3D
		if owner_node == null or owner_node == _player:
			continue
		var h = owner_node.get("health")
		if h == null or not h is HealthComponent or (h as HealthComponent).is_dead():
			continue
		var d := owner_node.global_position.distance_to(_player.global_position)
		if d < best_d and d < 40.0:
			best_d = d
			best = owner_node
	return best


func _planar_speed() -> float:
	return _horizontal(_player.velocity).length()


func _horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _first_at_least(arr: Array[float], threshold: float) -> int:
	for i: int in range(arr.size()):
		if arr[i] >= threshold:
			return i + 1
	return arr.size()


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_set_axis(&"move_right", &"move_left", world_dir.dot(right))
	_set_axis(&"move_back", &"move_forward", -world_dir.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
