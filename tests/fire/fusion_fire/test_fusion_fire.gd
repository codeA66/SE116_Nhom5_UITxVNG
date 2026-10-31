extends Node
## Unit test ghép Lửa vào vũ khí (Kiếm Lửa, Cung Lửa). Viết TRƯỚC khi code (TDD).
## Chạy: mở tests/fire/fusion_fire/test_fusion_fire.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1 Kiếm Lửa: chỉ nhát CUỐI combo làm cháy thứ dễ cháy trong vùng chém; các nhát trước chém thường.
##     Sát thương không đổi (luật 1 máu mỗi nhát); cháy thì thêm tick như thường.
## UC2 Chưa ghép Lửa: chém không làm cháy.
## UC3 Ghép Lửa vào vũ khí thì kỹ năng Phun Lửa (Q) bị khoá; tháo ra dùng lại được.
## UC4 Cung Lửa: tên trúng đâu thì bùng lửa ~1 m quanh chỗ trúng, đốt thứ dễ cháy ở đó (mục tiêu và vật đứng cạnh).
## UC5 Tên trúng vật không có máu (thùng gỗ) cũng bùng lửa.
## UC6 Vùng lửa dùng object pool: dùng liên tục không tạo node mới, xong tự trả về pool.
## UC7 Kiếm Lửa + Cung Gió cùng lúc: chém cho quái cháy rồi bắn tên gió -> Lốc Lửa đốt quái đứng cạnh.
## UC8 Thông số cực đoan (vùng chém, bán kính bùng) vẫn đúng.
##
## ===== TEST CASE =====
## TC1 (UC1) Ghép Lửa vào kiếm, chém Dummy1 đủ combo: sau nhát 1 và 2 chưa cháy; sau nhát cuối cháy; mỗi nhát -1 máu.
## TC2 (UC2) Tháo Lửa, chém đủ combo: không cháy.
## TC3 (UC3) Ghép Lửa vào kiếm: is_ability_fused(flame_breath) đúng, bấm Q không vào FlameBreath; tháo ra bấm Q vào được.
## TC4 (UC4) Ghép Lửa vào cung, bắn Enemy (đứng hình), CrateA đặt cạnh Enemy 0.8 m: cả Enemy và CrateA cháy.
## TC5 (UC5) Bắn thẳng vào CrateA (không có quái quanh): CrateA cháy.
## TC6 (UC6) Gọi hiệu ứng cung 10 lần liên tiếp: số FireTouch trong pool không vượt pool_size + số đang bận; hết lượt
##           thì mọi FireTouch trả về pool (không còn đang bận).
## TC7 (UC7) Lửa vào kiếm + Gió vào cung, EnemyRow2 đứng cạnh Enemy 1.5 m: chém Enemy đủ combo (cháy), bắn tên vào Enemy
##           -> EnemyRow2 cháy.
## TC8 (UC8) Vùng chém đẩy xa 6 m -> chém đủ combo không cháy; vùng chém 8 x 4 x 8 m -> Dummy2 (cách ~3 m) cháy;
##           bán kính bùng 0.2 m -> thùng cách 0.8 m không cháy; bán kính 5 m -> thùng cách 3 m cháy.
## TC9  (UC6) Bắn 3 phát Cung Lửa (trúng quái, trúng thùng, trượt xuống sàn): 4 s sau không vệt lửa nào còn chạy / phát hạt,
##            mọi vệt đã về pool (kiểm tra signal kết thúc của mũi tên thật sự gọi được hàm nhận).
## TC10 (UC6) Sau khi vùng lửa chỗ trúng xong + vòng mờ hết: mọi FireTouch và FireTouchVfx tắt xử lý, vòng ẩn.
## TC11 (UC4) Bắn EnemyRow3 còn 1 máu (chỉ dùng ở case này vì nó sẽ chết): nó chết, không cháy; thùng đứng cạnh vẫn cháy.
## TC12 (UC6) Kiếm Lửa chém đủ combo 5 lần liên tiếp: số FireTouch không tăng, xong không cái nào bận.
## TC13 (UC6) 3 s sau mọi lượt: không còn node lửa nào của fusion đang hiện (hạt đang phát / mesh hiện) trong sân thử.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const SWORD := WeaponData.Slot.SWORD
const BOW := WeaponData.Slot.BOW
const SWORD_FIRE := "res://resources/combat/fusion/fire/sword_fire.tres"
const BOW_FIRE := "res://resources/combat/fusion/fire/bow_fire.tres"
## Chờ giữa hai lần bấm chém: đủ để nhát trước ra đòn, còn trong cửa sổ nối combo
const SLASH_GAP := 0.32

