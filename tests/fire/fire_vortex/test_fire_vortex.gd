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
## UC8 Thông số cực đoan (bán kính, thời gian hố) vẫn đúng.
## UC9 Chơi thật: cáo có cung + ghép Gió vào cung, bắn tên vào quái đang cháy -> quái gần đó cháy theo.
##
## ===== TEST CASE =====
## TC1 (UC1) Hố tâm giữa Enemy và EnemyRow2 (mỗi con cách tâm 1.5 m), CrateA dời vào cách tâm 1.5 m, Enemy đang cháy:
##           perform hố -> 0.3 s sau EnemyRow2 và CrateA cháy; signal caught_fire phát 1 lần; EnemyRow2 chưa mất máu ngay.
## TC2 (UC2) Không ai cháy, perform hố -> sau 0.5 s không ai cháy, caught_fire không phát.
## TC3 (UC3) Chỉ EnemyRow3 (cách tâm 4.5 m) cháy -> hố không bốc lửa, EnemyRow2 không cháy.
## TC4 (UC4) Hố đang chạy, chưa ai cháy; 0.2 s sau đốt Enemy -> hố bốc lửa, EnemyRow2 cháy.
## TC5 (UC5) Sau lifetime: Igniter của hố tắt (không monitoring); dời CrateA vào lại và không bị đốt.
## TC8 (UC8) radius 0.5 -> Enemy cháy cách tâm 1.5 m không làm hố bốc lửa; radius 8 -> EnemyRow3 (4.5 m) cháy theo;
##           lifetime 0.1 -> vẫn bốc lửa và đốt EnemyRow2.
## TC9 (UC9) Ghép Gió vào cung, Enemy đang cháy, EnemyRow2 đứng cách 2 m: giữ aim rồi thả bắn tên vào Enemy -> EnemyRow2 cháy.
## TC10 (UC5) Bắn tên gió thật 3 lần (hố hút lấy từ pool, dùng lại): lần 1 Enemy cháy -> EnemyRow2 cháy; dập hết lửa,
##           lần 2, 3 không ai cháy -> hố KHÔNG bốc lửa (không giữ trạng thái lần trước); cuối cùng không hạt lửa nào còn phát.
## TC11 (UC10) Hố ở chỗ trống (không có gì dễ cháy bên trong), đứng 3.5 m bấm Q phun THẲNG vào hố -> hố bốc lửa.
## TC12 (UC10) Cùng chỗ, bấm Q phun NGƯỢC ra xa hố -> hố không bốc lửa.
## TC13 (UC11) Quái đang cháy đứng cách tâm 3.3 m (ngoài vùng hút 2.5 m, trong vùng bắt lửa 2.5 x 1.25) -> hố bốc lửa.
## TC14 (UC11) Quái đang cháy cách tâm 4.2 m (ngoài cả vùng bắt lửa) -> không bốc lửa.
## TC15 (UC11) catch_radius_scale 1.0 -> quái cháy cách 3.3 m không làm bốc lửa; 2.0 -> quái cháy cách 4.2 m làm bốc lửa.
## TC16 (UC10) Hố trong pool chưa hút (chưa perform): vùng lửa chạm vào -> KHÔNG bốc lửa, vùng nhận lửa của hố đang tắt.
## TC17 (UC10) NHƯ GAME THẬT: hố lấy từ pool Cung Gió (nằm DƯỚI node Player), hố trống, Q phun vào -> bốc lửa.
##            (lỗi cũ: luật "không tự đốt mình" xét cây node nên bỏ qua hố nằm dưới Player)
## TC18 (UC10) Như TC17 nhưng nguồn lửa là vùng bùng của Cung Lửa (FireTouch, người châm = Player) -> bốc lửa.
##
## UC10 (thêm 2026-10-31) Nguồn lửa chạm vào chính hố (Q, lửa theo gió, nhát cuối Kiếm Lửa, chỗ tên Cung Lửa trúng)
##      -> hố bốc lửa, kể cả khi trong hố không có gì dễ cháy.
## UC11 (thêm 2026-10-31) Vùng bắt lửa rộng bằng hình xoáy nhìn thấy (bán kính hút x catch_radius_scale), vùng hút không đổi.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const VORTEX_SCENE := "res://abilities/fusion/wind/moves/wind_vortex.tscn"
## Tâm hố cho các test đặt tay: giữa Enemy (z -10) và EnemyRow2 (z -13)
const CENTER := Vector3(-6, 0.5, -11.5)
## Chỗ trống trong sân thử (xa quái / hình nộm / thùng) cho các test hố không có gì bên trong
const EMPTY := Vector3(12, 0.5, 12)
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
	await _tc8_extremes()
	await _tc9_real_arrow()
	await _tc10_vortex_reuse()
	await _tc11_tc12_breath_into_vortex()
	await _tc13_to_tc15_catch_radius()
	await _tc16_idle_vortex()
	await _tc17_tc18_pooled_vortex()
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


