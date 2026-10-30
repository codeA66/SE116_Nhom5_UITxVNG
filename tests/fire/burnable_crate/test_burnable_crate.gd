extends Node
## Unit test Bước 6: vật dễ cháy không có máu (thùng gỗ thử). Viết TRƯỚC khi code (TDD).
## Chạy: mở tests/fire/burnable_crate/test_burnable_crate.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
## Dùng CrateA, CrateB (cách nhau 3 m theo trục -z) trong sân thử.
##
## ===== USE CASE =====
## UC1 Phun lửa (Q) vào thùng -> thùng cháy (vật không có máu: không có tick sát thương, không lỗi).
## UC2 Thùng cháy hết thời gian (3 s) thì tan: ẩn đi, tắt va chạm, player đi xuyên qua được.
## UC3 Thùng tan rồi hồi lại sau respawn_delay (3 s), đốt được tiếp.
## UC4 Thùng đang tan thì không bắt lửa.
## UC5 Thùng đang cháy nằm trong vết gió -> lửa theo vết gió sang thùng phía sau.
## UC6 Thùng không cháy bị gió thổi -> không lửa, thùng không bị đẩy đi; đốt thùng lúc không có gió thì lửa không tự lan.
## UC7 Thông số cực đoan: cháy 0.1 s, hồi lại 0.1 s vẫn đúng thứ tự cháy -> tan -> hồi.
##
## ===== TEST CASE =====
## TC1 (UC1)   Đứng trước CrateA bấm Q: 0.6 s sau đang cháy, burn_tick (nếu có) báo damage_taken = 0.
## TC2 (UC2)   2.5 s sau khi bắt lửa vẫn còn; 3.2 s sau thì is_present() = false, ẩn, mọi CollisionShape3D của thân bị tắt.
## TC3 (UC2)   Lúc thùng tan: đi player xuyên qua chỗ thùng (đặt player sau thùng, đi về phía trước) không bị chặn.
## TC4 (UC4)   Lúc đang tan gọi ignite(): không cháy.
## TC5 (UC3)   Sau respawn_delay: hiện lại, va chạm bật lại, ignite() lại cháy được.
## TC6 (UC5)   CrateA cháy, bấm E thổi về CrateB: CrateB cháy.
## TC7 (UC6)   Không thùng nào cháy, bấm E: không cháy, CrateA không xê dịch;
##             sau đó đốt CrateB bằng ignite() (không gió): CrateA không cháy.
## TC8 (UC7)   duration 0.1, respawn_delay 0.1: cháy -> tan -> hồi lại trong < 0.5 s.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const STAND_OFFSET := Vector3(0, 0.2, 1.5)

var _fails: int = 0
var _lv: Node
var _p: Player


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


## Chạy lần lượt mọi test case rồi in RESULT
func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	_check(_lv.get_node_or_null("CrateA") is BurnableCrate and _lv.get_node_or_null("CrateB") is BurnableCrate, "setup: sân thử có CrateA, CrateB")
	await _tc1_to_tc5()
	await _tc6_spread()
	await _tc7_no_fire_wind()
	await _tc8_extremes()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _tc1_to_tc5() -> void:
	var crate := _crate("CrateA")
	# Đối chứng cho TC3: lúc thùng còn thì thân player đi qua phải bị chặn
	_p.teleport(crate.global_position + Vector3(0, 0.3, -1.4), Vector3.BACK)
	await _f(5)
	_check(_p.test_move(_p.global_transform, Vector3(0, 0, 2.8)), "TC3 (đối chứng): thùng còn -> bị chặn")
	var ticks: Array[int] = []
	_burn("CrateA").burn_tick.connect(func(t: int) -> void: ticks.append(t))
	await _stand_before("CrateA")
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill_fire")
	await _wait(0.6)
	_check(_burn("CrateA").is_burning(), "TC1: Q vào thùng -> thùng cháy")
	var lit_ms := Time.get_ticks_msec() - 440
	await _wait(1.9)
	_check(crate.is_present(), "TC2: ~2.5 s sau khi bắt lửa thùng vẫn còn")
	await _wait(0.7)
	_check(not crate.is_present() and not crate.visible and _all_shapes_disabled(crate), "TC2: ~3.2 s thùng tan (ẩn, tắt va chạm)")
	_check(ticks.all(func(t: int) -> bool: return t == 0), "TC1: vật không máu: mọi tick báo 0 sát thương (%s)" % str(ticks))
	# TC3: thử dời thân player xuyên qua chỗ thùng bằng test_move (không phụ thuộc góc camera / phím)
	_p.teleport(crate.global_position + Vector3(0, 0.3, -1.4), Vector3.BACK)
	await _f(5)
	var blocked := _p.test_move(_p.global_transform, Vector3(0, 0, 2.8))
	_check(not blocked, "TC3: thùng tan -> thân player đi xuyên qua chỗ thùng không va chạm")
	_burn("CrateA").ignite(_p)
	_check(not _burn("CrateA").is_burning(), "TC4: đang tan thì không bắt lửa")
	_check(lit_ms > 0, "TC5: đã ghi mốc bắt lửa")
	# Chờ tới khi hiện lại (tối đa respawn_delay + 1 s), rồi chờ thêm 2 khung cho va chạm bật (set_deferred)
	for i: int in int((crate.respawn_delay + 1.0) / 0.1):
		if crate.is_present():
			break
		await _wait(0.1)
	await _f(2)
	_check(crate.is_present() and crate.visible and not _all_shapes_disabled(crate), "TC5: sau respawn_delay thùng hiện lại, có va chạm")
	_burn("CrateA").ignite(_p)
	_check(_burn("CrateA").is_burning(), "TC5: hồi lại rồi đốt được tiếp")
	_burn("CrateA").extinguish()
	await _wait(crate.respawn_delay + 0.3)


