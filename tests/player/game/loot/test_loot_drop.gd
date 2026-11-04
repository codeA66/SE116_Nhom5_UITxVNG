extends Node
## Unit test rơi đồ dạng chung (DropTable / LootDropComponent / PickupCollector / CurrencyPickup) + bộ đếm trên HUD.
## Phần hồi máu ở checkpoint đã chuyển sang tests/player/game/restore/test_restore.
## Viết TRƯỚC khi code (TDD). Thay cho test_soul_jade (hệ cũ chỉ biết Soul Jade).
## Chạy: mở tests/player/game/test_loot_drop.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1  Quái chết -> rơi ĐÚNG số cố định theo bảng rơi của loại quái đó (để tính được tiền qua cổng); viên rơi tự bay vào người.
## UC2  Một bảng rơi có nhiều mục (nhiều loại tiền) -> mỗi loại cộng đúng phần của nó.
## UC3  Quái thường / lớn / boss có bảng rơi riêng trong .tres; đổi số không sửa code.
## UC4  Thêm loại tiền mới (CurrencyData + scene viên rơi riêng) -> rơi và cộng được, không sửa code.
## UC5  Rơi nhiều (boss) -> số viên bay có giới hạn, tổng tiền vẫn đủ; xong thì mọi viên về pool, không sót.
## UC6  Nhiều quái chết cùng lúc / người chơi ở xa -> vẫn cộng đủ.
## UC7  Dữ liệu thiếu / sai (bảng rỗng, số 0, mục không có loại tiền, quái không gắn bảng) -> không rơi gì, không lỗi.
## UC8  Không có người nhặt trong khu (scene thử quái không có player) -> quái chết không lỗi.
## UC10 Bộ đếm tiền trên HUD thật không đè lên cụm kỹ năng / thanh máu / thanh năng lượng, nằm trọn trong màn hình.
## UC11 Hình viên rơi nằm trong scene (node thật), chỉnh được trong editor; script không tự dựng hình.
##      Đổi màu / số hạt trong scene thì lúc chạy dùng đúng giá trị đó.
## UC12 Nhận tiền phải "thấy được": viên nở ra lúc rơi, có vòng sáng ở chỗ quái gục (1 vòng mỗi lần rơi),
##      chớp sáng nhỏ lúc nhặt (giới hạn tần suất để 12 viên về cùng lúc không thành mảng chói); mọi hiệu ứng tự tắt hẳn.
##      Loại tiền khác có thể có hình rơi / nhặt riêng (khai báo trong CurrencyData).
##
## ===== TEST CASE =====
## TC1  (UC1)   Bảng [soul_jade x2]: giết quái -> 1 viên bay; 3 s sau +2 đúng, HUD đúng, pool rỗng. Lặp 3 lần đều +2 (không ngẫu nhiên).
## TC2  (UC2)   Bảng [soul_jade x3, test_gem x5] -> soul_jade +3, test_gem +5.
## TC3  (UC3)   drop_normal / drop_large / drop_boss .tres nạp được, số cố định > 0 và tăng dần thường < lớn < boss;
##              quái thường, gấu giáp, khỉ trưởng, boss 1 gắn đúng bảng.
## TC4  (UC4)   CurrencyData tạo bằng code (id mới, pickup_scene = scene viên Soul Jade) -> rơi và cộng vào đúng id mới.
## TC5  (UC5)   Bảng [soul_jade x50] -> số viên bay <= max_visual_pickups; 4 s sau +50, pool rỗng.
## TC6  (UC6)   Hai quái cùng frame mỗi con x3 -> +6; giết rồi dịch người ra xa 15 m -> vẫn +4.
## TC7  (UC7)   Bảng rỗng / mục số 0 / mục currency = null / quái drop_table = null -> tiền không đổi, không viên nào.
## TC8  (UC8)   Quái đứng riêng trong scene không có PickupCollector chết -> không lỗi (script không dừng), không tiền.
## TC11 (UC5)   3 s sau mọi test: không còn viên nào hiện / đang chạy _process.
## TC12 (UC10)  Khung bộ đếm (kể cả khi số lên 6 chữ số) không giao khung SkillCluster, HealthPanel, EnergyBar; nằm trong viewport.
## TC15 (UC11)  soul_jade_pickup.tscn có sẵn Visual + Trail trong file scene; sau _ready số node con không tăng.
## TC16 (UC12)  soul_jade.tres có drop_vfx_scene (không vòng sáng trên sàn, theo ảnh Death's Door) + collect_vfx_scene có Ring.
## TC24 (UC12)  Đốm có vệt sáng liền (Trail phát sáng cộng màu, đủ dày) + dư ảnh; màu loại tiền là hồng như ảnh tham khảo.
## TC17 (UC12)  Rơi 12: ngay sau đó đúng 1 vòng sáng đang chạy; viên vừa rơi có scale < 1, 0.3 s sau scale về 1.
## TC18 (UC12)  12 viên về người: số chớp sáng lúc nhặt > 0 và <= số viên, cách nhau >= collect_vfx_interval.
## TC19 (UC12)  3 s sau: mọi vòng / chớp sáng đã về pool (ẩn, không _process).
## TC20 (UC12)  Mọi viên Soul Jade dùng chung một material tinh thể (không duplicate từng viên).
## TC21 (UC1)   Mỗi lần rơi đúng 1 viên bay về người (kiểu Death's Door), viên mang toàn bộ số tiền: rơi 2 / 40 -> 1 viên, tổng +2 / +40.
## TC22 (UC12)  Không hiện chữ số nào ở chỗ quái gục (kiểu Death's Door): hiệu ứng rơi không có Label3D.
## TC23 (UC12)  Lúc bay: 4 dư ảnh (node Echoes) hiện sau đốm, cách nhau theo quãng đường (không chồng một chỗ), nhỏ và mờ dần;
##              nhặt xong thì dư ảnh ẩn hết; viên mới rơi không mang dư ảnh cũ từ lần trước.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const ENEMY := "res://entities/enemies/palace/enemy_1/enemy_1.tscn"
const SOUL_JADE := preload("res://resources/player/currency/soul_jade.tres")
const DROP_DIR := "res://resources/enemies/loot/"

