extends Node
## Unit test lửa theo vết gió: cú thổi E đi qua thứ đang cháy -> phần vết gió từ vật đó trở đi (xuôi gió) tới cuối tầm
## thành lửa, đốt mọi thứ dễ cháy trong đó. Viết TRƯỚC khi code (TDD).
## Chạy: mở tests/fire/fire_wind/test_fire_wind.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
## Dùng hàng hình nộm SpreadA (z 6), SpreadB (z 3), SpreadC (z 0), SpreadSide (lệch ngang 3 m), Dummy1 (không nhận gió),
## CrateA, và quái EnemyRow2 (đứng hình) trong sân thử.
##
## ===== USE CASE =====
## UC1 Thổi E qua thứ đang cháy (kể cả vật không nhận gió như hình nộm thường) -> thứ dễ cháy xuôi gió trong tầm bắt lửa.
## UC2 Thứ nằm giữa cáo và vật đang cháy (ngược gió) không cháy.
## UC3 Lửa dừng ở cuối tầm gió; thứ ngoài tầm / ngoài bề rộng gió không cháy.
## UC4 Vật đang cháy không bị làm mới thời gian cháy.
## UC5 Không có gì cháy -> gió không mang lửa.
## UC6 Một cú gió đốt cả hàng xuôi gió trong tầm.
## UC7 Nhiều vật đang cháy -> vết lửa tính từ vật gần cáo nhất.
## UC8 Gió tắt -> vết lửa tắt sau extra_time, không còn xử lý.
## UC9 Vật (thùng gỗ) đang cháy cũng dẫn lửa.
## UC10 Thông số cực đoan (tầm gió, bề rộng gió, extra_time) vẫn đúng.
## UC11 Bỏ kiểu phụt lửa sau lưng: quái / hình nộm / thùng không còn node FireSpread.
##
## ===== TEST CASE =====
## TC1  (UC1)  Dummy1 (không nhận gió) cháy, EnemyRow2 đứng sau nó 2.5 m: đứng trước Dummy1 1.5 m bấm E -> EnemyRow2 cháy.
## TC2  (UC2)  Tầm gió 8 m, đứng trước SpreadA 3 m, CrateA đặt giữa cáo và SpreadA; SpreadA cháy -> E: CrateA KHÔNG cháy, SpreadB cháy.
## TC3  (UC3)  Tầm gió 5 m (mặc định), đứng trước SpreadA 1.5 m: SpreadC (ngoài tầm) không cháy; SpreadSide (lệch 3 m) không cháy.
## TC4  (UC4)  SpreadA đốt lúc t0, thổi lúc t0 + 0.3 s -> SpreadA tắt đúng t0 + duration.
## TC5  (UC5)  Không ai cháy, E -> không ai cháy; signal fired không phát.
## TC6  (UC6)  Tầm gió 8 m: chỉ SpreadA cháy, một cú E -> SpreadB và SpreadC cháy.
## TC7  (UC7)  Tầm gió 8 m, SpreadA và SpreadB cùng cháy, CrateA đặt giữa A và B -> CrateA cháy (vết tính từ A, không từ B).
## TC8  (UC8)  Sau cú gió: chờ hết gió + extra_time -> vết lửa tắt (igniter không monitoring), FireWind tắt xử lý.
## TC9  (UC9)  CrateA đặt ở chỗ SpreadA (dời SpreadA đi), CrateA cháy -> E: SpreadB cháy.
## TC10 (UC10) Tầm gió 2 m -> SpreadB không cháy; tầm 12 m -> SpreadC cháy; rộng 0.5 m -> SpreadB (thẳng hàng) cháy;
##             rộng 8 m -> SpreadSide cháy; extra_time 0 -> SpreadB vẫn cháy.
## TC11 (UC11) Quái, hình nộm, thùng không còn node FireSpread; BurnableComponent không còn export fire_spread.
## TC12 (UC8)  5 cú gió liên tiếp (lần nào SpreadA cũng đang cháy): 1 s sau cú cuối FireWind tắt xử lý, igniter tắt,
##              không hạt nào dưới FireWind còn phát, không mesh nào của FireWind còn hiện.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const ROW: Array[String] = ["SpreadA", "SpreadB", "SpreadC", "SpreadSide"]
const FIRE_WIND_PATH := ^"Model/FireWind"

var _fails: int = 0
var _lv: Node
var _p: Player
var _wind: WindBlastData
var _reach0: float
var _width0: float
var _home: Dictionary[String, Vector3] = {}


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


## Chạy lần lượt mọi test case rồi in RESULT
func _run() -> void:
	await _setup()
	await _tc1_still_dummy()
	await _tc2_upwind()
	await _tc3_reach_and_width()
	await _tc4_no_refresh()
	await _tc5_nobody()
	await _tc6_row()
	await _tc7_nearest()
	await _tc8_turns_off()
	await _tc9_crate_source()
	await _tc10_extremes()
	_tc11_old_removed()
	await _tc12_five_gusts()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


