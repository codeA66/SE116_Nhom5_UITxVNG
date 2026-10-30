extends Node
## Unit test Bước 5: Gió thổi mục tiêu đang cháy -> lửa lan theo hướng gió. Viết TRƯỚC khi code (TDD).
## Chạy: mở tests/fire/fire_spread/test_fire_spread.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
## Dùng hàng hình nộm SpreadA/B/C (bật wind_enabled, cách nhau 3 m theo trục -z) và SpreadSide (lệch ngang 3 m) trong sân thử.
##
## ===== USE CASE =====
## UC1  Mục tiêu đang cháy bị Gió (E) thổi trúng -> luồng lửa phụt ra sau lưng nó theo hướng gió.
## UC2  Mục tiêu khác trong luồng lửa đó bắt lửa.
## UC3  Mục tiêu vừa bắt lửa mà cũng đang bị cú gió đó đẩy -> lan tiếp (một cú E đốt cả hàng).
## UC4  Không ai cháy mà bị gió thổi -> không có lửa lan.
## UC5  Mỗi mục tiêu chỉ phụt lửa 1 lần mỗi cú gió.
## UC6  Luồng lửa lan không đốt (không làm mới) chính mục tiêu phụt ra nó.
## UC7  Luồng lửa lan không gây sát thương ngay, chỉ làm cháy.
## UC8  Miễn đẩy (push immunity) -> không lan; wind_multiplier = 0 -> vẫn lan.
## UC9  Dài / rộng / thời gian luồng lửa chỉnh trong FireSpreadData, không sửa code.
## UC10 Không có gió thì luồng lửa nằm im (tắt monitoring, tắt xử lý).
##
## ===== TEST CASE =====
## TC1  (UC1,2)  A cháy, bấm E thổi về hàng: B (sau A 3 m theo hướng gió) cháy.
## TC2  (UC2)    Cùng cú gió: SpreadSide (lệch ngang 3 m) không cháy.
## TC3  (UC3)    Chỉ A cháy, bấm E: A, B, C đều cháy (C cách A 6 m, ngoài tầm luồng của A, chỉ cháy nhờ B lan tiếp).
## TC4  (UC3)    chain_while_pushed = false: B cháy, C không.
## TC5  (UC4)    Không ai cháy, bấm E: không ai cháy, không có spread_fired.
## TC6  (UC5)    Mỗi cú gió, spread_fired của mỗi hình nộm phát tối đa 1 lần.
## TC7  (UC6)    A bị đốt ở t0, thổi ở t0 + 0.3 s: A vẫn tắt đúng t0 + duration (không bị luồng của chính nó làm mới).
## TC8  (UC7)    B bắt lửa từ luồng lan: máu không giảm ngay; tới 1.5 s mới mất 1.
## TC9  (UC8)    A miễn đẩy -> B không cháy. A có wind_multiplier = 0 -> B vẫn cháy.
## TC10 (UC9)    length 0.5 -> B không cháy; length 20 (tắt lan tiếp) -> C cháy; width 0.3 -> B (thẳng hàng) cháy;
##               width 10 -> SpreadSide cháy; active_time 0.05 -> B vẫn cháy.
## TC11 (UC10)   FireSpread lúc nghỉ: igniter không monitoring, _physics_process tắt; xong một lần phụt thì tự tắt lại.
## TC12 (UC1)    Bấm Q thật vào A rồi bấm E thật: B cháy (nối đầy đủ với kỹ năng thật).

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const ROW: Array[String] = ["SpreadA", "SpreadB", "SpreadC", "SpreadSide"]
## Đứng sau A 1.5 m (phía +z), mặt hướng -z: cú gió tầm 5 m phủ A và B
const STAND_OFFSET := Vector3(0, 0.2, 1.5)

var _fails: int = 0
var _lv: Node
var _p: Player
var _spread_data: FireSpreadData
var _home: Dictionary[String, Vector3] = {}
var _fired: Dictionary[String, int] = {}


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
	await _tc1_tc2_tc6_tc8_basic()
	await _tc3_chain()
	await _tc4_no_chain()
	await _tc5_nobody_burning()
	await _tc7_no_self_refresh()
	await _tc9_push_rules()
	await _tc10_extremes()
	await _tc11_idle()
	await _tc12_real_keys()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


