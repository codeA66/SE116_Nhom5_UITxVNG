extends Node
## Quái chỉ bắt đầu tấn công khi player bước vào đúng phòng của quái (map Lửa tier 1 + tier 2).
## Với mỗi nguồn quái (Encounter, SpawnerCage, BossFight, HostageRescue) nằm trong một phòng (vùng RoomFocus):
## 1. Tĩnh: vùng kích hoạt (Trigger / ActiveArea) nằm gọn trong hộp phòng (lệch tối đa TOLERANCE m).
## 2. Hành vi thật: đặt player lần lượt ở các điểm có sàn ngay ngoài phòng (cách mép OUTSIDE m, mỗi STEP m dọc chu vi),
##    chờ vài frame vật lý rồi hỏi va chạm thật (overlaps_body): vùng kích hoạt không được bắt player.
## Nguồn quái ngoài mọi phòng (quái canh hành lang, cầu) không thuộc phòng nào: chỉ in ra để biết.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room_aggro_test.tscn

const LEVELS: Array[String] = [
	"res://levels/zone_3_fire/tier_1/tier_1.tscn",
	"res://levels/zone_3_fire/tier_2/tier_2.tscn",
]
const TOLERANCE: float = 0.3
const OUTSIDE: float = 1.5
const STEP: float = 2.0
const SETTLE_FRAMES: int = 3

var _player: Player
var _failed: int = 0
var _checked: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	for path: String in LEVELS:
		GameState.replace_progress(PlayerProgress.new())
		var level: Node = (load(path) as PackedScene).instantiate()
		(level as ZoneRoot).player_spawned.connect(func(p: Player) -> void: _player = p)
		add_child(level)
		await _frames(30)
		print("== %s" % path.get_file())
		await _check_level(level)
		level.queue_free()
		await _frames(5)
	print("ROOM AGGRO RESULT: %s (%d kiểm tra)" % ["OK" if _failed == 0 else "%d FAIL" % _failed, _checked])
	get_tree().quit(0 if _failed == 0 else 1)


func _check_level(level: Node) -> void:
	var rooms: Array[Dictionary] = []
	for zone: Node in level.get_node("RoomFocus").get_children():
		if zone is Area3D:
			rooms.append({"name": zone.name, "box": _area_box(zone as Area3D)})
	_player.get_node("HurtboxComponent").set_invincible(9999.0)
	for source: Dictionary in _sources(level):
		var area: Area3D = source.area
		var room: Dictionary = _room_of(source.at, _area_box(area), rooms)
		var label: String = "%s (%s)" % [source.node.name, source.kind]
		if room.is_empty():
			print("--   %s: ngoài mọi phòng (quái canh hành lang), bỏ qua" % label)
			continue
		var room_box: AABB = room.box
		var trigger_box: AABB = _area_box(area)
		var over: float = _overhang(trigger_box, room_box)
		var hits: Array[Vector3] = []
		var probes: int = 0
		for p: Vector3 in _outside_points(room_box):
			var floor_at: Variant = _floor_at(p, room_box)
			if floor_at == null:
				continue
			probes += 1
			_teleport(floor_at)
			await _frames(SETTLE_FRAMES)
			if area.overlaps_body(_player):
				hits.append(floor_at)
		if probes == 0:
			# Phòng kín (tầng tháp nối bằng đĩa dịch chuyển): quanh phòng là vực, vùng lấn ra cũng không ai đứng được
			print("--   %s: %s không có sàn bên ngoài (phòng kín), vùng lấn ra %.2f m không tính" % [label, room.name, over])
			continue
		_check(over <= TOLERANCE, "%s: vùng kích hoạt nằm trong %s (lấn ra %.2f m)" % [label, room.name, over])
		_check(hits.is_empty(), "%s: đứng ngoài %s (%d điểm có sàn) không kích hoạt%s" % [
			label, room.name, probes, "" if hits.is_empty() else ", bị bắt ở %s" % _fmt(hits)])


