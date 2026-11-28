extends Node
## CharmRevealOnClear: bùa ẩn hiện ra khi MỌI nguồn (lồng / trận) đã dọn xong.
## Ca đơn vị (nguồn giả có signal cleared + is_active()):
##  1. Mới vào: bùa ẩn, không nhặt được.
##  2. Dọn 1/2 nguồn: vẫn ẩn.  3. Dọn đủ 2/2: hiện, nhặt được.
##  4. Nguồn đã dọn sẵn lúc nạp: hiện ngay.  5. 1 nguồn và 3 nguồn vẫn đúng.
##  6. Đã sở hữu bùa (pickup tự xoá): không lỗi.  7. Danh sách rỗng / có nguồn null: không lỗi, không hiện.
## Ca tích hợp map Lửa:
##  8. Tier 1 phòng 14: bùa Hỏa Tiễn ẩn; phá + dọn 1 lồng vẫn ẩn; dọn cả 2 lồng thì hiện ở giữa phòng 14.
##  9. Tier 2 phòng 10: bùa Tro Ghìm nằm sẵn, nhìn thấy, nhặt được.
## Không ghi save thật. Chạy: godot --headless --path . res://tests/objects/charm_reveal/charm_reveal_on_clear_test.tscn

const PICKUP: PackedScene = preload("res://objects/core/pickups/charm/charm_pickup.tscn")
const CHARM: CharmData = preload("res://resources/player/items/charms/utility/light_step_charm.tres")
const TIER_1: String = "res://levels/zone_3_fire/tier_1/tier_1.tscn"
const TIER_2: String = "res://levels/zone_3_fire/tier_2/tier_2.tscn"
const FIRE_ARROW_ID: StringName = &"fire_arrow_charm"
const ASH_BIND_ID: StringName = &"ash_bind_charm"

var _failed: int = 0
var _total: int = 0


class FakeSource:
	extends Node
	signal cleared
	var done: bool = false

	func is_active() -> bool:
		return done

	func clear() -> void:
		done = true
		cleared.emit()


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	await _unit_cases()
	await _tier_1_case()
	await _tier_2_case()
	print("CHARM REVEAL RESULT: %s" % ("OK (%d checks)" % _total if _failed == 0 else "%d FAIL / %d" % [_failed, _total]))
	get_tree().quit(1 if _failed > 0 else 0)


func _unit_cases() -> void:
	GameState.replace_progress(PlayerProgress.new())
	# 1-3: hai nguồn
	var s: Array = await _setup(2, [false, false])
	var pickup: CharmPickup = s[0]
	var sources: Array = s[1]
	_check(not _shown(pickup), "mới vào: bùa ẩn, không nhặt được")
	(sources[0] as FakeSource).clear()
	await _frames(2)
	_check(not _shown(pickup), "dọn 1/2 nguồn: bùa vẫn ẩn")
	(sources[1] as FakeSource).clear()
	await _frames(2)
	_check(_shown(pickup), "dọn 2/2 nguồn: bùa hiện, nhặt được")
	(sources[1] as FakeSource).clear()
	await _frames(2)
	_check(_shown(pickup), "nguồn phát cleared lần nữa: không lỗi, bùa vẫn hiện")
	_teardown(s)
	# 4: đã dọn sẵn lúc nạp
	s = await _setup(2, [true, true])
	_check(_shown(s[0]), "nguồn đã dọn sẵn lúc nạp: bùa hiện ngay")
	_teardown(s)
	# 4b: một nguồn dọn sẵn, nguồn kia chưa
	s = await _setup(2, [true, false])
	_check(not _shown(s[0]), "nạp với 1/2 nguồn đã dọn: bùa ẩn")
	(s[1][1] as FakeSource).clear()
	await _frames(2)
	_check(_shown(s[0]), "dọn nốt nguồn còn lại: bùa hiện")
	_teardown(s)
	# 5: 1 nguồn và 3 nguồn
	s = await _setup(1, [false])
	(s[1][0] as FakeSource).clear()
	await _frames(2)
	_check(_shown(s[0]), "1 nguồn: dọn xong thì hiện")
	_teardown(s)
	s = await _setup(3, [false, false, false])
	(s[1][0] as FakeSource).clear()
	(s[1][2] as FakeSource).clear()
	await _frames(2)
	_check(not _shown(s[0]), "3 nguồn, dọn 2: vẫn ẩn")
	(s[1][1] as FakeSource).clear()
	await _frames(2)
	_check(_shown(s[0]), "3 nguồn, dọn đủ 3: hiện")
	_teardown(s)
	# 6: đã sở hữu bùa → pickup tự xoá, dọn nguồn không lỗi
	GameState.replace_progress(PlayerProgress.new())
	GameState.add_charm(CHARM)
	s = await _setup(1, [false])
	await _frames(2)
	_check(not is_instance_valid(s[0]) or (s[0] as Node).is_queued_for_deletion(), "đã có bùa: pickup không đặt thêm")
	(s[1][0] as FakeSource).clear()
	await _frames(2)
	_check(true, "đã có bùa: dọn nguồn không gây lỗi")
	_teardown(s)
	# 7: rỗng và nguồn null
	s = await _setup(0, [])
	_check(not _shown(s[0]), "danh sách nguồn rỗng: không hiện")
	_teardown(s)
	s = await _setup(1, [false], true)
	(s[1][0] as FakeSource).clear()
	await _frames(2)
	_check(not _shown(s[0]), "có nguồn null: không hiện (không coi null là đã dọn)")
	_teardown(s)


