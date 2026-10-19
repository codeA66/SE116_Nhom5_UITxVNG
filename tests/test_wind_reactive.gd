extends Node3D
## Kiểm tra va chạm gió thật, hình trước/trong/sau và cụm 200 cỏ.

const PROP_SCENES: Array[PackedScene] = [
	preload("res://objects/wind_reactive/grass_tuft.tscn"),
	preload("res://objects/wind_reactive/shrub_s.tscn"),
	preload("res://objects/wind_reactive/shrub_m.tscn"),
	preload("res://objects/wind_reactive/shrub_l.tscn"),
	preload("res://objects/wind_reactive/flag_pole.tscn"),
	preload("res://objects/wind_reactive/windmill.tscn"),
	preload("res://objects/wind_reactive/petal_drift.tscn"),
	preload("res://objects/wind_reactive/leaf_pile.tscn"),
	preload("res://objects/hanging_lantern/hanging_lantern.tscn"),
]
const BLAST_SCENE: PackedScene = preload("res://abilities/wind_blast/wind_blast_area.tscn")
const ZONE_SCENE: PackedScene = preload("res://objects/wind_zone/wind_zone.tscn")
const PATCH_SCENE: PackedScene = preload("res://objects/wind_reactive/grass_patch.tscn")

var _props: Array[Node3D] = []
var _reactions: Array[int] = []
var _gust_directions: Array[Vector3] = []
var _gust_strengths: Array[float] = []
var _leaf_blow_count: int = 0
var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_capture_dir = argument.trim_prefix("--out=")
	_build_stage()
	_run.call_deferred()


