extends Node
## Unit test Lốc Lửa: hố hút Cung Gió có thứ đang cháy bên trong -> cả hố bốc lửa, đốt mọi thứ dễ cháy trong bán kính.
## Viết TRƯỚC khi code (TDD). Chạy: mở tests/fire/fire_vortex/test_fire_vortex.tscn rồi F6, hoặc headless.
## Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1 Hố hút có quái / vật đang cháy bên trong -> hố bốc lửa tới hết thời gian hố; mọi thứ dễ cháy trong bán kính cháy
##     (quái và cả vật như thùng gỗ). Không gây sát thương ngay.
## UC2 Hố không có gì đang cháy -> không có lửa.
## UC3 Thứ đang cháy đứng ngoài bán kính hố -> không bốc lửa.
## UC4 Thứ bên trong bắt lửa giữa chừng (phun Q lúc hố đang hút) -> hố bốc lửa từ lúc đó.
## UC5 Hố hết thời gian -> lửa của hố tắt, không còn đốt.
## UC6 Hố kéo quái đang cháy không còn làm lửa phụt lung tung theo hướng kéo (chỉ cú gió mạnh như E mới phụt).
## UC7 Lan nối tiếp chỉ tính cú gió vừa xảy ra: quái bị hố kéo (đang trôi) bắt lửa không phụt theo hướng cú gió cũ.
## UC8 Thông số cực đoan (bán kính, thời gian hố, min_impulse) vẫn đúng.
## UC9 Chơi thật: cáo có cung + ghép Gió vào cung, bắn tên vào quái đang cháy -> quái gần đó cháy theo.
##
## ===== TEST CASE =====
## TC1 (UC1) Hố tâm giữa Enemy và EnemyRow2 (mỗi con cách tâm 1.5 m), CrateA dời vào cách tâm 1.5 m, Enemy đang cháy:
##           perform hố -> 0.3 s sau EnemyRow2 và CrateA cháy; signal caught_fire phát 1 lần; EnemyRow2 chưa mất máu ngay.
## TC2 (UC2) Không ai cháy, perform hố -> sau 0.5 s không ai cháy, caught_fire không phát.
## TC3 (UC3) Chỉ EnemyRow3 (cách tâm 4.5 m) cháy -> hố không bốc lửa, EnemyRow2 không cháy.
## TC4 (UC4) Hố đang chạy, chưa ai cháy; 0.2 s sau đốt Enemy -> hố bốc lửa, EnemyRow2 cháy.
## TC5 (UC5) Sau lifetime: Igniter của hố tắt (không monitoring); dời CrateA vào lại và không bị đốt.
## TC6 (UC6) Enemy đang cháy bị hố kéo suốt lifetime -> spread_fired của Enemy = 0.
## TC7 (UC7) EnemyRow2 bị hố kéo (đang trôi), cú gió E gần nhất đã lâu (> chain_window) -> bắt lửa không spread_fired.
## TC8 (UC8) radius 0.5 -> Enemy cháy cách tâm 1.5 m không làm hố bốc lửa; radius 8 -> EnemyRow3 (4.5 m) cháy theo;
##           lifetime 0.1 -> vẫn bốc lửa và đốt EnemyRow2; min_impulse 0 -> hố kéo quái cháy LÀM phụt lửa (spread_fired > 0);
##           min_impulse 50 -> cú gió E (12) không làm hàng SpreadA/B lan lửa.
## TC9 (UC9) Ghép Gió vào cung, Enemy đang cháy, EnemyRow2 đứng cách 2 m: giữ aim rồi thả bắn tên vào Enemy -> EnemyRow2 cháy.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const VORTEX_SCENE := "res://abilities/fusion/moves/wind_vortex.tscn"
## Tâm hố cho các test đặt tay: giữa Enemy (z -10) và EnemyRow2 (z -13)
const CENTER := Vector3(-6, 0.5, -11.5)
const ENEMIES: Array[String] = ["Enemy", "EnemyRow2", "EnemyRow3"]
const BOW_SLOT := WeaponData.Slot.BOW

var _fails: int = 0
var _lv: Node
var _p: Player
var _home: Dictionary[String, Vector3] = {}
var _crate_home: Vector3


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
	await _tc1_catch_fire()
	await _tc2_nobody_burning()
	await _tc3_outside()
	await _tc4_mid_ignite()
	await _tc5_after_lifetime()
	await _tc6_no_random_jets()
	await _tc7_stale_wind()
	await _tc8_extremes()
	await _tc9_real_arrow()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