var _fails: int = 0
var _lv: Node
var _p: Player
var _collector: PickupCollector
var _counter: CurrencyCounter
var _test_gem: CurrencyData


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	await _setup()
	await _tc1_fixed()
	await _tc2_multi()
	_tc3_tables()
	await _tc4_new_currency()
	await _tc5_boss_cap()
	await _tc6_many_far()
	await _tc7_bad_data()
	await _tc8_no_collector()
	await _tc11_nothing_left()
	await _tc12_hud_no_overlap()
	await _tc15_pickup_scene()
	_tc16_vfx_data()
	await _tc17_drop_ring_and_scale_in()
	await _tc18_collect_flash()
	await _tc19_vfx_end()
	_tc20_shared_material()
	await _tc21_few_pickups()
	await _tc22_no_world_number()
	await _tc23_echoes()
	_tc24_streak_and_color()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _setup() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_test_gem = CurrencyData.new()
	_test_gem.id = &"test_gem"
	_test_gem.pickup_scene = SOUL_JADE.pickup_scene
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	_collector = _first(_p, "PickupCollector") as PickupCollector
	_counter = _first(_p, "CurrencyCounter") as CurrencyCounter
	_check(_collector != null, "setup: player có PickupCollector")
	_check(_counter != null, "setup: HUD có bộ đếm")
	_check(SOUL_JADE.pickup_scene != null, "setup: soul_jade.tres có pickup_scene")


func _tc1_fixed() -> void:
	var id := SOUL_JADE.id
	for round_i: int in 3:
		var before := GameState.get_currency(id)
		_kill(_spawn_enemy(Vector3(2, 0, -3)), _table([[SOUL_JADE, 2]]))
		await _wait(0.1)
		if round_i == 0:
			_check(_collector.get_active_count() == 1, "TC1: 1 viên đang bay (%d)" % _collector.get_active_count())
		await _wait(3.0)
		_check(GameState.get_currency(id) == before + 2, "TC1 lần %d: +2 cố định (%d -> %d)" % [round_i + 1, before, GameState.get_currency(id)])
	_check(_counter.get_shown_value() == GameState.get_currency(id), "TC1: HUD hiện %d" % _counter.get_shown_value())
	_check(_collector.get_active_count() == 0, "TC1: pool rỗng")