## Mở sân thử, player bất tử, nhớ vị trí gốc của hàng hình nộm, đếm spread_fired của từng cái
func _setup() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	for n: String in ROW:
		var dummy := _lv.get_node_or_null(n) as Node3D
		_check(dummy != null, "setup: sân thử có hình nộm %s" % n)
		if dummy == null:
			continue
		_home[n] = dummy.global_position
		_fired[n] = 0
		_burn(n).spread_fired.connect(func(_d: Vector3) -> void: _fired[n] += 1)
	_spread_data = _spread(ROW[0]).data
	_check(_burn("SpreadA").fire_spread != null and _burn("SpreadA").wind_receiver != null, "setup: Burnable nối FireSpread + WindReceiver")


func _tc1_tc2_tc6_tc8_basic() -> void:
	await _reset_row()
	var hp_b := _hp("SpreadB")
	_burn("SpreadA").ignite(_p)
	await _blow()
	await _wait(0.2)
	_check(_burn("SpreadB").is_burning(), "TC1: A cháy + gió -> B (sau A 3 m) cháy")
	_check(not _burn("SpreadSide").is_burning(), "TC2: hình nộm lệch ngang 3 m không cháy")
	_check(_hp("SpreadB") == hp_b, "TC8: B bắt lửa từ luồng lan, chưa mất máu ngay (%d)" % _hp("SpreadB"))
	for n: String in ROW:
		_check(_fired[n] <= 1, "TC6: %s phụt lửa tối đa 1 lần mỗi cú gió (%d)" % [n, _fired[n]])
	await _wait(1.45)
	_check(_hp("SpreadB") == hp_b - 1, "TC8: tới 1.5 s B mới mất 1 máu (%d -> %d)" % [hp_b, _hp("SpreadB")])


func _tc3_chain() -> void:
	await _reset_row()
	_burn("SpreadA").ignite(_p)
	await _blow()
	await _wait(0.3)
	for n: String in ["SpreadA", "SpreadB", "SpreadC"]:
		_check(_burn(n).is_burning(), "TC3: một cú gió lan cả hàng: %s cháy" % n)


func _tc4_no_chain() -> void:
	await _reset_row()
	_spread_data.chain_while_pushed = false
	_burn("SpreadA").ignite(_p)
	await _blow()
	await _wait(0.3)
	_check(_burn("SpreadB").is_burning() and not _burn("SpreadC").is_burning(), "TC4: tắt lan tiếp -> B cháy, C không")
	_spread_data.chain_while_pushed = true


func _tc5_nobody_burning() -> void:
	await _reset_row()
	await _blow()
	await _wait(0.3)
	var any_burning := false
	var any_fired := false
	for n: String in ROW:
		any_burning = any_burning or _burn(n).is_burning()
		any_fired = any_fired or _fired[n] > 0
	_check(not any_burning and not any_fired, "TC5: không ai cháy + gió -> không lan, không spread_fired")


func _tc7_no_self_refresh() -> void:
	await _reset_row()
	var a := _burn("SpreadA")
	a.ignite(_p)
	var lit_at := Time.get_ticks_msec()
	await _wait(0.3)
	await _blow()
	# Đợi tới ngay sau thời điểm A phải tắt nếu không bị làm mới
	var left := a.data.duration - (Time.get_ticks_msec() - lit_at) / 1000.0 + 0.15
	await _wait(maxf(left, 0.0))
	_check(not a.is_burning(), "TC7: luồng lửa của A không làm mới chính A (A tắt đúng giờ)")


func _tc9_push_rules() -> void:
	await _reset_row()
	var receiver := _burn("SpreadA").wind_receiver
	receiver.set_push_immunity(true)
	_burn("SpreadA").ignite(_p)
	await _blow()
	await _wait(0.3)
	_check(not _burn("SpreadB").is_burning(), "TC9: A miễn đẩy -> không lan, B không cháy")
	receiver.set_push_immunity(false)
	await _reset_row()
	var mult := receiver.wind_multiplier
	receiver.wind_multiplier = 0.0
	_burn("SpreadA").ignite(_p)
	await _blow()
	await _wait(0.3)
	_check(_burn("SpreadB").is_burning(), "TC9: A có wind_multiplier = 0 -> vẫn lan, B cháy")
	receiver.wind_multiplier = mult


