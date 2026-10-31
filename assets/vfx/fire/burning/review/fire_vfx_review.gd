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
var _repeat_wind: bool = false
var _repeat_clock: float = 0.0

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
	if _bench:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if _case in ["lifecycle", "lifecycle_original"]:
		await _test_lifecycle(_case == "lifecycle_original")
		get_tree().quit(1 if _test_fails > 0 else 0)
		return
	if _case == "startup":
		await _test_startup()
		get_tree().quit(1 if _test_fails else 0)
		return
	if _case == "anchor_unit":
		await _test_anchor()
		get_tree().quit(1 if _test_fails else 0)
		return
	if _case == "status_unit":
		_setup_burning()
		await _test_status_readability()
		get_tree().quit(1 if _test_fails else 0)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_setup_stage(dark)
	if _palace: _setup_palace()
	if _case == "burn": _setup_burning()
	if _case == "crowd": _setup_crowd()
	if _case == "wind":
		_wind = (load("res://components/elements/fire/fire_wind/fire_wind.tscn") as PackedScene).instantiate() as FireWind
		_wind.position.z = -4.0
		add_child(_wind)
	if _case in ["vortex", "wind_only"]:
		_vortex = (load("res://abilities/fusion/wind/moves/wind_vortex.tscn") as PackedScene).instantiate() as WindVortex
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
	if _case == "crowd":
		await _review_crowd()
		return
	if _bench:
		_begin()
		await get_tree().create_timer(benchmark_duration).timeout
		_end("baseline")
		_begin()
	_repeat_wind = _bench and _case == "wind"
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
	if _case == "wind" and not _bench:
		var surface: MeshInstance3D = _wind.get_node("Vfx/FireSurface") as MeshInstance3D
		_test_check(not surface.visible, "FireSurface ẩn sau khi đòn gió kết thúc")
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
	print("BENCH ",label," frames=",_frames," mean_ms=",_sum/maxf(float(_frames),1.0)," fps=",1000.0 * _frames / maxf(_sum,0.001)," worst_ms=",_max," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

## Chỉ tích lũy scalar để đo không tự gây cấp phát mỗi khung.
func _process(_delta: float) -> void:
	if not _measuring: return
	if _repeat_wind:
		_repeat_clock += _delta
		if _repeat_clock >= 0.36:
			_repeat_clock = 0.0
			_wind.fired.emit(2.0, _length, _width)
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


## Tám quái thật, bốn cháy xen kẽ bốn không cháy rồi cả tám, không bật AI hoặc ghi save.
func _setup_crowd() -> void:
	var packed: PackedScene = load("res://entities/enemies/palace/enemy_1/enemy_1.tscn") as PackedScene
	for i: int in range(8):
		var actor: Enemy = packed.instantiate() as Enemy
		actor.position = Vector3(float(i % 4) * 2.2 - 3.3, 0, float(i / 4) * 2.6 - 1.3)
		add_child(actor)
		actor.set_physics_process(false)
		actor.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
		actor.health.max_health = 1000
		actor.health.current_health = 1000
		var burn: BurnableComponent = actor.get_node("BurnableComponent") as BurnableComponent
		burn.data = burn.data.duplicate() as BurnData
		burn.data.duration = 10.0
		_burns.append(burn)


## Chụp tín hiệu tick thật và trạng thái tắt; phép đo FPS không xen đọc ảnh.
func _review_crowd() -> void:
	for i: int in range(0, 8, 2): _burns[i].ignite()
	await get_tree().create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("mixed.png"))
	for burn: BurnableComponent in _burns: burn.extinguish()
	await get_tree().create_timer(0.4).timeout
	if _bench:
		_begin()
		await get_tree().create_timer(3.0).timeout
		_end("crowd_baseline")
	for burn: BurnableComponent in _burns: burn.ignite()
	await get_tree().create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("eight_steady.png"))
	# Chu kỳ burn_default phát tick thật; không gọi thẳng handler VFX.
	await _burns[0].burn_tick
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("eight_tick.png"))
	if _bench:
		_begin()
		await get_tree().create_timer(3.0).timeout
		_end("crowd_eight_burning")
	for burn: BurnableComponent in _burns: burn.extinguish()
	await get_tree().create_timer(0.4).timeout
	for burn: BurnableComponent in _burns:
		var vfx: BurningVfx = burn.get_parent().get_node("BurningVfx") as BurningVfx
		_test_check(not vfx.is_processing(), "Dập lửa xong nghỉ xử lý")
		_test_check(not (vfx.get_node("StatusCrown") as MeshInstance3D).visible, "Không còn silhouette sau khi dập")
	print("CROWD_RESULT fails=", _test_fails)
	get_tree().quit(1 if _test_fails else 0)


