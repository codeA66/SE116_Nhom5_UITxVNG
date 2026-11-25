extends Node
## Sân thử Mưa Hỏa Tiễn (Phun lửa cấp 2, kiểu chiêu R của Rumble). Viết TRƯỚC khi code (TDD).
## Chơi tay: nhặt sách lửa (F) -> Phun lửa lên cấp 2 -> giữ Q tại điểm đầu, rê chuột chọn hướng, thả Q để gọi mưa cầu lửa.
## Bản tự kiểm tra nâng cấp bằng code (thêm Ấn Lửa) vì màn giới thiệu khi nhặt sách chờ người chơi đóng bảng. Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.
## Chạy `-- --verify` để tự bấm phím thật và đo hành vi rồi thoát (0 = đạt).
##
## ===== USE CASE =====
## UC1 Chưa nâng cấp: Q là Phun lửa. Nâng bậc 1 (2 Ấn Lửa): Q thành Mưa Hỏa Tiễn, tốn 1 năng lượng, hồi chiêu 15 s.
## UC2 Giữ Q: hiện vạch ngắm; điểm đầu ở chỗ chuột lúc bấm nhưng không xa cáo quá max_cast_range; rê chuột đổi hướng.
##     Cáo đi lại được trong lúc ngắm.
## UC3 Thả Q: cầu lửa rơi dọc đường, quái trên đường mất đúng 1 máu (mỗi con 1 lần cả chiêu), ngoài đường không mất,
##     quái không bị đẩy.
## UC4 Dải cháy: đốt quái đi vào sau, đốt vật dễ cháy, không đốt cáo.
## UC5 Hết thời gian: dải tắt, node / hạt / vùng đốt trả về pool, không còn gì phát; dùng lại không giữ trạng thái cũ.
## UC6 Trừ 1 năng lượng, hồi chiêu 15 s tính từ lúc thả; hết năng lượng thì không ngắm được.
## UC7 Dash hoặc bị đánh trúng lúc đang ngắm: hủy, không tốn năng lượng, không tính hồi chiêu.
## UC8 Thông số cực đoan (đường 1 / 30 m, rộng 0.3 / 8 m, 1 / 20 quả, cháy 0 s) vẫn đúng.
##
## ===== TEST CASE =====
## TC1 (UC1) Cấp 1 bấm Q -> state FlameBreath. Thêm 2 Ấn Lửa, nâng cấp -> dạng là fire_rain, energy_cost 1, cooldown 15.
## TC2 (UC2) Chuột ở 20 m lúc bấm -> điểm đầu cách cáo đúng 12 m; rê chuột sang +X -> hướng lệch < 2°; vạch đang hiện;
##           giữ phím trái 0.4 s lúc ngắm -> cáo đi được > 0.3 m mà vẫn ở state FireRain.
## TC3 (UC7) Đang ngắm bấm dash -> state Dash, năng lượng không đổi, vạch ẩn; giữ Q lại ngay -> vào FireRain (không hồi chiêu).
## TC4 (UC7) Đang ngắm bị đánh trúng -> state Hurt, năng lượng không đổi, vạch ẩn.
## TC5 (UC3, UC6) Đường từ z -4 tới -14 dọc trục giữa: thả Q -> trừ 1 năng lượng; đủ 6 quả chạm đất;
##           DummyOn (giữa) và DummyEdgeIn (trong mép 0.5 m) trúng đúng 1 đòn của chiêu, mất 1 máu, lệch < 0.05 m;
##           DummyOut (ngoài mép 1 m) không trúng; thùng gỗ trên đường bắt lửa.
## TC6 (UC4) Đẩy DummyLate vào dải sau khi mưa xong -> bắt lửa; cáo đứng trong dải 2 s -> không mất máu, không cháy.
## TC7 (UC6) 14 s sau khi thả bấm Q -> không vào FireRain; 15.3 s -> vào được.
## TC8 (UC5) Hết dải cháy + tàn: pool không còn đối tượng dùng, vùng đốt tắt monitoring, không hạt nào còn phát;
##           đẩy quái mới vào chỗ cũ -> không cháy.
## TC9 (UC6) Năng lượng 0 bấm Q -> không vào FireRain.
## TC10 (UC5) 3 lần dùng liên tiếp (bỏ hồi chiêu) -> chỉ 1 đối tượng trong pool; lần nào DummyOn cũng trúng đúng 1 đòn.
## TC11 (UC8) Cực đoan: dài 1 m -> DummyOn không trúng; dài 30 m -> trúng; rộng 0.3 m -> DummyOn trúng, EdgeIn không;
##           rộng 8 m -> DummyOut trúng; 1 quả / 20 quả -> DummyOn trúng đúng 1 đòn; cháy 0 s -> vẫn về pool.