var _fails: int = 0
var _lv: Node
var _p: Player
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
	await _tc1_last_hit_only()
	await _tc2_not_fused()
	await _tc3_q_locked()
	await _tc4_bow_burst()
	await _tc5_bow_crate()
	await _tc6_pool()
	await _tc7_fire_sword_wind_bow()
	await _tc8_extremes()
	await _tc9_trails_end()
	await _tc10_touch_vfx_ends()
	await _tc11_dying_target()
	await _tc12_combo_repeat()
	_tc13_nothing_left()
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
	for n: Node in _lv.get_children():
		if n is Enemy:
			n.set_physics_process(false)
			n.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
			(n.get_node("HealthComponent") as HealthComponent).current_health = 99
	for n: String in ["Dummy1", "Dummy2", "Enemy", "EnemyRow2", "CrateA"]:
		_home[n] = (_lv.get_node(n) as Node3D).global_position
	_check(GameState.get_owned_elements().any(func(e: ElementData) -> bool: return e.id == &"fire"), "setup: có nguyên tố Lửa (đã mở Phun Lửa)")
	_check(load(SWORD_FIRE) is FusionData and load(BOW_FIRE) is FusionData, "setup: có Kiếm Lửa và Cung Lửa")


func _tc1_last_hit_only() -> void:
	await _reset()
	_check(GameState.fuse(&"fire", SWORD), "TC1: ghép Lửa vào kiếm")
	var hp := _hp("Dummy1")
	var lit: Array[bool] = await _combo_on("Dummy1")
	var n := lit.size()
	_check(n >= 2, "TC1: chém đủ combo (%d nhát)" % n)
	var early_ok := true
	for i: int in n - 1:
		early_ok = early_ok and not lit[i]
	_check(early_ok, "TC1: các nhát trước nhát cuối không làm cháy %s" % str(lit))
	_check(lit[n - 1], "TC1: nhát cuối làm cháy")
	_check(_hp("Dummy1") <= hp - n, "TC1: mỗi nhát vẫn -1 máu như thường (%d -> %d sau %d nhát)" % [hp, _hp("Dummy1"), n])
	GameState.unfuse(SWORD)


func _tc2_not_fused() -> void:
	await _reset()
	var lit: Array[bool] = await _combo_on("Dummy1")
	_check(not lit.has(true), "TC2: chưa ghép Lửa -> chém đủ combo không cháy %s" % str(lit))


func _tc3_q_locked() -> void:
	await _reset()
	GameState.fuse(&"fire", SWORD)
	_check(GameState.is_ability_fused(FlameBreathData.ID), "TC3: ghép Lửa -> Phun Lửa bị khoá")
	await _stand_before("Dummy1", 3.0)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill_fire")
	await _f(4)
	_check(String(_p.state_machine.current_state.name) != "FlameBreath", "TC3: bấm Q không phun khi đang ghép")
	GameState.unfuse(SWORD)
	await _wait(0.3)
	_p.energy.set_current(_p.energy.get_max())
	await _press(&"skill_fire")
	await _f(4)
	_check(String(_p.state_machine.current_state.name) == "FlameBreath", "TC3: tháo ra -> Q phun lại được")
	await _wait(1.5)


func _tc4_bow_burst() -> void:
	await _reset()
	GameState.fuse(&"fire", BOW)
	_move("CrateA", _home["Enemy"] + Vector3(0.8, 0, 0))
	await _shoot_at("Enemy")
	_check(_burn("Enemy").is_burning(), "TC4: Cung Lửa trúng quái -> quái cháy")
	_check(_burn("CrateA").is_burning(), "TC4: thùng đứng cạnh 0.8 m cũng cháy")
	GameState.unfuse(BOW)


func _tc5_bow_crate() -> void:
	await _reset()
	GameState.fuse(&"fire", BOW)
	_move("CrateA", Vector3(14, 0, 14))
	await _shoot_at("CrateA")
	_check(_burn("CrateA").is_burning(), "TC5: tên trúng thùng gỗ (không máu) -> thùng cháy")
	GameState.unfuse(BOW)


