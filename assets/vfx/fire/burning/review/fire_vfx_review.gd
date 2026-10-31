extends Node3D
## DONE 2026-10-30: review độc lập, không ghi save hoặc sửa scene gameplay.
## NOT DONE: số đo chỉ đại diện máy chạy review, không bảo đảm bản phát hành cache sạch.
## NOTES: --case=burn|wind|vortex|wind_only|lifecycle, --bench, --dark, --radius=, --length=, --width=.
## UC1/TC1: gió thuần bắt đầu/dừng/lặp dừng -> mọi frame đều không có lửa.
## UC2/TC2: caught_fire -> sáng và phát hạt; stopped -> tàn hết, nghỉ xử lý.
## UC3/TC3: stopped lặp trong lúc tàn -> opacity không tăng lại.
## UC4/TC4: started khi đang tàn -> xóa lửa cũ; lượt gió thuần tiếp theo luôn tối.
## Unit test lifecycle cô lập VFX bằng signal; wind_only kiểm tra thêm vòng đời hố thật.
@export_group("Review")
@export var output: String = "user://fire_family_review"
@export var wait_before: float = 2.0
@export var samples: Array[float] = [0.06, 0.18, 0.4, 0.8]
@export var benchmark_duration: float = 1.0
var _burns: Array[BurnableComponent] = []
var _wind: FireWind
var _vortex: WindVortex
var _fire: FireVortex
var _case: String = "burn"
var _palace: bool = false
var _bench: bool = false
var _frames: int = 0
var _sum: float = 0.0
var _max: float = 0.0
var _last: int = 0
var _measuring: bool = false
var _radius: float = 2.5
var _length: float = 5.0
var _width: float = 2.5
var _test_fails: int = 0

## Tạo phòng thử chỉ có hình ảnh và component thật, dùng signal công khai để phát VFX.
func _ready() -> void:
	set_process(false)
	var dark: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): _case = arg.trim_prefix("--case=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--radius="): _radius = arg.trim_prefix("--radius=").to_float()
		if arg.begins_with("--length="): _length = arg.trim_prefix("--length=").to_float()
		if arg.begins_with("--width="): _width = arg.trim_prefix("--width=").to_float()
		if arg == "--bench": _bench = true
		if arg == "--dark": dark = true
		if arg == "--palace": _palace = true
	if _case in ["lifecycle", "lifecycle_original"]:
		await _test_lifecycle(_case == "lifecycle_original")
		get_tree().quit(1 if _test_fails > 0 else 0)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_setup_stage(dark)
	if _palace: _setup_palace()
	if _case == "burn": _setup_burning()
	if _case == "wind":
		_wind = (load("res://components/elements/fire/fire_wind/fire_wind.tscn") as PackedScene).instantiate() as FireWind
		_wind.position.z = -4.0
		add_child(_wind)
	if _case in ["vortex", "wind_only"]:
		_vortex = (load("res://abilities/fusion/moves/wind_vortex.tscn") as PackedScene).instantiate() as WindVortex
		_vortex.radius = _radius
		_vortex.finished.connect(_on_review_vortex_finished)
		add_child(_vortex)
		_fire = _vortex.get_node("FireVortex") as FireVortex
	await get_tree().create_timer(wait_before).timeout
	if _bench and _vortex:
		# Lấy nền khi lớp gió đã chạy, để đo riêng chi phí thêm lửa.
		_vortex.lifetime = benchmark_duration * 2.0 + wait_before
		_vortex.perform(null, null, Vector3.FORWARD)
		await get_tree().create_timer(wait_before).timeout
	if _bench:
		_begin()
		await get_tree().create_timer(benchmark_duration).timeout
		_end("baseline")
		_begin()
	_activate()
	if _case == "wind_only":
		var vfx: FireVortexVfx = _fire.get_node("Vfx") as FireVortexVfx
		await _test_hidden_for(vfx, _vortex.lifetime * 0.5, "TC1 integration: gió thuần đang chạy")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("wind_only_active.png"))
		await _test_hidden_for(vfx, _vortex.lifetime * 0.5 + 0.03, "TC1 integration: gió thuần vừa dừng")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("wind_only_stopping.png"))
		await _test_hidden_for(vfx, _vortex.linger + 0.1, "TC1 integration: gió thuần đã kết thúc")
		print("WIND_ONLY_RESULT fails=", _test_fails)
		get_tree().quit(1 if _test_fails > 0 else 0)
		return
	if _bench:
		await get_tree().create_timer(benchmark_duration).timeout
		_end(_case)
	else:
		var start: int = Time.get_ticks_usec()
		var images: Array[Image] = []
		for stamp: float in samples:
			while float(Time.get_ticks_usec() - start) / 1000000.0 < stamp:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			images.append(get_viewport().get_texture().get_image())
		for i: int in range(images.size()):
			images[i].save_png(output.path_join(_case + "_%.2f.png" % samples[i]))
	if _vortex:
		_vortex.stopped.emit()
	for burn: BurnableComponent in _burns:
		burn.extinguish()
	await get_tree().create_timer(0.3).timeout
	print("REVIEW_COMPLETE ", _case)
	get_tree().quit()