## Mở sân thử, player bất tử, đứng hình quái, nhớ vị trí gốc của các vật dùng trong test
func _setup() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	for n: Node in _lv.get_children():
		if n is Enemy:
			n.set_physics_process(false)
			n.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
			(n.get_node("HealthComponent") as HealthComponent).current_health = 99
	for n: String in ROW + ["Dummy1", "EnemyRow2", "CrateA"]:
		_home[n] = (_lv.get_node(n) as Node3D).global_position
	_wind = GameState.get_ability(WindBlastData.ID) as WindBlastData
	_reach0 = _wind.reach
	_width0 = _wind.width
	_check(_p.get_node_or_null(FIRE_WIND_PATH) is FireWind, "setup: player có Model/FireWind")


func _tc1_still_dummy() -> void:
	await _reset()
	var dummy := _lv.get_node("Dummy1") as Node3D
	_move("EnemyRow2", dummy.global_position + Vector3(0, 0, -2.5))
	_burn("Dummy1").ignite(_p)
	await _blow_from("Dummy1", 1.5)
	await _wait(0.3)
	_check(_burn("EnemyRow2").is_burning(), "TC1: hình nộm không nhận gió đang cháy + E -> quái phía sau cháy")
	_move("EnemyRow2", _home["EnemyRow2"])


func _tc2_upwind() -> void:
	await _reset()
	_wind.reach = 8.0
	_move("CrateA", _home["SpreadA"] + Vector3(0, 0, 1.6))
	_burn("SpreadA").ignite(_p)
	await _blow_from("SpreadA", 3.0)
	await _wait(0.3)
	_check(not _burn("CrateA").is_burning(), "TC2: thùng nằm giữa cáo và vật cháy (ngược gió) không cháy")
	_check(_burn("SpreadB").is_burning(), "TC2: SpreadB xuôi gió vẫn cháy")
	_wind.reach = _reach0


func _tc3_reach_and_width() -> void:
	await _reset()
	_burn("SpreadA").ignite(_p)
	await _blow_from("SpreadA", 1.5)
	await _wait(0.3)
	_check(_burn("SpreadB").is_burning(), "TC3: SpreadB trong tầm cháy")
	_check(not _burn("SpreadC").is_burning(), "TC3: SpreadC ngoài tầm gió không cháy")
	_check(not _burn("SpreadSide").is_burning(), "TC3: SpreadSide lệch 3 m ngoài bề rộng gió không cháy")


func _tc4_no_refresh() -> void:
	await _reset()
	var a := _burn("SpreadA")
	a.ignite(_p)
	var lit_at := Time.get_ticks_msec()
	await _wait(0.3)
	await _blow_from("SpreadA", 1.5)
	var left := a.data.duration - (Time.get_ticks_msec() - lit_at) / 1000.0 + 0.15
	await _wait(maxf(left, 0.0))
	_check(not a.is_burning(), "TC4: vật đang cháy không bị vết lửa làm mới (tắt đúng giờ)")


func _tc5_nobody() -> void:
	await _reset()
	var fired: Array[int] = [0]
	var fw := _p.get_node(FIRE_WIND_PATH) as FireWind
	var counter := func(_s: float, _l: float) -> void: fired[0] += 1
	fw.fired.connect(counter)
	await _blow_from("SpreadA", 1.5)
	await _wait(0.3)
	fw.fired.disconnect(counter)
	var any := false
	for n: String in ROW:
		any = any or _burn(n).is_burning()
	_check(not any and fired[0] == 0, "TC5: không ai cháy -> gió không mang lửa")


func _tc6_row() -> void:
	await _reset()
	_wind.reach = 8.0
	_burn("SpreadA").ignite(_p)
	await _blow_from("SpreadA", 1.5)
	await _wait(0.3)
	_check(_burn("SpreadB").is_burning() and _burn("SpreadC").is_burning(), "TC6: một cú gió đốt cả hàng xuôi gió (B, C)")
	_wind.reach = _reach0


func _tc7_nearest() -> void:
	await _reset()
	_wind.reach = 8.0
	_move("CrateA", _home["SpreadA"] + Vector3(0, 0, -1.5))
	_burn("SpreadA").ignite(_p)
	_burn("SpreadB").ignite(_p)
	await _blow_from("SpreadA", 1.5)
	await _wait(0.3)
	_check(_burn("CrateA").is_burning(), "TC7: 2 vật cháy -> vết lửa tính từ vật gần cáo (thùng giữa A và B cháy)")
	_wind.reach = _reach0


func _tc8_turns_off() -> void:
	await _reset()
	var fw := _p.get_node(FIRE_WIND_PATH) as FireWind
	var igniter := fw.get_node("Igniter") as IgniterArea
	_burn("SpreadA").ignite(_p)
	await _blow_from("SpreadA", 1.5)
	await _wait(_wind.duration + fw.data.extra_time + 0.3)
	_check(not igniter.is_active() and not igniter.monitoring and not fw.is_physics_processing(), "TC8: gió tắt -> vết lửa tắt, hết xử lý")