func _tc2_multi() -> void:
	var a := GameState.get_currency(SOUL_JADE.id)
	var b := GameState.get_currency(_test_gem.id)
	_kill(_spawn_enemy(Vector3(-2, 0, -3)), _table([[SOUL_JADE, 3], [_test_gem, 5]]))
	await _wait(3.5)
	_check(GameState.get_currency(SOUL_JADE.id) == a + 3, "TC2: soul_jade +3")
	_check(GameState.get_currency(_test_gem.id) == b + 5, "TC2: test_gem +5")


func _tc3_tables() -> void:
	var amounts: Array[int] = []
	for kind: String in ["normal", "large", "boss"]:
		var table := load(DROP_DIR + "drop_%s.tres" % kind) as DropTable
		var amount := 0
		if table:
			for entry: DropEntry in table.entries:
				if entry and entry.currency == SOUL_JADE:
					amount += entry.amount
		amounts.append(amount)
		_check(table != null and amount > 0, "TC3: drop_%s.tres có soul_jade cố định %d" % [kind, amount])
	_check(amounts[0] < amounts[1] and amounts[1] < amounts[2], "TC3: thường < lớn < boss %s" % [amounts])
	var expect := {
		"res://entities/enemies/palace/enemy_1/enemy_1.tscn": "drop_normal.tres",
		"res://entities/enemies/wildlife/armored_polar_bear/armored_polar_bear.tscn": "drop_large.tres",
		"res://entities/enemies/wildlife/monkey_chieftain/monkey_chieftain.tscn": "drop_large.tres",
		"res://entities/bosses/boss_1/boss_1.tscn": "drop_boss.tres",
	}
	for path: String in expect:
		var node := (load(path) as PackedScene).instantiate()
		var drop := _first(node, "LootDropComponent") as LootDropComponent
		var got := drop.drop_table.resource_path.get_file() if drop and drop.drop_table else "none"
		_check(got == expect[path], "TC3: %s gắn %s (%s)" % [path.get_file(), expect[path], got])
		node.free()


func _tc4_new_currency() -> void:
	var fresh := CurrencyData.new()
	fresh.id = &"made_in_code"
	fresh.pickup_scene = SOUL_JADE.pickup_scene
	_kill(_spawn_enemy(Vector3(0, 0, -4)), _table([[fresh, 4]]))
	await _wait(3.5)
	_check(GameState.get_currency(fresh.id) == 4, "TC4: loại tiền mới rơi và cộng đúng (%d)" % GameState.get_currency(fresh.id))


func _tc5_boss_cap() -> void:
	var before := GameState.get_currency(SOUL_JADE.id)
	_kill(_spawn_enemy(Vector3(3, 0, -2)), _table([[SOUL_JADE, 50]]))
	await _wait(0.1)
	var flying := _collector.get_active_count()
	_check(flying > 0 and flying <= _collector.max_visual_pickups, "TC5: số viên bay %d <= %d" % [flying, _collector.max_visual_pickups])
	await _wait(4.0)
	_check(GameState.get_currency(SOUL_JADE.id) == before + 50, "TC5: +50 (%d)" % (GameState.get_currency(SOUL_JADE.id) - before))
	_check(_collector.get_active_count() == 0, "TC5: pool rỗng")


func _tc6_many_far() -> void:
	var before := GameState.get_currency(SOUL_JADE.id)
	_kill(_spawn_enemy(Vector3(2, 0, -2)), _table([[SOUL_JADE, 3]]))
	_kill(_spawn_enemy(Vector3(-2, 0, -2)), _table([[SOUL_JADE, 3]]))
	await _wait(4.0)
	_check(GameState.get_currency(SOUL_JADE.id) == before + 6, "TC6: hai quái cùng lúc +6")
	before = GameState.get_currency(SOUL_JADE.id)
	_kill(_spawn_enemy(Vector3(0, 0, -3)), _table([[SOUL_JADE, 4]]))
	await _wait(0.05)
	_p.global_position += Vector3(15, 0, 0)
	await _wait(5.0)
	_check(GameState.get_currency(SOUL_JADE.id) == before + 4, "TC6: người ở xa 15 m vẫn +4")
	_p.global_position -= Vector3(15, 0, 0)


