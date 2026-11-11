extends Node
## Không có khe hở hẹp trên sàn đi được: khe hẹp (rộng tới MAX_GAP) giữa hai mặt sàn ngang nhau (đường nối - phòng, ô góc
## 3 m so với ô 4 m...) làm Player lọt vào khe sâu ~10 cm và kẹt không bước ra được (lỗi gần lửa trại phòng 5).
## Đo bằng tia thật: lưới CELL m quanh mọi ô sàn / mặt cầu đang hiện, lấy độ cao mặt va chạm đầu tiên dưới mỗi điểm; điểm
## nào thấp hơn hoặc trống mà hai phía (cách GAP_PROBE m theo X hoặc Z) đều có mặt ngang nhau thì là khe.
## Không cần dựng cảnh chơi. Chạy: godot --headless --path . res://tests/levels/fire_level_3/floor_collision_gap_test.tscn

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")
const CELL: float = 0.25
## Lệch điểm đo để không trúng đúng đường giáp hai hộp va chạm (tia lọt đúng khe 0 m, không phải khe thật)
const SAMPLE_SHIFT: float = 0.07
## Khe rộng hơn mức này coi là vực / lối cố ý (không phải khe lọt chân)
const MAX_GAP: float = 0.75
## Hai phía khe phải ngang nhau trong khoảng này (m) mới tính là cùng một mặt sàn bị đứt
const LEVEL_TOLERANCE: float = 0.05
## Mặt thấp hơn mặt hai phía quá mức này (hoặc trống) mới là khe
const DROP: float = 0.04
const WORLD_MASK: int = 1
## Khe chỉ 1-2 ô lưới (<= 0,5 m dài) là vệt hẹp ở mép bệ / ô xoay, chân Player không lọt: chỉ báo cụm từ MIN_CLUSTER ô
const MIN_CLUSTER: int = 3

var _level: Node
var _space: PhysicsDirectSpaceState3D
var _heights: Dictionary = {}


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_flag(&"level_3.bridge_guards")
	_level = LEVEL.instantiate()
	add_child(_level)
	_run.call_deferred()


func _run() -> void:
	for _i: int in range(10):
		await get_tree().physics_frame
	_space = (_level as Node3D).get_world_3d().direct_space_state
	var tiles: Array[Node3D] = []
	_collect(_level, tiles)
	# 1. Lấy mẫu độ cao mặt va chạm trên lưới quanh mọi ô (mỗi ô nới 1 m ra ngoài để thấy khe ở mép)
	var cells: Dictionary = {}
	for tile: Node3D in tiles:
		var c: Vector3 = tile.global_position
		var surface: float = c.y + 0.32
		var half: float = 3.1
		var x0: int = roundi((c.x - half) / CELL)
		var x1: int = roundi((c.x + half) / CELL)
		var z0: int = roundi((c.z - half) / CELL)
		var z1: int = roundi((c.z + half) / CELL)
		for ix: int in range(x0, x1 + 1):
			for iz: int in range(z0, z1 + 1):
				var key: Vector3i = Vector3i(ix, roundi(surface / 0.5), iz)
				if cells.has(key):
					continue
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(ix * CELL + SAMPLE_SHIFT, surface + 0.9, iz * CELL + SAMPLE_SHIFT), Vector3(ix * CELL + SAMPLE_SHIFT, surface - 1.2, iz * CELL + SAMPLE_SHIFT), WORLD_MASK)
				var hit: Dictionary = _space.intersect_ray(q)
				cells[key] = (hit.position as Vector3).y if not hit.is_empty() else -INF
	# 2. Tìm khe: ô thấp / trống mà hai phía ngang nhau
	var max_cells: int = int(MAX_GAP / CELL)
	var gaps: Dictionary = {}
	for key: Vector3i in cells:
		var h: float = cells[key]
		for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			# Tìm phía trước / sau gần nhất cùng mặt sàn, khe dài tối đa max_cells ô
			for width: int in range(1, max_cells + 1):
				var back: Vector3i = Vector3i(key.x - axis.x, key.y, key.z - axis.y)
				var fwd: Vector3i = Vector3i(key.x + axis.x * width, key.y, key.z + axis.y * width)
				if not cells.has(back) or not cells.has(fwd):
					continue
				var hb: float = cells[back]
				var hf: float = cells[fwd]
				if hb == -INF or hf == -INF or absf(hb - hf) > LEVEL_TOLERANCE:
					continue
				# Mọi ô giữa back và fwd đều phải thấp hơn hai phía quá DROP (trống hoặc lọt)
				var all_low: bool = true
				for k: int in range(0, width):
					var mid: Vector3i = Vector3i(key.x + axis.x * k, key.y, key.z + axis.y * k)
					if cells.has(mid) and cells[mid] > hb - DROP:
						all_low = false
						break
				if all_low and h < hb - DROP:
					gaps[Vector2i(key.x, key.z)] = hb
	# 3. Gom thành cụm (ô kề nhau) để báo gọn
	var seen: Dictionary = {}
	var clusters: Array[String] = []
	for k: Vector2i in gaps:
		if seen.has(k):
			continue
		var stack: Array[Vector2i] = [k]
		var members: int = 0
		var sx: float = 0.0
		var sz: float = 0.0
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		var hy: float = gaps[k]
		seen[k] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			members += 1
			sx += cur.x * CELL
			sz += cur.y * CELL
			lo = lo.min(Vector2(cur.x * CELL, cur.y * CELL))
			hi = hi.max(Vector2(cur.x * CELL, cur.y * CELL))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + d
				if gaps.has(nb) and not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
		if members < MIN_CLUSTER:
			continue
		clusters.append("khe %d ô quanh (%.1f, %.2f, %.1f), x %.2f..%.2f, z %.2f..%.2f" % [members, sx / members, hy, sz / members, lo.x, hi.x, lo.y, hi.y])
	print("%s %d ô sàn, %d ô lưới đo, %d khe hẹp" % ["OK  " if clusters.is_empty() else "FAIL", tiles.size(), cells.size(), clusters.size()])
	for line: String in clusters.slice(0, 30):
		print("   ", line)
	print("FLOOR COLLISION GAP RESULT: %s" % ("OK" if clusters.is_empty() else "%d FAIL" % clusters.size()))
	get_tree().quit(0 if clusters.is_empty() else 1)


func _collect(n: Node, out: Array[Node3D]) -> void:
	var f: String = n.scene_file_path.get_file()
	if n is Node3D and (f.begins_with("floor_") or f == "bridge_4m.glb") and f.ends_with(".glb"):
		if (n as Node3D).is_visible_in_tree():
			out.append(n as Node3D)
		return
	for c: Node in n.get_children():
		_collect(c, out)