## Trả về [pickup, sources, reveal]
func _setup(count: int, done: Array, add_null: bool = false) -> Array:
	var root := Node3D.new()
	add_child(root)
	var sources: Array = []
	for i in count:
		var src := FakeSource.new()
		src.done = bool(done[i])
		root.add_child(src)
		sources.append(src)
	var pickup: CharmPickup = PICKUP.instantiate() as CharmPickup
	pickup.charm = CHARM
	pickup.starts_hidden = true
	pickup.persistent_id = &"test.charm_reveal"
	var reveal: Node = (load("res://objects/core/pickups/charm/charm_reveal_on_clear.gd") as GDScript).new()
	var list: Array[Node] = []
	for src: Node in sources:
		list.append(src)
	if add_null:
		list.append(null)
	reveal.set(&"sources", list)
	reveal.set(&"pickup", pickup)
	root.add_child(pickup)
	root.add_child(reveal)
	await _frames(2)
	return [pickup, sources, reveal, root]


func _teardown(s: Array) -> void:
	(s[3] as Node).queue_free()
	GameState.replace_progress(PlayerProgress.new())


func _tier_1_case() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var scene: PackedScene = load(TIER_1) as PackedScene
	_check(scene != null, "tier 1: nạp được scene")
	if scene == null:
		return
	var level: Node = scene.instantiate()
	add_child(level)
	await _frames(30)
	var pickup: CharmPickup = _find_charm(level, FIRE_ARROW_ID)
	_check(pickup != null, "tier 1: có bùa Hỏa Tiễn trong khu")
	if pickup == null:
		level.queue_free()
		return
	_check(not _shown(pickup), "tier 1: bùa Hỏa Tiễn ẩn lúc vào khu")
	var room: Node3D = level.get_node("Rooms/Tier1/Room14Crumbling") as Node3D
	var center: Vector3 = _room_center(level, "RoomFocus/Room14CrumblingZone")
	var off: float = Vector2(pickup.global_position.x - center.x, pickup.global_position.z - center.z).length()
	_check(off <= 4.0, "tier 1: bùa gần giữa phòng 14 (lệch %.1f m)" % off)
	_check(room != null, "tier 1: có phòng 14")
	var west: SpawnerCage = level.get_node("Room14/Room14CageWest") as SpawnerCage
	var east: SpawnerCage = level.get_node("Room14/Room14CageEast") as SpawnerCage
	_clear_cage(west)
	await _frames(10)
	_check(not _shown(pickup), "tier 1: dọn lồng Tây: bùa vẫn ẩn")
	_clear_cage(east)
	await _frames(10)
	_check(_shown(pickup), "tier 1: dọn cả 2 lồng: bùa Hỏa Tiễn hiện, nhặt được")
	level.queue_free()
	await _frames(2)


func _tier_2_case() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var scene: PackedScene = load(TIER_2) as PackedScene
	_check(scene != null, "tier 2: nạp được scene")
	if scene == null:
		return
	var level: Node = scene.instantiate()
	add_child(level)
	await _frames(30)
	var pickup: CharmPickup = _find_charm(level, ASH_BIND_ID)
	_check(pickup != null, "tier 2: có bùa Tro Ghìm trong khu")
	if pickup != null:
		_check(_shown(pickup), "tier 2: bùa Tro Ghìm nằm sẵn, nhặt được")
		# Bệ cuối đường Cinder Run (cạnh cổng): tâm bệ theo toạ độ phòng 10
		var room: Node3D = level.get_node("Rooms/Tier2/T210CinderRun") as Node3D
		var pad: Vector3 = room.to_global(Vector3(8, 0, 12))
		var off: float = Vector2(pickup.global_position.x - pad.x, pickup.global_position.z - pad.z).length()
		_check(off <= 2.5, "tier 2: bùa nằm trên bệ cuối phòng 10 (lệch tâm bệ %.1f m)" % off)
		var hit: Dictionary = (level as Node3D).get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(pickup.global_position + Vector3.UP * 3.0, pickup.global_position + Vector3.DOWN * 2.0, 1))
		_check(not hit.is_empty() and absf((hit.position as Vector3).y - pickup.global_position.y) < 0.3, "tier 2: dưới bùa có sàn thật")
	level.queue_free()
	await _frames(2)


## Lồng không sinh quái (player không vào vùng) nên phá lồng là dọn xong
func _clear_cage(cage: SpawnerCage) -> void:
	if cage == null:
		return
	(cage.get_node("HealthComponent") as HealthComponent).take_damage(9999)
	for e: Node in cage.get_node("Enemies").get_children():
		if e is Enemy and not (e as Enemy).is_dead():
			(e as Enemy).health.take_damage(9999)


func _room_center(level: Node, zone_path: String) -> Vector3:
	var zone: Node3D = level.get_node_or_null(zone_path) as Node3D
	if zone == null:
		return Vector3.INF
	var shape: CollisionShape3D = zone.get_node_or_null("Shape") as CollisionShape3D
	return shape.global_position if shape else zone.global_position


func _find_charm(level: Node, id: StringName) -> CharmPickup:
	for n: Node in level.find_children("*", "", true, false):
		var p := n as CharmPickup
		if p and p.charm and p.charm.id == id:
			return p
	return null


func _shown(pickup: Variant) -> bool:
	if not is_instance_valid(pickup):
		return false
	var p: CharmPickup = pickup as CharmPickup
	var inter: InteractableComponent = p.get_node("InteractableComponent") as InteractableComponent
	return p.is_visible_in_tree() and inter.enabled


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, msg: String) -> void:
	_total += 1
	if ok:
		print("PASS ", msg)
	else:
		_failed += 1
		print("FAIL ", msg)
