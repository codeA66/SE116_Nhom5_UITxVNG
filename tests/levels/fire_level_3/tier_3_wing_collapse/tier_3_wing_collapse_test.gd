extends Node
## Test sập khu vực khi gắn đá vào Finish/Altar ở tier_3_walkthrough:
## 1. Trạng thái ban đầu: 4 khu vực, 4 cầu nối, 4 checkpoint hiện và hoạt động; 4 tường chắn mép Hub tắt.
## 2. Đặt đá Ly lên Altar -> cutscene lia tới khu Ly, ScreenShake tăng mạnh, khu Ly + cầu South + checkpoint Ly sập và biến mất, tường SouthSealWall bật chắn mép Hub (kiểm va chạm vật lý thật), trả điều khiển về player.
## 3. Tải lại map khi đã có cờ đặt đá -> khu Ly sập ngay lập tức, không chiếu lại cutscene.
## 4. Thông số WingCollapseData cực đoan (0 target, rumble 0s, rơi chậm bị giới hạn bởi max_collapse_duration) -> hoàn tất an toàn, không treo.
## 5. Quét chống vệt loang (z-fighting) cho 4 tường chắn mép Hub với các tường lân cận trong Hub.

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/tier_3_walkthrough.tscn")
const COLLAPSE_CONTROLLER_PATH: String = "res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/wing_collapse/wing_collapse_controller.gd"
const COLLAPSE_DATA_PATH: String = "res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/wing_collapse/wing_collapse_data.gd"

var _level: ZoneRoot
var _player: Player
var _checks: int = 0
var _failed: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	get_tree().create_timer(60.0, true, true).timeout.connect(func() -> void:
		print("WING COLLAPSE RESULT: TIMEOUT")
		get_tree().quit(2))

	GameState.replace_progress(PlayerProgress.new())
	await _load_level()
	await _t_initial_state()
	await _t_place_ly_and_collapse()
	await _t_reload_restores_collapsed_state()
	await _t_ton_wind_screens_collapse()
	await _t_chan_phase2_hides_gates()
	await _t_extreme_parameters()
	_t_hub_seal_z_fighting()
	print("WING COLLAPSE RESULT: %s" % ("OK (%d checks)" % _checks if _failed == 0 else "%d FAIL / %d" % [_failed, _checks]))
	get_tree().quit(1 if _failed > 0 else 0)


func _load_level() -> void:
	_player = null
	_level = LEVEL.instantiate() as ZoneRoot
	_level.player_spawned.connect(func(p: Player) -> void: _player = p)
	add_child(_level)
	await ZoneRoot.wait_combat_ready(_level)
	await _frames(4)


func _reload_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		await _frames(5)
	await _load_level()


func _t_initial_state() -> void:
	var wings: Array[NodePath] = [^"LiFoundry", ^"KhamCondenser", ^"TonAshenGale", ^"ChanThunderAnvil"]
	var bridges: Array[NodePath] = [^"Connectors/South", ^"Connectors/North", ^"Connectors/West", ^"Connectors/East"]
	var checkpoints: Array[NodePath] = [^"RoomCheckpoints/Ly", ^"RoomCheckpoints/Kham", ^"RoomCheckpoints/Ton", ^"RoomCheckpoints/Chan"]
	var barriers: Array[NodePath] = [^"Connectors/Hub/SouthSealWall", ^"Connectors/Hub/NorthSealWall", ^"Connectors/Hub/WestSealWall", ^"Connectors/Hub/EastSealWall"]

	var all_wings_up: bool = true
	for i: int in range(4):
		var wing := _level.get_node_or_null(wings[i]) as Node3D
		var bridge := _level.get_node_or_null(bridges[i]) as Node3D
		var checkpoint := _level.get_node_or_null(checkpoints[i]) as Node3D
		if wing == null or not wing.visible or bridge == null or not bridge.visible or checkpoint == null or not checkpoint.visible:
			all_wings_up = false
	_check(all_wings_up, "ban đầu: cả 4 khu vực, cầu nối và checkpoint đều đang hiện")

	var all_barriers_off: bool = true
	for path: NodePath in barriers:
		var barrier := _level.get_node_or_null(path) as Node3D
		if barrier == null or barrier.visible or _has_enabled_collision(barrier):
			all_barriers_off = false
	_check(all_barriers_off, "ban đầu: cả 4 tường chắn mép Hub tồn tại, đang ẩn và tắt va chạm")


