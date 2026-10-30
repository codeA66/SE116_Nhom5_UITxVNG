extends Node
## Unit test Bước 4: phun lửa (Q) làm cháy qua IgniterArea. Viết TRƯỚC khi code (TDD).
## Chạy: mở tests/fire/test_igniter.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1  Người chơi bấm Q vào quái trong tầm -> quái mất 1 máu ngay và bốc cháy; cháy 2 s, giây 1.5 mất thêm 1 máu, không khựng.
## UC2  Quái ngoài tầm lửa -> không cháy.
## UC3  Nhiều quái trong luồng lửa -> tất cả cùng cháy.
## UC4  Designer đổi tầm / độ rộng trong flame_breath.tres -> vùng gây cháy đổi theo, không phải chỉnh nơi khác.
## UC5  Lửa bị ngắt giữa chừng (bị đánh, đổi state) -> vùng gây cháy tắt theo.
## UC6  Gió (E) và kiếm KHÔNG làm cháy.
## UC7  Quái đã chết không bắt lửa.
## UC8  Lửa không đốt chính người phun (sau này player có BurnableComponent).
## UC9  Mục tiêu đứng sẵn trong vùng lửa chỉ bắt lửa một lần mỗi lần phun.
## UC10 Nguồn lửa khác (luồng lửa lan, vũ khí lửa) dùng IgniterArea độc lập bằng activate()/deactivate(), không cần hitbox.
##
## ===== TEST CASE =====
## TC1  (UC1)  Đứng cách quái 2.5 m, bấm Q: 0.6 s sau quái mất 1 máu, đang cháy, VFX tạm bật, state không phải Hurt;
##             1.6 s sau lúc bắt lửa mất thêm 1 máu; hết 2 s thì tắt.
## TC2  (UC2)  reach = 0.5 m, quái cách 2.5 m: bấm Q -> không cháy, không mất máu.
## TC3  (UC3,4) reach = 12 m: đứng đầu hàng 3 quái (cách 2.5 / 5.5 / 8.5 m) -> cả 3 cháy.
## TC4  (UC4)  reach = 20 m, width = 0.3 m: quái thẳng trước 2.5 m -> cháy.
##             Quái lệch ngang 3 m: width 2.4 -> không cháy; width 10 -> cháy.
## TC5  (UC5)  Bấm Q, ngay khi lửa bật thì ép đổi state -> vùng gây cháy tắt (is_active false, monitoring false).
## TC6  (UC6)  Bấm E (gió) và chém kiếm vào quái -> không cháy.
## TC7  (UC7)  Giết quái rồi bấm Q vào xác -> không cháy.
## TC8  (UC8)  Gắn BurnableComponent cho player rồi bấm Q -> player không cháy, quái trước mặt vẫn cháy.
## TC9  (UC9)  Mỗi lần phun, signal ignited_target phát đúng 1 lần cho mỗi mục tiêu.
## TC10 (UC10) IgniterArea tự đứng (không follow_hitbox) có shape riêng: activate() -> hình nộm trong vùng cháy;
##             deactivate() rồi activate() lại vẫn đốt được lần nữa; trước activate() không đốt gì.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const IGNITER_PATH := ^"Model/FlameIgniter"
const TEST_ENEMY_HP := 99

var _fails: int = 0
var _lv: Node
var _p: Player
var _data: FlameBreathData
var _reach0: float
var _width0: float


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
	await _tc1_hit_burns()
	await _tc2_out_of_reach()
	await _tc3_row()
	await _tc4_extreme_shape()
	await _tc5_interrupt()
	await _tc6_other_sources()
	await _tc7_dead()
	await _tc8_no_self_burn()
	await _tc9_once_per_breath()
	await _tc10_standalone()
	_data.reach = _reach0
	_data.width = _width0
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


## Mở sân thử, player bất tử, đứng hình mọi quái (khỏi đi tuần / đuổi làm lệch vị trí),
## cho quái nhiều máu để không chết vì bị đốt qua nhiều test case
func _setup() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	for n: Node in _lv.get_children():
		if n is Enemy:
			# Thân quái tự chạy state machine + di chuyển trong _physics_process; component con (cháy, hurtbox) vẫn chạy
			n.set_physics_process(false)
			n.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
			(n.get_node("HealthComponent") as HealthComponent).current_health = TEST_ENEMY_HP
	_data = GameState.get_ability(FlameBreathData.ID) as FlameBreathData
	_reach0 = _data.reach
	_width0 = _data.width
	_check(_p.get_node_or_null(IGNITER_PATH) is IgniterArea, "setup: player có Model/FlameIgniter (IgniterArea)")