func _tc9_real_arrow() -> void:
	await _reset()
	# Bật lại thân quái cho tên trúng và hố kéo được thật; state machine vẫn tắt để quái không chạy lung tung
	for n: String in ENEMIES:
		# Lúc thân đứng hình, lực đẩy của hố / gió ở test trước dồn lại không giảm (chỉ giảm khi thân di chuyển):
		# bật/tắt miễn đẩy để xoá lực tồn, không thì bật thân lên quái bị bắn văng đi
		var receiver := _lv.get_node(n).get_node("WindReceiverComponent") as WindReceiverComponent
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


func _tc10_vortex_reuse() -> void:
	await _reset()
	_check(GameState.fuse(&"wind", BOW_SLOT), "TC10: ghép Gió vào cung")
	var enemy := _lv.get_node("Enemy") as Enemy
	var row2 := _lv.get_node("EnemyRow2") as Enemy
	for shot: int in 3:
		await _reset()
		for n: String in ENEMIES:
			var receiver := _lv.get_node(n).get_node("WindReceiverComponent") as WindReceiverComponent
			receiver.set_push_immunity(true)
			receiver.set_push_immunity(false)
			(_lv.get_node(n) as Enemy).set_physics_process(true)
		# Lần 1 có lửa; lần 2, 3 không ai cháy: hố lấy lại từ pool không được giữ "đang bốc lửa"
		if shot == 0:
			_burn("Enemy").ignite(_p)
		_p.teleport(_home["Enemy"] + Vector3(0, 0.2, 3.5), Vector3.FORWARD)
		await _f(8)
		_p.face_instantly(Vector3.FORWARD)
		_p.energy.set_current(_p.energy.get_max())
		Input.action_press(&"aim")
		await _wait(0.9)
		row2.global_position = enemy.global_position + Vector3(1.5, 0, 0)
		row2.velocity = Vector3.ZERO
		Input.action_release(&"aim")
		await _wait(0.6)
		var lit := _burn("EnemyRow2").is_burning()
		if shot == 0:
			_check(lit, "TC10: lần 1 (Enemy cháy) -> EnemyRow2 cháy")
		else:
			_check(not lit, "TC10: lần %d không ai cháy -> hố dùng lại KHÔNG bốc lửa" % (shot + 1))
		for n: String in ENEMIES:
			(_lv.get_node(n) as Enemy).set_physics_process(false)
		await _wait(1.2)
	GameState.unfuse(BOW_SLOT)
	# Không hạt lửa nào dưới FireVortex còn phát sau khi các hố đã xong
	var emitting: PackedStringArray = []
	for fv: Node in get_tree().root.find_children("*", "FireVortex", true, false):
		for p: Node in fv.find_children("*", "", true, false):
			if (p is GPUParticles3D and (p as GPUParticles3D).emitting) or (p is CPUParticles3D and (p as CPUParticles3D).emitting):
				emitting.append(String(fv.get_path_to(p)))
		_check(not (fv as FireVortex).is_lit(), "TC10: hố %s đã tắt lửa" % fv.get_parent().name)
	_check(emitting.is_empty(), "TC10: không hạt lửa lốc nào còn phát %s" % str(emitting))


func _tc11_tc12_breath_into_vortex() -> void:
	# [hướng quay, mong bốc lửa]: quay về hố (-z) thì lửa phun vào hố; quay ngược (+z) thì không
	for c: Array in [[Vector3.FORWARD, true], [Vector3.BACK, false]]:
		await _reset()
		await _wait(1.5)
		var v := _new_vortex()
		v.global_position = EMPTY
		_p.teleport(EMPTY + Vector3(0, -0.3, 3.5), c[0])
		await _f(8)
		_perform(v)
		_p.energy.set_current(_p.energy.get_max())
		Input.action_press(&"skill_fire")
		await _f(1)
		_p.face_instantly(c[0])
		await _f(1)
		Input.action_release(&"skill_fire")
		await _wait(0.5)
		var lit := (v.get_node("FireVortex") as FireVortex).is_lit()
		var label := "TC11: hố trống, Q phun thẳng vào -> bốc lửa" if c[1] else "TC12: Q phun ngược ra xa hố -> không bốc lửa"
		_check(lit == c[1], "%s (lit=%s)" % [label, lit])
		await _finish(v)


