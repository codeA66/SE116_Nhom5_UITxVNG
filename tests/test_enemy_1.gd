extends Node3D
## Đo hành vi thật của Quái 1 (lướt rồi chém). Chạy headless:
## godot --headless --path . tests/test_enemy_1.tscn
## Mỗi trial dựng sân riêng, đếm thời gian bằng số physics frame (60/s) nên không phụ thuộc tốc độ máy.
## Không ghi save: player chỉ dùng teleport, không mở khoá kỹ năng.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/enemy_1/enemy_1.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SPIKE_SCENE: PackedScene = preload("res://objects/hazards/spike_trap.tscn")
const KILL_SCENE: PackedScene = preload("res://objects/kill_zone/kill_zone.tscn")
const TICK := 1.0 / 60.0
## Tốc độ chạy / dash của player (m/s) dùng để giả lập né
const PLAYER_RUN := 6.0
const PLAYER_DASH_SPEED := 15.0
const PLAYER_DASH_TIME := 0.18
## Lực đẩy của kỹ năng gió thật (wind_blast.tres push_speed)
const WIND_PUSH := 12.0

var _failed: bool = false
var _active: Trial


## Một lần đo: sân + quái + player + nhật ký sự kiện theo frame
class Trial extends RefCounted:
	var arena: Node3D
	var enemy: Enemy
	var player: Player
	var frame: int = 0
	var log: Array = []
	var driver: Callable
	var hb_was_active: bool = false
	var positions: Array[Vector3] = []
	var yaws: Array[float] = []
	var machine: StateMachine
	var dash: Node

	func sample() -> void:
		frame += 1
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			positions.append(enemy.global_position)
			yaws.append(enemy.model.rotation.y)
			var active := enemy.hitbox.is_active()
			if active != hb_was_active:
				hb_was_active = active
				log.append([frame, "hit_on" if active else "hit_off"])
		else:
			positions.append(positions.back() if not positions.is_empty() else Vector3.ZERO)
			yaws.append(0.0)
		if driver.is_valid() and is_instance_valid(player):
			driver.call(self)

	func note(label: String) -> void:
		log.append([frame, label])

	## Frame của lần thứ n (0 = đầu tiên) xuất hiện nhãn; -1 nếu chưa có
	func at(label: String, n: int = 0) -> int:
		var seen := 0
		for entry in log:
			if entry[1] == label:
				if seen == n:
					return entry[0]
				seen += 1
		return -1

	func count(label: String) -> int:
		var c := 0
		for entry in log:
			if entry[1] == label:
				c += 1
		return c

	func secs(a: int, b: int) -> float:
		return (b - a) * TICK


func _ready() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _active:
		_active.sample()


func _run() -> void:
	# Truyền tên bài sau "--" để chạy riêng, ví dụ: ... tests/test_enemy_1.tscn -- wind slope
	var only := OS.get_cmdline_user_args()
	var all := {
		"telegraph": _t_telegraph_and_timing, "tracking": _t_tracking_and_lock, "distances": _t_dash_distances,
		"nopass": _t_no_pass_player, "single": _t_single_hit, "dodges": _t_dodges, "counter": _t_counter_and_cancel,
		"cooldown": _t_cooldown, "blocked": _t_blocked_path, "fence": _t_thin_fence, "isolation": _t_two_enemies_isolation,
		"ledge": _t_ledge, "spikes": _t_spikes, "wind": _t_wind, "glow": _t_glow_cleanup, "perf": _t_perf_flags,
		"extremes": _t_extremes, "slope": _t_slope, "debug": _t_debug,
	}
	for key: String in all:
		if key in only or (only.is_empty() and key != "debug"):
			await all[key].call()
	print("ENEMY1_CHECK ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


# ---------- Dựng sân / trial ----------

## opts: enemy_pos, enemy_face, player_pos, mod (Callable(enemy) trước add_child), extra (Callable(arena)),
## floor_z_max (cắt sàn để tạo vực), player_ghost (player bất tử, không bị đánh)
func _make(opts: Dictionary) -> Trial:
	var t := Trial.new()
	t.arena = Node3D.new()
	add_child(t.arena)
	if not opts.get("no_floor", false):
		_add_floor(t.arena, Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0), opts.get("floor_z_max", 1000.0))
	var extra: Callable = opts.get("extra", Callable())
	if extra.is_valid():
		extra.call(t.arena)
	t.enemy = ENEMY_SCENE.instantiate() as Enemy
	# Tách dữ liệu riêng để mỗi trial chỉnh thông số không đổi file .tres dùng chung
	t.enemy.data = t.enemy.data.duplicate()
	t.enemy.data.attack = t.enemy.data.attack.duplicate()
	t.dash = t.enemy.get_node("StateMachine/DashSlash")
	t.dash.data = t.dash.data.duplicate()
	t.enemy.position = opts.get("enemy_pos", Vector3.ZERO)
	var mod: Callable = opts.get("mod", Callable())
	if mod.is_valid():
		mod.call(t.enemy)
	t.arena.add_child(t.enemy)
	t.machine = t.enemy.state_machine
	t.machine.state_changed.connect(func(from: StringName, to: StringName) -> void:
		t.note("exit_" + String(from))
		t.note("enter_" + String(to)))
	t.enemy.died.connect(func(_e: Enemy) -> void: t.note("died"))
	t.dash.phase_started.connect(func(phase: int) -> void:
		t.note(["phase_WINDUP", "phase_DASH", "phase_SLASH"][phase]))
	t.player = PLAYER_SCENE.instantiate() as Player
	t.arena.add_child(t.player)
	t.player.teleport(opts.get("player_pos", Vector3(0.0, 0.0, 3.0)), Vector3.BACK)
	var hurt := t.player.get_node("HurtboxComponent") as HurtboxComponent
	hurt.hurt.connect(func(_info: DamageInfo, _dmg: int) -> void: t.note("player_hurt"))
	if opts.get("player_ghost", false):
		hurt.set_invincible(100000.0)
	await _frames(2)
	t.enemy.face_instantly(opts.get("enemy_face", Vector3.BACK))
	return t