## UC: idle không dấu cháy; ignite hiện silhouette; tick bùng ngay; dập xong về nghỉ, không có đèn.
func _test_status_readability() -> void:
	for burn: BurnableComponent in _burns:
		var vfx: BurningVfx = burn.get_node("BurningVfx") as BurningVfx
		var crown: MeshInstance3D = vfx.get_node("StatusCrown") as MeshInstance3D
		_test_check(not crown.visible, "UC1 silhouette ẩn trước ignite")
		_test_check(vfx.find_children("*", "OmniLight3D", true, false).is_empty(), "UC2 không có đèn trên mục tiêu")
		burn.ignite()
		_test_check(crown.visible, "UC3 ignite hiện silhouette không chờ ngẫu nhiên particle")
		_test_check(crown.mesh.get_aabb().size.y * crown.scale.y <= vfx.crown_height + 0.001, "UC4 mục tiêu to vẫn chặn chiều cao crown")
	await get_tree().create_timer(0.3).timeout
	for burn: BurnableComponent in _burns:
		var vfx: BurningVfx = burn.get_node("BurningVfx") as BurningVfx
		var crown: MeshInstance3D = vfx.get_node("StatusCrown") as MeshInstance3D
		var mat: ShaderMaterial = crown.material_override as ShaderMaterial
		_test_check(float(mat.get_shader_parameter("pulse")) < 0.01, "UC5 pulse đầu đã kết thúc")
		burn.burn_tick.emit(1)
		_test_check(is_equal_approx(float(mat.get_shader_parameter("pulse")), 1.0), "UC6 tick bật pulse ngay")
		burn.extinguish()
		burn.extinguish()
	await get_tree().create_timer(0.4).timeout
	for burn: BurnableComponent in _burns:
		var vfx: BurningVfx = burn.get_node("BurningVfx") as BurningVfx
		_test_check(not vfx.is_processing() and not (vfx.get_node("StatusCrown") as MeshInstance3D).visible, "UC7 dập lặp không lóe và không còn xử lý")
	print("STATUS_READABILITY_RESULT fails=", _test_fails)