func _tc6_spread() -> void:
	await _ensure_present()
	_burn("CrateA").ignite(_p)
	await _blow()
	await _wait(0.3)
	_check(_burn("CrateB").is_burning(), "TC6: thùng A cháy + gió -> thùng B (sau 3 m) cháy")
	_burn("CrateA").extinguish()
	_burn("CrateB").extinguish()
	await _wait(_crate("CrateA").respawn_delay + 0.3)


func _tc7_no_fire_wind() -> void:
	await _ensure_present()
	var pos := _crate("CrateA").global_position
	await _blow()
	await _wait(0.4)
	_check(not _burn("CrateA").is_burning() and not _burn("CrateB").is_burning(), "TC7: không ai cháy + gió -> không cháy")
	_check(_crate("CrateA").global_position.distance_to(pos) < 0.01, "TC7: thùng không bị gió đẩy đi")
	# Đốt thùng sau khi gió đã tắt: không có gió thì không có lửa đi đâu cả, thùng kia vẫn yên
	await _wait(0.6)
	_burn("CrateB").ignite(_p)
	await _wait(0.3)
	_check(not _burn("CrateA").is_burning(), "TC7: đốt thùng khi không có gió -> lửa không tự lan sang thùng khác")
	_burn("CrateB").extinguish()
	await _wait(_crate("CrateB").respawn_delay + 0.3)


func _tc8_extremes() -> void:
	await _ensure_present()
	var crate := _crate("CrateA")
	var data := _burn("CrateA").data
	var duration0 := data.duration
	var delay0 := crate.respawn_delay
	data.duration = 0.1
	crate.respawn_delay = 0.1
	_burn("CrateA").ignite(_p)
	await _wait(0.17)
	var gone := not crate.is_present()
	await _wait(0.2)
	_check(gone and crate.is_present(), "TC8: cháy 0.1 s -> tan -> hồi lại sau 0.1 s")
	data.duration = duration0
	crate.respawn_delay = delay0


# ---------- tiện ích ----------

## Chờ tới khi cả hai thùng đều đang hiện (sau lần tan trước)
func _ensure_present() -> void:
	for i: int in 60:
		if _crate("CrateA").is_present() and _crate("CrateB").is_present():
			return
		await _wait(0.1)


func _stand_before(n: String) -> void:
	_p.teleport((_lv.get_node(n) as Node3D).global_position + STAND_OFFSET, Vector3.FORWARD)
	await _f(8)


## Đứng sau CrateA bấm E thật (gió thổi về -z)
func _blow() -> void:
	await _stand_before("CrateA")
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill")


func _all_shapes_disabled(crate: Node) -> bool:
	for child: Node in crate.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			return false
	return true


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _f(2)
	Input.action_release(action)


func _crate(n: String) -> BurnableCrate:
	return _lv.get_node(n) as BurnableCrate


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