func _t_place_ly_and_collapse() -> void:
	var cutscene := _level.get_node_or_null(^"CollapseCutscene") as CameraCutscene
	var ly_collapse := _level.get_node_or_null(^"WingCollapses/LyCollapse")
	_check(cutscene != null and ly_collapse != null, "scene có CollapseCutscene và WingCollapses/LyCollapse")
	if cutscene == null or ly_collapse == null:
		return

	GameState.set_flag(&"level_3.t3_walkthrough_ly_picked")
	var altar := _level.get_node(^"Finish/Altar") as Tier3Altar
	var interactable := altar.get_node(^"InteractableComponent") as InteractableComponent
	_player.teleport(Vector3(0.0, 0.4, 3.35), Vector3.FORWARD)
	await _frames(3)
	_check(interactable.can_interact(_player), "đứng trước Finish/Altar khi có đá Ly có thể tương tác")

	var counts: Dictionary[StringName, int] = {
		&"cutscene_started": 0,
		&"cutscene_finished": 0,
		&"collapse_finished": 0,
	}
	var peak_trauma: float = 0.0
	cutscene.started.connect(func() -> void: counts[&"cutscene_started"] += 1)
	cutscene.finished.connect(func() -> void: counts[&"cutscene_finished"] += 1)
	ly_collapse.connect(&"collapse_finished", func() -> void: counts[&"collapse_finished"] += 1)

	interactable.interact(_player)

	var deadline_ms: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline_ms:
		peak_trauma = maxf(peak_trauma, ScreenShake.trauma)
		if counts[&"collapse_finished"] > 0 and counts[&"cutscene_finished"] > 0:
			break
		await get_tree().process_frame

	_check(counts[&"cutscene_started"] == 1, "cutscene camera đã kích hoạt sau khi gắn đá (%d)" % counts[&"cutscene_started"])
	_check(peak_trauma >= 0.7, "camera shake mạnh trong lúc sập (peak trauma = %.2f)" % peak_trauma)
	_check(counts[&"collapse_finished"] == 1 and counts[&"cutscene_finished"] == 1, "sập khu vực và cutscene kết thúc trọn vẹn")
	_check(_player.controls_enabled, "trả lại điều khiển cho player sau cutscene")

	var li := _level.get_node(^"LiFoundry") as Node3D
	var south := _level.get_node(^"Connectors/South") as Node3D
	var ly_cp := _level.get_node(^"RoomCheckpoints/Ly") as Node3D
	var south_wall := _level.get_node_or_null(^"Connectors/Hub/SouthSealWall") as Node3D
	_check(not li.visible and li.process_mode == Node.PROCESS_MODE_DISABLED, "LiFoundry bị ẩn và tắt xử lý")
	_check(not south.visible and not _has_enabled_collision(south), "cầu South bị ẩn và tắt va chạm")
	_check(not ly_cp.visible and ly_cp.process_mode == Node.PROCESS_MODE_DISABLED, "checkpoint Ly bị ẩn và tắt xử lý")
	_check(south_wall != null and south_wall.visible and _has_enabled_collision(south_wall), "tường chắn mép Hub hướng Nam bật hiện và va chạm")

	await _frames(2)
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var wall_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.9, 12.0), Vector3(0.0, 0.9, 15.5)))
	_check(not wall_hit.is_empty() and wall_hit["collider"] == south_wall, "va chạm thật: tia từ Hub hướng Nam đụng SouthSealWall")
	var bridge_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 2.0, 21.0), Vector3(0.0, -2.0, 21.0)))
	_check(bridge_hit.is_empty() or bridge_hit["collider"] != south, "va chạm thật: cầu South không còn sàn va chạm")

	var kham := _level.get_node(^"KhamCondenser") as Node3D
	var ton := _level.get_node(^"TonAshenGale") as Node3D
	var chan := _level.get_node(^"ChanThunderAnvil") as Node3D
	_check(kham.visible and ton.visible and chan.visible, "3 khu vực còn lại vẫn nguyên vẹn")