## Mọi nguồn quái trong khu: node, loại, vùng kích hoạt, điểm đặt (để tìm phòng)
func _sources(level: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in level.find_children("*", "Node3D", true, false):
		var area: Area3D = null
		var kind: String = ""
		if n is Encounter:
			area = n.get_node_or_null("Trigger") as Area3D
			kind = "trận"
		elif n is SpawnerCage:
			area = n.get_node_or_null("ActiveArea") as Area3D
			kind = "lồng"
		elif n is BossFight:
			area = n.get_node_or_null("Trigger") as Area3D
			kind = "boss"
		elif n is HostageRescue:
			area = n.get_node_or_null("ActiveArea") as Area3D
			kind = "con tin"
		if area == null:
			continue
		out.append({"node": n, "kind": kind, "area": area, "at": _anchor(n, area)})
	return out


## Điểm xác định phòng của nguồn: quái đầu tiên của trận (đứng sẵn trong phòng), còn lại là chính node
func _anchor(n: Node, area: Area3D) -> Vector3:
	var enemies: Node = n.get_node_or_null("Enemies")
	if enemies != null:
		for e: Node in enemies.get_children():
			if e is Node3D:
				return (e as Node3D).global_position
	if n is BossFight:
		return (n.get_node("Spawn") as Node3D).global_position
	return (n as Node3D).global_position


## Phòng chứa điểm đặt; nhiều phòng (hộp phòng cao chồng theo độ cao) thì chọn phòng giao nhiều nhất với vùng kích hoạt
func _room_of(at: Vector3, trigger: AABB, rooms: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_volume: float = -1.0
	for r: Dictionary in rooms:
		var box: AABB = r.box
		if not box.grow(0.05).has_point(at):
			continue
		var volume: float = box.intersection(trigger).get_volume()
		if volume > best_volume:
			best_volume = volume
			best = r
	return best


## Hộp bao toàn cục của mọi BoxShape3D / SphereShape3D con của vùng (kể cả shape đang tắt chờ cờ: lúc bật vẫn là hộp này)
func _area_box(area: Area3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for c: Node in area.get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		var size: Vector3
		if cs.shape is BoxShape3D:
			size = (cs.shape as BoxShape3D).size
		elif cs.shape is SphereShape3D:
			size = Vector3.ONE * (cs.shape as SphereShape3D).radius * 2.0
		else:
			continue
		var b: AABB = cs.global_transform * AABB(-size * 0.5, size)
		box = b if first else box.merge(b)
		first = false
	return box


## Phần lấn ra ngoài phòng lớn nhất theo mặt bằng (x, z)
func _overhang(inner: AABB, outer: AABB) -> float:
	var a: Vector3 = inner.position
	var b: Vector3 = inner.end
	var oa: Vector3 = outer.position
	var ob: Vector3 = outer.end
	return maxf(maxf(oa.x - a.x, b.x - ob.x), maxf(oa.z - a.z, b.z - ob.z))


## Điểm trên vòng chu vi phòng nới ra OUTSIDE m, cách nhau STEP m
func _outside_points(box: AABB) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x0: float = box.position.x - OUTSIDE
	var x1: float = box.end.x + OUTSIDE
	var z0: float = box.position.z - OUTSIDE
	var z1: float = box.end.z + OUTSIDE
	var x: float = x0
	while x <= x1:
		out.append(Vector3(x, 0.0, z0))
		out.append(Vector3(x, 0.0, z1))
		x += STEP
	var z: float = z0 + STEP
	while z < z1:
		out.append(Vector3(x0, 0.0, z))
		out.append(Vector3(x1, 0.0, z))
		z += STEP
	return out


## Sàn đứng được (lớp world) dưới điểm, trong khoảng cao độ của phòng; null nếu là vực
func _floor_at(p: Vector3, room_box: AABB) -> Variant:
	var top: Vector3 = Vector3(p.x, room_box.end.y, p.z)
	var bottom: Vector3 = Vector3(p.x, room_box.position.y - 4.0, p.z)
	var query := PhysicsRayQueryParameters3D.create(top, bottom, 1)
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
		return null
	return hit.position


func _teleport(p: Vector3) -> void:
	_player.global_position = p + Vector3(0.0, 0.3, 0.0)
	_player.velocity = Vector3.ZERO


func _fmt(points: Array[Vector3]) -> String:
	var parts: PackedStringArray = []
	for p: Vector3 in points.slice(0, 4):
		parts.append("(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z])
	return ", ".join(parts) + (" ... (%d điểm)" % points.size() if points.size() > 4 else "")


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
