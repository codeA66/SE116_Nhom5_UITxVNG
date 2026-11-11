extends Node
## Test cụm 3 tier 2 map Lửa (phòng 07 tối om + đốm lửa của Cung Lửa) bằng phím, va chạm và node thật:
## 1. Cung Lửa (ghép Lửa vào cung thật): bắn tên thật, chỗ tên cắm còn đốm lửa sáng; sáng ~life giây rồi tắt, trả về pool.
##    Cung chưa ghép Lửa: không có đốm. Cực đoan: sáng 0,5 s (không tắt dần) / 60 s.
## 2. Phòng tối: vào phòng thì nắng tắt hẳn (DarkZone), ra thì sáng lại.
## 3. Hình nộm ở bệ vào: chém thật +năng lượng; mỗi phát cung tốn năng lượng (năng lượng = số tên).
## 4. Đường ô sàn sụp: đi bộ thật hết đường tới bệ cuối; ô đã đi qua rơi và 6 s sau vẫn không hiện lại.
## 5. Lõi đông + cổng: cổng về Hub tắt khi chưa có lõi; nhặt lõi thì mở, bước vào sang Hub.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/blackout/blackout_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const BOW_FIRE: FusionData = preload("res://resources/combat/fusion/fire/bow_fire.tres")
const BOW_SLOT := WeaponData.Slot.BOW

