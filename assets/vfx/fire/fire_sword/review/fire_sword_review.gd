extends Node
## DONE 2026-10-31: test hook generic trong sandbox RAM, không lưu scene hay save.
## NOT DONE: không thay cho kiểm tra instance do người dùng gắn vào Player.
## NOTES: --output= đường dẫn ảnh/log, --dark đổi nền; đo không xen chụp ảnh.
var fails: int = 0
var output: String = "user://fire_sword_review"
var dark: bool = false
var player: Player
var vfx: Node3D
var samples: PackedFloat64Array = PackedFloat64Array()

## Chờ autoload sẵn rồi dựng sandbox thật, gắn scene mới chỉ trong RAM.
func _ready() -> void:
	_run.call_deferred()

## Chạy cả lọc nguyên tố, combo bất kỳ, kích thước và reset sau ba giây.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--dark": dark = true
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var level: Node = (load("res://tests/fire/sandbox/fire_sandbox.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(level)
	await get_tree().create_timer(1.0).timeout
	player = level.get_node("Player") as Player
	player.set_controls_enabled(false)
	for node: Node in level.get_children():
		if node is Enemy:
			node.set_physics_process(false)
			node.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	var floor_mesh: MeshInstance3D = level.get_node("Floor/MeshInstance3D") as MeshInstance3D
	var floor_mat: StandardMaterial3D = floor_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	floor_mat.albedo_color = Color(0.06,0.07,0.09) if dark else Color(0.72,0.70,0.65)
	floor_mesh.material_override = floor_mat
	if dark:
		_setup_palace(level, floor_mesh)
	vfx = (load("res://assets/vfx/fire/fire_sword/fire_sword_vfx.tscn") as PackedScene).instantiate() as Node3D
	vfx.set("player", player)
	player.add_child(vfx)
	for frame: int in range(5):
		await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.02).timeout
	var arc: MeshInstance3D = vfx.get_node("Arc") as MeshInstance3D
	var echo: MeshInstance3D = vfx.get_node("Echo") as MeshInstance3D
	var embers: CPUParticles3D = vfx.get_node("Embers") as CPUParticles3D
	_check(not arc.visible and not vfx.is_processing(), "idle sau warmup không vẽ")
	var attack: AttackData = player.get_weapon().combo[0]
	player.fusion_melee_swing.emit(&"wind", attack, 2, 3, Vector3.FORWARD, 0.12)
	_check(not arc.visible and not embers.emitting, "wind bị bỏ qua")
	player.fusion_melee_swing.emit(&"", attack, 0, 3, Vector3.FORWARD, 0.12)
	_check(not arc.visible, "không nguyên tố không có lửa")
	var normal_scale: float = 0.0
	for index: int in [0, 2]:
		player.fusion_melee_swing.emit(&"fire", player.get_weapon().combo[index], index, 3, Vector3(1,0,1).normalized(), 0.12)
		_check((vfx.get_node("Flash") as MeshInstance3D).visible == (index == 2), "chớp chỉ xuất hiện ở finisher")
		await get_tree().create_timer(0.09).timeout
		_check(not (vfx.get_node("Flash") as MeshInstance3D).visible, "chớp đã tắt đúng nhịp")
		_check(arc.visible and echo.visible == (index == 2), "fire %d/3 đúng lớp cung" % index)
		_check(embers.amount < (60 if index == 2 else 30), "ngân sách hạt %d" % index)
		if index == 0: normal_scale = arc.scale.x
		else: _check(arc.scale.x > normal_scale, "finisher lớn hơn nhát thường")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("swing_%d.png" % index))
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("after_half_%d.png" % index))
		await get_tree().create_timer(2.5).timeout
		_check(not arc.visible and not echo.visible and not embers.visible and not vfx.is_processing(), "3 giây sạch và nghỉ")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("after_three_%d.png" % index))
	player.fusion_melee_swing.emit(&"fire", attack, 1, 2, Vector3.FORWARD, 0.08)
	_check(echo.visible, "combo 2 đòn: nhát 1/2 là finisher")
	vfx.call("reset")
	var weapon: WeaponData = player.get_weapon()
	var original: float = weapon.attack_range
	for reach: float in [0.5, 8.0]:
		weapon.attack_range = reach
		player.fusion_melee_swing.emit(&"fire", attack, 2, 3, Vector3(1,0,1).normalized(), 0.12)
		await get_tree().create_timer(0.09).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("reach_%.1f.png" % reach))
		vfx.call("reset")
	weapon.attack_range = original
	samples.resize(4000)
	await _measure("idle", attack, -1)
	await _measure("normal", attack, 0)
	await _measure("finisher", attack, 2)
	print("FIRE_SWORD_RESULT fails=", fails)
	get_tree().quit(1 if fails else 0)

