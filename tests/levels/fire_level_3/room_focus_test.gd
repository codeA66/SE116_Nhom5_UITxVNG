extends Node
## Nhìn phòng kiểu sinh tồn góc trên xuống (va chạm, input và node thật):
## 1. Biển dung nham một mặt phủ cả map. 15 vùng phòng, mọi phòng luôn hiện hình (không ẩn hẳn).
## 2. Spawn phòng 1: phòng 1 sáng, 14 phòng khác phủ tối. Có cửa sổ: đo điểm ảnh sàn phòng khác tối đi so với khi bỏ phủ.
## 3. Đi bộ thật phòng 6 → hub: trên đường nối giữ phòng 6 sáng; vào hub thì hub sáng, phòng 6 tối.
## 4. Tường phía camera (nam, đông) của phòng đang đứng hạ còn chân; tường bắc / tây giữ nguyên; va chạm tường vẫn còn.
##    Ra phòng khác: tường phòng cũ dựng lại đúng chiều cao.
## 5. Quái: lồng phòng 11 sinh quái khi player vào: quái hiện. Player sang phòng 12: quái phòng 11 ẩn (vẫn chạy AI).
##    Quái ra đường nối (ngoài mọi phòng): hiện. Quái bị giải phóng rồi đổi phòng: không lỗi.
## 6. Cực đoan: shade_alpha 0 / 1 / 5 (kẹp).
## Không ghi save thật. Chạy: godot --headless --path . res://tests/levels/fire_level_3/room_focus_test.tscn (bỏ --headless thêm -- --capture để đo ảnh)

