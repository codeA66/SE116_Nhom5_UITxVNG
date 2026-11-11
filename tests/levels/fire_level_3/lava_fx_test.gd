extends Node
## Hiệu ứng lava (va chạm và node thật):
## 1. Bước vào LavaZone: splash bắn đúng một lần, xong thì nhả về pool.
## 2. Bước vào lần nữa: dùng lại slot cũ, pool không tạo thêm node.
## 3. Có Giày Dung Nham (miễn nhiễm): không bắn splash.
## 4. Rơi xuống biển lava (AbyssKillZone): splash bắn ở mặt dung nham ngay dưới chỗ rơi.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/lava_fx_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const LAVA_ZONE: PackedScene = preload("res://objects/combat/hazards/lava_zone/lava_zone.tscn")
const LAVA_BOOTS: AbilityData = preload("res://abilities/lava_boots/lava_boots.tres")

var _player: Player
var _level: Node
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.bridge_guards")
	_level = LEVEL.instantiate()
	(_level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	await _capture("lava_surface.png")
	# 1. Bước vào LavaZone
	var zone: LavaZone = LAVA_ZONE.instantiate() as LavaZone
	var home: Vector3 = _player.global_position
	_level.add_child(zone)
	zone.global_position = home + Vector3(0, 1.0, 0)
	var pool: ObjectPool = await _wait_pool(zone)
	_check(pool != null and pool.get_active_count() == 1, "bước vào LavaZone: splash bắn 1 lần (đang chạy %d)" % (pool.get_active_count() if pool else -1))
	var splash: LavaSplash = pool.get_active()[0] as LavaSplash
	_check(splash.global_position.distance_to(_player.global_position) < 0.6 and splash.get_node("Flash").visible, "splash đúng chỗ chân và đèn chớp bật")
	await _frames(8)
	await _capture("lava_splash_zone.png")
	await _frames(120)
	_check(pool.get_active_count() == 0 and not splash.get_node("Flash").visible, "xong: nhả về pool, đèn tắt")
	# 2. Bước vào lần nữa: dùng lại slot
	_player.teleport(home + Vector3(5, 0.1, 0))
	await _frames(20)
	_player.teleport(home + Vector3(0, 0.1, 0))
	await _frames(15)
	_check(pool.get_active_count() == 1 and pool.get_total_created() == 2, "vào lại: dùng lại slot cũ (đang chạy %d, đã tạo %d)" % [pool.get_active_count(), pool.get_total_created()])
	await _frames(140)
	# 3. Có giày: không bắn
	GameState.unlock_ability(LAVA_BOOTS)
	_player.teleport(home + Vector3(5, 0.1, 0))
	await _frames(20)
	_player.teleport(home + Vector3(0, 0.1, 0))
	await _frames(15)
	_check(_player.has_ability(&"lava_boots") and pool.get_active_count() == 0, "có Giày Dung Nham: không bắn splash")
	# 4. Rơi xuống biển lava
	var abyss: KillZone = _level.get_node("AbyssKillZone") as KillZone
	_player.teleport(Vector3(home.x, abyss.global_position.y + 0.8, home.z))
	await _frames(6)
	var abyss_pool: ObjectPool = _find_pool(abyss)
	_check(abyss_pool != null and abyss_pool.get_active_count() == 1, "rơi xuống biển lava: splash bắn")
	if abyss_pool and abyss_pool.get_active_count() > 0:
		var s: Node3D = abyss_pool.get_active()[0] as Node3D
		_check(absf(s.global_position.y - (abyss.global_position.y + abyss.splash_y_offset)) < 0.01 and absf(s.global_position.x - home.x) < 0.7, "splash nằm ở mặt dung nham (y = %.2f)" % s.global_position.y)
		await _frames(4)
		await _capture("lava_splash_abyss.png")
	print("LAVA FX RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


## Pool của SplashPoolComponent con của node (tạo lười ở lần phát đầu)
func _find_pool(host: Node) -> ObjectPool:
	for c: Node in host.get_children():
		if c is SplashPoolComponent:
			return (c as SplashPoolComponent).get_pool()
	return null


func _wait_pool(host: Node) -> ObjectPool:
	for _i: int in range(30):
		await get_tree().physics_frame
		var p: ObjectPool = _find_pool(host)
		if p != null:
			return p
	return null


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
