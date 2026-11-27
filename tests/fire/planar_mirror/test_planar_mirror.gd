extends Node
## Unit test cho PlanarMirrorComponent (viết TRƯỚC khi code theo quy trình TDD).
## Chạy: mở tests/fire/planar_mirror/test_planar_mirror.tscn rồi F6, hoặc headless.
## Tự ngắt kết nối SaveManager, không ghi save thật.
##
## ===== USE CASE =====
## UC1 Toán học phản chiếu: camera ảo đối xứng qua mặt phẳng gương ở mọi góc xoay và giữ hệ trục tay phải.
## UC2 Gương 2 mặt & 1 mặt: double_sided=true phản chiếu cả 2 phía; double_sided=false tắt ở mặt sau.
## UC3 Tối ưu hiệu năng: set_active(false) tắt SubViewport update và _process; set_active(true) bật lại.
## UC4 Cô lập Visual Layer: target_mesh có mirror_visual_layer, camera phản chiếu loại bỏ layer đó khỏi cull_mask.
## UC5 Thông số cực đoan: resolution_scale, max_resolution, mirror_radius giữ kích thước an toàn, tỉ lệ đúng, near hợp lệ.
## UC6 Tích hợp RotatingMirror: có PlanarMirrorComponent dưới Pivot, đồng bộ bật/tắt theo set_present().
##
## ===== TEST CASE =====
## TC1 (UC1) Xoay gương 0°, 45°, 90°, 180°: camera đặt đúng phía trước mặt gương (surface_offset),
##           hướng nhìn đi ra phía trước khớp tia phản xạ và determinant > 0.
## TC2 (UC2) double_sided=true: camera ở phía -Z rồi sang phía +Z đều valid=true và is_rendering_active()=true.
## TC3 (UC2) double_sided=false: camera ở phía sau (+Z của mặt hướng -Z) -> valid=false và UPDATE_DISABLED.
## TC4 (UC3) set_active(false) -> UPDATE_DISABLED & not is_processing(); set_active(true) -> bật lại.
## TC5 (UC4) mirror_visual_layer=20 -> target_mesh chỉ bật layer 20 (tắt layer 1), mirror_camera loại layer 20 khỏi cull_mask.
## TC6 (UC5) resolution_scale 0.01/0.3/2.0, max_resolution 64/256 trên 1280x720 và 1920x1080 -> >=32, <=max, aspect lệch <0.05.
## TC7 (UC5) mirror_radius 0.05/0.86/10.0 -> compute_safe_near hợp lệ; khi use_near_plane_clip=false giữ nguyên near của camera chính.
## TC8 (UC6) Instantiate rotating_mirror.tscn -> có PlanarMirrorComponent dưới Pivot; set_present(false/true) đồng bộ active.

const COMPONENT_SCRIPT_PATH := "res://components/utility/planar_mirror/planar_mirror_component.gd"
const CONFIG_SCRIPT_PATH := "res://components/utility/planar_mirror/planar_mirror_config.gd"
const PRESET_PATH := "res://resources/vfx/planar_mirror_bronze.tres"
const SHADER_PATH := "res://assets/shaders/environment/props/planar_mirror.gdshader"
const ROTATING_MIRROR_SCENE_PATH := "res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/rotating_mirror/rotating_mirror.tscn"

var _fails: int = 0
var _component_script: Script
var _config_script: Script


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	var has_files: bool = (
		ResourceLoader.exists(COMPONENT_SCRIPT_PATH)
		and ResourceLoader.exists(CONFIG_SCRIPT_PATH)
		and ResourceLoader.exists(PRESET_PATH)
		and ResourceLoader.exists(SHADER_PATH)
	)
	_check(has_files, "setup: tồn tại đủ file component, config, preset và shader")
	if not has_files:
		print("RESULT fails=%d" % _fails)
		get_tree().quit(1)
		return

	_component_script = load(COMPONENT_SCRIPT_PATH) as Script
	_config_script = load(CONFIG_SCRIPT_PATH) as Script
	_check(_component_script != null and _config_script != null, "setup: nạp được script component và config")
	if _component_script == null or _config_script == null:
		print("RESULT fails=%d" % _fails)
		get_tree().quit(1)
		return

	_tc1_reflection_math()
	await _tc2_and_tc3_sidedness()
	await _tc4_active_toggle()
	await _tc5_visual_layer_isolation()
	_tc6_extreme_viewport_sizes()
	await _tc7_extreme_near_plane()
	await _tc8_rotating_mirror_integration()

	print("RESULT fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _tc1_reflection_math() -> void:
	var plane_origin: Vector3 = Vector3(2.0, 1.65, -3.0)
	var angles_deg: PackedFloat32Array = PackedFloat32Array([0.0, 45.0, 90.0, 180.0])
	var cam_pos: Vector3 = Vector3(6.5, 9.0, 5.0)
	var cam_transform: Transform3D = Transform3D(Basis.IDENTITY, cam_pos).looking_at(plane_origin, Vector3.UP)

	var all_ok: bool = true
	for angle_deg: float in angles_deg:
		var plane_normal: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(angle_deg)).normalized()
		var res: Dictionary = _component_script.call(
			&"compute_reflected_transform",
			cam_transform,
			plane_origin,
			plane_normal,
			true,
			0.1,
			0.0
		)
		if not bool(res.get("valid", false)):
			all_ok = false
			continue
		var refl_xform: Transform3D = res.get("transform", Transform3D.IDENTITY)
		var front_normal: Vector3 = res.get("front_normal", plane_normal)
		var front_offset: float = (refl_xform.origin - plane_origin).dot(front_normal)

		var incident: Vector3 = (plane_origin - cam_transform.origin).normalized()
		var expected_forward: Vector3 = (incident - 2.0 * incident.dot(front_normal) * front_normal).normalized()
		var actual_forward: Vector3 = -refl_xform.basis.z.normalized()
		var forward_error: float = actual_forward.distance_to(expected_forward)
		var det: float = refl_xform.basis.determinant()

		if front_offset <= 0.05 or actual_forward.dot(front_normal) <= 0.0 or forward_error > 0.001 or det <= 0.0:
			all_ok = false
	_check(all_ok, "TC1: camera phản chiếu đặt phía trước mặt gương ở 0°, 45°, 90°, 180° và determinant > 0")


