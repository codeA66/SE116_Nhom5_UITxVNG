extends Node
## DONE 2026-10-31: kiểm tra signal trên Player thật trong RAM, không sửa scene hoặc save.
## NOT DONE: chờ gắn instance production và duyệt hình ảnh.
## NOTES: --dark dùng hình học cung điện; --output= lưu ảnh/log; đo không xen chụp.
var player: Player
var vfx: Node3D
var fails: int = 0
var output: String = "user://fire_bow_review"
@export var closeup_fov: float = 28.0
var motion: bool = false
var closeup: bool = false
var dark: bool = false
var samples: PackedFloat64Array = PackedFloat64Array()

## Chờ autoload sẵn trước khi nạp sân thử.
func _ready() -> void:
	_run.call_deferred()

## Kéo/buông/hủy, kiểm tra offset với TipSparks thật; chỉ gắn instance trong RAM.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--dark": dark = true
		if arg == "--closeup": closeup = true
		if arg == "--motion": motion = true
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var level: Node = (load("res://tests/fire/sandbox/fire_sandbox.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(level)
	await get_tree().create_timer(1.0).timeout
	player = level.get_node("Player") as Player
	player.set_controls_enabled(false)
	if closeup: (player.get_node("CameraRig/Camera3D") as Camera3D).fov = closeup_fov
	player.face_instantly(Vector3(1,0,1).normalized())
	for node: Node in level.get_children():
		if node is Enemy:
			node.set_physics_process(false)
			node.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	var floor_mesh: MeshInstance3D = level.get_node("Floor/MeshInstance3D") as MeshInstance3D
	var mat: StandardMaterial3D = floor_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.72,0.70,0.65)
	floor_mesh.material_override = mat
	if dark: _setup_palace(level, floor_mesh)
	_check(GameState.fuse(&"fire",WeaponData.Slot.BOW),"setup: ghép Fire Bow thật")
	vfx = player.get_node_or_null("FireBowVfx") as Node3D
	if vfx == null:
		vfx = (load("res://assets/vfx/fire/fire_bow/fire_bow_vfx.tscn") as PackedScene).instantiate() as Node3D
		vfx.set("player",player)
		player.add_child(vfx)
	var flame: MeshInstance3D = vfx.get_node("Flame") as MeshInstance3D
	var gather: CPUParticles3D = vfx.get_node("Gather") as CPUParticles3D
	var burst: CPUParticles3D = vfx.get_node("Release") as CPUParticles3D
	for frame: int in range(5):
		await RenderingServer.frame_post_draw
		if frame == 0: await _capture("warmup")
	_check(not flame.visible and not vfx.is_processing(),"idle sau warmup ẩn và nghỉ")
	_check(not (vfx.get_node("Coils") as MeshInstance3D).visible,"cuộn lửa ẩn khi idle")
	var core: Color = vfx.get("core_color")
	_check(core.r > core.g*2.0 and core.b < 0.4,"lõi đỏ cam, không trắng")
	player.fusion_bow_draw.emit(&"wind",1.0)
	_check(not flame.visible and not gather.emitting,"wind không phát lửa")
	player.begin_bow_aim()
	var tip: Node3D = player.find_child("NockedArrow",true,false).get_node("TipSparks") as Node3D
	var previous_size: float = 0.0
	for amount: float in [0.0,0.5,1.0]:
		_draw(amount)
		await get_tree().create_timer(0.08).timeout
		_check(vfx.global_position.distance_to(tip.global_position)<0.005,"neo đầu tên thật mức %.1f" % amount)
		_check(flame.visible and gather.emitting,"tụ lực hiện mức %.1f" % amount)
		_check(flame.scale.length()>previous_size,"silhouette tăng theo mức kéo")
		previous_size=flame.scale.length()
		await _capture("draw_%.1f" % amount)
	if motion:
		var camera: Camera3D = Camera3D.new()
		level.add_child(camera)
		var focus: Vector3 = vfx.global_position
		camera.position = focus + Vector3(2.5,5.5,3.0)
		camera.fov = 40.0
		camera.look_at(focus)
		camera.make_current()
		for frame: int in range(24):
			_draw(1.0)
			await _capture("coil_%02d" % frame)
			await get_tree().create_timer(0.025).timeout
		camera.queue_free()
		(player.get_node("CameraRig/Camera3D") as Camera3D).make_current()
	var body_mat: ShaderMaterial = flame.material_override as ShaderMaterial
	for frame: int in range(30):
		_draw(1.0)
		await get_tree().create_timer(0.01).timeout
	_check(float(body_mat.get_shader_parameter("pulse"))<0.01,"giữ full không reset ready mỗi frame")
	_check(gather.amount+burst.amount<40,"tổng ngân sách dưới 40 hạt")
	_check(vfx.find_children("*","Light3D",true,false).is_empty(),"VFX không có đèn")
	player.fusion_bow_released.emit(&"fire")
	player.fusion_bow_draw.emit(&"fire",0.0)
	await get_tree().create_timer(0.04).timeout
	_check(not gather.emitting and burst.visible,"released rồi draw(0) không bật lại tụ lực")
	await _capture("release")
	player.fusion_bow_aim_ended.emit(&"fire")
	await _check_clean("after_shot")
	player.begin_bow_aim()
	_draw(0.6)
	await get_tree().create_timer(0.10).timeout
	player.fusion_bow_aim_ended.emit(&"fire")
	await _check_clean("cancel")
	# Đổi lượt trước khi fade cũ hết không được bị callback cũ dọn mất.
	player.begin_bow_aim()
	_draw(0.4)
	player.fusion_bow_aim_ended.emit(&"fire")
	_draw(0.7)
	await get_tree().create_timer(0.25).timeout
	_check(flame.visible and gather.emitting,"lượt mới sống qua fade cũ")
	vfx.call("reset")
	# Một instance mới nhận hook ngay giữa warmup phải giữ được lượt thật.
	var probe: Node3D = (load("res://assets/vfx/fire/fire_bow/fire_bow_vfx.tscn") as PackedScene).instantiate() as Node3D
	probe.set("player",player)
	player.add_child(probe)
	_draw(0.8)
	for frame: int in range(5): await RenderingServer.frame_post_draw
	_check((probe.get_node("Flame") as MeshInstance3D).visible and probe.is_processing(),"hook giữa warmup không bị cleanup mất")
	player.fusion_bow_released.emit(&"fire")
	player.fusion_bow_aim_ended.emit(&"fire")
	await get_tree().create_timer(0.3).timeout
	_check(not probe.is_processing() and not (probe.get_node("Release") as CPUParticles3D).visible,"release và aim_ended cùng frame dọn sạch")
	probe.queue_free()
	samples.resize(5000)
	await _measure("idle")
	_draw(1.0)
	await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(2.0).timeout
	(vfx.get_node("Coils") as MeshInstance3D).hide()
	await _measure("full_without_coils")
	(vfx.get_node("Coils") as MeshInstance3D).show()
	await _measure("full_hold")
	(vfx.get_node("Coils") as MeshInstance3D).hide()
	await _measure("full_without_coils_repeat")
	(vfx.get_node("Coils") as MeshInstance3D).show()
	await _measure("full_hold_repeat")
	player.fusion_bow_released.emit(&"fire")
	await _measure("release")
	player.fusion_bow_aim_ended.emit(&"fire")
	await get_tree().create_timer(0.3).timeout
	_check(not vfx.is_processing(),"cuối bài nghỉ xử lý")
	print("FIRE_BOW_RESULT fails=",fails)
	get_tree().quit(1 if fails else 0)

## Đổi cả hình cung gốc và signal generic, không sửa BowVisual.
func _draw(amount: float) -> void:
	player.set_bow_draw(amount)

## Ảnh chụp trực tiếp viewport, ngoài các cửa sổ đo.
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))