## Giữ hố thật sống hết thời gian quan sát, giống listener của pool trong gameplay.
func _on_review_vortex_finished() -> void:
	pass

## Chỉ đưa VFX vào cây; hai nguồn signal không chạy gameplay, vật lý hoặc tự hủy.
func _test_lifecycle(original_stop: bool = false) -> void:
	var source: WindVortex = WindVortex.new()
	var fire: FireVortex = FireVortex.new()
	fire.vortex = source
	var vfx: FireVortexVfx = (load("res://assets/vfx/fire/fire_vortex/fire_vortex_vfx.tscn") as PackedScene).instantiate() as FireVortexVfx
	if original_stop:
		# Đối chứng lỗi cũ trong RAM; không đổi file production hoặc làm editor hot-reload.
		var original: GDScript = GDScript.new()
		original.source_code = "extends FireVortexVfx\nfunc _on_stopped() -> void:\n\t_lit = false\n\t_ring.emitting = false\n\t_fade = fade_time\n\tset_process(true)\n"
		if original.reload() != OK:
			_test_check(false, "Không tạo được đối chứng logic cũ")
			vfx.free()
			fire.free()
			source.free()
			return
		vfx.set_script(original)
	vfx.fire_vortex = fire
	add_child(vfx)
	# Đợi chuẩn bị GPU xong để chỉ đo trạng thái combat.
	if DisplayServer.get_name() != "headless":
		for frame: int in range(vfx.prepare_frames + 1):
			await RenderingServer.frame_post_draw
	await _test_hidden_for(vfx, 0.03, "TC1a: chưa kích hoạt")
	source.started.emit(source.radius, source.lifetime)
	await _test_hidden_for(vfx, 0.03, "TC1b: gió thuần đang chạy")
	source.stopped.emit()
	await _test_hidden_for(vfx, vfx.fade_time + 0.04, "TC1c: gió thuần dừng không lóe lửa")
	source.stopped.emit()
	await _test_hidden_for(vfx, vfx.fade_time + 0.04, "TC1d: gió thuần dừng lặp")
	source.started.emit(source.radius, source.lifetime)
	fire.caught_fire.emit()
	await get_tree().create_timer(vfx.ignition_time + 0.03).timeout
	var particles: GPUParticles3D = vfx.get_node("Ring") as GPUParticles3D
	_test_check(_test_opacity(vfx) > 0.9 and particles.emitting, "TC2a: bắt lửa -> mesh sáng và phát hạt")
	source.stopped.emit()
	await get_tree().create_timer(vfx.fade_time * 0.4).timeout
	var before: float = _test_opacity(vfx)
	_test_check(before > 0.0 and before < 1.0 and not particles.emitting, "TC2b: dừng lửa -> đang tàn, ngừng phát hạt mới")
	source.stopped.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_test_check(_test_opacity(vfx) <= before + 0.001, "TC3: dừng lặp không tăng opacity")
	await get_tree().create_timer(vfx.fade_time + 0.03).timeout
	_test_check(is_zero_approx(_test_opacity(vfx)) and not vfx.is_processing(), "TC2c: tàn hết -> opacity 0 và nghỉ xử lý")
	source.started.emit(source.radius, source.lifetime)
	fire.caught_fire.emit()
	await get_tree().create_timer(vfx.ignition_time + 0.03).timeout
	source.stopped.emit()
	# Pool tái dùng ngay lúc lượt cũ còn đang tàn.
	source.started.emit(source.radius, source.lifetime)
	await _test_hidden_for(vfx, vfx.fade_time + 0.04, "TC4a: tái dùng xóa lửa đang tàn")
	source.stopped.emit()
	await _test_hidden_for(vfx, vfx.fade_time + 0.04, "TC4b: lượt gió thuần tiếp theo dừng không có lửa")
	vfx.free()
	fire.free()
	source.free()
	print("LIFECYCLE_RESULT fails=", _test_fails)

## Quan sát mọi frame vì chờ tới cuối fade sẽ bỏ sót lóe lửa thoáng qua.
func _test_hidden_for(vfx: FireVortexVfx, seconds: float, label: String) -> void:
	var particles: GPUParticles3D = vfx.get_node("Ring") as GPUParticles3D
	var until: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	var hidden: bool = true
	while Time.get_ticks_usec() < until:
		hidden = hidden and is_zero_approx(_test_opacity(vfx)) and not particles.emitting
		await get_tree().process_frame
	_test_check(hidden and is_zero_approx(_test_opacity(vfx)) and not particles.emitting, label)

## Đọc đầu ra renderer thay vì suy từ biến trạng thái private.
func _test_opacity(vfx: FireVortexVfx) -> float:
	var surface: MeshInstance3D = vfx.get_node("FireSurface") as MeshInstance3D
	return float((surface.material_override as ShaderMaterial).get_shader_parameter(&"opacity"))

## Tích lũy lỗi và thoát khác 0, không dừng coroutine giữa chừng như assert.
func _test_check(passed: bool, label: String) -> void:
	if not passed:
		_test_fails += 1
	print("PASS " if passed else "FAIL ", label)