func _tc6_pool() -> void:
	await _reset()
	var effect := (load(BOW_FIRE) as FusionData).effects[0] as IgniteOnImpactEffect
	for i: int in 10:
		effect.on_projectile_impact(_p, Vector3(14, 0.5, -14), Vector3.FORWARD)
		await _f(1)
	var touches := _touches()
	_check(touches.size() <= effect.pool_size + 10 and touches.size() > 0, "TC6: có FireTouch trong pool (%d node)" % touches.size())
	# Chờ 10 vùng vừa bắn liên tục trả về pool, rồi mới đếm lượt dùng có nghỉ
	await _wait(effect.duration + 0.2)
	var created := touches.size()
	for i: int in 10:
		effect.on_projectile_impact(_p, Vector3(14, 0.5, -14), Vector3.FORWARD)
		await _wait(effect.duration + 0.1)
	_check(_touches().size() == created, "TC6: dùng tiếp 10 lần có nghỉ không tạo node mới (%d -> %d)" % [created, _touches().size()])
	await _wait(effect.duration + 0.2)
	var busy := 0
	for t: FireTouch in _touches():
		busy += 1 if t.is_active() else 0
	_check(busy == 0, "TC6: xong lượt -> mọi FireTouch đã trả về pool (%d đang bận)" % busy)


func _tc7_fire_sword_wind_bow() -> void:
	await _reset()
	GameState.fuse(&"fire", SWORD)
	GameState.fuse(&"wind", BOW)
	_move("EnemyRow2", _home["Enemy"] + Vector3(1.5, 0, 0))
	# Chém đủ combo + giữ cung + tên bay mất ~2.6 s, lâu hơn thời gian cháy mặc định 2 s: kéo dài tạm trong test này
	var burn_data := _burn("Enemy").data
	var duration0 := burn_data.duration
	burn_data.duration = 6.0
	var lit: Array[bool] = await _combo_on("Enemy")
	_check(lit.size() > 0 and lit[lit.size() - 1], "TC7: Kiếm Lửa đốt quái ở nhát cuối")
	# Thân quái chạy vật lý để tên trúng và hố kéo thật; xoá lực đẩy dồn (thân đứng hình không tự giảm)
	for n: String in ["Enemy", "EnemyRow2"]:
		var receiver := _lv.get_node(n).get_node("WindReceiverComponent") as WindReceiverComponent
		receiver.set_push_immunity(true)
		receiver.set_push_immunity(false)
	await _shoot_at("Enemy")
	_check(_burn("EnemyRow2").is_burning(), "TC7: + Cung Gió -> Lốc Lửa đốt quái đứng cạnh")
	burn_data.duration = duration0
	GameState.unfuse(SWORD)
	GameState.unfuse(BOW)


func _tc8_extremes() -> void:
	var sword := (load(SWORD_FIRE) as FusionData).effects[0] as IgniteOnLastHitEffect
	var size0 := sword.area_size
	var fwd0 := sword.forward
	# Vùng chém đẩy xa 6 m: không trúng hình nộm trước mặt
	await _reset()
	GameState.fuse(&"fire", SWORD)
	sword.forward = 6.0
	var lit: Array[bool] = await _combo_on("Dummy1")
	_check(not lit.has(true), "TC8: vùng chém đẩy xa 6 m -> không cháy")
	sword.forward = fwd0
	# Vùng chém 8 x 4 x 8 m: hình nộm bên cạnh (~3 m) cũng cháy
	await _reset()
	# _reset() tháo mọi ghép: ghép Lửa lại cho kiếm
	GameState.fuse(&"fire", SWORD)
	sword.area_size = Vector3(8, 4, 8)
	await _combo_on("Dummy1")
	_check(_burn("Dummy2").is_burning(), "TC8: vùng chém 8 x 4 x 8 m -> Dummy2 cách ~3 m cháy")
	sword.area_size = size0
	GameState.unfuse(SWORD)
	# Bán kính bùng của cung
	var bow := (load(BOW_FIRE) as FusionData).effects[0] as IgniteOnImpactEffect
	var r0 := bow.radius
	for c: Array in [[0.2, 0.8, false], [5.0, 3.0, true]]:
		await _reset()
		bow.radius = c[0]
		_move("CrateA", Vector3(14, 0, -14) + Vector3(c[1], 0, 0))
		bow.on_projectile_impact(_p, Vector3(14, 0.5, -14), Vector3.FORWARD)
		await _wait(0.3)
		var hit := _burn("CrateA").is_burning()
		_check(hit == c[2], "TC8: bán kính bùng %.1f m, thùng cách %.1f m -> %s" % [c[0], c[1], "cháy" if hit else "không cháy"])
	bow.radius = r0