const FIRE_SEAL: ItemData = preload("res://resources/player/items/upgrades/fire_seal.tres")
const STORAGE := "user://test_fire_rain/"
const STATE_PATH := ^"StateMachine/FireRain"
const LINE_START := Vector3(0.0, 0.0, -4.0)
const LINE_END := Vector3(0.0, 0.0, -14.0)

@export var weapons: Array[Resource] = []
@export var abilities: Array[Resource] = []

var _failed: int = 0
var _cursor: Vector3 = Vector3.INF
## Số đòn của chiêu (không tính tick cháy) mỗi hình nộm nhận
var _hits: Dictionary[Node, int] = {}
var _impacts: int = 0
var _attack: AttackData
var _zone: ZoneRoot
var _player: Player


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for progress_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if progress_signal.is_connected(SaveManager.save_game):
			progress_signal.disconnect(SaveManager.save_game)


func _ready() -> void:
	for weapon in weapons:
		GameState.add_weapon(weapon as WeaponData)
	if not weapons.is_empty():
		GameState.set_weapon(weapons[0] as WeaponData)
	for ability in abilities:
		GameState.unlock_ability(ability as AbilityData)
		# Sân luôn bắt đầu ở cấp 1 để thử đúng đường nâng cấp
		GameState.progress.ability_levels.erase((ability as AbilityData).id)
	GameState.progress.items.erase(FIRE_SEAL.id)
	if OS.get_cmdline_user_args().has("--verify"):
		_verify.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _state_name() -> StringName:
	return _player.state_machine.current_state.name


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## Giữ Q với chuột ở press_at, rê chuột tới drag_to rồi (tuỳ chọn) thả
func _cast(press_at: Vector3, drag_to: Vector3, release: bool = true) -> void:
	_cursor = press_at
	Input.action_press(&"skill_fire")
	await _frames(3)
	_cursor = drag_to
	await _frames(3)
	if release:
		Input.action_release(&"skill_fire")
		await _frames(1)


func _dummy(node_name: String) -> Node3D:
	return _zone.get_node(node_name) as Node3D


func _reset_dummies() -> void:
	for node_name: String in ["DummyOn", "DummyEdgeIn", "DummyOut", "DummyLate"]:
		var dummy := _dummy(node_name)
		(dummy.get_node(^"BurnableComponent") as BurnableComponent).extinguish()
		(dummy.get_node(^"HealthComponent") as HealthComponent).heal_full()
		_hits[dummy] = 0


func _watch(dummy: Node) -> void:
	_hits[dummy] = 0
	(dummy.get_node(^"HurtboxComponent") as HurtboxComponent).hurt.connect(
		func(info: DamageInfo, _taken: int) -> void:
			if _attack != null and info.attack == _attack:
				_hits[dummy] += 1)


func _active_particles(root: Node) -> int:
	var count := 0
	for node in root.find_children("*", "CPUParticles3D", true, false):
		if (node as CPUParticles3D).emitting:
			count += 1
	for node in root.find_children("*", "GPUParticles3D", true, false):
		if (node as GPUParticles3D).emitting:
			count += 1
	return count