func _tc10_extremes() -> void:
	var length0 := _spread_data.length
	var width0 := _spread_data.width
	var active0 := _spread_data.active_time
	# [length, width, active_time, chain, hình nộm cần xét, mong cháy]
	var cases: Array = [
		[0.5, width0, active0, true, "SpreadB", false],
		[20.0, width0, active0, false, "SpreadC", true],
		[length0, 0.3, active0, true, "SpreadB", true],
		[length0, 10.0, active0, true, "SpreadSide", true],
		[length0, width0, 0.05, true, "SpreadB", true],
	]
	for c: Array in cases:
		await _reset_row()
		_spread_data.length = c[0]
		_spread_data.width = c[1]
		_spread_data.active_time = c[2]
		_spread_data.chain_while_pushed = c[3]
		_burn("SpreadA").ignite(_p)
		await _blow()
		await _wait(0.3)
		var lit := _burn(c[4]).is_burning()
		_check(lit == c[5], "TC10: dài %.1f, rộng %.1f, bật %.2f s -> %s %s" % [c[0], c[1], c[2], c[4], "cháy" if lit else "không cháy"])
	_spread_data.length = length0
	_spread_data.width = width0
	_spread_data.active_time = active0
	_spread_data.chain_while_pushed = true


func _tc11_idle() -> void:
	await _reset_row()
	var fs := _spread("SpreadA")
	var igniter := fs.get_node("Igniter") as IgniterArea
	_check(not fs.is_active() and not igniter.monitoring and not fs.is_physics_processing(), "TC11: lúc nghỉ FireSpread tắt monitoring + xử lý")
	_burn("SpreadA").ignite(_p)
	await _blow()
	await _wait(_spread_data.active_time + 0.2)
	_check(not fs.is_active() and not igniter.monitoring and not fs.is_physics_processing(), "TC11: phụt xong tự tắt lại")


func _tc12_real_keys() -> void:
	await _reset_row()
	var a := _lv.get_node("SpreadA") as Node3D
	# Đứng sát A và tầm lửa ngắn để Q chỉ trúng A, không trúng B
	var flame := GameState.get_ability(FlameBreathData.ID) as FlameBreathData
	var reach0 := flame.reach
	flame.reach = 1.5
	_p.teleport(a.global_position + STAND_OFFSET, Vector3.FORWARD)
	await _f(8)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill_fire")
	await _wait(0.5)
	_check(_burn("SpreadA").is_burning() and not _burn("SpreadB").is_burning(), "TC12: Q thật -> chỉ A cháy")
	await _wait(flame.get_lockout())
	flame.reach = reach0
	await _blow(false)
	await _wait(0.3)
	_check(_burn("SpreadB").is_burning(), "TC12: E thật sau đó -> lửa lan sang B")


# ---------- tiện ích ----------

## Tắt lửa, đưa hàng hình nộm về chỗ cũ, hồi máu, xoá bộ đếm; chờ hết hồi chiêu lửa lan
func _reset_row() -> void:
	for n: String in ROW:
		var dummy := _lv.get_node(n) as CharacterBody3D
		_burn(n).extinguish()
		dummy.global_position = _home[n]
		dummy.velocity = Vector3.ZERO
		(dummy.get_node("HealthComponent") as HealthComponent).heal_full()
		_fired[n] = 0
	await _wait(_spread_data.spread_cooldown + 0.6)
	for n: String in ROW:
		var dummy := _lv.get_node(n) as CharacterBody3D
		dummy.global_position = _home[n]
		dummy.velocity = Vector3.ZERO


## Đứng sau A, bấm E thật (gió); teleport = false thì giữ chỗ đang đứng
func _blow(teleport: bool = true) -> void:
	if teleport:
		_p.teleport((_lv.get_node("SpreadA") as Node3D).global_position + STAND_OFFSET, Vector3.FORWARD)
		await _f(8)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill")


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _f(2)
	Input.action_release(action)


func _burn(n: String) -> BurnableComponent:
	return _lv.get_node(n).get_node("BurnableComponent") as BurnableComponent


func _spread(n: String) -> FireSpread:
	return _lv.get_node(n).get_node("FireSpread") as FireSpread


func _hp(n: String) -> int:
	return (_lv.get_node(n).get_node("HealthComponent") as HealthComponent).current_health


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