func _tc2_and_tc3_sidedness() -> void:
	var harness: Node3D = Node3D.new()
	add_child(harness)

	var main_cam: Camera3D = Camera3D.new()
	harness.add_child(main_cam)

	var mirror_node: Node3D = _component_script.new() as Node3D
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = CylinderMesh.new()
	harness.add_child(mesh_inst)
	var cfg: Resource = _config_script.new() as Resource
	cfg.set(&"double_sided", true)
	mirror_node.set(&"config", cfg)
	mirror_node.set(&"target_mesh", mesh_inst)
	mirror_node.set(&"use_screen_notifier", false)
	harness.add_child(mirror_node)
	await _frames(2)

	# Mặt chuẩn của Pivot hướng -Z trong local space: đứng ở Z = -5 (trước mặt) và Z = +5 (mặt kia)
	main_cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -5.0)).looking_at(Vector3.ZERO, Vector3.UP)
	var front_ok: bool = bool(mirror_node.call(&"sync_with_camera", main_cam, Vector2i(1280, 720)))
	var front_active: bool = bool(mirror_node.call(&"is_rendering_active"))

	main_cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 5.0)).looking_at(Vector3.ZERO, Vector3.UP)
	var back_ok: bool = bool(mirror_node.call(&"sync_with_camera", main_cam, Vector2i(1280, 720)))
	var back_active: bool = bool(mirror_node.call(&"is_rendering_active"))
	_check(front_ok and front_active and back_ok and back_active, "TC2: double_sided=true phản chiếu cả hai mặt -Z và +Z")

	# TC3: tắt double_sided, đứng ở +Z (mặt sau của pháp tuyến -Z) phải tắt render
	cfg.set(&"double_sided", false)
	var one_side_back_ok: bool = bool(mirror_node.call(&"sync_with_camera", main_cam, Vector2i(1280, 720)))
	var sub_vp: SubViewport = mirror_node.call(&"get_sub_viewport") as SubViewport
	var disabled_behind: bool = sub_vp != null and sub_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED
	_check((not one_side_back_ok) and disabled_behind, "TC3: double_sided=false tắt SubViewport khi camera ở mặt sau")

	harness.queue_free()
	await _frames(1)


func _tc4_active_toggle() -> void:
	var harness: Node3D = Node3D.new()
	add_child(harness)
	var main_cam: Camera3D = Camera3D.new()
	main_cam.current = true
	harness.add_child(main_cam)
	main_cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -5.0)).looking_at(Vector3.ZERO, Vector3.UP)

	var mirror_node: Node3D = _component_script.new() as Node3D
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = CylinderMesh.new()
	harness.add_child(mesh_inst)
	mirror_node.set(&"config", _config_script.new())
	mirror_node.set(&"target_mesh", mesh_inst)
	mirror_node.set(&"use_screen_notifier", false)
	harness.add_child(mirror_node)
	await _frames(2)

	mirror_node.call(&"set_active", false)
	var sub_vp: SubViewport = mirror_node.call(&"get_sub_viewport") as SubViewport
	var off_ok: bool = (
		not bool(mirror_node.call(&"is_active"))
		and not mirror_node.is_processing()
		and sub_vp != null
		and sub_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED
	)

	mirror_node.call(&"set_active", true)
	await _frames(2)
	var on_ok: bool = (
		bool(mirror_node.call(&"is_active"))
		and mirror_node.is_processing()
		and bool(mirror_node.call(&"is_rendering_active"))
	)
	_check(off_ok and on_ok, "TC4: set_active(false/true) tắt và bật lại _process cùng SubViewport update")

	harness.queue_free()
	await _frames(1)