func _tc1_hit_burns() -> void:
	var e := "Enemy"
	var hp := _hp(e)
	await _breath_at(e)
	await _wait(0.6)
	_check(_hp(e) == hp - 1, "TC1: Q trúng -> mất 1 máu ngay (%d -> %d)" % [hp, _hp(e)])
	_check(_burn(e).is_burning(), "TC1: quái đang cháy")
	_check((_lv.get_node(e + "/BurningVfx/Flames") as GPUParticles3D).emitting, "TC1: VFX tạm bật")
	# Cú phun trúng trực tiếp là đòn thường (vẫn khựng như trước); chỉ tick cháy là không khựng -> đưa về Idle rồi đo lúc tick
	(_lv.get_node(e) as Enemy).state_machine.transition_to(&"Idle")
	# Bắt lửa ở ~0.16 s sau khi bấm; tick ở +1.5 s
	await _wait(1.15)
	_check(_hp(e) == hp - 2, "TC1: giây 1.5 kể từ bắt lửa mất thêm 1 máu (%d -> %d)" % [hp, _hp(e)])
	_check(_state(e) == "Idle", "TC1: tick cháy không làm khựng (state %s)" % _state(e))
	await _wait(0.5)
	_check(not _burn(e).is_burning(), "TC1: hết 2 s thì tắt")
	await _cooldown()


func _tc2_out_of_reach() -> void:
	_data.reach = 0.5
	var e := "EnemyRow2"
	var hp := _hp(e)
	await _breath_at(e)
	await _wait(0.6)
	_check(not _burn(e).is_burning() and _hp(e) == hp, "TC2: tầm 0.5 m, quái cách 2.5 m -> không cháy")
	_data.reach = _reach0
	await _cooldown()


func _tc3_row() -> void:
	_data.reach = 12.0
	await _breath_at("Enemy")
	await _wait(0.6)
	for e: String in ["Enemy", "EnemyRow2", "EnemyRow3"]:
		_check(_burn(e).is_burning(), "TC3: tầm 12 m, hàng quái: %s cháy" % e)
	_data.reach = _reach0
	await _wait(2.2)
	await _cooldown()


func _tc4_extreme_shape() -> void:
	_data.reach = 20.0
	_data.width = 0.3
	await _breath_at("EnemyRow2")
	await _wait(0.6)
	_check(_burn("EnemyRow2").is_burning(), "TC4: tầm 20 m, rộng 0.3 m -> quái thẳng trước cháy")
	await _wait(2.2)
	await _cooldown()
	_data.reach = _reach0
	for cfg: Array in [[2.4, false], [10.0, true]]:
		_data.width = cfg[0]
		await _breath_at("EnemyRow3", Vector3(3.0, 0.0, 0.0))
		# Chiêu lửa có aim assist tự quay về quái gần nhất: ép quay thẳng trước lúc lửa bật để đo đúng độ rộng
		_p.face_instantly(Vector3.FORWARD)
		await _wait(0.6)
		var lit := _burn("EnemyRow3").is_burning()
		_check(lit == cfg[1], "TC4: quái lệch ngang 3 m, rộng %.1f m -> %s" % [cfg[0], "cháy" if lit else "không cháy"])
		await _wait(2.2)
		await _cooldown()
	_data.width = _width0


func _tc5_interrupt() -> void:
	var igniter := _p.get_node(IGNITER_PATH) as IgniterArea
	_p.teleport(Vector3(10, 0.2, 10), Vector3.FORWARD)
	await _f(5)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill_fire")
	await _wait(_data.active_start + 0.05)
	_check(igniter.is_active(), "TC5: lửa bật -> vùng gây cháy bật")
	_p.state_machine.transition_to(&"Idle")
	await _f(3)
	_check(not igniter.is_active() and not igniter.monitoring, "TC5: bị ngắt state -> vùng gây cháy tắt")
	await _cooldown()