## Phép đo chỉ ghi vào mảng giữ sẵn; không chụp hoặc ghi file trong cửa sổ đo.
func _measure(label: String, attack: AttackData, combo: int) -> void:
	await get_tree().create_timer(0.7).timeout
	if combo >= 0: player.fusion_melee_swing.emit(&"fire", player.get_weapon().combo[combo], combo, 3, Vector3(1,0,1).normalized(), 0.12)
	var last: int = Time.get_ticks_usec()
	var start: int = last
	var count: int = 0
	while Time.get_ticks_usec() - start < 700000 and count < samples.size():
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		samples[count] = float(now - last) / 1000.0
		last = now
		count += 1
	var total: float = 0.0
	var worst: float = 0.0
	for i: int in range(count):
		total += samples[i]
		worst = maxf(worst, samples[i])
	print("SWORD_PERF ", label, " fps=", 1000.0 * count / total, " worst_ms=", worst)

## Assertion không dừng sớm để thấy đủ mọi lỗi vòng đời.
func _check(passed: bool, label: String) -> void:
	if not passed: fails += 1
	print("PASS " if passed else "FAIL ", label)


## Chép phần nhìn của phòng thật vào sân review, không chạy script phòng hoặc lưu scene.
func _setup_palace(level: Node, floor_mesh: MeshInstance3D) -> void:
	var source: Node = (load("res://levels/zone_1_wind/level_1/rooms/tier_2/t2_room_26_treasure.scn") as PackedScene).instantiate()
	var geometry: Node3D = Node3D.new()
	level.add_child(geometry)
	_copy_geometry(source, Transform3D.IDENTITY, geometry, true)
	var area: float = 0.0
	var floor_bounds: AABB
	for child: Node in geometry.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		if bounds.size.y < 1.0 and bounds.size.x * bounds.size.z > area:
			area = bounds.size.x * bounds.size.z
			floor_bounds = bounds
	if area > 0.0:
		geometry.position = -Vector3(floor_bounds.get_center().x, floor_bounds.end.y, floor_bounds.get_center().z)
	floor_mesh.hide()
	var environment: Environment = (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_energy = 0.35
	(level.get_node("Sun") as DirectionalLight3D).light_energy = 0.6
	source.free()

## Giữ transform và material gốc; bỏ các nhánh vốn không hiển thị.
func _copy_geometry(node: Node, parent_transform: Transform3D, destination: Node3D, parent_visible: bool) -> void:
	var transform: Transform3D = parent_transform
	var shown: bool = parent_visible
	if node is Node3D:
		transform *= (node as Node3D).transform
		shown = shown and (node as Node3D).visible
	if not shown:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var original: MeshInstance3D = node as MeshInstance3D
		var copy: MeshInstance3D = MeshInstance3D.new()
		copy.mesh = original.mesh
		copy.material_override = original.material_override
		copy.transform = transform
		destination.add_child(copy)
	for child: Node in node.get_children():
		_copy_geometry(child, transform, destination, shown)