func _build_stage() -> void:
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.0, sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * 32.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(32.0, 10.0)
	ground.mesh = plane
	add_child(ground)
	for index in PROP_SCENES.size():
		var prop: Node3D = PROP_SCENES[index].instantiate() as Node3D
		prop.position = Vector3((float(index) - 4.0) * 3.0, 0.0, 0.0)
		add_child(prop)
		_props.append(prop)
		_reactions.append(0)
		_gust_directions.append(Vector3.ZERO)
		_gust_strengths.append(0.0)
		var reactive: WindReactiveComponent = prop.get_node("WindReactive") as WindReactiveComponent
		reactive.reacted.connect(_count_reaction.bind(index))
		if prop is WindReactiveLeafPile:
			(prop as WindReactiveLeafPile).blown_away.connect(_on_leaf_blown)


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_capture("before")
	var blast: WindBlastArea = BLAST_SCENE.instantiate() as WindBlastArea
	blast.position = Vector3(0.0, 0.8, -3.0)
	add_child(blast)
	blast.owner = self
	var blast_data := WindBlastData.new()
	blast_data.width = 30.0
	blast_data.height = 3.0
	blast_data.reach = 6.0
	blast_data.push_speed = 10.0
	blast.activate(blast_data)
	for frame in 5:
		await get_tree().physics_frame
	var gust_speed: float = (_props[5] as WindReactiveWindmill).get_spin_speed()
	_check(gust_speed > 0.0, "Cánh cối xay không tăng tốc")
	_check((_props[4].get_node("FlagCloth") as MeshInstance3D).mesh.get_surface_count() > 0, "Cờ thiếu vải")
	_check((_props[6] as WindReactivePetals).is_processing(), "Cánh hoa không bắt đầu bay")
	_check(_leaf_blow_count > 0, "Đống lá không phát blown_away")
	_check(not (_props[7].get_node("Model") as Node3D).visible, "Đống lá không bung lên")
	for index in _props.size():
		_check(_reactions[index] > 0, "WindBlastArea không chạm %s" % _props[index].name)
		_check(_gust_directions[index].z > 0.9, "Hướng cú thổi sai: %s" % _props[index].name)
		_check(is_equal_approx(_gust_strengths[index], blast_data.push_speed), "Sức cú thổi sai: %s" % _props[index].name)
	await get_tree().create_timer(0.3).timeout
	_check_clock_during_recovery()
	var petal_material: ShaderMaterial = _find_mesh(_props[6].get_node("Model")).material_override as ShaderMaterial
	var flight_progress: float = float(petal_material.get_shader_parameter(&"gust_progress"))
	_check(flight_progress > 0.1 and flight_progress < 1.0, "Cánh hoa không ở pha bay")
	_capture("during_blast")
	blast.deactivate()
	await get_tree().create_timer(2.0).timeout
	_check((_props[5] as WindReactiveWindmill).get_spin_speed() < gust_speed, "Cối xay không giảm tốc")
	_check((_props[7].get_node("Model") as Node3D).visible, "Đống lá không rơi lại")
	_check(not (_props[6] as WindReactivePetals).is_processing(), "Cánh hoa không ngủ sau khi rơi")
	_check_gust_recovery("Blast")
	_capture("after_blast")
	blast.queue_free()
	var zone: WindZone = ZONE_SCENE.instantiate() as WindZone
	zone.position = Vector3(0.0, 0.5, 0.0)
	zone.size = Vector3(32.0, 4.0, 8.0)
	add_child(zone)
	for frame in 5:
		await get_tree().physics_frame
	for prop in _props:
		var reactive: WindReactiveComponent = prop.get_node("WindReactive") as WindReactiveComponent
		var zone_force: Vector3 = zone.get_wind_at(reactive.global_position)
		_check(zone_force.z < 0.0, "Hướng WindZone sai: %s" % prop.name)
		_check(is_equal_approx(reactive.get_wind_strength(), zone_force.length()), "Cường độ WindZone sai: %s" % prop.name)
	_capture("during_zone")
	var overlap_blast: WindBlastArea = BLAST_SCENE.instantiate() as WindBlastArea
	overlap_blast.position = Vector3(0.0, 0.8, -3.0)
	add_child(overlap_blast)
	overlap_blast.owner = self
	overlap_blast.activate(blast_data)
	for frame in 5:
		await get_tree().physics_frame
	_check_shader_directions()
	await get_tree().create_timer(0.3).timeout
	_capture("zone_plus_blast")
	overlap_blast.deactivate()
	await get_tree().create_timer(2.0).timeout
	_check_shader_directions()
	_check_gust_recovery("Zone+Blast")
	_capture("zone_after_blast")
	overlap_blast.queue_free()
	zone.position = Vector3(100.0, 0.0, 0.0)
	for frame in 5:
		await get_tree().physics_frame
	for prop in _props:
		var reactive: WindReactiveComponent = prop.get_node("WindReactive") as WindReactiveComponent
		_check(is_zero_approx(reactive.get_wind_strength()), "WindZone không rời %s" % prop.name)
		_check(not reactive.is_processing(), "Component vẫn chạy khi rảnh: %s" % prop.name)
	_capture("after_zone")
	zone.queue_free()
	for prop in _props:
		prop.queue_free()
	for frame in 3:
		await get_tree().physics_frame
	await _measure_patch()
	await _test_nonzero_base()
	_test_patch_extremes()
	print("WIND_REACTIVE_RESULT failures=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _measure_patch() -> void:
	var patch: WindReactiveGrassPatch = PATCH_SCENE.instantiate() as WindReactiveGrassPatch
	patch.position = Vector3(0.0, 0.0, -4.0)
	add_child(patch)
	var multi: MultiMeshInstance3D = patch.get_node("GrassMultiMesh") as MultiMeshInstance3D
	_check(multi.multimesh.instance_count == 200, "MultiMesh thiếu cỏ")
	_check(patch.get_child_count() == 3, "Cụm cỏ tạo node từng bụi")
	await get_tree().create_timer(0.3).timeout
	var idle_ms: float = await _sample_frame_ms()
	var receiver: WindReceiverComponent = patch.get_node("WindReceiver") as WindReceiverComponent
	receiver.push(Vector3(10.0, 0.0, 0.0))
	await get_tree().create_timer(0.2).timeout
	var active_ms: float = await _sample_frame_ms()
	print("GRASS_200 idle_ms=%.3f active_ms=%.3f delta_ms=%.3f" % [idle_ms, active_ms, active_ms - idle_ms])
	var zone: WindZone = ZONE_SCENE.instantiate() as WindZone
	zone.position = patch.position + Vector3(0.0, 0.5, 0.0)
	zone.size = Vector3(20.0, 4.0, 8.0)
	add_child(zone)
	for frame in 5:
		await get_tree().physics_frame
	var blast: WindBlastArea = BLAST_SCENE.instantiate() as WindBlastArea
	blast.position = patch.position + Vector3(0.0, 0.8, -3.0)
	add_child(blast)
	blast.owner = self
	var blast_data := WindBlastData.new()
	blast_data.width = 20.0
	blast_data.height = 3.0
	blast_data.reach = 6.0
	blast_data.push_speed = 10.0
	blast.activate(blast_data)
	for frame in 5:
		await get_tree().physics_frame
	var material: ShaderMaterial = multi.material_override as ShaderMaterial
	_assert_opposite_wind(material, "GrassPatch")
	blast.deactivate()
	blast.queue_free()
	zone.queue_free()
	patch.queue_free()


func _sample_frame_ms() -> float:
	var samples := PackedFloat32Array()
	for frame in 120:
		var started: int = Time.get_ticks_usec()
		await get_tree().process_frame
		samples.append(float(Time.get_ticks_usec() - started) * 0.001)
	samples.sort()
	return samples[60]


func _test_patch_extremes() -> void:
	for configuration in [Vector3(1.0, 1.0, 0.1), Vector3(1000.0, 37.0, 10.0)]:
		var patch: WindReactiveGrassPatch = PATCH_SCENE.instantiate() as WindReactiveGrassPatch
		patch.grass_count = int(configuration.x)
		patch.columns = int(configuration.y)
		patch.spacing = configuration.z
		add_child(patch)
		var multi: MultiMeshInstance3D = patch.get_node("GrassMultiMesh") as MultiMeshInstance3D
		_check(multi.multimesh.instance_count == patch.grass_count, "Cụm cỏ lệch số lượng cực trị")
		patch.queue_free()


func _test_nonzero_base() -> void:
	var windmill: WindReactiveWindmill = PROP_SCENES[5].instantiate() as WindReactiveWindmill
	windmill.base_spin_speed = 3.0
	windmill.position = Vector3(100.0, 0.0, 0.0)
	add_child(windmill)
	var rotor: Node3D = windmill.get_node("Model/Windmill/Windmill_Rotor") as Node3D
	var initial_angle: float = rotor.rotation.z
	await get_tree().create_timer(0.25).timeout
	_check(windmill.is_processing(), "Cối xay tốc độ nền ngủ sai")
	_check(is_equal_approx(windmill.get_spin_speed(), 3.0), "Tốc độ nền cối xay đổi sai")
	_check(absf(rotor.rotation.z - initial_angle) > 0.1, "Cánh cối xay tốc độ nền đứng yên")
	windmill.queue_free()


func _check_shader_directions() -> void:
	var grass_mesh: MeshInstance3D = _find_mesh(_props[0].get_node("Model"))
	_assert_opposite_wind(grass_mesh.material_override as ShaderMaterial, "Grass")
	var cloth: MeshInstance3D = _props[4].get_node("FlagCloth") as MeshInstance3D
	_assert_opposite_wind(cloth.material_override as ShaderMaterial, "Flag")


func _assert_opposite_wind(material: ShaderMaterial, label: String) -> void:
	var gust_direction: Vector3 = material.get_shader_parameter(&"gust_direction") as Vector3
	var hold_direction: Vector3 = material.get_shader_parameter(&"hold_direction") as Vector3
	_check(gust_direction.z > 0.9, "%s: hướng cú thổi sai khi chồng nguồn" % label)
	_check(hold_direction.z < -0.9, "%s: hướng vùng gió bị ghi đè" % label)
	_check(float(material.get_shader_parameter(&"hold_strength")) > 0.0, "%s: mất lực WindZone" % label)


func _check_gust_recovery(label: String) -> void:
	var clock: WindReactiveClock = WindReactiveClock.ensure_clock(get_tree())
	_check(not clock.is_processing(), "%s: đồng hồ không ngủ sau hồi phục" % label)
	var elapsed_min: float = INF
	for material in [
		_find_mesh(_props[0].get_node("Model")).material_override as ShaderMaterial,
		_props[4].get_node("FlagCloth").material_override as ShaderMaterial,
	]:
		var elapsed: float = clock.current_time - float(material.get_shader_parameter(&"gust_time"))
		var recovery: float = float(material.get_shader_parameter(&"recovery_seconds"))
		elapsed_min = minf(elapsed_min, elapsed)
		_check(elapsed >= recovery, "%s: shader tắt cú thổi quá sớm" % label)
	print("SHADER_RECOVERY %s min_elapsed=%.3f clock_active=%s" % [label, elapsed_min, clock.is_processing()])


func _check_clock_during_recovery() -> void:
	var clock: WindReactiveClock = WindReactiveClock.ensure_clock(get_tree())
	var material: ShaderMaterial = _find_mesh(_props[0].get_node("Model")).material_override as ShaderMaterial
	var elapsed: float = Time.get_ticks_msec() * 0.001 - float(material.get_shader_parameter(&"gust_time"))
	var recovery: float = float(material.get_shader_parameter(&"recovery_seconds"))
	if elapsed < recovery:
		_check(clock.is_processing(), "Đồng hồ gió ngủ khi cú thổi còn hồi phục")
	else:
		_check(clock.current_time - float(material.get_shader_parameter(&"gust_time")) >= recovery, "Đồng hồ gió tắt trước khi shader hồi phục")
	print("CLOCK_DURING_RECOVERY elapsed=%.3f recovery=%.3f active=%s" % [elapsed, recovery, clock.is_processing()])


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null


func _count_reaction(direction: Vector3, strength: float, index: int) -> void:
	_reactions[index] += 1
	_gust_directions[index] = direction
	_gust_strengths[index] = strength


func _on_leaf_blown() -> void:
	_leaf_blow_count += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _capture(label: String) -> void:
	if _capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var path: String = _capture_dir.path_join("wind_reactive_%s.png" % label)
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("CAPTURE_UNAVAILABLE %s" % label)
		return
	image.save_png(path)
	print("CAPTURE %s" % path)