## Kiểm tra sau deadline và ba giây, không để hạt hoặc mesh sót sau hủy.
func _check_clean(label: String) -> void:
	player.end_bow_aim()
	await get_tree().create_timer(0.5).timeout
	await _capture(label+"_half")
	await get_tree().create_timer(2.5).timeout
	_check(not (vfx.get_node("Coils") as MeshInstance3D).visible and not (vfx.get_node("Flame") as MeshInstance3D).visible and not (vfx.get_node("Gather") as CPUParticles3D).visible and not (vfx.get_node("Release") as CPUParticles3D).visible and not vfx.is_processing(),label+" sạch sau 3 giây")
	await _capture(label+"_three")

## Chỉ ghi số vào mảng sẵn có; không readback ảnh hoặc ghi file trong phép đo.
func _measure(label: String) -> void:
	var last: int=Time.get_ticks_usec()
	var start: int=last
	var count: int=0
	while Time.get_ticks_usec()-start<700000 and count<samples.size():
		await get_tree().process_frame
		var now: int=Time.get_ticks_usec()
		samples[count]=float(now-last)/1000.0
		last=now
		count+=1
	var total: float=0.0
	var worst: float=0.0
	for i: int in range(count):
		total+=samples[i]
		worst=maxf(worst,samples[i])
	print("BOW_PERF ",label," fps=",1000.0*count/total," worst_ms=",worst)

## Ghi đủ ca lỗi trước khi trả exit code.
func _check(passed: bool,label: String) -> void:
	if not passed: fails+=1
	print("PASS " if passed else "FAIL ",label)

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