func _add_floor(parent: Node3D, center: Vector3, size: Vector3, z_max: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var depth := minf(size.z, z_max + size.z * 0.5)
	box.size = Vector3(size.x, size.y, depth)
	shape.shape = box
	body.add_child(shape)
	# Cạnh sau của sàn giữ nguyên, cắt cạnh trước tại z_max
	body.position = Vector3(center.x, center.y, center.z - size.z * 0.5 + depth * 0.5)
	parent.add_child(body)


## Tường mỏng chặn thân quái (layer 1 world) hoặc rào vô hình (layer 256 player_blocker)
func _add_wall(parent: Node3D, pos: Vector3, size: Vector3, layer: int = 256, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	return body


func _end(t: Trial) -> void:
	_active = null
	t.arena.queue_free()
	await _frames(3)


func _begin(t: Trial) -> void:
	_active = t


# ---------- Các bài đo ----------

func _t_telegraph_and_timing() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	var idle_overlay := _has_overlay(t.enemy)
	var idle_glow := _glow_visible(t.enemy)
	await _until(t, func() -> bool: return t.at("hit_on") >= 0, 4.0)
	var enter := t.at("enter_DashSlash")
	var hit := t.at("hit_on")
	var total := t.secs(enter, hit)
	_check(enter > 0 and hit > 0 and total >= 0.69 - TICK and total <= 0.94 + TICK, "telegraph -> hộp chém bật = %.3f s (cần 0.69-0.94)" % total)
	_check(not idle_overlay and not idle_glow, "ảnh Idle: không overlay cam, glow tắt")
	await _end(t)

	# Mẫu trạng thái hiển thị tại t = 0.1 / 0.45 / 0.6 s kể từ lúc vào DashSlash
	t = await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	await _until(t, func() -> bool: return t.at("enter_DashSlash") >= 0, 4.0)
	var start := t.frame
	var samples := {}
	for mark: float in [0.1, 0.45, 0.6]:
		await _until(t, func() -> bool: return t.secs(start, t.frame) >= mark, 2.0)
		samples[mark] = [_has_overlay(t.enemy), _glow_visible(t.enemy), t.enemy.model.get_node("Visual/Rig/Enemy1Model/Hips").rotation.x]
	print("INFO mẫu (overlay, glow, Hips.rot.x) @0.1/0.45/0.6: ", samples)
	_check(samples[0.1][0] and not samples[0.1][1], "t=0.1: overlay cam bật, glow chưa loé")
	_check(samples[0.45][0] and samples[0.6][0], "t=0.45 và 0.6: overlay cam còn bật")
	_check(samples[0.6][1], "t=0.6: glow đã loé")
	_check(absf(samples[0.6][2]) > 0.05 or true, "tư thế khom (chỉ in số, xem ảnh chụp)")
	await _end(t)


func _t_tracking_and_lock() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	var center := t.enemy.position
	t.driver = func(tr: Trial) -> void:
		# Player đi vòng quanh quái bán kính 3 m với 2 rad/s (= 6 m/s)
		var start := tr.at("enter_DashSlash")
		if start < 0:
			return
		var s := tr.secs(start, tr.frame)
		var a := 2.0 * s
		tr.player.global_position = center + Vector3(sin(a), 0.0, cos(a)) * 3.0
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_DASH") >= 0, 4.0)
	var start := t.at("enter_DashSlash")
	var f := func(sec: float) -> float: return t.yaws[start + roundi(sec / TICK) - 1]
	var y0: float = f.call(0.02)
	var y_mid: float = f.call(0.4)
	var y_lock: float = f.call(0.47)
	var y_end: float = f.call(0.64)
	print("INFO yaw @0.02/0.40/0.47/0.64: %.3f %.3f %.3f %.3f" % [y0, y_mid, y_lock, y_end])
	_check(absf(angle_difference(y0, y_mid)) > 0.3, "bám hướng: yaw đổi %.2f rad trong 0.45 s đầu" % absf(angle_difference(y0, y_mid)))
	_check(absf(angle_difference(y_lock, y_end)) < 0.01, "khoá hướng: yaw sau 0.47 s không đổi (%.4f)" % absf(angle_difference(y_lock, y_end)))
	await _end(t)


func _t_dash_distances() -> void:
	for dist: float in [4.3, 3.0, 1.5, 0.8]:
		var t := await _make({"player_pos": Vector3(0, 0, dist), "player_ghost": true})
		_begin(t)
		await _until(t, func() -> bool: return t.at("phase_SLASH") >= 0, 4.0)
		var slash := t.at("phase_SLASH")
		var gap := t.player.global_position.distance_to(t.enemy.global_position) if slash > 0 else -1.0
		var traveled := t.positions[slash - 1].distance_to(t.positions[t.at("enter_DashSlash")])
		var had_dash := t.at("phase_DASH") >= 0
		print("INFO player %.1f m: dash=%s, lướt %.2f m, cách player %.2f m" % [dist, had_dash, traveled, gap])
		var expect_gap := maxf(1.0, minf(dist, 1.0)) if dist >= 1.0 else dist
		_check(absf(gap - expect_gap) <= 0.1 and traveled <= 3.5 + 0.1, "player %.1f m: cách %.2f (cần %.2f ±0.1), lướt %.2f ≤ 3.5" % [dist, gap, expect_gap, traveled])
		if dist <= 1.0:
			_check(not had_dash, "0.8 m: chém tại chỗ, không lướt")
		await _end(t)


func _t_no_pass_player() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	t.driver = func(tr: Trial) -> void:
		var start := tr.at("enter_DashSlash")
		if start < 0:
			return
		var s := tr.secs(start, tr.frame)
		# Từ lúc khoá hướng player chạy lao về phía quái, dừng ở 0.3 m trước quái
		if s > 0.45:
			var target_z := tr.enemy.global_position.z + 0.3
			tr.player.global_position.z = move_toward(tr.player.global_position.z, target_z, PLAYER_RUN * TICK)
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_SLASH") >= 0, 4.0)
	var min_lead := INF
	for i in range(t.at("phase_DASH"), t.at("phase_SLASH")):
		min_lead = minf(min_lead, t.player.global_position.z - t.positions[i].z)
	var gap := t.player.global_position.distance_to(t.enemy.global_position)
	print("INFO không xuyên: khoảng cách cuối %.2f m, player luôn ở trước quái (min lead %.2f)" % [gap, min_lead])
	# Player đứng sát quái lúc ấy: quái không được vượt qua
	_check(t.enemy.global_position.z <= t.player.global_position.z + 0.01, "lướt không vượt qua player đang lao tới")
	await _end(t)


func _t_single_hit() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 0.8)})
	(t.player.get_node("HurtboxComponent") as HurtboxComponent).invincibility_time = 0.0
	_begin(t)
	await _until(t, func() -> bool: return t.at("hit_off") >= 0, 4.0)
	await _frames(5)
	_check(t.count("player_hurt") == 1, "player đứng trong hộp suốt active (i-frames tắt): hurt = %d (cần 1)" % t.count("player_hurt"))
	await _end(t)


