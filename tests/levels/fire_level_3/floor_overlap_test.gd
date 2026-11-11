extends Node
## Sàn map Lửa không có hai ô gạch (floor_*) chồng lên nhau gần như cùng độ cao: mặt cầu xoay 45° chìm dưới sân
## chỉ 2 cm thì hoa văn ô chéo lộ qua sàn ô thẳng (z-fight), nhìn như ô gạch đè nhau.
## Đo bằng hình học thật: mọi cặp ô vuông 4 m đang hiện (có xoay) chồng nhau hơn 5 cm mà lệch cao dưới MIN_GAP thì lỗi.
## Không cần dựng cảnh chơi. Chạy: godot --headless --path . res://tests/levels/fire_level_3/floor_overlap_test.tscn (-- --capture để chụp ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
## Chồng nhau thì mặt trên phải cách nhau tối thiểu bằng này (m)
const MIN_GAP: float = 0.05
const TILE: float = 4.0

var _player: Player
var _level: Node


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
	for _i: int in range(20):
		await get_tree().physics_frame
	var tiles: Array[Node3D] = []
	_collect(_level, tiles)
	var bad: Array[String] = []
	for i: int in range(tiles.size()):
		for j: int in range(i + 1, tiles.size()):
			var a: Vector3 = tiles[i].global_position
			var b: Vector3 = tiles[j].global_position
			if Vector2(a.x - b.x, a.z - b.z).length() > TILE * 1.45 or absf(a.y - b.y) >= MIN_GAP:
				continue
			if _overlap(a, tiles[i].global_rotation.y, b, tiles[j].global_rotation.y):
				bad.append("%s %s <> %s %s" % [tiles[i].name, a, tiles[j].name, b])
	print("%s %d ô sàn, %d cặp chồng nhau lệch cao < %.2f m" % ["OK  " if bad.is_empty() else "FAIL", tiles.size(), bad.size(), MIN_GAP])
	for line: String in bad.slice(0, 60):
		print("   ", line)
	if "--capture" in OS.get_cmdline_user_args() and _player:
		_player.teleport(Vector3(56, 4.4, 56))
		for _i: int in range(40):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/floor_plaza.png")
	print("FLOOR OVERLAP RESULT: %s" % ("OK" if bad.is_empty() else "%d FAIL" % bad.size()))
	get_tree().quit(0 if bad.is_empty() else 1)


func _collect(n: Node, out: Array[Node3D]) -> void:
	if n is Node3D and n.scene_file_path.get_file().begins_with("floor_") and n.scene_file_path.ends_with(".glb"):
		# Ô đang ẩn (sàn lưới thử thách cuối chỉ hiện khi đang đánh) không tính
		if (n as Node3D).is_visible_in_tree():
			out.append(n as Node3D)
		return
	for c: Node in n.get_children():
		_collect(c, out)


func _axes(yaw: float) -> Array[Vector2]:
	return [Vector2(cos(yaw), -sin(yaw)), Vector2(sin(yaw), cos(yaw))]


func _corners(c: Vector3, yaw: float) -> Array[Vector2]:
	var ax: Array[Vector2] = _axes(yaw)
	var out: Array[Vector2] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			out.append(Vector2(c.x, c.z) + ax[0] * TILE * 0.5 * sx + ax[1] * TILE * 0.5 * sz)
	return out


## SAT hai hình vuông; chồng thật khi cả bốn trục đều chồng hơn 5 cm (chạm mép không tính)
func _overlap(a: Vector3, ya: float, b: Vector3, yb: float) -> bool:
	var ca: Array[Vector2] = _corners(a, ya)
	var cb: Array[Vector2] = _corners(b, yb)
	for axis: Vector2 in _axes(ya) + _axes(yb):
		var mina: float = INF
		var maxa: float = -INF
		var minb: float = INF
		var maxb: float = -INF
		for p: Vector2 in ca:
			mina = minf(mina, p.dot(axis))
			maxa = maxf(maxa, p.dot(axis))
		for p: Vector2 in cb:
			minb = minf(minb, p.dot(axis))
			maxb = maxf(maxb, p.dot(axis))
		if minf(maxa, maxb) - maxf(mina, minb) < 0.05:
			return false
	return true