## Màu nền được đổi ở scene review, không ghi đè tài nguyên của map.
func _setup_stage(dark: bool) -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.07, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	var floor: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40,40)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.07,0.08,0.10) if dark else Color(0.65,0.65,0.62)
	plane.material = mat
	floor.mesh = plane
	add_child(floor)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-30,0)
	sun.light_energy = 0.8
	add_child(sun)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(16.0, maxf(_radius * 2.8, _length * 1.5))
	camera.position = Vector3(10,16,14)
	add_child(camera)
	camera.look_at(Vector3(0,0.5,0))
	camera.current = true

## Tám mục tiêu có collider khác nhau, gồm một thùng và một mục tiêu lớn.
func _setup_burning() -> void:
	for i: int in range(8):
		var target: StaticBody3D = StaticBody3D.new()
		target.position = Vector3(float(i % 4) * 2.6 - 3.9,0,float(i / 4) * 3.5 - 1.75)
		var height: float = 3.6 if i == 7 else 1.8
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = height * 0.22
		capsule.height = height
		mesh.mesh = capsule
		mesh.position.y = height * 0.5
		target.add_child(mesh)
		var collider: CollisionShape3D = CollisionShape3D.new()
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.radius = capsule.radius
		shape.height = height
		collider.shape = shape
		collider.position.y = height * 0.5
		target.add_child(collider)
		if i == 0:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh.mesh = box
			mesh.position.y = 0.5
			var box_shape: BoxShape3D = BoxShape3D.new()
			box_shape.size = Vector3.ONE
			collider.shape = box_shape
			collider.position.y = 0.5
		var burn: BurnableComponent = BurnableComponent.new()
		burn.data = (load("res://resources/combat/fire/burn_default.tres") as BurnData).duplicate() as BurnData
		burn.data.duration = 5.0
		burn.match_shape_of = collider
		target.add_child(burn)
		var vfx: BurningVfx = (load("res://assets/vfx/fire/burning/burning_vfx.tscn") as PackedScene).instantiate() as BurningVfx
		vfx.burnable = burn
		burn.add_child(vfx)
		add_child(target)
		_burns.append(burn)

## Chỉ phát signal tương đương gameplay; không tự gây sát thương hay ghi progress.
func _activate() -> void:
	for burn: BurnableComponent in _burns: burn.ignite()
	if _wind: _wind.fired.emit(2.0,_length,_width)
	if _vortex:
		if not _bench:
			_vortex.perform(null, null, Vector3.FORWARD)
		if _case != "wind_only":
			_fire.caught_fire.emit()

## Bắt đầu cửa sổ đo không chụp ảnh.
func _begin() -> void:
	_frames = 0
	_sum = 0.0
	_max = 0.0
	_last = Time.get_ticks_usec()
	_measuring = true
	set_process(true)

## Ghi cả đỉnh khung và trung bình, không suy từ bộ đếm FPS trễ.
func _end(label: String) -> void:
	_measuring = false
	set_process(false)
	print("BENCH ",label," frames=",_frames," mean_ms=",_sum/maxf(float(_frames),1.0)," worst_ms=",_max," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

## Chỉ tích lũy scalar để đo không tự gây cấp phát mỗi khung.
func _process(_delta: float) -> void:
	if not _measuring: return
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last) / 1000.0
	_last = now
	_frames += 1
	_sum += ms
	_max = maxf(_max,ms)


## Chỉ chép mesh của phòng thật vào sân review; không chạy script hoặc lưu lại scene nguồn.
func _setup_palace() -> void:
	var source: Node = (load("res://levels/zone_1_wind/level_1/rooms/tier_2/t2_room_26_treasure.scn") as PackedScene).instantiate()
	var visual: Node3D = Node3D.new()
	add_child(visual)
	_copy_geometry(source, Transform3D.IDENTITY, visual)
	var largest: float = 0.0
	var floor_bounds: AABB
	for child: Node in visual.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		var area: float = bounds.size.x * bounds.size.z
		if bounds.size.y < 1.0 and area > largest:
			largest = area
			floor_bounds = bounds
	if largest > 0.0:
		visual.position = -Vector3(floor_bounds.get_center().x, floor_bounds.end.y, floor_bounds.get_center().z)
	source.free()
	print("PALACE_GEOMETRY meshes=",visual.get_child_count())

## Giữ mesh và material gốc theo tham chiếu, không sửa tài nguyên của map.
func _copy_geometry(node: Node, parent_transform: Transform3D, destination: Node3D) -> void:
	var accumulated: Transform3D = parent_transform
	if node is Node3D:
		accumulated *= (node as Node3D).transform
	if node is MeshInstance3D:
		var original: MeshInstance3D = node as MeshInstance3D
		if original.mesh:
			var copy: MeshInstance3D = MeshInstance3D.new()
			copy.mesh = original.mesh
			copy.material_override = original.material_override
			copy.transform = accumulated
			destination.add_child(copy)
	for child: Node in node.get_children():
		_copy_geometry(child, accumulated, destination)