func _tc7_bad_data() -> void:
	var before := GameState.get_currency(SOUL_JADE.id)
	_kill(_spawn_enemy(Vector3(2, 0, -3)), DropTable.new())
	_kill(_spawn_enemy(Vector3(-2, 0, -3)), _table([[SOUL_JADE, 0]]))
	_kill(_spawn_enemy(Vector3(0, 0, -4)), _table([[null, 5]]))
	_kill(_spawn_enemy(Vector3(1, 0, -5)), null)
	await _wait(0.2)
	_check(_collector.get_active_count() == 0, "TC7: dữ liệu rỗng / 0 / null -> không viên nào")
	await _wait(1.0)
	_check(GameState.get_currency(SOUL_JADE.id) == before, "TC7: tiền không đổi")


func _tc8_no_collector() -> void:
	var holder := Node3D.new()
	get_tree().root.add_child(holder)
	# Tạm tách collector khỏi group: giống scene thử quái không có player
	_collector.remove_from_group(PickupCollector.GROUP)
	var e := (load(ENEMY) as PackedScene).instantiate() as Node3D
	holder.add_child(e)
	e.set_physics_process(false)
	e.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	var before := GameState.get_currency(SOUL_JADE.id)
	_kill(e, _table([[SOUL_JADE, 3]]))
	await _wait(1.0)
	_check(GameState.get_currency(SOUL_JADE.id) == before, "TC8: không có người nhặt -> không lỗi, không tiền")
	_collector.add_to_group(PickupCollector.GROUP)
	holder.queue_free()


func _tc11_nothing_left() -> void:
	await _wait(3.0)
	var left := 0
	for pickup: Node in _collector.find_children("*", "CurrencyPickup", true, false):
		if (pickup as Node3D).visible or pickup.is_processing():
			left += 1
	_check(left == 0, "TC11: không còn viên nào hiện / chạy (%d)" % left)


func _tc12_hud_no_overlap() -> void:
	GameState.add_currency(SOUL_JADE.id, 999_999 - GameState.get_currency(SOUL_JADE.id))
	await get_tree().process_frame
	await get_tree().process_frame
	var box := _counter.get_global_rect()
	for path: String in ["HUD/GameHud/SkillCluster", "HUD/GameHud/HealthPanel", "HUD/EnergyBar"]:
		var other := _p.get_node_or_null(path) as Control
		var hit := other != null and box.intersects(other.get_global_rect())
		_check(other != null and not hit, "TC12: bộ đếm %s không đè %s %s" % [box, path.get_file(), other.get_global_rect() if other else "?"])
	var screen := Rect2(Vector2.ZERO, _counter.get_viewport_rect().size)
	_check(screen.encloses(box), "TC12: bộ đếm nằm trọn trong màn hình")


func _tc15_pickup_scene() -> void:
	var scene := SOUL_JADE.pickup_scene
	var names := _scene_node_names(scene)
	_check("Visual" in names and "Trail" in names, "TC15: scene viên rơi có sẵn Visual + Trail %s" % [names])
	var pickup := scene.instantiate()
	var count := pickup.get_child_count()
	add_child(pickup)
	await get_tree().process_frame
	_check(pickup.get_child_count() == count, "TC15: _ready không tạo thêm node (%d -> %d)" % [count, pickup.get_child_count()])
	pickup.queue_free()


## Tên các node con ghi trong file scene (không tính node script tạo lúc chạy)
func _scene_node_names(scene: PackedScene) -> Array[String]:
	var state := scene.get_state()
	var out: Array[String] = []
	for i in state.get_node_count():
		out.append(String(state.get_node_name(i)))
	return out


## Bảng rơi tạm cho một lần giết: [[CurrencyData, số], ...]
func _table(rows: Array) -> DropTable:
	var table := DropTable.new()
	for row: Array in rows:
		var entry := DropEntry.new()
		entry.currency = row[0]
		entry.amount = row[1]
		table.entries.append(entry)
	return table


