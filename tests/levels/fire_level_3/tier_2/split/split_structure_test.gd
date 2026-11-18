extends Node
## Kiểm tra cấu trúc sau khi tách tier 2 thành scene riêng (levels/zone_3_fire/tier_2/tier_2.tscn):
## 1. Cả hai scene nạp và dựng được, không lỗi tham chiếu.
## 2. Tier 1 (level_3.tscn) không còn phòng / cơ chế tier 2; cổng ra phòng boss 10 là cổng chuyển khu sang tier 2.
## 3. Tier 2 có ZoneRoot, điểm xuất hiện "start", đủ phòng tháp và các nhóm cơ chế.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/tier_2/split/split_structure_test.tscn

const LEVEL_PATH: String = "res://levels/zone_3_fire/tier_1/tier_1.tscn"
const TIER_2_PATH: String = "res://levels/zone_3_fire/tier_2/tier_2.tscn"
const TIER_2_NODES: Array[NodePath] = [^"Rooms/Tier2", ^"Tier2Mechanics", ^"Tier2Fights", ^"Tier2Links", ^"Tier2Zone"]

var _failed: int = 0
var _checks: int = 0


func _ready() -> void:
	get_tree().create_timer(60.0, true, true).timeout.connect(func() -> void:
		print("SPLIT STRUCTURE RESULT: TIMEOUT")
		get_tree().quit(2))
	var level: Node = _instance(LEVEL_PATH)
	var tier2: Node = _instance(TIER_2_PATH)
	if level != null and tier2 != null:
		_check_level(level)
		_check_tier2(tier2)
		level.free()
		tier2.free()
	print("SPLIT STRUCTURE RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _instance(path: String) -> Node:
	var ps: PackedScene = load(path) as PackedScene
	_expect(ps != null, "nạp được %s" % path)
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	_expect(inst != null, "dựng được %s" % path)
	return inst


func _check_level(level: Node) -> void:
	for p: NodePath in TIER_2_NODES:
		_expect(level.get_node_or_null(p) == null, "tier 1 không còn %s" % p)
	_expect(level.get_node_or_null(^"Rooms/Tier1") != null, "tier 1 còn Rooms/Tier1")
	var exit := level.get_node_or_null(^"Room10ExitReveal/ExitPortal") as Portal
	_expect(exit != null, "cổng ra phòng boss 10 là Portal")
	if exit != null:
		_expect(exit.target_zone == TIER_2_PATH, "cổng ra trỏ tới scene tier 2")
		_expect(exit.target_portal_id == &"start", "cổng ra vào điểm xuất hiện 'start'")


func _check_tier2(tier2: Node) -> void:
	_expect(tier2 is ZoneRoot, "gốc tier 2 là ZoneRoot")
	var start := tier2.get_node_or_null(^"Start") as SpawnPoint
	_expect(start != null and start.spawn_id == &"start", "có điểm xuất hiện 'start'")
	for p: NodePath in TIER_2_NODES:
		_expect(tier2.get_node_or_null(p) != null, "tier 2 có %s" % p)
	_expect(tier2.get_node_or_null(^"Rooms/Tier1") == null, "tier 2 không có phòng tier 1")
	_expect(tier2.get_node_or_null(^"Rooms/Tier2/T201Arrival") != null, "tier 2 có phòng đáp T201")
	_expect(tier2.get_node_or_null(^"Rooms/Tier2/T2T6Summit") != null, "tier 2 có phòng đỉnh tháp T2T6")
	_expect(tier2.get_node_or_null(^"FireLighting") != null, "tier 2 có ánh sáng map Lửa")
	_expect(tier2.get_node_or_null(^"Tier2Mechanics/DarkTrial") == null, "tier 2 không còn thử thách u tối (đã bỏ)")


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		print("FAIL: %s" % what)