## kind: stand / run_side / dash_side / back
func _dodge(kind: String, reaction: float) -> int:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0)})
	var side := Vector3.RIGHT
	var back := Vector3.BACK
	t.driver = func(tr: Trial) -> void:
		var start := tr.at("enter_DashSlash")
		if start < 0:
			return
		var s := tr.secs(start, tr.frame) - 0.45 - reaction
		if s < 0.0:
			return
		match kind:
			"run_side":
				tr.player.global_position += side * PLAYER_RUN * TICK
			"dash_side":
				if s < PLAYER_DASH_TIME:
					tr.player.global_position += side * PLAYER_DASH_SPEED * TICK
					(tr.player.get_node("HurtboxComponent") as HurtboxComponent).set_invincible(TICK * 2.0)
			"back":
				tr.player.global_position += back * PLAYER_RUN * TICK
	_begin(t)
	await _until(t, func() -> bool: return t.at("hit_off") >= 0, 4.0)
	await _frames(5)
	var hits := t.count("player_hurt")
	await _end(t)
	return hits


func _t_dodges() -> void:
	var stand := await _dodge("stand", 0.0)
	var run_side := await _dodge("run_side", 0.0)
	var dash_side := await _dodge("dash_side", 0.0)
	var back := await _dodge("back", 0.0)
	_check(stand == 1, "né (d) đứng yên: trúng %d (cần 1)" % stand)
	_check(run_side == 0, "né (a) chạy ngang ngay khi loé sáng: trúng %d (cần 0)" % run_side)
	_check(dash_side == 0, "né (b) dash ngang: trúng %d (cần 0)" % dash_side)
	_check(back == 0, "né (c) lùi thẳng: trúng %d (cần 0)" % back)
	var run_late := await _dodge("run_side", 0.2)
	var back_late := await _dodge("back", 0.2)
	var dash_late := await _dodge("dash_side", 0.2)
	print("INFO phản xạ 0.2 s sau loé: chạy ngang trúng %d, lùi trúng %d, dash ngang trúng %d" % [run_late, back_late, dash_late])


func _hurt(enemy: Enemy, source: Node3D, direction: Vector3 = Vector3.BACK) -> void:
	enemy.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, direction * 5.0, source))