func _finish() -> void:
	Input.action_release(&"skill_fire")
	print("FIRE RAIN VERIFY: %s" % ("OK" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


func _verify() -> void:
	_zone = get_parent() as ZoneRoot
	if not _zone.is_combat_ready():
		await _zone.combat_ready
	_player = _zone.get_node(^"Player") as Player
	for node in _zone.get_children():
		if node is Enemy:
			node.queue_free()
	for node_name: String in ["DummyOn", "DummyEdgeIn", "DummyOut", "DummyLate"]:
		_watch(_dummy(node_name))
	await _wait(0.3)
	var flame := abilities[0] as SkillData

	# --- TC1: cấp 1 là Phun lửa; nâng cấp thành Mưa Hỏa Tiễn
	_player.face_instantly(Vector3.FORWARD)
	await _tap(&"skill_fire")
	await _frames(2)
	_check(_state_name() == &"FlameBreath", "TC1 cấp 1: Q vào FlameBreath (đang ở %s)" % _state_name())
	await _wait(1.6)
	GameState.add_item(FIRE_SEAL, 2)
	_check(GameState.upgrade_ability(flame), "TC1 đủ 2 Ấn Lửa thì nâng cấp được")
	var form: SkillData = _player.get_skill_form(flame)
	_check(form != null and form.id == &"fire_rain", "TC1 cấp 2: dạng đang dùng là fire_rain (%s)" % (form.id if form else &"null"))
	if form == null or form.id != &"fire_rain":
		_finish()
		return
	_check(form.energy_cost == 1, "TC1 tốn 1 năng lượng (%d)" % form.energy_cost)
	_check(is_equal_approx(float(form.get(&"cooldown")), 15.0), "TC1 hồi chiêu 15 s trong .tres (%s)" % str(form.get(&"cooldown")))
	_attack = form.get(&"attack") as AttackData
	_check(_attack != null and _attack.damage == 1 and is_zero_approx(_attack.knockback), "TC1 đòn chiêu: 1 sát thương, không đẩy")

	var state := _player.get_node_or_null(STATE_PATH)
	_check(state != null, "có state FireRain trong player")
	if state == null:
		_finish()
		return
	state.set(&"cursor_source", func() -> Vector3: return _cursor)
	var aim_vfx: Node = state.get(&"aim_visual")
	var pool := state.get_node(^"Pool") as ObjectPool

	# --- TC2: ngắm kiểu Rumble
	_player.energy.set_current(_player.energy.get_max())
	var energy_full := _player.energy.current
	_player.teleport(Vector3.ZERO, Vector3.FORWARD)
	await _wait(0.2)
	await _cast(Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, -20.0), false)
	_check(_state_name() == &"FireRain", "TC2 giữ Q vào FireRain (đang ở %s)" % _state_name())
	var start: Vector3 = state.call(&"get_line_start")
	var start_distance := Vector2(start.x - _player.global_position.x, start.z - _player.global_position.z).length()
	_check(absf(start_distance - 12.0) < 0.05, "TC2 điểm đầu bị kẹp ở 12 m (%.2f m)" % start_distance)
	_cursor = start + Vector3(6.0, 0.0, 0.0)
	await _frames(3)
	var direction: Vector3 = state.call(&"get_line_direction")
	_check(rad_to_deg(direction.angle_to(Vector3.RIGHT)) < 2.0, "TC2 rê chuột sang +X: hướng lệch %.2f°" % rad_to_deg(direction.angle_to(Vector3.RIGHT)))
	_check(aim_vfx != null and bool(aim_vfx.call(&"is_showing")), "TC2 vạch ngắm đang hiện")
	_check(_player.energy.current == energy_full, "TC2 ngắm chưa tốn năng lượng")
	var before_walk := _player.global_position
	Input.action_press(&"move_left")
	await _wait(0.4)
	Input.action_release(&"move_left")
	var walked := before_walk.distance_to(_player.global_position)
	_check(walked > 0.3 and _state_name() == &"FireRain", "TC2 đi được lúc ngắm: %.2f m, state %s" % [walked, _state_name()])

	# --- TC3: dash hủy ngắm
	await _tap(&"dash")
	await _frames(2)
	_check(_state_name() == &"Dash", "TC3 dash lúc ngắm -> Dash (đang ở %s)" % _state_name())
	_check(_player.energy.current == energy_full, "TC3 hủy bằng dash không tốn năng lượng")
	_check(not bool(aim_vfx.call(&"is_showing")), "TC3 vạch ngắm ẩn")
	Input.action_release(&"skill_fire")
	await _wait(0.6)
	await _cast(_player.global_position + Vector3(0, 0, -5), _player.global_position + Vector3(0, 0, -9), false)
	_check(_state_name() == &"FireRain", "TC3 hủy xong dùng lại ngay được (đang ở %s)" % _state_name())

	# --- TC4: bị đánh trúng lúc ngắm thì hủy
	var hurtbox := _player.get_node(^"HurtboxComponent") as HurtboxComponent
	hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _dummy("DummyOut")))
	await _frames(2)
	_check(_state_name() == &"Hurt", "TC4 trúng đòn lúc ngắm -> Hurt (đang ở %s)" % _state_name())
	_check(_player.energy.current == energy_full, "TC4 hủy do trúng đòn không tốn năng lượng")
	_check(not bool(aim_vfx.call(&"is_showing")), "TC4 vạch ngắm ẩn")
	Input.action_release(&"skill_fire")
	_player.health.heal_full()
	await _wait(1.6)

	# --- TC5: thả Q, mưa cầu lửa dọc trục z -4 -> -14
	var impact_signal_bound := false
	for fire_rain: Node in pool.get_children():
		fire_rain.connect(&"impacted", func(_index: int, _point: Vector3, landed: bool) -> void:
			if landed:
				_impacts += 1)
		impact_signal_bound = true
	_check(impact_signal_bound, "pool có sẵn đối tượng FireRain")
	_reset_dummies()
	var crate := _dummy("Crate")
	var crate_lit := [false]
	crate.connect(&"caught_fire", func() -> void: crate_lit[0] = true)
	_player.teleport(Vector3.ZERO, Vector3.FORWARD)
	await _wait(0.3)
	var on_before := _dummy("DummyOn").global_position
	var edge_before := _dummy("DummyEdgeIn").global_position
	_impacts = 0
	await _cast(LINE_START, LINE_END)
	var released_at := Time.get_ticks_msec()
	_check(energy_full - _player.energy.current == 1, "TC5 thả Q trừ 1 năng lượng (trừ %d)" % (energy_full - _player.energy.current))
	var rain_time := float(form.get(&"first_impact_delay")) + float(form.get(&"impact_spread_time"))
	await _wait(rain_time + 0.3)
	_check(_impacts == int(form.get(&"impact_count")), "TC5 đủ %d quả chạm đất (%d)" % [int(form.get(&"impact_count")), _impacts])
	_check(_hits[_dummy("DummyOn")] == 1, "TC5 DummyOn trúng đúng 1 đòn (%d)" % _hits[_dummy("DummyOn")])
	_check(_hits[_dummy("DummyEdgeIn")] == 1, "TC5 DummyEdgeIn (trong mép 0.5 m) trúng 1 đòn (%d)" % _hits[_dummy("DummyEdgeIn")])
	_check(_hits[_dummy("DummyOut")] == 0, "TC5 DummyOut (ngoài mép 1 m) không trúng (%d)" % _hits[_dummy("DummyOut")])
	var on_moved := on_before.distance_to(_dummy("DummyOn").global_position)
	var edge_moved := edge_before.distance_to(_dummy("DummyEdgeIn").global_position)
	_check(on_moved < 0.05 and edge_moved < 0.05, "TC5 quái không bị đẩy (%.3f / %.3f m)" % [on_moved, edge_moved])
	_check(crate_lit[0], "TC5 thùng gỗ trên đường bắt lửa")
	_check(pool.get_active_count() == 1, "TC5 đúng 1 dải lửa đang chạy (%d)" % pool.get_active_count())

	# --- TC6: dải cháy đốt thứ đi vào sau, không đốt cáo
	var late := _dummy("DummyLate")
	late.global_position = Vector3(0.0, 0.0, -8.0)
	await _wait(0.4)
	_check((late.get_node(^"BurnableComponent") as BurnableComponent).is_burning(), "TC6 DummyLate đi vào dải sau -> bắt lửa")
	_check(_hits[late] == 0, "TC6 DummyLate không bị tính đòn cầu lửa (%d)" % _hits[late])
	var health_before := _player.health.current_health
	_player.teleport(Vector3(0.0, 0.0, -10.0), Vector3.FORWARD)
	await _wait(2.0)
	var player_burn := _player.get_node(^"BurnableComponent") as BurnableComponent
	_check(_player.health.current_health == health_before and not player_burn.is_burning(),
		"TC6 cáo đứng trong dải 2 s: không mất máu (%d -> %d), không cháy" % [health_before, _player.health.current_health])
	_player.teleport(Vector3.ZERO, Vector3.FORWARD)
	late.global_position = Vector3(8.0, 0.0, -8.0)

	# --- TC8: hết dải cháy, trả pool, không sót gì
	var lifetime := rain_time + float(form.get(&"burn_lifetime")) + float(form.get(&"linger"))
	await _wait(maxf(lifetime - (Time.get_ticks_msec() - released_at) / 1000.0, 0.0) + 0.4)
	_check(pool.get_active_count() == 0, "TC8 dải lửa tan xong trả về pool (%d)" % pool.get_active_count())
	var used := pool.get_child(0)
	_check(not (used.get_node(^"Strip") as Area3D).monitoring, "TC8 vùng đốt tắt monitoring")
	_check(_active_particles(used) == 0, "TC8 không hạt nào còn phát (%d)" % _active_particles(used))
	var late_burn := late.get_node(^"BurnableComponent") as BurnableComponent
	late_burn.extinguish()
	late.global_position = Vector3(0.0, 0.0, -8.0)
	await _wait(0.4)
	_check(not late_burn.is_burning(), "TC8 dải đã tắt: đi vào chỗ cũ không cháy")
	late.global_position = Vector3(8.0, 0.0, -8.0)

	# --- TC7: hồi chiêu 15 s tính từ lúc thả
	await _wait(maxf(14.0 - (Time.get_ticks_msec() - released_at) / 1000.0, 0.0))
	_player.energy.set_current(_player.energy.get_max())
	await _cast(Vector3(0, 0, -4), Vector3(0, 0, -8), false)
	_check(_state_name() != &"FireRain", "TC7 14 s sau khi thả: chưa dùng lại được (đang ở %s)" % _state_name())
	Input.action_release(&"skill_fire")
	await _wait(maxf(15.3 - (Time.get_ticks_msec() - released_at) / 1000.0, 0.0))
	await _cast(Vector3(0, 0, -4), Vector3(0, 0, -8), false)
	_check(_state_name() == &"FireRain", "TC7 15.3 s sau khi thả: dùng lại được (đang ở %s)" % _state_name())
	await _tap(&"dash")
	Input.action_release(&"skill_fire")
	await _wait(0.6)

	# --- TC9: hết năng lượng
	_player.energy.set_current(0)
	await _cast(Vector3(0, 0, -4), Vector3(0, 0, -8), false)
	_check(_state_name() != &"FireRain", "TC9 năng lượng 0: không vào FireRain (đang ở %s)" % _state_name())
	Input.action_release(&"skill_fire")
	await _wait(0.3)

	# --- TC10: dùng lại 3 lần, pool không tạo thêm, không giữ trạng thái cũ
	form.set(&"cooldown", 0.0)
	for round_index in 3:
		_reset_dummies()
		_player.energy.set_current(_player.energy.get_max())
		_player.teleport(Vector3.ZERO, Vector3.FORWARD)
		await _wait(0.3)
		_impacts = 0
		await _cast(LINE_START, LINE_END)
		await _wait(rain_time + 0.3)
		_check(_hits[_dummy("DummyOn")] == 1, "TC10 lần %d: DummyOn trúng đúng 1 đòn (%d)" % [round_index + 1, _hits[_dummy("DummyOn")]])
		await _wait(float(form.get(&"burn_lifetime")) + float(form.get(&"linger")) + 0.3)
		_check(pool.get_active_count() == 0, "TC10 lần %d: trả về pool" % (round_index + 1))
	_check(pool.get_total_created() == 1, "TC10 chỉ 1 đối tượng trong pool (%d)" % pool.get_total_created())

	# --- TC11: thông số cực đoan
	var base := {
		&"line_length": form.get(&"line_length"), &"line_width": form.get(&"line_width"),
		&"impact_count": form.get(&"impact_count"), &"burn_lifetime": form.get(&"burn_lifetime"),
	}
	# [thuộc tính, giá trị, hình nộm -> số đòn mong đợi]
	var extremes: Array = [
		[&"line_length", 1.0, {"DummyOn": 0}],
		[&"line_length", 30.0, {"DummyOn": 1}],
		[&"line_width", 0.3, {"DummyOn": 1, "DummyEdgeIn": 0}],
		[&"line_width", 8.0, {"DummyOn": 1, "DummyOut": 1}],
		[&"impact_count", 1, {"DummyOn": 1, "DummyEdgeIn": 1}],
		[&"impact_count", 20, {"DummyOn": 1, "DummyEdgeIn": 1}],
		[&"burn_lifetime", 0.0, {"DummyOn": 1}],
	]
	for extreme: Array in extremes:
		for property: StringName in base:
			form.set(property, base[property])
		form.set(extreme[0], extreme[1])
		_reset_dummies()
		_player.energy.set_current(_player.energy.get_max())
		_player.teleport(Vector3.ZERO, Vector3.FORWARD)
		await _wait(0.3)
		await _cast(LINE_START, LINE_END)
		await _wait(rain_time + 0.3)
		var expected: Dictionary = extreme[2]
		var got := {}
		var ok := true
		for dummy_name: String in expected:
			got[dummy_name] = _hits[_dummy(dummy_name)]
			ok = ok and got[dummy_name] == expected[dummy_name]
		_check(ok, "TC11 %s = %s: mong %s, được %s" % [extreme[0], str(extreme[1]), str(expected), str(got)])
		await _wait(float(form.get(&"burn_lifetime")) + float(form.get(&"linger")) + 0.3)
		_check(pool.get_active_count() == 0, "TC11 %s = %s: trả về pool" % [extreme[0], str(extreme[1])])
	for property: StringName in base:
		form.set(property, base[property])
	_finish()