var _player: Player
var _level: ZoneRoot
var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.boss_defeated")
	GameState.unlock_ability(FLAME_BREATH)
	_level = LEVEL.instantiate()
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await _frames(30)
	_player.health.max_health = 9999
	_player.health.heal_full()
	await _t_ember()
	await _t_ember_extremes()
	await _t_dark()
	await _t_dummy_energy()
	await _t_path()
	await _t_core_portal()
	print("BLACKOUT RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


# ---------- 1. Đốm lửa của Cung Lửa ----------

func _t_ember() -> void:
	# Chưa ghép: không có đốm
	GameState.unfuse(BOW_SLOT)
	# Bắn thẳng vào tường cao phía bắc phòng 01 (tên phải cắm vào đâu đó mới có điểm trúng; phòng 02 có búa nện)
	_teleport(Vector3(208, 4.42, 52), Vector3.FORWARD)
	await _frames(10)
	await _shoot()
	await _frames(60)
	_check(_lit_embers().is_empty(), "cung thường (chưa ghép Lửa): tên cắm không để lại đốm lửa")
	_check(GameState.fuse(&"fire", BOW_SLOT), "ghép Lửa vào cung")
	await _frames(5)
	await _shoot()
	await _frames(60)
	var lit := _lit_embers()
	_check(lit.size() == 1, "Cung Lửa: tên cắm để lại 1 đốm lửa đang sáng (%d)" % lit.size())
	if lit.is_empty():
		return
	var ember: EmberLight = lit[0]
	var effect := _ember_effect()
	# Đếm theo frame vật lý (thời gian game)
	var frames := 60
	while ember.is_lit() and frames < 60 * 30:
		await get_tree().physics_frame
		frames += 1
	var took := frames / float(Engine.physics_ticks_per_second)
	_check(absf(took - effect.life) < 0.6, "đốm lửa sáng %.1f s rồi tắt (đặt %.1f s, gồm %.1f s tắt dần)" % [took, effect.life, effect.fade_time])
	await _frames(5)
	_check(not ember.visible, "tắt hẳn: đốm ẩn, trả về pool")


func _t_ember_extremes() -> void:
	var effect := _ember_effect()
	var life0 := effect.life
	var fade0 := effect.fade_time
	for c: Array in [[0.5, 0.0], [60.0, 3.0]]:
		effect.life = c[0]
		effect.fade_time = c[1]
		await _shoot()
		var lit := _lit_embers()
		var frames := 0
		while lit.is_empty() and frames < 120:
			await get_tree().physics_frame
			frames += 1
			lit = _lit_embers()
		var ember: EmberLight = lit[0] if not lit.is_empty() else null
		var start := frames
		while ember and ember.is_lit() and frames < 60 * 70:
			await get_tree().physics_frame
			frames += 1
		var took := (frames - start) / float(Engine.physics_ticks_per_second)
		_check(ember != null and absf(took - float(c[0])) < 0.7, "đốm sáng %.1f s (tắt dần %.1f s): đo %.1f s" % [c[0], c[1], took])
	effect.life = life0
	effect.fade_time = fade0


# ---------- 2. Phòng tối ----------

func _t_dark() -> void:
	var sun := _level.get_node(^"FireLighting/SunLight") as DirectionalLight3D
	_teleport(Vector3(318, 4.42, 50), Vector3.RIGHT)
	await _frames(90)
	var outside := sun.light_energy
	_teleport(Vector3(330, 4.42, 50), Vector3.RIGHT)
	await _frames(90)
	var inside := sun.light_energy
	_teleport(Vector3(318, 4.42, 50), Vector3.RIGHT)
	await _frames(90)
	var back := sun.light_energy
	_check(outside > 0.1 and inside < outside * 0.05 and absf(back - outside) < 0.05,
			"phòng 07 tối hẳn: nắng %.2f → %.2f trong phòng → %.2f khi ra" % [outside, inside, back])


# ---------- 3. Hình nộm nạp năng lượng ----------

func _t_dummy_energy() -> void:
	var dummy := _level.get_node(^"Tier2Mechanics/Room07Blackout/TrainingDummy") as Node3D
	_player.energy.set_current(0)
	_teleport(dummy.global_position + Vector3(0, 0.1, 1.4), Vector3.FORWARD)
	await _frames(15)
	for _i: int in range(4):
		await _tap(&"attack")
		await _frames(24)
	var gained := _player.energy.current
	_check(gained >= 2, "chém hình nộm ở bệ vào: +%d năng lượng" % gained)
	var bow := GameState.get_weapon_in_slot(BOW_SLOT)
	_teleport(Vector3(330, 4.42, 50), Vector3.RIGHT)
	await _frames(10)
	var before := _player.energy.current
	await _shoot(false)
	await _frames(10)
	_check(before - _player.energy.current == bow.energy_cost, "mỗi phát cung tốn %d năng lượng (%d → %d)" % [bow.energy_cost, before, _player.energy.current])


# ---------- 4. Đường ô sàn sụp ----------

func _t_path() -> void:
	var tiles := _level.get_node(^"Tier2Mechanics/Room07Blackout/Path").get_children()
	var fell := {"n": 0}
	for t: Node in tiles:
		(t as CrumblingFloor).crumbled.connect(func() -> void: fell["n"] = int(fell["n"]) + 1)
	_teleport(Vector3(330, 4.42, 50), Vector3.RIGHT)
	await _frames(20)
	var route: Array[Vector3] = [Vector3(333, 4.32, 50), Vector3(339, 4.32, 50), Vector3(339, 4.32, 56), Vector3(345, 4.32, 56), Vector3(345, 4.32, 42), Vector3(350, 4.32, 41)]
	var ok := true
	for p: Vector3 in route:
		ok = ok and await _run_to(p, 240)
		if _player.global_position.y < 3.0:
			ok = false
			break
	_check(ok and _player.global_position.y > 4.0, "đi bộ hết đường ô sàn sụp tới bệ cuối (%s)" % _player.global_position.snapped(Vector3.ONE * 0.1))
	await _frames(int(6.0 * 60))
	var restored := 0
	for t: Node in tiles:
		if (t.get_node("CollisionShape3D") as CollisionShape3D).disabled == false:
			restored += 1
	_check(int(fell["n"]) >= tiles.size() - 1 and restored <= 1, "ô đã đi qua rơi hẳn: %d / %d ô rơi, 6 s sau %d ô còn va chạm" % [fell["n"], tiles.size(), restored])


# ---------- 5. Mảnh vỡ Đông + cổng về Hub ----------

func _t_core_portal() -> void:
	var portal := _level.get_node(^"Tier2Mechanics/Room07Blackout/Portals/BlackoutReturnPortal") as WarpPortal
	_check(not portal.is_active(), "chưa nhặt mảnh vỡ Đông: cổng về Hub tắt")
	# Nhặt mảnh đo bằng đi bộ thật ở skills_checkpoints_test: ở đây chỉ đặt cờ mảnh như lúc nhặt xong
	GameState.set_flag(&"level_3.t2_shard_east")
	await _frames(60)
	_check(portal.is_active(), "nhặt mảnh vỡ Đông: cổng về Hub mở")
	_teleport(portal.get_arrival().global_position + Vector3(0, 0.3, 0), Vector3.ZERO)
	await _frames(15)
	for _i: int in range(120):
		var to := portal.global_position - _player.global_position
		to.y = 0.0
		if to.length() < 0.3 or _player.global_position.x < 300.0:
			break
		_press_towards(to.normalized())
		await get_tree().physics_frame
	_release()
	await _wait_until(func() -> bool: return _player.global_position.x < 300.0, 180)
	await _frames(30)
	var pos := _player.global_position
	_check(pos.x > 264.0 and pos.x < 292.0 and pos.z > 36.0 and pos.z < 64.0 and _player.is_on_floor(), "bước vào cổng: về Hub (%s)" % pos.snapped(Vector3.ONE * 0.1))


# ---------- Tiện ích ----------

## Giữ ngắm rồi nhả (bắn một phát) theo hướng đang quay; nạp đầy năng lượng trước nếu refill
func _shoot(refill: bool = true) -> void:
	if refill:
		_player.energy.set_current(_player.energy.get_max())
	Input.action_press(&"aim")
	await _frames(54)
	Input.action_release(&"aim")
	await _frames(2)


func _ember_effect() -> LightOnImpactEffect:
	for e: FusionEffect in BOW_FIRE.effects:
		if e is LightOnImpactEffect:
			return e as LightOnImpactEffect
	return null


func _lit_embers() -> Array:
	# find_children chỉ lọc theo lớp gốc của Godot, không theo class_name: lọc bằng "is"
	return _player.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is EmberLight and (n as EmberLight).is_lit())


func _run_to(target: Vector3, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		var pos := _player.global_position
		var flat := Vector2(target.x - pos.x, target.z - pos.z)
		if flat.length() <= 0.5:
			_release()
			return true
		if pos.y < target.y - 2.0:
			_release()
			return false
		_press_towards(Vector3(flat.x, 0, flat.y).normalized())
		await get_tree().physics_frame
	_release()
	return false


func _teleport(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_set_axis(&"move_right", &"move_left", world_dir.dot(right))
	_set_axis(&"move_back", &"move_forward", -world_dir.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"aim", &"attack"]:
		Input.action_release(a)


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for _i: int in range(max_frames):
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