## Mở sân thử, player bất tử, đứng hình quái (tắt thân + state machine), cho nhiều máu, nhớ vị trí gốc
func _setup() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	_p.global_position = Vector3(15, 0.2, 15)
	for n: String in ENEMIES:
		var e := _lv.get_node(n) as Enemy
		e.set_physics_process(false)
		e.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
		(e.get_node("HealthComponent") as HealthComponent).current_health = 99
		_home[n] = e.global_position
	_crate_home = (_lv.get_node("CrateA") as Node3D).global_position
	_check(GameState.get_weapon_in_slot(BOW_SLOT) != null, "setup: sân thử cho sẵn cung")
	var probe := _new_vortex()
	_check(probe.get_node_or_null("FireVortex") is FireVortex, "setup: hố hút Cung Gió có node FireVortex")
	probe.queue_free()


func _tc1_catch_fire() -> void:
	await _reset()
	_crate_to(Vector3(-4.5, 0, -11.5))
	var v := _new_vortex()
	var caught: Array[int] = [0]
	(v.get_node("FireVortex") as FireVortex).caught_fire.connect(func() -> void: caught[0] += 1)
	var hp2 := _hp("EnemyRow2")
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(0.3)
	_check(_burn("EnemyRow2").is_burning(), "TC1: quái đang cháy trong hố -> quái khác trong hố cháy")
	_check(_burn_node("CrateA").is_burning(), "TC1: thùng gỗ trong hố cũng cháy")
	_check(caught[0] == 1, "TC1: caught_fire phát đúng 1 lần (%d)" % caught[0])
	_check(_hp("EnemyRow2") == hp2, "TC1: lốc lửa không gây sát thương ngay")
	await _finish(v)


func _tc2_nobody_burning() -> void:
	await _reset()
	_crate_to(Vector3(-4.5, 0, -11.5))
	var v := _new_vortex()
	var caught: Array[int] = [0]
	(v.get_node("FireVortex") as FireVortex).caught_fire.connect(func() -> void: caught[0] += 1)
	_perform(v)
	await _wait(0.5)
	_check(not _any_burning() and caught[0] == 0, "TC2: không ai cháy -> hố không bốc lửa")
	await _finish(v)


func _tc3_outside() -> void:
	await _reset()
	var v := _new_vortex()
	_burn("EnemyRow3").ignite(_p)
	_perform(v)
	await _wait(0.5)
	_check(not _burn("EnemyRow2").is_burning() and not _burn("Enemy").is_burning(), "TC3: thứ cháy ngoài bán kính -> hố không bốc lửa")
	await _finish(v)


func _tc4_mid_ignite() -> void:
	await _reset()
	var v := _new_vortex()
	_perform(v)
	await _wait(0.2)
	_check(not _burn("EnemyRow2").is_burning(), "TC4: trước khi đốt, chưa ai cháy")
	_burn("Enemy").ignite(_p)
	await _wait(0.3)
	_check(_burn("EnemyRow2").is_burning(), "TC4: đốt giữa chừng -> hố bốc lửa, EnemyRow2 cháy")
	await _finish(v)


func _tc5_after_lifetime() -> void:
	await _reset()
	var v := _new_vortex()
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(v.lifetime + 0.3)
	var igniter := v.get_node("FireVortex/Igniter") as IgniterArea
	_check(not igniter.is_active() and not igniter.monitoring, "TC5: hết thời gian hố -> lửa của hố tắt")
	_crate_to(Vector3(-4.5, 0, -11.5))
	await _wait(0.3)
	_check(not _burn_node("CrateA").is_burning(), "TC5: thùng dời vào sau khi hố tắt không bị đốt")
	await _finish(v)


func _tc6_no_random_jets() -> void:
	await _reset()
	var fired: Array[int] = [0]
	var counter := func(_d: Vector3) -> void: fired[0] += 1
	_burn("Enemy").spread_fired.connect(counter)
	var v := _new_vortex()
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(v.lifetime + 0.2)
	_burn("Enemy").spread_fired.disconnect(counter)
	_check(fired[0] == 0, "TC6: hố kéo quái đang cháy không làm phụt lửa theo hướng kéo (%d)" % fired[0])
	await _finish(v)