const LEVEL: PackedScene = preload("res://levels/zone_3_fire/level_3/level_3.tscn")

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
	await _frames(40)
	_player.get_node("HurtboxComponent").invulnerable = true
	var focus: RoomFocus = _level.get_node("RoomFocus") as RoomFocus
	# 1
	var sea: MeshInstance3D = _level.get_node_or_null("LavaSea") as MeshInstance3D
	_check(sea != null and (sea.mesh as PlaneMesh).size == Vector2(184, 112), "biển dung nham một mặt phủ cả map")
	_check(focus.get_zones().size() == 15, "15 vùng phòng")
	var all_shown: bool = true
	for z: TierZone in focus.get_zones():
		all_shown = all_shown and focus.get_room(z) != null and focus.get_room(z).is_visible_in_tree()
	_check(all_shown, "mọi phòng luôn hiện hình")
	# 2
	await _seconds(0.5)
	_check(focus.current != null and focus.current.name == &"Room01SpawnZone" and _lit_rooms(focus) == ["Room01Spawn"], "spawn: phòng 1 sáng, phòng khác tối (sáng: %s)" % ", ".join(_lit_rooms(focus)))
	# 3 Đi bộ thật phòng 6 → hub
	_player.teleport(Vector3(104, 4.4, 54), Vector3.RIGHT)
	await _seconds(0.5)
	_check(_lit_rooms(focus) == ["Room06ChokePoint"], "vào phòng 6: phòng 6 sáng")
	var hub_zone: TierZone = focus.get_node("Room07HubZone")
	var on_path: bool = false
	for i: int in range(300):
		_press_towards(Vector3.RIGHT)
		await get_tree().physics_frame
		var x: float = _player.global_position.x
		if x > 109.0 and x < 111.0 and not on_path:
			on_path = true
			_check(focus.current.name == &"Room06ChokePoint" + "Zone", "trên đường nối (x %.1f): giữ phòng 6 sáng" % x)
		if x > 114.0:
			break
	_release()
	await _seconds(0.5)
	_check(on_path and focus.current == hub_zone and _lit_rooms(focus) == ["Room07Hub"], "đi bộ vào hub: hub sáng, phòng 6 tối (%s)" % ", ".join(_lit_rooms(focus)))
	await _seconds(1.5)
	await _capture("focus_hub.png")
	await _measure_shade(focus)
	# 4 Tường: phòng 8 (tường đủ cao)
	_player.teleport(Vector3(114, 8.4, 14))
	await _seconds(0.5)
	var walls8: Node = focus.get_room(focus.get_node("Room08ArenaZone")).get_node("Walls")
	var lowered: int = 0
	var kept_ok: bool = true
	var center: Vector3 = walls8.get_parent().global_position
	for w: Node in walls8.get_children():
		var wall: Node3D = w as Node3D
		var off: Vector3 = wall.global_position - center
		var camera_side: bool = off.x > 1.0 or off.z > 1.0
		if focus.is_wall_lowered(wall):
			lowered += 1
			kept_ok = kept_ok and camera_side and wall.scale.y < 0.3
		elif not camera_side:
			kept_ok = kept_ok and is_equal_approx(wall.scale.y, 1.0)
	_check(lowered > 0 and kept_ok, "phòng 8: hạ %d tường phía camera còn chân, tường bắc / tây giữ" % lowered)
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(114, 9.0, 18), Vector3(114, 9.0, 30), 1))
	_check(not hit.is_empty() and hit.position.z < 24.5, "tường nam phòng 8 đã hạ vẫn chặn (va chạm z %.2f)" % (hit.position.z if not hit.is_empty() else -1.0))
	await _capture("focus_room8_walls.png")
	var a_wall: Node3D = null
	for w: Node in walls8.get_children():
		if focus.is_wall_lowered(w as Node3D):
			a_wall = w as Node3D
			break
	_player.teleport(Vector3(124, 4.4, 48))
	await _seconds(0.5)
	_check(a_wall != null and is_equal_approx(a_wall.scale.y, 1.0) and not focus.is_wall_lowered(a_wall), "rời phòng 8: tường dựng lại đủ cao")
	# 5 Quái
	var cage: SpawnerCage = _level.get_node("Room11/Room11Cage") as SpawnerCage
	_player.teleport(Vector3(68, 0.4, 74))
	await _frames(40)
	var enemy: Enemy = null
	for e: Node in cage.get_node("Enemies").get_children():
		if e is Enemy:
			enemy = e
	_check(enemy != null and enemy.visible, "vào phòng 11: quái lồng hiện")
	if enemy:
		_player.teleport(Vector3(94, 0.4, 80))
		await _frames(20)
		_check(focus.current.name == &"Room12DrainedLavaZone" and not enemy.visible and enemy.can_process(), "sang phòng 12: quái phòng 11 ẩn, vẫn chạy AI")
		enemy.global_position = Vector3(86, 0.4, 78)
		await _frames(10)
		_check(enemy.visible, "quái ra đường nối (ngoài mọi phòng): hiện")
		enemy.global_position = Vector3(70, 0.4, 76)
		await _frames(10)
		_check(not enemy.visible, "quái về phòng 11 (không phải phòng đang đứng): ẩn")
		enemy.free()
		_player.teleport(Vector3(68, 0.4, 74))
		await _frames(10)
		_player.teleport(Vector3(94, 0.4, 80))
		await _frames(10)
		_check(focus.current.name == &"Room12DrainedLavaZone", "quái bị giải phóng rồi đổi phòng: không lỗi")
	# 6 Cực đoan
	focus.set_shade_alpha(1.0)
	_player.teleport(Vector3(124, 4.4, 48))
	await _frames(10)
	var zone6: TierZone = focus.get_node("Room06ChokePointZone")
	_check(focus.is_shaded(zone6) and not focus.is_shaded(hub_zone) and _dark_color(focus, zone6) < 0.001, "shade_alpha 1: phòng khác đen hẳn")
	await _capture("focus_alpha1.png")
	focus.set_shade_alpha(0.0)
	_check(_dark_color(focus, zone6) > 0.0 and is_equal_approx(_dark_color(focus, zone6), _base_color(zone6, focus)), "shade_alpha 0: không tối")
	focus.set_shade_alpha(5.0)
	_check(is_equal_approx(focus.shade_alpha, 1.0), "shade_alpha 5 bị kẹp về 1")
	_finish()


