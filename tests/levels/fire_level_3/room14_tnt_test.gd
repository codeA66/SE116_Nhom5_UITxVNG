extends Node
## Kiểm tra phòng 14 + vật phẩm TNT (chọn dùng, phím T, nhắm bằng con trỏ), đo bằng va chạm, phím thật và máu thật:
## 1. Lối Hub → 14 đã chặn (đi bộ vào không qua được); checkpoint trước phòng boss có mặt.
## 2. Phòng 14: 2 lồng sinh quái, rương ẩn; phá 1 lồng chưa hiện rương, phá cả 2 + hạ quái thì rương TNT hiện.
## 3. Mở rương, nhặt TNT: có trong túi và tự chọn dùng; player có QuickItemUser gắn lúc chạy (không sửa player).
## 4. Giữ T: hiện vòng tầm 3 m + dấu; thả T: đặt khối ở chỗ dấu, không chém / phun lửa.
##    Có cửa sổ (chuột thật): con trỏ trong tầm -> đặt đúng chỗ con trỏ; ngoài tầm -> mép tầm 3 m theo hướng con trỏ;
##    con trỏ trùng nhân vật -> đẩy ra min_range. Headless (không có chuột): đặt trước mặt default_distance.
## 5. Phun lửa vào khối: ngòi cháy rồi nổ, quái trong vùng mất máu, khối ẩn. Đặt lại dùng lại đúng khối đó.
## 6. Đứng sát khối khi nổ: player cũng mất máu. Giá trị cực đoan của khối (ngòi 0 s, bán kính 0,5 / 12 m).
## 7. Bỏ chọn: T không làm gì; giữ T rồi mất điều khiển: huỷ, không đặt; lưu / đọc save giữ vật phẩm đang dùng.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room14_tnt_test.tscn
## (bỏ --headless thêm -- --capture để đo phần con trỏ và chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const ENEMY: PackedScene = preload("res://entities/enemies/palace/enemy_1/enemy_1.tscn")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const TNT: QuickItemData = preload("res://resources/player/items/tools/tnt.tres")