func _tc7_stale_wind() -> void:
	await _reset()
	var data := _burn("EnemyRow2").fire_spread.data
	var fired: Array[int] = [0]
	var counter := func(_d: Vector3) -> void: fired[0] += 1
	_burn("EnemyRow2").spread_fired.connect(counter)
	# Cú gió mạnh cũ (đủ mạnh để ghi hướng), rồi chờ quá chain_window
	_burn("EnemyRow2").wind_receiver.push(Vector3(0, 0, -12))
	await _wait(data.chain_window + 0.3)
	var v := _new_vortex()
	_perform(v)
	await _wait(0.2)
	_check(_burn("EnemyRow2").wind_receiver.is_being_pushed(), "TC7: EnemyRow2 đang trôi (thân đứng hình nên lực đẩy cũ chưa giảm)")
	_burn("EnemyRow2").ignite(_p)
	await _wait(0.2)
	_burn("EnemyRow2").spread_fired.disconnect(counter)
	_check(fired[0] == 0, "TC7: cú gió cũ quá chain_window -> bắt lửa không phụt theo hướng cũ (%d)" % fired[0])
	await _finish(v)


func _tc8_extremes() -> void:
	# Bán kính 0.5: Enemy cháy cách tâm 1.5 m nằm ngoài
	await _reset()
	var v := _new_vortex(0.5)
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(0.4)
	_check(not _burn("EnemyRow2").is_burning(), "TC8: bán kính 0.5 m -> quái cháy cách 1.5 m không làm hố bốc lửa")
	await _finish(v)
	# Bán kính 8: EnemyRow3 cách tâm 4.5 m cháy theo
	await _reset()
	v = _new_vortex(8.0)
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(0.4)
	_check(_burn("EnemyRow3").is_burning(), "TC8: bán kính 8 m -> quái cách 4.5 m cháy theo")
	await _finish(v)
	# Thời gian hố 0.1 s: vẫn kịp bốc lửa
	await _reset()
	v = _new_vortex(-1.0, 0.1)
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(0.4)
	_check(_burn("EnemyRow2").is_burning(), "TC8: hố chỉ 0.1 s -> vẫn bốc lửa, EnemyRow2 cháy")
	await _finish(v)
	# min_impulse 0: lực kéo nhỏ của hố cũng làm phụt lửa
	await _reset()
	var data := _burn("Enemy").fire_spread.data
	var min0 := data.min_impulse
	data.min_impulse = 0.0
	var fired: Array[int] = [0]
	var counter := func(_d: Vector3) -> void: fired[0] += 1
	_burn("Enemy").spread_fired.connect(counter)
	v = _new_vortex()
	_burn("Enemy").ignite(_p)
	_perform(v)
	await _wait(0.5)
	_burn("Enemy").spread_fired.disconnect(counter)
	_check(fired[0] > 0, "TC8: min_impulse 0 -> lực kéo của hố làm phụt lửa (%d)" % fired[0])
	await _finish(v)
	# min_impulse 50: cú gió E (12) không đủ mạnh để lan
	await _reset()
	data.min_impulse = 50.0
	var spread_home: Dictionary[String, Vector3] = {}
	for n: String in ["SpreadA", "SpreadB"]:
		spread_home[n] = (_lv.get_node(n) as Node3D).global_position
	_burn_node("SpreadA").ignite(_p)
	_p.teleport((_lv.get_node("SpreadA") as Node3D).global_position + Vector3(0, 0.2, 1.5), Vector3.FORWARD)
	await _f(8)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill")
	await _wait(0.4)
	_check(not _burn_node("SpreadB").is_burning(), "TC8: min_impulse 50 -> cú gió E không lan lửa")
	data.min_impulse = min0
	_burn_node("SpreadA").extinguish()
	await _wait(1.0)
	# Cú gió thổi hình nộm trôi đi vài mét: đưa về chỗ cũ để không thành mục tiêu tự ngắm của test sau
	for n: String in ["SpreadA", "SpreadB"]:
		var d := _lv.get_node(n) as CharacterBody3D
		d.velocity = Vector3.ZERO
		d.global_position = spread_home[n]