func _tc9_trails_end() -> void:
	await _reset()
	GameState.fuse(&"fire", BOW)
	# Không bật vật lý thân quái: thân chạy thì quái tự trôi khỏi đường tên; tên vẫn trúng thân đứng hình
	await _shoot_at("Enemy")
	_move("CrateA", Vector3(14, 0, 14))
	await _shoot_at("CrateA")
	# Trượt: đứng giữa sân trống bắn thẳng, tên rơi xuống sàn / bay hết tầm
	_p.teleport(Vector3(16, 0.2, -16), Vector3.FORWARD)
	await _f(8)
	_p.face_instantly(Vector3.FORWARD)
	_p.energy.set_current(_p.energy.get_max())
	Input.action_press(&"aim")
	await _wait(0.9)
	Input.action_release(&"aim")
	await _wait(4.0)
	var running := 0
	var emitting := 0
	var trails := _p.find_children("*", "FireArrowTrail", true, false)
	for t: Node in trails:
		running += 1 if t.is_processing() else 0
		emitting += 1 if (t.get_node("Flames") as GPUParticles3D).emitting else 0
	_check(trails.size() > 0, "TC9: có vệt lửa bám tên (%d node)" % trails.size())
	_check(running == 0 and emitting == 0, "TC9: 4 s sau 3 phát (trúng quái / thùng / trượt) không vệt nào còn chạy (%d) hay phát lửa (%d)" % [running, emitting])
	GameState.unfuse(BOW)


func _tc10_touch_vfx_ends() -> void:
	await _reset()
	var effect := (load(BOW_FIRE) as FusionData).effects[0] as IgniteOnImpactEffect
	effect.on_projectile_impact(_p, Vector3(14, 0.5, -14), Vector3.FORWARD)
	await _wait(0.1)
	var vfx_busy := false
	for v: Node in _p.find_children("*", "FireTouchVfx", true, false):
		vfx_busy = vfx_busy or v.is_processing()
	_check(vfx_busy, "TC10: lúc vừa bùng, VFX vùng lửa đang chạy")
	await _wait(1.0)
	var busy := 0
	var ring_visible := 0
	for t: FireTouch in _touches():
		busy += 1 if t.is_active() or t.is_physics_processing() else 0
	for v: Node in _p.find_children("*", "FireTouchVfx", true, false):
		busy += 1 if v.is_processing() else 0
		ring_visible += 1 if (v.get_node("Ring") as Node3D).visible else 0
	_check(busy == 0 and ring_visible == 0, "TC10: 1 s sau vùng lửa + VFX tắt hết xử lý (%d bận), vòng ẩn (%d hiện)" % [busy, ring_visible])


func _tc11_dying_target() -> void:
	await _reset()
	GameState.fuse(&"fire", BOW)
	# Đưa ra chỗ trống: chỗ cũ nằm thẳng hàng sau EnemyRow2, tên sẽ trúng con chắn giữa
	_move("EnemyRow3", Vector3(16, 0, -8))
	# Không bật vật lý thân quái: thân chạy thì quái tự trôi khỏi đường tên (test chập chờn); tên vẫn trúng thân đứng hình
	(_lv.get_node("EnemyRow3/HealthComponent") as HealthComponent).current_health = 1
	_move("CrateA", (_lv.get_node("EnemyRow3") as Node3D).global_position + Vector3(0.8, 0, 0))
	await _shoot_at("EnemyRow3")
	var enemy := _lv.get_node_or_null("EnemyRow3") as Enemy
	var dead := enemy == null or enemy.is_dead()
	_check(dead, "TC11: quái còn 1 máu trúng tên -> chết")
	_check(enemy == null or not _burn("EnemyRow3").is_burning(), "TC11: quái đã chết không cháy")
	_check(_burn("CrateA").is_burning(), "TC11: thùng đứng cạnh vẫn cháy")
	GameState.unfuse(BOW)


func _tc12_combo_repeat() -> void:
	await _reset()
	GameState.fuse(&"fire", SWORD)
	await _combo_on("Dummy1")
	var created := _touches().size()
	for i: int in 4:
		(_lv.get_node("Dummy1/HealthComponent") as HealthComponent).heal_full()
		await _combo_on("Dummy1")
	await _wait(0.5)
	var busy := 0
	for t: FireTouch in _touches():
		busy += 1 if t.is_active() else 0
	_check(_touches().size() == created, "TC12: 5 combo liên tiếp không tạo thêm FireTouch (%d -> %d)" % [created, _touches().size()])
	_check(busy == 0, "TC12: xong mọi combo không FireTouch nào còn bận (%d)" % busy)
	GameState.unfuse(SWORD)