var _level: Node
var _player: Player
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	# Cổng phòng boss mở sau thử thách cuối (đo riêng ở final_trial_test): coi như đã qua
	GameState.set_flag(&"level_3.boss_gate")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	var hurtbox: HurtboxComponent = _player.get_node("HurtboxComponent") as HurtboxComponent
	hurtbox.invulnerable = true
	# 1. Lối Hub → 14 chặn; checkpoint trước boss
	await _walk_from(Vector3(134, 4.4, 56), Vector3(134, 4, 68))
	_check(_player.global_position.z < 61.0, "lối Hub → phòng 14 đã chặn (z = %.2f)" % _player.global_position.z)
	var boss_cp: Node3D = _level.get_node_or_null("BossCheckpoint") as Node3D
	_check(boss_cp != null and boss_cp.global_position.distance_to(Vector3(142, 4.32, 45.6)) < 0.1, "có checkpoint trước phòng boss")
	await _walk_from(Vector3(130, 4.4, 50), Vector3(150, 4, 50))
	_check(_player.global_position.x > 147.0, "đi thẳng qua làn z 50 cạnh checkpoint vào phòng boss (x = %.1f)" % _player.global_position.x)
	# 2. Phòng 14
	var west: SpawnerCage = _level.get_node("Room14/Room14CageWest") as SpawnerCage
	var east: SpawnerCage = _level.get_node("Room14/Room14CageEast") as SpawnerCage
	var reveal: FlagReveal = _level.get_node("Room14/Room14ChestReveal") as FlagReveal
	_check(reveal.get_child_count() == 0, "rương phòng 14 ẩn")
	_player.teleport(Vector3(146, 4.4, 77))
	await _frames(20)
	_check(west.alive_count() >= 1 and east.alive_count() >= 1, "vào phòng 14: cả 2 lồng sinh quái (%d, %d)" % [west.alive_count(), east.alive_count()])
	await _capture("room14_cages.png")
	await _clear_cage(west)
	_check(west.is_cleared and reveal.get_child_count() == 0, "dọn 1 lồng: rương vẫn ẩn")
	await _clear_cage(east)
	_check(east.is_cleared and reveal.get_child_count() == 1, "dọn cả 2 lồng: rương TNT hiện")
	# 3. Mở rương, nhặt TNT
	var chest: AbilityChest = reveal.get_node("TntChest") as AbilityChest
	var reward: Node3D = chest.get_node("Reward") as Node3D
	_player.teleport(chest.global_position + Vector3(0, 0.1, 1.3), Vector3.FORWARD)
	await _frames(15)
	await _press(&"interact")
	await _frames(70)
	_check(chest.is_opened and reward.visible, "bấm interact: rương mở, TNT bay lên")
	await _press(&"interact")
	await _frames(20)
	_check(GameState.get_item_count(TNT) == 1 and GameState.get_selected_item() == TNT, "nhặt TNT: có trong túi, tự chọn dùng")
	var user: QuickItemUser = _player.get_node_or_null("QuickItemUser") as QuickItemUser
	_check(user != null and _player.controls_enabled, "player có QuickItemUser gắn lúc chạy, không mở hộp thoại nào")
	if user == null:
		_finish()
		return
	# 4. Giữ T nhắm, thả T đặt
	GameState.unlock_ability(FLAME_BREATH)
	_player.energy.set_current(_player.energy.get_max())
	var spot: Vector3 = Vector3(142, 4.4, 74)
	_player.teleport(spot, Vector3.FORWARD)
	await _frames(15)
	var feet: Vector3 = _player.global_position
	var states: Array[StringName] = []
	var watch := func(_from: StringName, to: StringName) -> void: states.append(to)
	_player.state_machine.state_changed.connect(watch)
	await _aim_mouse_at(feet + Vector3(0, 0, -2.0))
	await _key_t(true)
	await _frames(4)
	var indicator: AimIndicator = user.get_indicator(TNT.id)
	_check(user.aiming == TNT and indicator != null and indicator.visible and is_equal_approx(indicator.get_node("Ring").scale.x, TNT.aim_range), "giữ T: hiện vòng tầm %.1f m + dấu" % TNT.aim_range)
	await _capture("tnt_aim.png")
	await _key_t(false)
	await _frames(20)
	_player.state_machine.state_changed.disconnect(watch)
	var blocks: Array[Node] = _level.find_children("*", "TntBlock", true, false)
	var block: TntBlock = blocks.front() as TntBlock if blocks.size() == 1 else null
	_check(block != null and block.phase == TntBlock.Phase.ARMED and not indicator.visible, "thả T: có 1 khối TNT trên sàn, dấu ẩn (%d khối)" % blocks.size())
	_check(not states.has(&"Attack") and not states.has(&"FlameBreath"), "T không chém / không phun lửa (%s)" % ", ".join(states))
	if block == null:
		_finish()
		return
	var expected: Vector3 = feet + Vector3(0, 0, -2.0) if _has_mouse() else feet + _flat(_player.get_facing_direction()) * TNT.default_distance
	_check(_flat_distance(block.global_position, expected) < 0.35 and absf(block.global_position.y - 4.32) < 0.15, "%s: khối đặt đúng chỗ (lệch %.2f m, y %.2f)" % ["con trỏ trong tầm 2 m" if _has_mouse() else "headless: trước mặt", _flat_distance(block.global_position, expected), block.global_position.y])
	if _has_mouse():
		# Con trỏ ngoài tầm 6 m về phía tây: đặt ở mép tầm 3 m
		await _frames(40)
		await _place_with_t(feet + Vector3(-6, 0, 0))
		var reach: float = _flat_distance(block.global_position, feet)
		var dir: Vector3 = _flat(block.global_position - feet).normalized()
		_check(absf(reach - TNT.aim_range) < 0.2 and dir.dot(Vector3.LEFT) > 0.97, "con trỏ ngoài tầm (6 m): khối ở mép tầm (%.2f m, hướng %.2f)" % [reach, dir.dot(Vector3.LEFT)])
		# Con trỏ trùng nhân vật: đẩy ra min_range
		await _frames(40)
		await _place_with_t(_player.global_position)
		reach = _flat_distance(block.global_position, _player.global_position)
		_check(absf(reach - TNT.min_range) < 0.2, "con trỏ trùng nhân vật: khối đẩy ra %.2f m (min_range %.2f)" % [reach, TNT.min_range])
		await _frames(40)
		await _place_with_t(feet + Vector3(0, 0, -2.0))
	else:
		print("SKIP con trỏ ngoài tầm / trùng nhân vật: headless không có chuột (chạy có cửa sổ để đo)")
	# 5. Quái cạnh khối; phun lửa vào khối
	var enemy: Enemy = ENEMY.instantiate() as Enemy
	_level.add_child(enemy)
	# Sau khối 2,6 m theo hướng phun: cách player 5,2 m, ngoài tầm lửa phun 4,5 m (chỉ trúng nổ), trong bán kính nổ 3 m
	enemy.global_position = block.global_position + Vector3(0, 0.1, -2.6)
	enemy.set_dormant(true)
	await _frames(10)
	var enemy_hp: int = enemy.health.current_health
	_player.teleport(block.global_position + Vector3(0, 0.1, 2.6), Vector3.FORWARD)
	await _frames(10)
	var player_hp: int = _player.health.current_health
	var lit_at: Array[float] = [-1.0]
	var boom_at: Array[float] = [-1.0]
	var clock: Array[float] = [0.0]
	block.fuse_lit.connect(func() -> void: lit_at[0] = clock[0])
	block.exploded.connect(func(_at: Vector3) -> void: boom_at[0] = clock[0])
	await _aim_mouse_at(block.global_position)
	await _press(&"skill_fire")
	while boom_at[0] < 0.0 and clock[0] < 4.0:
		await get_tree().physics_frame
		clock[0] += get_physics_process_delta_time()
		if lit_at[0] >= 0.0 and clock[0] - lit_at[0] > 0.3 and clock[0] - lit_at[0] < 0.32:
			await _capture("tnt_fuse.png")
	await _frames(3)
	await _capture("tnt_explode.png")
	_check(lit_at[0] >= 0.0, "phun lửa trúng khối: ngòi cháy (%.2f s)" % lit_at[0])
	_check(boom_at[0] > lit_at[0] and absf(boom_at[0] - lit_at[0] - block.fuse_time) < 0.1, "nổ sau ngòi %.2f s (fuse_time %.2f)" % [boom_at[0] - lit_at[0], block.fuse_time])
	await _frames(5)
	_check(enemy.health.current_health == maxi(enemy_hp - block.attack.damage, 0), "quái cách %.1f m mất %d máu (%d → %d)" % [2.6, block.attack.damage, enemy_hp, enemy.health.current_health])
	_check(block.phase == TntBlock.Phase.SPENT and not block.get_node("Visual").visible, "nổ xong: khối ẩn")
	_check(_player.health.current_health == player_hp, "player đứng ngoài vùng (2,6 m) không mất máu (%d → %d)" % [player_hp, _player.health.current_health])
	# Đặt lại: dùng lại đúng khối
	await _frames(40)
	_player.teleport(spot, Vector3.FORWARD)
	await _frames(10)
	await _place_with_t(spot + Vector3(0, 0, -1.3))
	var again: Array[Node] = _level.find_children("*", "TntBlock", true, false)
	_check(again.size() == 1 and again.front() == block and block.phase == TntBlock.Phase.ARMED, "đặt lại: vẫn 1 khối, dùng lại khối cũ")
	# 6. Đứng sát khối khi nổ: player mất máu
	hurtbox.invulnerable = false
	await _frames(5)
	_player.health.heal_full()
	var hp: int = _player.health.current_health
	_player.teleport(block.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	await _frames(10)
	_player.energy.set_current(_player.energy.get_max())
	await _aim_mouse_at(block.global_position)
	await _press(&"skill_fire")
	var t: float = 0.0
	while block.phase != TntBlock.Phase.SPENT and t < 4.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _frames(5)
	# Player mất đúng 1 máu mỗi đòn (HurtboxComponent.fixed_damage_per_hit = 1 của player), không theo damage của nổ
	_check(_player.health.current_health == hp - 1, "đứng sát khối (1,2 m) khi nổ: player trúng nổ (%d → %d)" % [hp, _player.health.current_health])
	hurtbox.invulnerable = true
	# Giá trị cực đoan: ngòi 0 s nổ ngay lúc bắt lửa; bán kính 0,5 m không trúng quái cách 2,6 m; bán kính 12 m trúng quái cách 10 m
	var near: Enemy = _spawn_enemy(block.global_position + Vector3(0, 0.1, -2.6))
	var far: Enemy = _spawn_enemy(block.global_position + Vector3(-10, 0.1, 0))
	await _frames(10)
	var near_hp: int = near.health.current_health
	var far_hp: int = far.health.current_health
	block.fuse_time = 0.0
	block.radius = 0.5
	block.place(block.global_position, 0.0, _player)
	block.get_node("BurnableComponent").ignite(_player)
	_check(block.phase == TntBlock.Phase.SPENT and near.health.current_health == near_hp, "ngòi 0 s: nổ ngay; bán kính 0,5 m: quái cách 2,6 m không mất máu (%d → %d)" % [near_hp, near.health.current_health])
	await _frames(5)
	block.radius = 12.0
	block.place(block.global_position, 0.0, _player)
	block.get_node("BurnableComponent").ignite(_player)
	await _frames(3)
	_check(far.health.current_health == maxi(far_hp - block.attack.damage, 0), "bán kính 12 m: quái cách 10 m mất máu (%d → %d)" % [far_hp, far.health.current_health])
	block.fuse_time = 0.6
	block.radius = 3.0
	# 7. Bỏ chọn / huỷ nhắm / lưu
	await _frames(40)
	var before: Vector3 = block.global_position
	GameState.select_item(&"")
	await _place_with_t(Vector3(138, 4.32, 72))
	_check(block.global_position.distance_to(before) < 0.01 and block.phase == TntBlock.Phase.SPENT, "bỏ chọn TNT: bấm T không đặt")
	GameState.select_item(TNT.id)
	_player.teleport(Vector3(138, 4.4, 74), Vector3.FORWARD)
	await _frames(40)
	await _key_t(true)
	await _frames(4)
	_player.set_controls_enabled(false)
	await _frames(4)
	_check(user.aiming == null and not indicator.visible, "giữ T rồi mất điều khiển: huỷ nhắm, dấu ẩn")
	await _key_t(false)
	await _frames(10)
	_player.set_controls_enabled(true)
	_check(block.phase == TntBlock.Phase.SPENT, "thả T sau khi huỷ: không đặt")
	var data: Dictionary = SaveManager.to_dict(GameState.progress)
	var loaded: PlayerProgress = SaveManager.from_dict(JSON.parse_string(JSON.stringify(data)))
	_check(loaded.selected_item == TNT.id, "lưu / đọc save giữ TNT đang dùng")
	var junk: PlayerProgress = SaveManager.from_dict({"selected_item": "khong_co"})
	_check(junk.selected_item.is_empty(), "save sửa tay (vật phẩm lạ): bỏ qua")
	_check(not GameState.select_item(&"energy_stone"), "không chọn dùng được vật phẩm không phải dùng phím (đá năng lượng)")
	_finish()


func _finish() -> void:
	print("ROOM14 TNT RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _spawn_enemy(at: Vector3) -> Enemy:
	var e: Enemy = ENEMY.instantiate() as Enemy
	_level.add_child(e)
	e.global_position = at
	e.set_dormant(true)
	return e


func _clear_cage(cage: SpawnerCage) -> void:
	(cage.get_node("HealthComponent") as HealthComponent).take_damage(999)
	await _frames(5)
	for e: Node in cage.get_node("Enemies").get_children():
		if e is Enemy and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)
	await _frames(30)


## Chạy có cửa sổ thì kỹ năng nhắm theo chuột: đưa chuột tới điểm cần nhắm (headless không có chuột, dùng hướng quay)
func _aim_mouse_at(world: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(world))


## Giữ / thả phím T thật (InputEventKey qua Input.parse_input_event, đi tới _unhandled_input như người chơi bấm)
func _key_t(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	event.keycode = KEY_T
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frames(2)


## Đưa chuột tới world (có cửa sổ), giữ T vài khung rồi thả
func _place_with_t(world: Vector3) -> void:
	await _aim_mouse_at(world)
	await _key_t(true)
	await _frames(4)
	await _aim_mouse_at(world)
	await _frames(2)
	await _key_t(false)
	await _frames(10)


func _has_mouse() -> bool:
	return DisplayServer.get_name() != "headless"


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return _flat(a - b).length()


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## Gửi phím qua sự kiện thật (hộp thoại đọc _unhandled_input, không thấy Input.action_press)
func _tap(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(3)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(6)


func _walk_from(start: Vector3, target: Vector3) -> void:
	_player.teleport(start)
	await _frames(10)
	var t: float = 0.0
	while t < 6.0:
		var flat: Vector2 = Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if flat.length() < 0.6:
			break
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var d: Vector3 = Vector3(flat.x, 0.0, flat.y).normalized()
		_axis(&"move_right", &"move_left", d.dot(right))
		_axis(&"move_back", &"move_forward", -d.dot(forward))
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)