## Có cửa sổ: player đứng giữa phòng 6 (camera nhìn thẳng vào), chuyển sáng sang phòng khác để phòng 6 tối,
## so độ sáng trung bình lưới điểm sàn quanh player (bỏ vùng HUD góc trái và chính player) khi bật / tắt
func _measure_shade(focus: RoomFocus) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP đo điểm ảnh: headless")
		return
	_player.teleport(Vector3(102, 4.4, 54))
	await _seconds(1.5)
	var zone6: TierZone = focus.get_node("Room06ChokePointZone")
	focus.focus(focus.get_node("Room07HubZone"))
	var cam: Camera3D = get_viewport().get_camera_3d()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var pixels: Array[Vector2i] = []
	for x: float in [98.0, 100.0, 104.0, 106.0]:
		for z: float in [50.0, 52.0, 56.0, 58.0]:
			var p: Vector2 = cam.unproject_position(Vector3(x, 4.32, z))
			if p.x > 320 and p.y > 260 and p.x < size.x - 2 and p.y < size.y - 2:
				pixels.append(Vector2i(p))
	await _frames(3)
	await RenderingServer.frame_post_draw
	var dark: float = _avg(get_viewport().get_texture().get_image(), pixels)
	await _capture("focus_room6_shaded.png")
	focus.enabled = false
	await _frames(3)
	await RenderingServer.frame_post_draw
	var bright: float = _avg(get_viewport().get_texture().get_image(), pixels)
	await _capture("focus_room6_lit.png")
	focus.enabled = true
	var ratio: float = dark / maxf(bright, 0.001)
	_check(focus.is_shaded(zone6) and pixels.size() > 3 and ratio < 0.6 and ratio > 0.1, "sàn phòng 6 khi tối (alpha %.2f): %d điểm, độ sáng %.3f -> %.3f, còn %.0f%%" % [focus.shade_alpha, pixels.size(), bright, dark, ratio * 100.0])
	focus.focus(zone6)


func _avg(img: Image, pixels: Array[Vector2i]) -> float:
	var sum: float = 0.0
	for px: Vector2i in pixels:
		sum += img.get_pixelv(px).get_luminance()
	return sum / maxf(pixels.size(), 1)


## Độ sáng màu vật liệu đang dùng của mesh đầu tiên có BaseMaterial3D trong phòng
func _dark_color(focus: RoomFocus, zone: TierZone) -> float:
	for m: Node in focus.get_room(zone).find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		if mat:
			return mat.albedo_color.get_luminance()
	return -1.0


func _base_color(zone: TierZone, focus: RoomFocus) -> float:
	for m: Node in focus.get_room(zone).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.get_active_material(0) is BaseMaterial3D:
			var base := (mi.mesh.surface_get_material(0) if mi.mesh else null) as BaseMaterial3D
			return base.albedo_color.get_luminance() if base else -2.0
	return -1.0


func _lit_rooms(focus: RoomFocus) -> Array[String]:
	var out: Array[String] = []
	for z: TierZone in focus.get_zones():
		if not focus.is_shaded(z):
			out.append(String(z.name).trim_suffix("Zone"))
	return out


func _press_towards(world_dir: Vector3) -> void:
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	_set_axis(&"move_right", &"move_left", world_dir.dot(right))
	_set_axis(&"move_back", &"move_forward", -world_dir.dot(forward))


func _set_axis(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.05:
		Input.action_press(positive, clampf(value, 0.0, 1.0))
	elif value < -0.05:
		Input.action_press(negative, clampf(-value, 0.0, 1.0))


func _release() -> void:
	for a: StringName in [&"move_right", &"move_left", &"move_forward", &"move_back"]:
		Input.action_release(a)


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	print("ROOM FOCUS RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)


func _capture(file: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/fire_level_3/qa/" + file)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().physics_frame