func _tc6_other_sources() -> void:
	var e := "Enemy"
	_p.energy.set_current(_p.energy.get_max())
	await _stand_before(e)
	await _press(&"skill")
	await _wait(1.0)
	_check(not _burn(e).is_burning(), "TC6: gió (E) không làm cháy")
	await _stand_before(e)
	await _press(&"attack")
	await _wait(0.8)
	_check(not _burn(e).is_burning(), "TC6: kiếm không làm cháy")
	await _cooldown()


func _tc7_dead() -> void:
	var e := "Dummy3"
	var health := _lv.get_node(e).find_child("HealthComponent", true, false) as HealthComponent
	health.take_damage(health.current_health)
	await _breath_at(e)
	await _wait(0.6)
	_check(not _burn(e).is_burning(), "TC7: mục tiêu đã chết không cháy")
	await _cooldown()


func _tc8_no_self_burn() -> void:
	var own := (load("res://components/elements/fire/burnable/burnable_component.tscn") as PackedScene).instantiate() as BurnableComponent
	own.hurtbox = _p.get_node("HurtboxComponent") as HurtboxComponent
	own.match_shape_of = _p.get_node("HurtboxComponent/CollisionShape3D") as CollisionShape3D
	_p.add_child(own)
	await _breath_at("Dummy1")
	await _wait(0.6)
	_check(not own.is_burning(), "TC8: lửa không đốt chính player")
	_check(_burn("Dummy1").is_burning(), "TC8: hình nộm trước mặt vẫn cháy")
	own.queue_free()
	await _wait(2.2)
	await _cooldown()


func _tc9_once_per_breath() -> void:
	var igniter := _p.get_node(IGNITER_PATH) as IgniterArea
	var counts: Dictionary[BurnableComponent, int] = {}
	var counter := func(b: BurnableComponent) -> void: counts[b] = counts.get(b, 0) + 1
	igniter.ignited_target.connect(counter)
	await _breath_at("Dummy2")
	await _wait(0.9)
	igniter.ignited_target.disconnect(counter)
	var target := _burn("Dummy2")
	_check(counts.get(target, 0) == 1, "TC9: một lần phun -> ignited_target phát đúng 1 lần cho mục tiêu (%d)" % counts.get(target, 0))
	await _wait(1.5)
	await _cooldown()


func _tc10_standalone() -> void:
	var target := _burn("Dummy2")
	target.extinguish()
	var igniter := IgniterArea.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	igniter.add_child(shape)
	_lv.add_child(igniter)
	igniter.global_position = (_lv.get_node("Dummy2") as Node3D).global_position + Vector3.UP
	await _f(5)
	_check(not target.is_burning(), "TC10: chưa activate() thì không đốt")
	igniter.activate()
	await _f(5)
	_check(target.is_burning(), "TC10: activate() -> hình nộm trong vùng cháy")
	igniter.deactivate()
	target.extinguish()
	await _f(5)
	igniter.activate()
	await _f(5)
	_check(target.is_burning(), "TC10: tắt rồi bật lại vẫn đốt được lần nữa")
	igniter.queue_free()


# ---------- tiện ích ----------

## Đứng cách mục tiêu 2.5 m phía +z (lệch thêm offset), quay mặt về -z
func _stand_before(target: String, offset: Vector3 = Vector3.ZERO) -> void:
	var t := _lv.get_node(target) as Node3D
	_p.teleport(t.global_position + Vector3(0, 0.2, 2.5) + offset, Vector3.FORWARD)
	await _f(8)


## Đứng trước mục tiêu rồi bấm Q thật
func _breath_at(target: String, offset: Vector3 = Vector3.ZERO) -> void:
	await _stand_before(target, offset)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill_fire")


## Chờ hết hồi chiêu Q (duration + cooldown) để lần bấm sau không bị nuốt
func _cooldown() -> void:
	await _wait(_data.get_lockout() + 0.1)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _f(2)
	Input.action_release(action)


func _burn(n: String) -> BurnableComponent:
	return _lv.get_node(n).get_node("BurnableComponent") as BurnableComponent


func _hp(n: String) -> int:
	return (_lv.get_node(n).find_child("HealthComponent", true, false) as HealthComponent).current_health


func _state(n: String) -> String:
	return String((_lv.get_node(n) as Enemy).state_machine.current_state.name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