## UC: collider lệch không làm lửa phát ở chỗ trống; bám mesh sau khi di chuyển/xoay và khi ẩn model.
func _test_anchor() -> void:
	var host: StaticBody3D = StaticBody3D.new()
	add_child(host)
	var model: Node3D = Node3D.new()
	model.name = "Model"
	host.add_child(model)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	model.add_child(visual)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.position = Vector3(1.0, 1.0, -0.8)
	visual.add_child(body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.position = Vector3(-3.0, 0.5, 2.0)
	host.add_child(shape)
	var burn: BurnableComponent = BurnableComponent.new()
	burn.match_shape_of = shape
	burn.data = load("res://resources/combat/fire/burn_default.tres") as BurnData
	host.add_child(burn)
	var vfx: BurningVfx = (load("res://assets/vfx/fire/burning/burning_vfx.tscn") as PackedScene).instantiate() as BurningVfx
	vfx.burnable = burn
	host.add_child(vfx)
	await get_tree().create_timer(0.15).timeout
	burn.ignite()
	body.position += Vector3(0.6, 0.2, -0.3)
	model.rotation.y = 0.8
	await get_tree().create_timer(0.15).timeout
	var particles: CPUParticles3D = vfx.get_node("Flames") as CPUParticles3D
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var match_point: Vector3 = body.global_transform * vertices[0]
	var emitter_point: Vector3 = particles.global_transform * particles.emission_points[0]
	_test_check(emitter_point.distance_to(match_point) < 0.001, "Lửa bám vertex mesh thật sau di chuyển và xoay; không bám collider lệch")
	var crown: MeshInstance3D = vfx.get_node("StatusCrown") as MeshInstance3D
	var actual_top: float = -INF
	for vertex: Vector3 in vertices:
		actual_top = maxf(actual_top, (body.global_transform * vertex).y)
	_test_check(absf(crown.global_position.y - actual_top - vfx.crown_clearance) < 0.001, "Chân silhouette chạm model thật, không treo ở đỉnh hurtbox")
	model.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	_test_check(not vfx.is_visible_in_tree(), "Ẩn model thì không để lửa trên vùng trống")
	model.show()
	await get_tree().process_frame
	await get_tree().process_frame
	_test_check(vfx.is_visible_in_tree(), "Model trở lại thì hiện trạng thái cháy đang còn")
	burn.extinguish()
	await get_tree().create_timer(0.3).timeout
	_test_check(not vfx.is_processing(), "Dập xong nghỉ cả cập nhật điểm neo")
	print("ANCHOR_RESULT fails=", _test_fails)


## UC: kiểm tra các frame đầu sandbox thật; phần được pre-warm phải bị thu nhỏ trước khi vẽ.
func _test_startup() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var level: Node = (load("res://tests/fire/sandbox/fire_sandbox.tscn") as PackedScene).instantiate()
	add_child(level)
	var visuals: Array[Node] = []
	for node: Node in level.find_children("*", "Node3D", true, false):
		if node is BurningVfx or node is FireWindVfx or node is FlameBreathVfx:
			visuals.append(node)
	for frame: int in range(35):
		for node: Node in visuals:
			if node is FireWindVfx:
				var surface: MeshInstance3D = node.get_node("FireSurface") as MeshInstance3D
				var mat: ShaderMaterial = surface.material_override as ShaderMaterial
				if surface.visible:
					if float(mat.get_shader_parameter("prewarm_scale")) > 0.00001:
						_test_check(false, "FireWind idle còn vẽ surface cỡ thật")
			elif node is BurningVfx:
				var flames: CPUParticles3D = node.get_node("Flames") as CPUParticles3D
				var mat: ShaderMaterial = flames.mesh.surface_get_material(0) as ShaderMaterial
				if flames.visible and float(mat.get_shader_parameter("prewarm_scale")) > 0.00001:
					_test_check(false, "Burning startup còn hạt cỡ thật")
			elif node is FlameBreathVfx:
				for name: String in ["Nozzle/FlameBody", "Nozzle/GroundGlow"]:
					var mesh: MeshInstance3D = node.get_node(name) as MeshInstance3D
					var mat: ShaderMaterial = mesh.material_override as ShaderMaterial
					if mesh.visible and float(mat.get_shader_parameter("prewarm_scale")) > 0.00001:
						_test_check(false, "Q startup còn mesh cỡ thật")
		await RenderingServer.frame_post_draw
		if frame in [0, 1, 2, 6, 16, 34]:
			get_viewport().get_texture().get_image().save_png(output.path_join("startup_%02d.png" % frame))
		await get_tree().process_frame
	print("STARTUP_IDLE_RESULT fails=", _test_fails, " vfx_checked=", visuals.size())
	var player: Player = level.get_node("Player") as Player
	player.state_machine.transition_to(&"FlameBreath")
	player.face_instantly(Vector3(1, 0, 1).normalized())
	await get_tree().create_timer(0.25).timeout
	for node: Node in visuals:
		if node is FlameBreathVfx:
			var body: MeshInstance3D = node.get_node("Nozzle/FlameBody") as MeshInstance3D
			var mat: ShaderMaterial = body.material_override as ShaderMaterial
			_test_check(body.visible and is_equal_approx(float(mat.get_shader_parameter("prewarm_scale")), 1.0), "Q thật sau prewarm khôi phục cỡ đầy đủ")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("first_cast.png"))
	print("STARTUP_RESULT fails=", _test_fails, " vfx_checked=", visuals.size())