func _tc9_crate_source() -> void:
	await _reset()
	_move("SpreadA", _home["SpreadA"] + Vector3(0, 0, 20))
	_move("CrateA", _home["SpreadA"])
	_burn("CrateA").ignite(_p)
	await _stand(_home["SpreadA"] + Vector3(0, 0.2, 1.5))
	await _blow()
	await _wait(0.3)
	_check(_burn("SpreadB").is_burning(), "TC9: thùng gỗ đang cháy cũng dẫn lửa theo gió")


func _tc10_extremes() -> void:
	var fw := _p.get_node(FIRE_WIND_PATH) as FireWind
	var extra0 := fw.data.extra_time
	# [reach, width, extra_time, hình nộm, mong cháy]
	var cases: Array = [
		[2.0, _width0, extra0, "SpreadB", false],
		[12.0, _width0, extra0, "SpreadC", true],
		[_reach0, 0.5, extra0, "SpreadB", true],
		[_reach0, 8.0, extra0, "SpreadSide", true],
		[_reach0, _width0, 0.0, "SpreadB", true],
	]
	for c: Array in cases:
		await _reset()
		_wind.reach = c[0]
		_wind.width = c[1]
		fw.data.extra_time = c[2]
		_burn("SpreadA").ignite(_p)
		await _blow_from("SpreadA", 1.5)
		await _wait(0.3)
		var lit := _burn(c[3]).is_burning()
		_check(lit == c[4], "TC10: tầm %.1f, rộng %.1f, extra %.2f -> %s %s" % [c[0], c[1], c[2], c[3], "cháy" if lit else "không cháy"])
	_wind.reach = _reach0
	_wind.width = _width0
	fw.data.extra_time = extra0


func _tc11_old_removed() -> void:
	var ok := true
	for n: String in ["EnemyRow2", "Dummy1", "CrateA"]:
		ok = ok and _lv.get_node(n).get_node_or_null("FireSpread") == null
	ok = ok and not ("fire_spread" in _burn("SpreadA"))
	_check(ok, "TC11: không còn FireSpread (phụt sau lưng) trên quái / hình nộm / thùng")


func _tc12_five_gusts() -> void:
	var fw := _p.get_node(FIRE_WIND_PATH) as FireWind
	var igniter := fw.get_node("Igniter") as IgniterArea
	for i: int in 5:
		await _reset()
		_burn("SpreadA").ignite(_p)
		await _blow_from("SpreadA", 1.5)
	await _wait(1.0)
	_check(not fw.is_physics_processing() and not igniter.is_active() and not igniter.monitoring, "TC12: sau 5 cú gió FireWind + igniter đã tắt")
	var left: PackedStringArray = []
	for n: Node in fw.find_children("*", "", true, false):
		if (n is GPUParticles3D and (n as GPUParticles3D).emitting) or (n is CPUParticles3D and (n as CPUParticles3D).emitting):
			left.append("hạt:" + String(fw.get_path_to(n)))
		elif n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			left.append("mesh:" + String(fw.get_path_to(n)))
	_check(left.is_empty(), "TC12: 1 s sau cú cuối không còn gì của lửa theo gió đang phát / hiện %s" % str(left))


# ---------- tiện ích ----------

## Tắt lửa mọi thứ, đưa về chỗ cũ, chờ thùng hiện lại và hết hồi chiêu gió
func _reset() -> void:
	for n: String in _home:
		_burn(n).extinguish()
		_move(n, _home[n])
	var crate := _lv.get_node("CrateA") as BurnableCrate
	for i: int in 60:
		if crate.is_present():
			break
		await _wait(0.1)
	await _wait(_wind.get_lockout() + 0.1)
	# Hình nộm hàng Spread nhận gió: trôi sau cú thổi trước, đưa về lại
	for n: String in _home:
		_move(n, _home[n])


func _move(n: String, pos: Vector3) -> void:
	var node := _lv.get_node(n) as Node3D
	node.global_position = pos
	if node is CharacterBody3D:
		(node as CharacterBody3D).velocity = Vector3.ZERO


## Đứng trước vật (phía +z) cách dist mét, mặt hướng -z, rồi bấm E
func _blow_from(n: String, dist: float) -> void:
	await _stand((_lv.get_node(n) as Node3D).global_position + Vector3(0, 0.2, dist))
	await _blow()


func _stand(pos: Vector3) -> void:
	_p.teleport(pos, Vector3.FORWARD)
	await _f(8)


## Bấm E thật; ép quay thẳng -z ngay khi vào state (tránh tự ngắm lệch về quái gần nhất)
func _blow() -> void:
	_p.energy.set_current(_p.energy.get_max())
	Input.action_press(&"skill")
	await _f(1)
	_p.face_instantly(Vector3.FORWARD)
	await _f(1)
	Input.action_release(&"skill")


func _burn(n: String) -> BurnableComponent:
	return _lv.get_node(n).get_node("BurnableComponent") as BurnableComponent


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