func _tc5_visual_layer_isolation() -> void:
	var harness: Node3D = Node3D.new()
	add_child(harness)
	var main_cam: Camera3D = Camera3D.new()
	harness.add_child(main_cam)
	main_cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -5.0)).looking_at(Vector3.ZERO, Vector3.UP)

	var mirror_node: Node3D = _component_script.new() as Node3D
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.mesh = CylinderMesh.new()
	harness.add_child(mesh_inst)
	var cfg: Resource = _config_script.new() as Resource
	cfg.set(&"mirror_visual_layer", 20)
	mirror_node.set(&"config", cfg)
	mirror_node.set(&"target_mesh", mesh_inst)
	mirror_node.set(&"use_screen_notifier", false)
	harness.add_child(mirror_node)
	await _frames(2)

	mirror_node.call(&"sync_with_camera", main_cam, Vector2i(1280, 720))
	var mirror_cam: Camera3D = mirror_node.call(&"get_mirror_camera") as Camera3D
	var ok: bool = (
		mesh_inst.get_layer_mask_value(20)
		and not mesh_inst.get_layer_mask_value(1)
		and mirror_cam != null
		and not mirror_cam.get_cull_mask_value(20)
	)
	_check(ok, "TC5: target_mesh chỉ bật layer 20 (bỏ layer 1) và mirror_camera loại layer 20 khỏi cull_mask")

	harness.queue_free()
	await _frames(1)


func _tc6_extreme_viewport_sizes() -> void:
	var screens: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
	var scales: PackedFloat32Array = PackedFloat32Array([0.01, 0.3, 2.0])
	var max_caps: PackedInt32Array = PackedInt32Array([64, 256])
	var ok: bool = true

	for screen: Vector2i in screens:
		var expected_aspect: float = float(screen.x) / float(screen.y)
		for scale_val: float in scales:
			for cap: int in max_caps:
				var sz: Vector2i = _component_script.call(&"compute_viewport_size", screen, scale_val, cap)
				var aspect: float = float(sz.x) / float(maxi(sz.y, 1))
				if sz.x < 32 or sz.y < 16 or sz.x > cap or sz.y > cap or absf(aspect - expected_aspect) > 0.05:
					ok = false
	_check(ok, "TC6: thông số cực đoan resolution_scale & max_resolution giữ kích thước an toàn và đúng tỉ lệ")


func _tc7_extreme_near_plane() -> void:
	var radii: PackedFloat32Array = PackedFloat32Array([0.05, 0.86, 10.0])
	var cam_xform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -6.0)).looking_at(Vector3.ZERO, Vector3.UP)
	var min_near: float = 0.05
	var max_far: float = 100.0
	var ok: bool = true

	for radius: float in radii:
		var near_val: float = float(_component_script.call(
			&"compute_safe_near",
			cam_xform,
			Vector3.ZERO,
			Basis.IDENTITY,
			radius,
			min_near,
			max_far,
			0.15
		))
		if near_val < min_near or near_val >= max_far:
			ok = false

	# Kiểm tra khi use_near_plane_clip = false (mặc định top-down): near không bị đẩy theo khoảng cách 32 m.
	var harness: Node3D = Node3D.new()
	add_child(harness)
	var main_cam: Camera3D = Camera3D.new()
	main_cam.near = 0.05
	harness.add_child(main_cam)
	main_cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(16.0, 24.0, 16.0)).looking_at(Vector3.ZERO, Vector3.UP)

	var mirror_node: Node3D = _component_script.new() as Node3D
	var cfg: Resource = _config_script.new() as Resource
	cfg.set(&"use_near_plane_clip", false)
	mirror_node.set(&"config", cfg)
	mirror_node.set(&"use_screen_notifier", false)
	harness.add_child(mirror_node)
	await _frames(2)

	mirror_node.call(&"sync_with_camera", main_cam, Vector2i(1280, 720))
	var mirror_cam: Camera3D = mirror_node.call(&"get_mirror_camera") as Camera3D
	var unclipped_ok: bool = mirror_cam != null and is_equal_approx(mirror_cam.near, 0.05)
	harness.queue_free()
	await _frames(1)

	_check(ok and unclipped_ok, "TC7: compute_safe_near hợp lệ và use_near_plane_clip=false giữ nguyên near của camera chính")


func _tc8_rotating_mirror_integration() -> void:
	var mirror_scene: PackedScene = load(ROTATING_MIRROR_SCENE_PATH) as PackedScene
	if mirror_scene == null:
		_check(false, "TC8: nạp được rotating_mirror.tscn")
		return
	var mirror: RotatingFireMirror = mirror_scene.instantiate() as RotatingFireMirror
	add_child(mirror)
	await _frames(2)

	var comp: Node = mirror.get_node_or_null(^"Pivot/PlanarMirrorComponent")
	var has_comp: bool = comp != null and comp.get_script() == _component_script
	mirror.set_present(false)
	var off_ok: bool = comp != null and not bool(comp.call(&"is_active"))
	mirror.set_present(true)
	var on_ok: bool = comp != null and bool(comp.call(&"is_active"))

	_check(has_comp and off_ok and on_ok, "TC8: RotatingMirror có PlanarMirrorComponent dưới Pivot và đồng bộ set_present()")
	mirror.queue_free()
	await _frames(1)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