## Gắn bảng rơi tạm (không sửa .tres thật) rồi giết bằng sát thương thật
func _kill(e: Node, table: DropTable) -> void:
	(_first(e, "LootDropComponent") as LootDropComponent).drop_table = table
	var health := e.get_node("HealthComponent") as HealthComponent
	health.take_damage(health.current_health)


func _spawn_enemy(offset: Vector3) -> Node:
	var e := (load(ENEMY) as PackedScene).instantiate()
	_lv.add_child(e)
	(e as Node3D).global_position = _p.global_position + offset
	e.set_physics_process(false)
	e.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	return e


func _first(root: Node, type: String) -> Node:
	var found := root.find_children("*", type, true, false)
	return found.front() if not found.is_empty() else null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


func _tc16_vfx_data() -> void:
	_check(SOUL_JADE.drop_vfx_scene != null and not "Ring" in _scene_node_names(SOUL_JADE.drop_vfx_scene), "TC16: hiệu ứng rơi không có vòng sáng trên sàn")
	_check(SOUL_JADE.collect_vfx_scene != null and "Ring" in _scene_node_names(SOUL_JADE.collect_vfx_scene), "TC16: hiệu ứng nhặt có Ring")


func _tc17_drop_ring_and_scale_in() -> void:
	_kill(_spawn_enemy(Vector3(3, 0, -3)), _table([[SOUL_JADE, 12]]))
	await get_tree().process_frame
	_check(_collector.get_active_drop_vfx_count() == 1, "TC17: rơi 12 -> đúng 1 vòng sáng (%d)" % _collector.get_active_drop_vfx_count())
	var pickups := _collector.find_children("*", "CurrencyPickup", true, false).filter(func(n: Node) -> bool: return n.is_processing())
	_check(not pickups.is_empty() and (pickups[0] as Node3D).scale.x < 1.0, "TC17: viên vừa rơi đang nở (scale %.2f < 1)" % ((pickups[0] as Node3D).scale.x if not pickups.is_empty() else -1.0))
	await _wait(0.3)
	var settled := pickups.filter(func(n: Node) -> bool: return n.is_processing())
	_check(settled.is_empty() or is_equal_approx(snappedf((settled[0] as Node3D).scale.x, 0.01), 1.0), "TC17: 0.3 s sau scale về 1 (%s)" % ((settled[0] as Node3D).scale.x if not settled.is_empty() else "đã nhặt"))
	await _wait(3.0)


func _tc18_collect_flash() -> void:
	var times: Array[float] = []
	_collector.collect_vfx_played.connect(func() -> void: times.append(Time.get_ticks_msec() / 1000.0))
	_kill(_spawn_enemy(Vector3(-3, 0, -3)), _table([[SOUL_JADE, 12]]))
	await _wait(3.0)
	_check(times.size() > 0 and times.size() <= 12, "TC18: số chớp sáng lúc nhặt %d (1..12)" % times.size())
	var min_gap := INF
	for i in range(1, times.size()):
		min_gap = minf(min_gap, times[i] - times[i - 1])
	_check(times.size() < 2 or min_gap >= _collector.collect_vfx_interval - 0.02, "TC18: chớp cách nhau >= %.2f s (nhỏ nhất %.3f)" % [_collector.collect_vfx_interval, min_gap])


func _tc19_vfx_end() -> void:
	await _wait(3.0)
	_check(_collector.get_active_drop_vfx_count() == 0 and _collector.get_active_collect_vfx_count() == 0, "TC19: mọi vòng / chớp sáng đã về pool")
	var left := 0
	for vfx: Node in _collector.find_children("*", "PickupVfx", true, false):
		if (vfx as Node3D).visible or vfx.is_processing():
			left += 1
	_check(left == 0, "TC19: không còn hiệu ứng nào hiện / chạy (%d)" % left)


func _tc20_shared_material() -> void:
	var mats := {}
	for pickup: Node in _collector.find_children("*", "CurrencyPickup", true, false):
		var visual := pickup.get_node_or_null("Visual") as MeshInstance3D
		if visual:
			mats[visual.get_active_material(0)] = true
	_check(mats.size() == 1, "TC20: các viên dùng chung 1 material tinh thể (%d)" % mats.size())


