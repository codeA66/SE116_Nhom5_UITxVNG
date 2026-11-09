extends Node
## Lồng sinh quái phòng 4 → sách Phun lửa (va chạm, input và node thật):
## 1. Chưa vào phòng 4: chưa có quái, sách chưa hiện.
## 2. Vào phòng: lồng sinh quái đều, không vượt max_alive; ra khỏi phòng thì ngừng sinh.
## 3. Chém lồng bằng kiếm (bấm attack thật) tới vỡ: ngừng sinh, sách vẫn chưa hiện khi còn quái.
## 4. Hạ hết quái: lưu cờ, sách hiện, bấm interact nhặt được Phun lửa.
## 5. Thông số lệch / cực đoan trên lồng thử riêng: spawn_interval rất nhỏ + max_alive 1,
##    spawn_interval rất lớn + max_alive 50, vùng hoạt động hẹp dài không vuông.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/spawner_cage_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const CAGE_SCENE: PackedScene = preload("res://objects/combat/spawner_cage/spawner_cage.tscn")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	var cage: SpawnerCage = _level.get_node("Room4SpawnerCage") as SpawnerCage
	var reveal: FlagReveal = _level.get_node("Pickups/Room4BookReveal") as FlagReveal
	# 1. Ngoài phòng 4
	_player.teleport(Vector3(62, 4.4, 40))
	await _frames(30)
	_check(cage.alive_count() == 0 and reveal.get_child_count() == 0, "chưa vào phòng 4: chưa có quái, sách chưa hiện")
	# 2. Vào phòng: con đầu ra ngay, sau 2 chu kỳ đủ 3 con, chờ thêm vẫn 3
	_player.teleport(Vector3(68, 8.4, 16))
	await _frames(10)
	_check(cage.alive_count() == 1, "vào phòng: lồng sinh con đầu ngay (%d)" % cage.alive_count())
	await _seconds(cage.spawn_interval * 2.0 + 0.3)
	_check(cage.alive_count() == 3, "sau 2 chu kỳ: 3 con (%d)" % cage.alive_count())
	await _seconds(cage.spawn_interval * 2.0)
	_check(cage.alive_count() == 3, "đủ max_alive thì không sinh thêm (%d)" % cage.alive_count())
	await _capture("cage_room4_active.png")
	# Hạ 1 con rồi ra khỏi phòng: không sinh bù
	_kill(_enemies(cage).slice(0, 1))
	await _frames(5)
	_player.teleport(Vector3(62, 4.4, 40))
	await _seconds(cage.spawn_interval + 0.5)
	_check(cage.alive_count() == 2, "ra khỏi phòng: ngừng sinh (%d)" % cage.alive_count())
	# 3. Chém lồng bằng kiếm thật. Hạ quái trước cho soft lock không kéo đòn sang quái
	_player.equip_weapon(load("res://resources/combat/weapons/sword.tres") as WeaponData)
	_kill(_enemies(cage))
	await _frames(5)
	var dir: Vector3 = Vector3(0, 0, -1)
	_player.teleport(cage.global_position - dir * 1.7 + Vector3(0, 0.1, 0), dir)
	await _frames(5)
	var hp: HealthComponent = cage.get_node("HealthComponent")
	var start_hp: int = hp.current_health
	var t: float = 0.0
	while not cage.is_broken and t < 25.0:
		_player.energy.set_current(_player.energy.get_max())
		_player.teleport(cage.global_position - dir * 1.7 + Vector3(0, 0.1, 0), dir)
		# Chạy có cửa sổ (để chụp ảnh) thì đòn đánh nhắm theo chuột: đặt chuột lên lồng
		if DisplayServer.get_name() != "headless":
			get_viewport().warp_mouse(get_viewport().get_camera_3d().unproject_position(cage.global_position + Vector3(0, 1.0, 0)))
		await _press(&"attack")
		await _seconds(0.35)
		t += 0.4
	_check(cage.is_broken, "chém lồng bằng kiếm: lồng vỡ (máu %d → %d, %.1f s)" % [start_hp, hp.current_health, t])
	_check(not cage.is_cleared and reveal.get_child_count() == 0 or cage.alive_count() == 0, "lồng vỡ khi còn quái thì chưa xong")
	await _seconds(cage.spawn_interval + 0.5)
	_check(_enemies(cage).size() == cage.alive_count() and not cage.get_node("ActiveArea").monitoring, "lồng vỡ: không sinh thêm")
	_kill(_enemies(cage))
	await _frames(30)
	# 4. Sách hiện, nhặt được
	_check(cage.is_cleared and GameState.has_flag(cage.persistent_id) and reveal.get_child_count() == 1, "hạ hết quái: lưu cờ, sách hiện")
	var book: Node3D = reveal.get_node_or_null("FlameBreathBook") as Node3D
	if book:
		_player.teleport(book.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
		await _frames(15)
		await _capture("cage_book_revealed.png")
		await _press(&"interact")
		t = 0.0
		while not _player.has_ability(&"flame_breath") and t < 8.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
	_check(_player.has_ability(&"flame_breath"), "nhặt sách sau khi phá lồng → có Phun lửa (%.1f s, điều khiển %s)" % [t, _player.controls_enabled])
	# Bảng nhận kỹ năng giữ khóa điều khiển tới khi đóng: đóng bằng API public close_reveal()
	var acquire: Node = book.get_node_or_null("AbilityAcquireVfx") if is_instance_valid(book) else null
	t = 0.0
	while not _player.controls_enabled and t < 10.0:
		if is_instance_valid(acquire):
			acquire.call(&"close_reveal")
		await _frames(10)
		t += 10.0 / 60.0
	# 5. Thông số cực đoan
	await _extreme(0.1, 1, Vector3(14, 4, 18), 2.0, 1, "interval 0.1 s, max 1")
	await _extreme(60.0, 50, Vector3(14, 4, 18), 2.0, 1, "interval 60 s, max 50")
	await _extreme(0.5, 50, Vector3(1.0, 4, 30), 1.6, 4, "vùng hẹp dài 1 × 30 m, interval 0.5 s")
	print("SPAWNER CAGE RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


## Lồng thử riêng đặt ở phòng 4 (đã dọn); player đứng mép vùng theo trục dài để kiểm vùng không vuông
func _extreme(interval: float, max_alive: int, area: Vector3, wait: float, expect: int, what: String) -> void:
	var c: SpawnerCage = CAGE_SCENE.instantiate() as SpawnerCage
	c.enemy_scene = load("res://entities/enemies/palace/enemy_1/enemy_1.tscn")
	c.spawn_interval = interval
	c.max_alive = max_alive
	c.active_area_size = area
	_level.add_child(c)
	c.global_position = Vector3(72, 8.32, 4)
	_player.teleport(Vector3(70, 4.4, 40))
	await _frames(5)
	_player.teleport(c.global_position + Vector3(0, 0.1, area.z * 0.5 - 0.5))
	await _seconds(wait)
	var n: int = c.alive_count()
	_check(n == expect, "%s: %d con sau %.1f s (mong %d)" % [what, n, wait, expect])
	_kill(_enemies(c))
	c.queue_free()
	_player.teleport(Vector3(62, 4.4, 40))
	await _frames(30)


func _enemies(c: SpawnerCage) -> Array[Node]:
	return c.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n is Enemy and not (n as Enemy).is_dead())


func _kill(list: Array) -> void:
	for e: Node in list:
		(e as Enemy).health.take_damage(9999)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