func _t_reload_restores_collapsed_state() -> void:
	await _reload_level()
	var cutscene := _level.get_node_or_null(^"CollapseCutscene") as CameraCutscene
	var counts: Dictionary[StringName, int] = {&"cutscene_started": 0}
	if cutscene != null:
		cutscene.started.connect(func() -> void: counts[&"cutscene_started"] += 1)
	await _frames(10)

	var li := _level.get_node(^"LiFoundry") as Node3D
	var south := _level.get_node(^"Connectors/South") as Node3D
	var ly_cp := _level.get_node(^"RoomCheckpoints/Ly") as Node3D
	var south_wall := _level.get_node_or_null(^"Connectors/Hub/SouthSealWall") as Node3D
	var north_wall := _level.get_node_or_null(^"Connectors/Hub/NorthSealWall") as Node3D

	_check(not li.visible and not south.visible and not ly_cp.visible, "tải lại map: khu Ly + cầu South + checkpoint Ly sập sẵn")
	_check(south_wall != null and south_wall.visible and _has_enabled_collision(south_wall), "tải lại map: tường chắn SouthSealWall bật sẵn")
	_check(north_wall != null and not north_wall.visible, "tải lại map: các hướng chưa đặt đá vẫn mở")
	_check(counts[&"cutscene_started"] == 0, "tải lại map: không chiếu lại cutscene")


func _t_ton_wind_screens_collapse() -> void:
	var ton_collapse := _level.get_node(^"WingCollapses/TonCollapse") as WingCollapseController
	var first_screen := _level.get_node(^"TonAshenGale/WindClusters/First/Screen") as Node3D
	var start_y: float = first_screen.global_position.y
	var data_script: GDScript = load(COLLAPSE_DATA_PATH) as GDScript
	var fast_data: Resource = data_script.new()
	fast_data.set(&"rumble_duration", 0.05)
	fast_data.set(&"stagger_step", 0.0)
	fast_data.set(&"fall_gravity", 150.0)
	fast_data.set(&"max_collapse_duration", 1.0)
	fast_data.set(&"post_fall_hold", 0.0)
	ton_collapse.set(&"data", fast_data)

	var counts: Dictionary[StringName, int] = {&"done": 0}
	var moved_down: Dictionary[StringName, bool] = {&"dropped": false}
	ton_collapse.collapse_finished.connect(func() -> void: counts[&"done"] += 1)
	ton_collapse.trigger_collapse(null)

	var chunks: Array = ton_collapse.get(&"_chunk_nodes") as Array
	_check(first_screen in chunks, "phòng Tốn: bình phong First/Screen nằm trong danh sách mảnh rung và rơi")

	var deadline_ms: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline_ms:
		if first_screen.global_position.y < start_y - 0.5:
			moved_down[&"dropped"] = true
		if counts[&"done"] > 0:
			break
		await get_tree().process_frame

	_check(moved_down[&"dropped"], "phòng Tốn: bình phong First/Screen thật sự rơi xuống theo trục Y")
	_check(counts[&"done"] == 1 and not first_screen.is_visible_in_tree(), "phòng Tốn: bình phong ẩn sau khi sập xong")


func _t_chan_phase2_hides_gates() -> void:
	var chan := _level.get_node(^"ChanThunderAnvil") as ChanThunderAnvil
	var encounter := chan.get_node(^"Encounter") as ChanEncounter
	var tutorial_gate := chan.get_node(^"TutorialGate") as StaticBody3D
	var forge_gate := chan.get_node(^"ForgeGate") as StaticBody3D
	_check(tutorial_gate.visible and forge_gate.visible, "phòng Chấn: ban đầu hai cửa TutorialGate và ForgeGate đang hiện")

	encounter.phase = ChanEncounter.Phase.FULL_ROOM
	encounter.phase_changed.emit(ChanEncounter.Phase.FULL_ROOM)
	await _frames(3)

	_check(not tutorial_gate.visible and tutorial_gate.collision_layer == 0, "phòng Chấn Phase 2: TutorialGate ẩn mesh và tắt va chạm")
	_check(not forge_gate.visible and forge_gate.collision_layer == 0, "phòng Chấn Phase 2: ForgeGate ẩn mesh và tắt va chạm")