func _tc9_real_arrow() -> void:
	await _reset()
	# Bật lại thân quái cho tên trúng và hố kéo được thật; state machine vẫn tắt để quái không chạy lung tung
	for n: String in ENEMIES:
		# Lúc thân đứng hình, lực đẩy của hố / gió ở test trước dồn lại không giảm (chỉ giảm khi thân di chuyển):
		# bật/tắt miễn đẩy để xoá lực tồn, không thì bật thân lên quái bị bắn văng đi
		var receiver := _burn(n).wind_receiver
		receiver.set_push_immunity(true)
		receiver.set_push_immunity(false)
		(_lv.get_node(n) as Enemy).set_physics_process(true)
	var row2 := _lv.get_node("EnemyRow2") as Enemy
	var enemy := _lv.get_node("Enemy") as Enemy
	_check(GameState.fuse(&"wind", BOW_SLOT), "TC9: ghép Gió vào cung")
	_burn("Enemy").ignite(_p)
	# Đứng gần (3.5 m) để quái chắc chắn là mục tiêu gần nhất của tự ngắm khi bắn
	_p.teleport(_home["Enemy"] + Vector3(0, 0.2, 3.5), Vector3.FORWARD)
	await _f(8)
	_p.face_instantly(Vector3.FORWARD)
	_p.energy.set_current(_p.energy.get_max())
	Input.action_press(&"aim")
	await _wait(0.9)
	# Thân quái đang chạy vật lý nên Enemy có thể đã trôi: đặt EnemyRow2 cạnh nó (lệch ngang 1.5 m) ngay lúc bắn
	row2.global_position = enemy.global_position + Vector3(1.5, 0, 0)
	row2.velocity = Vector3.ZERO
	Input.action_release(&"aim")
	var lit := false
	for i: int in 90:
		await get_tree().physics_frame
		if _burn("EnemyRow2").is_burning():
			lit = true
			break
	_check(lit, "TC9: bắn tên gió thật vào quái đang cháy -> quái đứng cạnh cháy theo")
	GameState.unfuse(BOW_SLOT)
	for n: String in ENEMIES:
		(_lv.get_node(n) as Enemy).set_physics_process(false)


# ---------- tiện ích ----------

## Tạo một hố hút riêng cho test; radius / lifetime < 0 thì giữ mặc định
func _new_vortex(radius: float = -1.0, lifetime: float = -1.0) -> WindVortex:
	var v := (load(VORTEX_SCENE) as PackedScene).instantiate() as WindVortex
	if radius > 0.0:
		v.radius = radius
	if lifetime > 0.0:
		v.lifetime = lifetime
	# Nối finished để hố không tự queue_free (test tự dọn)
	v.finished.connect(func() -> void: pass)
	_lv.add_child(v)
	v.global_position = CENTER
	return v


func _perform(v: WindVortex) -> void:
	v.perform(null, null, Vector3.FORWARD)


## Chờ hố chạy xong rồi dọn
func _finish(v: WindVortex) -> void:
	await _wait(v.lifetime + v.linger + 0.2)
	v.queue_free()
	await _f(2)


## Tắt lửa mọi thứ, đưa quái và thùng về chỗ cũ
func _reset() -> void:
	for n: String in ENEMIES:
		var e := _lv.get_node(n) as Enemy
		_burn(n).extinguish()
		e.global_position = _home[n]
		e.velocity = Vector3.ZERO
	_burn_node("CrateA").extinguish()
	_crate_to(_crate_home)
	await _wait(0.4)
	# Thùng tắt lửa thì tan rồi hồi lại: chờ hiện lại
	var crate := _lv.get_node("CrateA") as BurnableCrate
	for i: int in 50:
		if crate.is_present():
			break
		await _wait(0.1)


func _crate_to(pos: Vector3) -> void:
	(_lv.get_node("CrateA") as Node3D).global_position = pos


func _any_burning() -> bool:
	for n: String in ENEMIES:
		if _burn(n).is_burning():
			return true
	return _burn_node("CrateA").is_burning()


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _f(2)
	Input.action_release(action)


func _burn(n: String) -> BurnableComponent:
	return _burn_node(n)


func _burn_node(n: String) -> BurnableComponent:
	return _lv.get_node(n).get_node("BurnableComponent") as BurnableComponent


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