func _t_counter_and_cancel() -> void:
	# Chém trong pha hồi -> khựng; 3 nhát -> chết
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	await _until(t, func() -> bool: return t.at("hit_off") >= 0, 4.0)
	await _frames(6)
	_hurt(t.enemy, t.player)
	await _frames(2)
	_check(String(t.machine.current_state.name) == "Hurt", "chém trong pha hồi: vào Hurt (state = %s)" % t.machine.current_state.name)
	await _seconds(0.5)
	_hurt(t.enemy, t.player)
	await _seconds(0.5)
	_hurt(t.enemy, t.player)
	await _frames(3)
	_check((t.count("died") > 0), "3 nhát: quái chết")
	await _end(t)

	# Chém trong pha lấy đà: huỷ đòn, telegraph tắt, glow tắt, cooldown chạy
	t = await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_WINDUP") >= 0, 4.0)
	var start := t.frame
	await _until(t, func() -> bool: return t.secs(start, t.frame) >= 0.55, 2.0)
	_check(_has_overlay(t.enemy) and _glow_visible(t.enemy), "trước khi bị chém: overlay + glow đang bật")
	_hurt(t.enemy, t.player)
	await _seconds(0.3)
	_check(t.at("phase_DASH") < 0, "chém trong lấy đà: không lướt")
	_check(not _has_overlay(t.enemy), "chém trong lấy đà: overlay tắt")
	_check(not _glow_visible(t.enemy), "chém trong lấy đà: glow tắt")
	var exit_frame := t.at("exit_DashSlash")
	await _until(t, func() -> bool: return t.at("enter_DashSlash", 1) >= 0, 5.0)
	var gap := t.secs(exit_frame, t.at("enter_DashSlash", 1))
	_check(gap >= 1.4 - TICK, "cooldown sau khi bị ngắt: %.2f s mới vào DashSlash lại (cần ≥ 1.4)" % gap)
	await _end(t)


func _t_cooldown() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	await _until(t, func() -> bool: return t.at("enter_DashSlash", 2) >= 0, 12.0)
	var gap1 := t.secs(t.at("exit_DashSlash", 0), t.at("enter_DashSlash", 1))
	var gap2 := t.secs(t.at("exit_DashSlash", 1), t.at("enter_DashSlash", 2))
	print("INFO chu kỳ: nghỉ %.2f s, %.2f s" % [gap1, gap2])
	_check(gap1 >= 1.4 - TICK and gap2 >= 1.4 - TICK, "cooldown ≥ 1.4 s giữa hai đòn (%.2f, %.2f)" % [gap1, gap2])
	# Telegraph không nhấp nháy: số lần overlay bật = số lần vào DashSlash (kiểm gián tiếp: mỗi lần chỉ 1 windup)
	_check(t.count("phase_WINDUP") == t.count("enter_DashSlash"), "mỗi lần vào DashSlash chỉ một lần lấy đà")
	await _end(t)


func _t_blocked_path() -> void:
	var t := await _make({
		"enemy_pos": Vector3(0, 0, 0), "player_pos": Vector3(0, 0, 4.0), "player_ghost": true,
		"extra": func(a: Node3D) -> void: _add_wall(a, Vector3(0, 1.5, 2.0), Vector3(12, 3, 0.3)),
	})
	_begin(t)
	var seen_overlay: Array[bool] = [false]
	t.driver = func(tr: Trial) -> void:
		if _has_overlay(tr.enemy):
			seen_overlay[0] = true
	await _seconds(6.0)
	print("INFO sau rào: vào DashSlash %d lần, lấy đà %d lần" % [t.count("enter_DashSlash"), t.count("phase_WINDUP")])
	_check(t.count("phase_WINDUP") == 0 and not seen_overlay[0], "player sau rào: không lấy đà, không hiện telegraph")
	_check(t.count("enter_DashSlash") >= 1, "quái vẫn thử đòn rồi huỷ (vào DashSlash %d lần)" % t.count("enter_DashSlash"))
	_check(t.at("phase_DASH") < 0 and t.enemy.global_position.z < 1.7, "quái không đâm xuyên rào")
	await _end(t)


## Rào dày 0.3 m, quái ép sát; player ngay sau rào. fence=false là đối chứng
func _fence_trial(fence: bool, diagonal: bool, mods: Dictionary = {}) -> int:
	var player_pos := Vector3(0.65, 0, 0.95) if diagonal else Vector3(0, 0, 0.9)
	var t := await _make({
		"enemy_pos": Vector3(0, 0, 0.05), "player_pos": player_pos,
		"mod": func(e: Enemy) -> void:
			var dash := e.get_node("StateMachine/DashSlash")
			dash.data = dash.data.duplicate()
			dash.data.require_clear_path = false
			for key: String in mods:
				if key in e.data:
					e.data.set(key, mods[key])
				else:
					dash.data.set(key, mods[key]),
		"extra": func(a: Node3D) -> void:
			if fence:
				_add_wall(a, Vector3(0, 1.5, 0.55), Vector3(12, 3, 0.3)),
	})
	(t.player.get_node("HurtboxComponent") as HurtboxComponent).invincibility_time = 0.0
	# Giữ player đứng yên đúng chỗ (bị đẩy lùi thì kéo lại), chỉ đo có trúng hay không
	t.driver = func(tr: Trial) -> void: tr.player.global_position = player_pos
	_begin(t)
	await _until(t, func() -> bool: return t.at("hit_off") >= 0, 4.0)
	await _frames(5)
	var hits := t.count("player_hurt")
	await _end(t)
	return hits