func _t_extreme_parameters() -> void:
	var ctrl_script: GDScript = load(COLLAPSE_CONTROLLER_PATH) as GDScript
	var data_script: GDScript = load(COLLAPSE_DATA_PATH) as GDScript
	_check(ctrl_script != null and data_script != null, "tồn tại script WingCollapseController và WingCollapseData")
	if ctrl_script == null or data_script == null:
		return

	# Trường hợp 1: targets rỗng, rumble = 0, stagger = 0, fall_gravity rất lớn
	var ctrl_empty: Node3D = ctrl_script.new() as Node3D
	var data_fast: Resource = data_script.new()
	data_fast.set(&"rumble_duration", 0.0)
	data_fast.set(&"stagger_step", 0.0)
	data_fast.set(&"fall_gravity", 200.0)
	data_fast.set(&"post_fall_hold", 0.0)
	ctrl_empty.set(&"data", data_fast)
	var counts: Dictionary[StringName, int] = {&"empty_done": 0, &"slow_done": 0}
	ctrl_empty.connect(&"collapse_finished", func() -> void: counts[&"empty_done"] += 1)
	add_child(ctrl_empty)
	ctrl_empty.call(&"trigger_collapse", null)
	await _frames(5)
	_check(counts[&"empty_done"] == 1 and bool(ctrl_empty.call(&"is_collapsed")), "thông số cực đoan (0 target, rumble=0): hoàn tất ngay không treo")
	ctrl_empty.queue_free()

	# Trường hợp 2: rơi rất chậm nhưng bị chặn bởi max_collapse_duration
	var dummy_root := Node3D.new()
	var dummy_mesh := MeshInstance3D.new()
	dummy_mesh.mesh = BoxMesh.new()
	dummy_root.add_child(dummy_mesh)
	add_child(dummy_root)

	var ctrl_slow: Node3D = ctrl_script.new() as Node3D
	var data_slow: Resource = data_script.new()
	data_slow.set(&"rumble_duration", 0.05)
	data_slow.set(&"fall_gravity", 2.0)
	data_slow.set(&"sink_y", -500.0)
	data_slow.set(&"max_collapse_duration", 0.2)
	data_slow.set(&"post_fall_hold", 0.05)
	ctrl_slow.set(&"data", data_slow)
	var targets: Array[Node3D] = [dummy_root]
	ctrl_slow.set(&"targets", targets)
	ctrl_slow.connect(&"collapse_finished", func() -> void: counts[&"slow_done"] += 1)
	add_child(ctrl_slow)
	ctrl_slow.call(&"trigger_collapse", null)
	var slow_deadline_ms: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < slow_deadline_ms:
		if counts[&"slow_done"] > 0:
			break
		await get_tree().process_frame
	_check(counts[&"slow_done"] == 1 and not dummy_root.visible, "thông số cực đoan (rơi rất chậm, sink_y=-500): kết thúc đúng max_collapse_duration và ẩn target")
	ctrl_slow.queue_free()
	dummy_root.queue_free()


func _t_hub_seal_z_fighting() -> void:
	var hub := _level.get_node_or_null(^"Connectors/Hub") as Node3D
	_check(hub != null, "có node Connectors/Hub để kiểm tra vệt loang")
	if hub == null:
		return
	var seal_names: PackedStringArray = PackedStringArray(["SouthSealWall", "NorthSealWall", "WestSealWall", "EastSealWall"])
	var seal_meshes: Array[MeshInstance3D] = []
	var other_meshes: Array[MeshInstance3D] = []
	for name_str: String in seal_names:
		var wall := hub.get_node_or_null(name_str) as Node3D
		if wall == null:
			_check(false, "thiếu Hub/%s để quét vệt loang" % name_str)
			return
		wall.visible = true
	_collect_meshes(hub, seal_names, seal_meshes, other_meshes)

	var overlaps: Array[String] = []
	for s: MeshInstance3D in seal_meshes:
		var sa: AABB = _world_aabb(s)
		for o: MeshInstance3D in other_meshes:
			var oa: AABB = _world_aabb(o)
			if not sa.intersects(oa):
				continue
			var inter: AABB = sa.intersection(oa)
			# Chạm mép hoặc chồng < 2cm ở ít nhất một trục là bình thường; chỉ báo nếu xuyên vào trong > 2cm cả 3 trục
			if inter.size.x > 0.02 and inter.size.y > 0.02 and inter.size.z > 0.02:
				overlaps.append("%s <> %s (inter=%s)" % [s.name, o.name, str(inter.size)])
	_check(overlaps.is_empty(), "quét z-fighting 4 tường chắn mép Hub: 0 cặp chồng (%s)" % ", ".join(overlaps))


func _collect_meshes(node: Node, seal_names: PackedStringArray, seal_out: Array[MeshInstance3D], other_out: Array[MeshInstance3D], under_seal: bool = false) -> void:
	var is_seal: bool = under_seal or (node.name in seal_names)
	if node is MeshInstance3D and (node as MeshInstance3D).visible:
		if is_seal:
			seal_out.append(node as MeshInstance3D)
		else:
			other_out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, seal_names, seal_out, other_out, is_seal)


func _world_aabb(mi: MeshInstance3D) -> AABB:
	return mi.global_transform * mi.get_aabb()


func _has_enabled_collision(root: Node) -> bool:
	for node: Node in root.find_children("*", "CollisionShape3D", true, false):
		if not (node as CollisionShape3D).disabled:
			return true
	return false


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1