func _tc13_nothing_left() -> void:
	var left: PackedStringArray = []
	for n: Node in _p.find_children("*", "", true, false):
		var owner_scene := n.owner if n.owner else n
		if not (owner_scene is FireTouch or owner_scene is FireArrowTrail or n is FireTouch or n is FireArrowTrail):
			continue
		if n is GPUParticles3D and (n as GPUParticles3D).emitting:
			left.append(String(_p.get_path_to(n)))
		elif n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
			left.append(String(_p.get_path_to(n)))
	_check(left.is_empty(), "TC13: hết lượt không còn lửa fusion nào đang hiện %s" % str(left))


# ---------- tiện ích ----------

## Bật thân quái chạy vật lý (tên trúng / hố kéo thật); xoá lực đẩy dồn lúc thân đứng hình
func _wake(n: String) -> void:
	var receiver := _lv.get_node(n).get_node("WindReceiverComponent") as WindReceiverComponent
	receiver.set_push_immunity(true)
	receiver.set_push_immunity(false)
	(_lv.get_node(n) as Enemy).set_physics_process(true)


## Đứng hình lại thân quái (state machine vẫn tắt từ setup)
func _sleep(n: String) -> void:
	var e := _lv.get_node_or_null(n) as Enemy
	if e:
		e.set_physics_process(false)

## Đứng trước mục tiêu 1.4 m, chém liên tục tới hết combo; trả về mảng "đang cháy" sau từng nhát
func _combo_on(target: String) -> Array[bool]:
	await _stand_before(target, 1.4)
	var result: Array[bool] = []
	var hp := _hp_any(target)
	for i: int in 6:
		await _press(&"attack")
		await _wait(SLASH_GAP)
		var now_hp := _hp_any(target)
		if now_hp == hp:
			break
		hp = now_hp
		result.append(_burn(target).is_burning())
	await _wait(0.6)
	return result


## Đứng sau mục tiêu 5 m (phía +z), giữ aim rồi thả bắn; chờ tên bay tới
func _shoot_at(target: String) -> void:
	await _stand_before(target, 5.0)
	_p.energy.set_current(_p.energy.get_max())
	Input.action_press(&"aim")
	await _wait(0.9)
	Input.action_release(&"aim")
	await _wait(0.8)


func _stand_before(target: String, dist: float) -> void:
	_p.teleport((_lv.get_node(target) as Node3D).global_position + Vector3(0, 0.2, dist), Vector3.FORWARD)
	await _f(8)
	_p.face_instantly(Vector3.FORWARD)


## Tắt lửa, đưa về chỗ cũ, tháo mọi ghép, chờ thùng hiện lại
func _reset() -> void:
	GameState.unfuse(SWORD)
	GameState.unfuse(BOW)
	for n: String in _home:
		_burn(n).extinguish()
		_move(n, _home[n])
	for n: String in ["Dummy1", "Dummy2", "Dummy3"]:
		_burn(n).extinguish()
		# Hình nộm chỉ 5 máu: hồi đầy để nhiều combo liên tiếp không làm nó chết rồi hồi giữa chừng
		(_lv.get_node(n).get_node("HealthComponent") as HealthComponent).heal_full()
	var crate := _lv.get_node("CrateA") as BurnableCrate
	for i: int in 60:
		if crate.is_present():
			break
		await _wait(0.1)
	await _wait(0.5)


func _touches() -> Array[FireTouch]:
	var out: Array[FireTouch] = []
	for n: Node in _p.find_children("*", "FireTouch", true, false):
		out.append(n as FireTouch)
	return out


func _move(n: String, pos: Vector3) -> void:
	var node := _lv.get_node(n) as Node3D
	node.global_position = pos
	if node is CharacterBody3D:
		(node as CharacterBody3D).velocity = Vector3.ZERO


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _f(2)
	Input.action_release(action)


func _burn(n: String) -> BurnableComponent:
	return _lv.get_node(n).get_node("BurnableComponent") as BurnableComponent


func _hp(n: String) -> int:
	return (_lv.get_node(n).get_node("HealthComponent") as HealthComponent).current_health


func _hp_any(n: String) -> int:
	var h := _lv.get_node(n).get_node_or_null("HealthComponent") as HealthComponent
	return h.current_health if h else 0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