func _tc13_to_tc15_catch_radius() -> void:
	# [hệ số vùng bắt lửa, khoảng cách tâm quái tới tâm hố, mong bốc lửa]
	var cases: Array = [
		[1.25, 3.3, true],
		[1.25, 4.2, false],
		[1.0, 3.3, false],
		[2.0, 4.2, true],
	]
	var row3 := _lv.get_node("EnemyRow3") as Enemy
	var home3 := row3.global_position
	for c: Array in cases:
		await _reset()
		var v := _new_vortex()
		v.global_position = EMPTY
		(v.get_node("FireVortex") as FireVortex).catch_radius_scale = c[0]
		row3.global_position = Vector3(EMPTY.x + c[1], 0.0, EMPTY.z)
		row3.velocity = Vector3.ZERO
		await _f(4)
		_burn("EnemyRow3").ignite(_p)
		_perform(v)
		await _wait(0.4)
		var lit := (v.get_node("FireVortex") as FireVortex).is_lit()
		var tc := "TC13" if c[0] == 1.25 and c[2] else ("TC14" if c[0] == 1.25 else "TC15")
		_check(lit == c[2], "%s: hệ số %.2f, quái cháy cách tâm %.1f m -> %s" % [tc, c[0], c[1], "bốc lửa" if lit else "không bốc lửa"])
		await _finish(v)
	row3.global_position = home3


func _tc16_idle_vortex() -> void:
	await _reset()
	var v := _new_vortex()
	v.global_position = EMPTY
	await _f(4)
	# Một vùng lửa tự đứng chạm vào hố lúc hố CHƯA hút (đang nằm trong pool)
	var igniter := IgniterArea.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	igniter.add_child(shape)
	_lv.add_child(igniter)
	igniter.global_position = EMPTY
	igniter.activate()
	await _f(6)
	var fv := v.get_node("FireVortex") as FireVortex
	var self_burnable := fv.get_node("SelfBurnable") as BurnableComponent
	_check(not fv.is_lit() and not self_burnable.is_burning(), "TC16: hố chưa hút bị lửa chạm -> không bốc lửa, vùng nhận lửa của hố đang tắt")
	igniter.queue_free()
	v.queue_free()
	await _f(2)


func _tc17_tc18_pooled_vortex() -> void:
	var wind_effect := (load("res://resources/combat/fusion/wind/bow_wind.tres") as FusionData).effects[0]
	var fire_burst := (load("res://resources/combat/fusion/fire/bow_fire.tres") as FusionData).effects[0] as IgniteOnImpactEffect
	for source: String in ["Q", "Cung Lửa"]:
		await _reset()
		await _wait(1.5)
		_p.teleport(EMPTY + Vector3(0, -0.3, 3.5), Vector3.FORWARD)
		await _f(8)
		# Hố nở từ pool của chính Player, đúng đường đi của mũi tên Cung Gió trúng đích
		wind_effect.on_projectile_impact(_p, EMPTY, Vector3.FORWARD)
		var v: WindVortex = null
		for n: Node in _p.find_children("*", "WindVortex", true, false):
			if n.is_physics_processing():
				v = n as WindVortex
		_check(v != null and _p.is_ancestor_of(v), "TC17/18: hố lấy từ pool nằm dưới Player")
		if v == null:
			continue
		if source == "Q":
			_p.energy.set_current(_p.energy.get_max())
			Input.action_press(&"skill_fire")
			await _f(1)
			_p.face_instantly(Vector3.FORWARD)
			await _f(1)
			Input.action_release(&"skill_fire")
			await _wait(0.5)
		else:
			fire_burst.on_projectile_impact(_p, EMPTY + Vector3(1.0, 0, 0), Vector3.FORWARD)
			await _wait(0.3)
		var lit := (v.get_node("FireVortex") as FireVortex).is_lit()
		_check(lit, "%s: hố từ pool dưới Player, nguồn lửa %s chạm vào -> bốc lửa (lit=%s)" % ["TC17" if source == "Q" else "TC18", source, lit])
		await _wait(v.lifetime + v.linger + 0.3)


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
