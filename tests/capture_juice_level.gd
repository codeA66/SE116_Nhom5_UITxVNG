extends Node
## Chụp hiệu ứng chiến đấu bằng camera game thật trong Level 1, trên nền tối (cỏ) và nền sáng (cao nguyên sách).
## Mỗi bộ chụp ở các khung 0, 2, 5, 10, 20 frame sau lúc xảy ra (kể cả trong hitstop).
## Chạy có cửa sổ: godot --path . --fixed-fps 60 --resolution 1280x720 res://tests/capture_juice_level.tscn
## SHOT_DIR = thư mục lưu ảnh; APPDATA/LOCALAPPDATA nên trỏ vào .godot/...

const LEVEL_SCENE: PackedScene = preload("res://levels/zone_1_wind/level_1/level_1.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/enemy_1/enemy_1.tscn")
const SLASH_1: AttackData = preload("res://resources/attacks/sword_slash_1.tres")
const SLASH_3: AttackData = preload("res://resources/attacks/sword_slash_3.tres")
## Khung chụp (frame 60 Hz sau sự kiện)
const FRAMES: Array[int] = [0, 2, 5, 10, 20]
## Chỗ chụp: [tên, vị trí player]; nền tối = cỏ ở Start, nền sáng = sân cao nguyên sách
const SPOTS: Array = [["dark", Vector3(0.0, 0.2, 4.0)], ["light", Vector3(33.0, 12.2, -188.0)]]
## Khoảng cách quái trước mặt player (m)
const ENEMY_DISTANCE := 1.8

var _dir: String = ""
var _player: Player
var _level: Node3D


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	GameState.replace_progress(PlayerProgress.new())
	_level = LEVEL_SCENE.instantiate() as Node3D
	add_child(_level)
	await get_tree().physics_frame
	_player = _level.get_node("Player") as Player
	# Quái trong level không được can thiệp: chỉ quái ta đặt
	for spot: Array in SPOTS:
		await _run_spot(spot[0] as String, spot[1] as Vector3)
	get_tree().quit()


func _run_spot(spot_name: String, pos: Vector3) -> void:
	_player.teleport(pos)
	_player.get_node("HurtboxComponent").set_invincible(0.0)
	await _wait(1.5)
	var forward := Vector3(0.0, 0.0, -1.0)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = pos + forward * ENEMY_DISTANCE
	_level.add_child(enemy)
	await _wait(0.3)
	enemy.health.max_health = 100
	enemy.health.heal_full()
	enemy.set_physics_process(false)
	_player.face_instantly(forward)
	var hitbox := _player.get_node("Model/Hitbox") as HitboxComponent
	var hurt := enemy.hurtbox
	# 1) Chém trúng thường rồi chém mạnh (đòn 3), có hitstop thật
	hitbox.activate(SLASH_1)
	hurt.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, forward * 5.0, _player))
	HitStop.stop(0.07)
	await _shoot("%s_hit_normal" % spot_name)
	hitbox.deactivate()
	await _wait(1.0)
	hitbox.activate(SLASH_3)
	hurt.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, forward * 9.0, _player))
	HitStop.stop(0.11)
	await _shoot("%s_hit_strong" % spot_name)
	hitbox.deactivate()
	# Vết máu trên sàn sau khi máu rơi
	await _wait(1.2)
	await _shoot_at([0], "%s_blood_floor" % spot_name)
	# 2) Vệt chém đòn 1 và đòn 3 (không có quái)
	# 3) Quái chết
	enemy.health.take_damage(enemy.health.current_health - 1)
	hurt.set_invincible(0.0)
	hurt.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, forward * 9.0, _player))
	await _shoot("%s_kill" % spot_name)
	await _wait(2.0)
	await _shoot_at([0], "%s_kill_after" % spot_name)
	# 4) Player bị đánh: viền đỏ + rung
	_player.get_node("HurtboxComponent").receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3(0.0, 0.0, 3.0), null))
	await _shoot("%s_player_hurt" % spot_name)
	await _wait(1.0)
	CombatFx.get_blood_stains().clear()


## Chụp ở các khung FRAMES kể từ lúc gọi
func _shoot(shot_name: String) -> void:
	await _shoot_at(FRAMES, shot_name)


func _shoot_at(frames: Array[int], shot_name: String) -> void:
	var passed := 0
	for i in frames.size():
		while passed < frames[i]:
			await get_tree().process_frame
			passed += 1
		await RenderingServer.frame_post_draw
		var path := _dir.path_join("lvl_%s_f%d.png" % [shot_name, frames[i]])
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
