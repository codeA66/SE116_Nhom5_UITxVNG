extends Node
## Kiểm tra blockout zone 3: đưa player tới từng phòng / đoạn nối, đo player có đứng được trên sàn
## (va chạm thật, không rơi xuống dung nham), chụp ảnh bằng camera game, rồi chụp toàn cảnh từ trên xuống.
## Chạy: godot --path . res://tests/levels/fire_level_3/level_3_route_test.tscn -- --capture

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

## Điểm thử (x, y sàn, z) theo tọa độ thế giới; tên dùng cho log và tên ảnh
const CHECKPOINTS: Array[Dictionary] = [
	{"name": "01_spawn", "p": Vector3(19.5, 4, 90.5)},
	{"name": "01_spawn_door", "p": Vector3(26, 4, 84)},
	{"name": "02_combat_c2", "p": Vector3(22, 0, 30)},
	{"name": "03_combat_treasure", "p": Vector3(46, 0, 18)},
	{"name": "path_ignite_chain", "p": Vector3(54, 1, 34)},
	{"name": "05_ambush", "p": Vector3(62, 4, 40)},
	{"name": "04_treasure_north", "p": Vector3(70, 8, 14)},
	{"name": "bridge_start_at_door", "p": Vector3(32, 4, 78)},
	{"name": "bridge_middle", "p": Vector3(42, 4, 68)},
	{"name": "bridge_end_landing", "p": Vector3(56, 4, 54)},
	{"name": "path_west_corridor", "p": Vector3(70, 4, 54)},
	{"name": "06_choke_point", "p": Vector3(102, 4, 54)},
	{"name": "07_hub", "p": Vector3(118, 4, 54)},
	{"name": "08_arena", "p": Vector3(114, 8, 18)},
	{"name": "09_side_room", "p": Vector3(92, 8, 18)},
	{"name": "10_boss", "p": Vector3(158, 4, 52)},
	{"name": "11_treasure_south", "p": Vector3(72, 0, 78)},
	{"name": "12_drained_lava", "p": Vector3(100, 0, 80)},
	{"name": "13_secret", "p": Vector3(118, 0, 80)},
	{"name": "14_crumbling", "p": Vector3(142, 4, 72)},
	{"name": "15_ruins_plaza", "p": Vector3(144, 0, 98)},
]

## Nhãn tên khu theo sơ đồ chú thích, đặt ở tâm phòng (x, z) cho ảnh top_down_labeled.png
const ROOM_LABELS: Array[Dictionary] = [
	{"text": "1. Phòng Bắt đầu
(Spawn)", "p": Vector2(19, 94)},
	{"text": "2. Phòng Chiến đấu C2
(hầm tối, mini-boss)", "p": Vector2(26, 32)},
	{"text": "3. Kho báu / Chiến đấu
(hầm tối, mini-boss)", "p": Vector2(42, 16)},
	{"text": "4. Kho báu T1
(phía bắc)", "p": Vector2(72, 10)},
	{"text": "5. Chốt chặn
(Ambush)", "p": Vector2(62, 38)},
	{"text": "6. Điểm Thắt", "p": Vector2(102, 54)},
	{"text": "7. HUB
+ Bệ thờ bị kẹt", "p": Vector2(124, 48)},
	{"text": "8. Khu vực Sự kiện
(Arena, mini-boss)", "p": Vector2(114, 14)},
	{"text": "9. Phòng phụ
+ cổng về Hub", "p": Vector2(90, 16)},
	{"text": "10. PHÒNG BOSS
+ Cổng về", "p": Vector2(162, 46)},
	{"text": "11. Kho báu T1 (nam)
cửa 1 chiều ra bắc", "p": Vector2(72, 78)},
	{"text": "12. Dung nham đã nứt", "p": Vector2(100, 74)},
	{"text": "13. Khu bí mật S2", "p": Vector2(120, 82)},
	{"text": "14. Góc phục kích
(sàn sụp)", "p": Vector2(142, 72)},
	{"text": "15. Quảng trường
+ cổng về Hub", "p": Vector2(142, 98)},
	{"text": "CẦU GẠCH NETHER
(tuyến chính)", "p": Vector2(48, 72)},
	{"text": "Hồ dung nham", "p": Vector2(44, 92)},
	{"text": "Lối đi hướng Tây (8 m)
◄ cổng khóa (giải đố 3, 4)", "p": Vector2(80, 52)},
	{"text": "Rào gỗ ▸ xuống hầm", "p": Vector2(56, 28)},
	{"text": "Dòng dung nham
/ Vực thẳm", "p": Vector2(82, 61)},
	{"text": "Đường hầm
phía nam", "p": Vector2(86, 81)},
]

@export var settle_frames: int = 45
@export_dir var capture_dir: String = "res://output/fire_level_3/qa/"

var _player: Player


func _ready() -> void:
	var level: ZoneRoot = LEVEL.instantiate()
	level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(level)
	_run.call_deferred(level)


func _run(level: ZoneRoot) -> void:
	for _i: int in range(30):
		await get_tree().physics_frame
	if _player == null:
		push_error("Player không xuất hiện (thiếu SpawnPoint 'start'?)")
		get_tree().quit(1)
		return
	var capture: bool = "--capture" in OS.get_cmdline_user_args()
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	var failed: int = 0
	print("Spawn: ", _player.global_position.snapped(Vector3.ONE * 0.01))
	for check: Dictionary in CHECKPOINTS:
		var target: Vector3 = check.p
		_player.global_position = target + Vector3(0.0, 1.5, 0.0)
		_player.velocity = Vector3.ZERO
		for _i: int in range(settle_frames):
			await get_tree().physics_frame
		var pos: Vector3 = _player.global_position
		# Đứng trên sàn và không tụt quá 1 m dưới mặt sàn dự kiến (mặt sàn = y + 0.32)
		var ok: bool = _player.is_on_floor() and pos.y > target.y - 1.0
		if not ok:
			failed += 1
		print("%s %s  floor=%s  y=%.2f (sàn %.2f)" % ["OK  " if ok else "FAIL", check.name, _player.is_on_floor(), pos.y, target.y + 0.32])
		if capture:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_dir.path_join("route_%s.png" % check.name))
	if capture:
		await _capture_overview(level)
	print("ROUTE RESULT: %d/%d OK" % [CHECKPOINTS.size() - failed, CHECKPOINTS.size()])
	get_tree().quit(0 if failed == 0 else 1)


func _capture_overview(level: Node3D) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 140.0
	cam.far = 400.0
	level.add_child(cam)
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(-60.0), deg_to_rad(20.0), 0.0))
	cam.global_transform = Transform3D(basis, Vector3(90.0, 0.0, 52.0) + basis.z * 150.0)
	cam.current = true
	for _i: int in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join("overview.png"))
	var top: Basis = Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0))
	cam.global_transform = Transform3D(top, Vector3(90.0, 120.0, 52.0))
	cam.size = 112.0
	for _i: int in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join("top_down.png"))
	# Bản có ghi tên khu theo sơ đồ, để đối chiếu từng phòng
	for entry: Dictionary in ROOM_LABELS:
		var label: Label3D = Label3D.new()
		label.text = str(entry.text)
		label.position = Vector3(entry.p.x, 30.0, entry.p.y)
		label.rotation_degrees.x = -90.0
		label.pixel_size = 0.034
		label.font_size = 56
		label.outline_size = 16
		label.modulate = Color(1.0, 0.95, 0.6)
		label.no_depth_test = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level.add_child(label)
	for _i: int in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_dir.path_join("top_down_labeled.png"))