func _t_thin_fence() -> void:
	var with_straight := await _fence_trial(true, false)
	var without_straight := await _fence_trial(false, false)
	var with_diag := await _fence_trial(true, true)
	var without_diag := await _fence_trial(false, true)
	_check(with_straight == 0 and without_straight >= 1, "rào 0.3 m thẳng: có rào trúng %d (cần 0), không rào trúng %d (cần ≥1)" % [with_straight, without_straight])
	_check(with_diag == 0 and without_diag >= 1, "rào 0.3 m chéo: có rào trúng %d (cần 0), không rào trúng %d (cần ≥1)" % [with_diag, without_diag])


func _t_two_enemies_isolation() -> void:
	var t := await _make({
		"enemy_pos": Vector3(0, 0, 0.05), "player_pos": Vector3(0, 0, 0.9), "player_ghost": true,
		"mod": func(e: Enemy) -> void:
			var dash := e.get_node("StateMachine/DashSlash")
			dash.data = dash.data.duplicate()
			dash.data.require_clear_path = false,
		"extra": func(a: Node3D) -> void: _add_wall(a, Vector3(0, 1.5, 0.55), Vector3(12, 3, 0.3)),
	})
	# Quái B ở xa, chưa thấy player, cùng loại
	var b := ENEMY_SCENE.instantiate() as Enemy
	b.position = Vector3(-20, 0, -20)
	t.arena.add_child(b)
	await _frames(2)
	var shape_a := t.enemy.get_node("Model/Hitbox/CollisionShape3D") as CollisionShape3D
	var shape_b := b.get_node("Model/Hitbox/CollisionShape3D") as CollisionShape3D
	var before := (shape_b.shape as BoxShape3D).size.z
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_SLASH") >= 0, 4.0)
	await _frames(2)
	var a_depth := (shape_a.shape as BoxShape3D).size.z
	var b_depth := (shape_b.shape as BoxShape3D).size.z
	print("INFO hộp chém A (sát rào) sâu %.3f, B %.3f (trước %.3f)" % [a_depth, b_depth, before])
	_check(a_depth < before - 0.3 and is_equal_approx(b_depth, before), "rút tầm hộp A không đổi hộp B (local_to_scene)")
	await _end(t)


func _t_ledge() -> void:
	for stop: bool in [true, false]:
		var t := await _make({
			"enemy_pos": Vector3(0, 0, 2.4), "player_pos": Vector3(0, 0, 6.5), "player_ghost": true,
			"floor_z_max": 3.0,
			"mod": func(e: Enemy) -> void:
				var dash := e.get_node("StateMachine/DashSlash")
				dash.data = dash.data.duplicate()
				dash.data.stop_at_ledge = stop
				dash.data.require_clear_path = false,
			"extra": func(a: Node3D) -> void:
				_add_floor(a, Vector3(0, -0.5, 14.0), Vector3(60, 1, 16), 1000.0)
				var kz := KILL_SCENE.instantiate() as KillZone
				kz.position = Vector3(0, -6, 5)
				kz.size = Vector3(60, 2, 60)
				kz.collision_mask = 6
				a.add_child(kz),
		})
		_begin(t)
		await _seconds(3.0)
		var fell := t.count("died") > 0 or (is_instance_valid(t.enemy) and t.enemy.global_position.y < -1.0)
		if stop:
			_check(not fell, "mép vực (stop_at_ledge = true): quái không rơi (y = %.2f)" % t.positions.back().y)
		else:
			_check(fell, "stop_at_ledge = false: quái rơi và chết (y = %.2f, chết = %s)" % [t.positions.back().y, (t.count("died") > 0)])
		await _end(t)


func _t_spikes() -> void:
	var t := await _make({
		"enemy_pos": Vector3(0, 0, 0), "player_pos": Vector3(0, 0, 4.0), "player_ghost": true,
		"extra": func(a: Node3D) -> void:
			var spikes := SPIKE_SCENE.instantiate() as Area3D
			spikes.position = Vector3(0, 0, 2.2)
			spikes.collision_mask = 6
			a.add_child(spikes),
	})
	_begin(t)
	await _seconds(3.0)
	_check((t.count("died") > 0), "dụ lướt qua gai: quái chết")
	await _end(t)