func _tc21_few_pickups() -> void:
	_check(_collector.max_visual_pickups == 1, "TC21: mỗi lần rơi 1 viên (kiểu Death's Door) (%d)" % _collector.max_visual_pickups)
	for amount: int in [2, 40]:
		await _wait(3.0)
		var before := GameState.get_currency(SOUL_JADE.id)
		_kill(_spawn_enemy(Vector3(2, 0, -3)), _table([[SOUL_JADE, amount]]))
		await get_tree().process_frame
		var expect := mini(amount, _collector.max_visual_pickups)
		_check(_collector.get_active_count() == expect, "TC21: rơi %d -> %d viên (%d)" % [amount, expect, _collector.get_active_count()])
		await _wait(4.0)
		_check(GameState.get_currency(SOUL_JADE.id) == before + amount, "TC21: rơi %d -> tổng +%d (%d)" % [amount, amount, GameState.get_currency(SOUL_JADE.id) - before])


func _tc22_no_world_number() -> void:
	_check(not "Amount" in _scene_node_names(SOUL_JADE.drop_vfx_scene), "TC22: scene hiệu ứng rơi không có node chữ số")
	_kill(_spawn_enemy(Vector3(-2, 0, -3)), _table([[SOUL_JADE, 40]]))
	await get_tree().process_frame
	var labels := _collector.find_children("*", "Label3D", true, false)
	_check(labels.is_empty(), "TC22: lúc rơi không có chữ nào trên đầu quái (%d)" % labels.size())
	await _wait(4.0)


func _tc23_echoes() -> void:
	await _wait(3.0)
	_kill(_spawn_enemy(Vector3(6, 0, -5)), _table([[SOUL_JADE, 2]]))
	await get_tree().process_frame
	var pickup: Node3D = null
	for n: Node in _collector.find_children("*", "CurrencyPickup", true, false):
		if n.is_processing():
			pickup = n
	_check(pickup != null, "TC23: có viên đang bay")
	if pickup == null:
		return
	var echoes := pickup.get_node_or_null("Echoes")
	_check(echoes != null and echoes.get_child_count() == 4, "TC23: có 4 dư ảnh")
	if echoes == null:
		return
	var start := pickup.global_position
	await _wait(0.6)
	var shown := 0
	var min_gap := INF
	var prev := Vector3.INF
	var prev_scale := 2.0
	var shrinking := true
	for echo: Node in echoes.get_children():
		var e := echo as Node3D
		if e.visible:
			shown += 1
			if prev != Vector3.INF:
				min_gap = minf(min_gap, e.global_position.distance_to(prev))
			shrinking = shrinking and e.scale.x < prev_scale
			prev_scale = e.scale.x
			prev = e.global_position
	_check(shown == 4, "TC23: lúc bay 4 dư ảnh đang hiện (%d)" % shown)
	_check(min_gap > 0.15, "TC23: các dư ảnh cách nhau theo quãng đường (gần nhất %.2f m, đã bay %.1f m)" % [min_gap, start.distance_to(pickup.global_position)])
	_check(shrinking, "TC23: dư ảnh nhỏ dần về phía sau")
	await _wait(4.0)
	var left := 0
	for echo: Node in echoes.get_children():
		left += 1 if (echo as Node3D).visible else 0
	_check(left == 0, "TC23: nhặt xong dư ảnh ẩn hết (%d)" % left)


func _tc24_streak_and_color() -> void:
	var pickup := SOUL_JADE.pickup_scene.instantiate()
	var trail := pickup.get_node_or_null("Trail") as CPUParticles3D
	var mat := (trail.mesh as QuadMesh).material as StandardMaterial3D if trail and trail.mesh is QuadMesh else null
	_check(trail != null and trail.amount >= 12 and not trail.local_coords, "TC24: vệt sáng đủ dày, để lại theo đường bay (%d hạt)" % (trail.amount if trail else 0))
	_check(mat != null and mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "TC24: vệt sáng phát sáng (cộng màu)")
	var c := SOUL_JADE.color
	_check(c.r > 0.8 and c.b > 0.4 and c.g < 0.5, "TC24: màu loại tiền hồng cánh sen %s" % c)
	pickup.free()