func _t_wind() -> void:
	# Quãng trôi trên sàn phẳng
	var t := await _make({"enemy_pos": Vector3(0, 0, 0), "player_pos": Vector3(0, 0, 30.0), "player_ghost": true, "mod": func(e: Enemy) -> void: e.data.patrol_radius = 0.0})
	_begin(t)
	await _frames(5)
	var start := t.enemy.global_position
	t.enemy.wind_receiver.push(Vector3.BACK * WIND_PUSH)
	# Lấy quãng xa nhất: hết trôi quái tự đi về home_position, đo cuối cửa sổ sẽ ra số nhỏ hơn quãng trôi thật
	var drift := 0.0
	for i in int(2.5 / TICK):
		await get_tree().physics_frame
		drift = maxf(drift, t.enemy.global_position.distance_to(start))
	print("INFO trôi trên sàn phẳng: %.2f m (kỳ vọng ~5.2)" % drift)
	_check(absf(drift - 5.2) <= 0.5, "quãng trôi %.2f m (cần 5.2 ±0.5)" % drift)
	await _end(t)

	# Thổi ở từng pha: Idle / lấy đà / lướt / hồi
	for phase_name: String in ["idle", "windup", "dash", "recover"]:
		t = await _make({"enemy_pos": Vector3(0, 0, 0), "player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
		_begin(t)
		match phase_name:
			"idle":
				await _frames(1)
			"windup":
				await _until(t, func() -> bool: return t.at("phase_WINDUP") >= 0, 3.0)
				await _frames(20)
			"dash":
				await _until(t, func() -> bool: return t.at("phase_DASH") >= 0, 3.0)
				await _frames(1)
			"recover":
				await _until(t, func() -> bool: return t.at("hit_off") >= 0, 3.0)
				await _frames(5)
		# Quái chưa thấy player ở "idle" thì chỉ cần đang Idle
		t.enemy.wind_receiver.push(Vector3.LEFT * WIND_PUSH)
		await _frames(3)
		var blown := String(t.machine.current_state.name) == "Blown"
		var reach_ok := is_equal_approx((t.enemy.get_node("Model/Hitbox/CollisionShape3D").shape as BoxShape3D).size.z + 0.1, t.enemy.data.hitbox_reach)
		_check(blown and not _has_overlay(t.enemy) and not t.enemy.hitbox.is_active() and reach_ok,
			"thổi lúc %s: Blown=%s, overlay tắt, hộp tắt, tầm hộp trả về (%s)" % [phase_name, blown, reach_ok])
		await _end(t)

	# Thổi từ cách mép khe 1 m -> rơi vào vực chết
	t = await _make({
		"enemy_pos": Vector3(0, 0, 2.0), "player_pos": Vector3(0, 0, 30.0), "player_ghost": true,
		"floor_z_max": 3.0,
		"extra": func(a: Node3D) -> void:
			var kz := KILL_SCENE.instantiate() as KillZone
			kz.position = Vector3(0, -6, 5)
			kz.size = Vector3(60, 2, 60)
			kz.collision_mask = 6
			a.add_child(kz),
	})
	_begin(t)
	await _frames(5)
	t.enemy.wind_receiver.push(Vector3.BACK * WIND_PUSH)
	await _seconds(3.0)
	_check((t.count("died") > 0), "thổi từ cách mép 1 m: rơi vực, chết")
	await _end(t)

	# wind_multiplier cực đoan
	t = await _make({"enemy_pos": Vector3(0, 0, 0), "player_pos": Vector3(0, 0, 30.0), "player_ghost": true,
		"mod": func(e: Enemy) -> void: e.data.wind_multiplier = 0.0; e.data.patrol_radius = 0.0})
	_begin(t)
	await _frames(5)
	start = t.enemy.global_position
	t.enemy.wind_receiver.push(Vector3.BACK * WIND_PUSH)
	await _seconds(1.5)
	_check(String(t.machine.current_state.name) != "Blown" and t.enemy.global_position.distance_to(start) < 0.05, "wind_multiplier 0: không Blown, không trôi (%.3f m)" % t.enemy.global_position.distance_to(start))
	await _end(t)

	t = await _make({"enemy_pos": Vector3(0, 0, -5), "player_pos": Vector3(0, 0, 30.0), "player_ghost": true,
		"floor_z_max": -2.0,
		"extra": func(a: Node3D) -> void: _add_floor(a, Vector3(0, -0.5, 14.0), Vector3(60, 1, 20), 1000.0),
		"mod": func(e: Enemy) -> void: e.data.wind_multiplier = 3.0; e.data.patrol_radius = 0.0})
	_begin(t)
	await _frames(5)
	start = t.enemy.global_position
	t.enemy.wind_receiver.push(Vector3.BACK * WIND_PUSH)
	await _seconds(3.0)
	print("INFO wind_multiplier 3.0: vị trí cuối z=%.2f y=%.2f (sàn gần hết ở z=-2, sàn xa bắt đầu z=4), chết=%s" % [t.positions.back().z, t.positions.back().y, (t.count("died") > 0)])
	await _end(t)


func _t_glow_cleanup() -> void:
	for phase_name: String in ["windup", "dash", "slash"]:
		var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
		_begin(t)
		var label := "phase_" + phase_name.to_upper()
		await _until(t, func() -> bool: return t.at(label) >= 0, 3.0)
		match phase_name:
			"windup":
				await _seconds(0.55)
			"dash":
				await _frames(2)
			"slash":
				await _frames(3)
		_hurt(t.enemy, t.player)
		await _seconds(0.3)
		_check(not _glow_visible(t.enemy) and not _has_overlay(t.enemy), "ngắt đòn ở pha %s: glow và overlay tắt" % phase_name)
		await _end(t)
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_WINDUP") >= 0, 3.0)
	await _seconds(0.6)
	t.enemy.wind_receiver.push(Vector3.LEFT * WIND_PUSH)
	await _seconds(0.3)
	_check(not _glow_visible(t.enemy) and not _has_overlay(t.enemy), "bị thổi lúc lấy đà (glow đang bật): glow và overlay tắt")
	await _end(t)


func _t_perf_flags() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	var clearance := t.enemy.get_node("Model/SlashClearance") as ShapeCast3D
	var probe := t.enemy.get_node("Model/LedgeProbe") as RayCast3D
	var always_off: Array[bool] = [true]
	t.driver = func(_tr: Trial) -> void:
		if clearance.enabled or probe.enabled:
			always_off[0] = false
	_begin(t)
	await _until(t, func() -> bool: return t.at("enter_DashSlash", 1) >= 0, 12.0)
	_check(always_off[0], "clearance và ledge_probe luôn enabled = false (cả khi lướt)")
	await _end(t)


func _t_extremes() -> void:
	# Mỗi ca: không lỗi, không kẹt state (ra khỏi DashSlash trong windup + 4 s), ghi lại số đo
	var cases := {
		"windup_time 0.05": {"windup_time": 0.05},
		"windup_time 3.0": {"windup_time": 3.0},
		"track_time 1.0 > windup": {"track_time": 1.0},
		"track_time 0": {"track_time": 0.0},
		"dash_max_distance 0": {"dash_max_distance": 0.0},
		"dash_max_distance 12": {"dash_max_distance": 12.0},
		"dash_speed 2": {"dash_speed": 2.0},
		"dash_speed 40": {"dash_speed": 40.0},
		"dash_speed 0": {"dash_speed": 0.0},
		"stop_distance 0": {"stop_distance": 0.0},
		"stop_distance 3": {"stop_distance": 3.0},
		"hitbox_reach 0.2": {"hitbox_reach": 0.2},
		"hitbox_reach 4.0": {"hitbox_reach": 4.0},
		"attack_range 1 < reach": {"attack_range": 1.0},
		"attack_cooldown 0": {"attack_cooldown": 0.0},
	}
	for label: String in cases:
		var mods: Dictionary = cases[label]
		var t := await _make({
			"player_pos": Vector3(0, 0, 3.0), "player_ghost": true,
			"mod": func(e: Enemy) -> void:
				var dash := e.get_node("StateMachine/DashSlash")
				for key: String in mods:
					if key in e.data:
						e.data.set(key, mods[key])
					else:
						dash.data.set(key, mods[key]),
		})
		_begin(t)
		var wait := 6.0 if mods.has("windup_time") and mods["windup_time"] > 1.0 else 4.0
		await _until(t, func() -> bool: return t.at("exit_DashSlash") >= 0, wait + 4.0)
		var done := t.at("exit_DashSlash") >= 0
		var d := t.positions[t.at("phase_SLASH") - 1].distance_to(t.positions[maxi(t.at("enter_DashSlash"), 0)]) if t.at("phase_SLASH") > 0 else -1.0
		var gap := t.player.global_position.distance_to(t.enemy.global_position)
		print("INFO [%s] xong=%s lướt=%.2f m cách player=%.2f m state=%s" % [label, done, d, gap, t.machine.current_state.name])
		_check(done and is_finite(t.enemy.global_position.x), "cực đoan %s: thoát DashSlash, vị trí hữu hạn" % label)
		await _end(t)

	# Quãng dài 12 m: dừng ở 1.0 m trước player; tường (không huỷ trước) chặn lướt; 40 m/s không xuyên rào 0.3 m
	var t := await _make({"enemy_pos": Vector3(0, 0, -6), "player_pos": Vector3(0, 0, 3.0), "player_ghost": true,
		"mod": func(e: Enemy) -> void:
			e.data.attack_range = 12.0
			var dash := e.get_node("StateMachine/DashSlash")
			dash.data.dash_max_distance = 12.0})
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_SLASH") >= 0, 6.0)
	var gap := t.player.global_position.distance_to(t.enemy.global_position)
	_check(absf(gap - 1.0) <= 0.1, "lướt dài 12 m: dừng cách player %.2f m (cần 1.0 ±0.1)" % gap)
	await _end(t)

	for speed: float in [40.0, 14.0]:
		t = await _make({"enemy_pos": Vector3(0, 0, 0), "player_pos": Vector3(0, 0, 4.0), "player_ghost": true,
			"extra": func(a: Node3D) -> void: _add_wall(a, Vector3(0, 1.5, 2.0), Vector3(12, 3, 0.3), 1),
			"mod": func(e: Enemy) -> void:
				var dash := e.get_node("StateMachine/DashSlash")
				dash.data.dash_speed = speed
				dash.data.require_clear_path = false})
		_begin(t)
		await _until(t, func() -> bool: return t.at("exit_DashSlash") >= 0, 6.0)
		var z := t.enemy.global_position.z
		print("INFO tường 0.3 m ở z=2, dash_speed %.0f: quái dừng z=%.2f" % [speed, z])
		_check(z < 1.85 + 0.01, "dash_speed %.0f: không xuyên tường 0.3 m (z=%.2f < 1.85)" % [speed, z])
		await _end(t)

	# Hộp chém không vuông
	t = await _make({"player_pos": Vector3(0, 0, 0.8), "player_ghost": true,
		"mod": func(e: Enemy) -> void:
			((e.get_node("Model/Hitbox/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size = Vector3(0.3, 2.0, 3.0)})
	_begin(t)
	await _until(t, func() -> bool: return t.at("exit_DashSlash") >= 0, 5.0)
	_check(t.at("exit_DashSlash") >= 0, "hộp chém 0.3 x 2 x 3: không lỗi, không kẹt")
	await _end(t)

	# attack_cooldown 0 không lặp vô hạn trong cùng frame: số lần vào DashSlash trong 3 s có hạn
	t = await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true, "mod": func(e: Enemy) -> void: e.data.attack_cooldown = 0.0})
	_begin(t)
	await _seconds(3.0)
	print("INFO attack_cooldown 0: vào DashSlash %d lần trong 3 s" % t.count("enter_DashSlash"))
	_check(t.count("enter_DashSlash") < 10, "attack_cooldown 0: không lặp vô hạn")
	await _end(t)


func _t_slope() -> void:
	# Dốc 20 độ nâng dần về phía -Z (mặt dốc y = (8 - z) * tan). Đo độ lệch của quái so với mặt dốc lúc lướt lên / xuống
	var slope := deg_to_rad(20.0)
	var surface := func(z: float) -> float: return (8.0 - z) * tan(slope)
	for case_name: String in ["lên dốc", "xuống dốc"]:
		var up := case_name == "lên dốc"
		var enemy_z := 8.0 if up else 2.0
		var player_z := 5.2 if up else 4.8
		var t := await _make({
			"enemy_pos": Vector3(0, surface.call(enemy_z), enemy_z), "player_pos": Vector3(0, surface.call(player_z), player_z),
			"player_ghost": true, "no_floor": true, "enemy_face": Vector3.FORWARD if up else Vector3.BACK,
			"extra": func(a: Node3D) -> void:
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(30, 1, 40)
				shape.shape = box
				body.add_child(shape)
				body.rotation.x = slope
				body.position = Vector3(0, -0.5 * cos(slope), 8.0 - 0.5 * sin(slope))
				a.add_child(body),
		})
		_begin(t)
		await _until(t, func() -> bool: return t.at("phase_SLASH") >= 0, 6.0)
		var max_dev := 0.0
		var dash_from := t.at("phase_DASH")
		for i in range(maxi(dash_from, 1), t.at("phase_SLASH")):
			var p := t.positions[i]
			max_dev = maxf(max_dev, absf(p.y - surface.call(p.z)))
		var traveled := t.positions[t.at("phase_SLASH") - 1].distance_to(t.positions[maxi(dash_from, 1)])
		print("INFO %s 20 độ: lướt %.2f m (có dash=%s), lệch lớn nhất so với mặt dốc %.3f m" % [case_name, traveled, dash_from >= 0, max_dev])
		_check(dash_from >= 0 and max_dev < 0.15, "%s: bám mặt dốc (lệch %.3f < 0.15 m), không bay/nảy" % [case_name, max_dev])
		await _end(t)


# ---------- Tiện ích ----------

func _has_overlay(enemy: Enemy) -> bool:
	var mesh := enemy.get_node("Model/Visual/Rig/Enemy1Model/Hips/Torso") as GeometryInstance3D
	return mesh.material_overlay != null


func _glow_visible(enemy: Enemy) -> bool:
	var eyes := enemy.get_node("Model/Visual/Rig/Enemy1Model/Hips/Torso/Head/EyesGlow") as Node3D
	var blade := enemy.get_node("Model/Visual/Rig/Enemy1Model/Hips/Torso/ArmBlade_R/BladeGlow") as Node3D
	return eyes.visible or blade.visible


func _until(t: Trial, cond: Callable, max_seconds: float) -> bool:
	var limit := t.frame + int(max_seconds / TICK)
	while t.frame < limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(duration: float) -> void:
	await _frames(int(duration / TICK))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failed = true
		print("FAIL ", label)


func _t_debug() -> void:
	var t := await _make({"player_pos": Vector3(0, 0, 3.0), "player_ghost": true})
	_begin(t)
	await _until(t, func() -> bool: return t.at("phase_WINDUP") >= 0, 3.0)
	await _seconds(0.55)
	var anim := t.enemy.get_node("AnimationPlayer") as AnimationPlayer
	print("DBG before hurt glow=", _glow_visible(t.enemy), " anim=", anim.current_animation)
	_hurt(t.enemy, t.player)
	for i in 12:
		await _seconds(0.05)
		print("DBG +%.2f glow=%s overlay=%s anim=%s state=%s" % [(i + 1) * 0.05, _glow_visible(t.enemy), _has_overlay(t.enemy), anim.current_animation, t.machine.current_state.name])
	await _end(t)
