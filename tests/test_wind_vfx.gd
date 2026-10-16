extends Node3D
## Kiểm tra VFX gió và lực có pulse. Chạy headless:
## godot --headless --path . tests/test_wind_vfx.tscn
## Không mở khóa kỹ năng vào save: dùng preview_* của player thay vì GameState.

const ZONE_SCENE: PackedScene = preload("res://objects/wind_zone/wind_zone.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const DUMMY_SCENE: PackedScene = preload("res://objects/training_dummy/training_dummy.tscn")
const BLAST_DATA: WindBlastData = preload("res://abilities/wind_blast/wind_blast.tres")

var _failed: bool = false


func _ready() -> void:
	_build_floor()
	_run.call_deferred()


func _run() -> void:
	await _check_blast()
	await _check_steady_zone()
	await _check_pulse_zone()
	print("WIND_VFX_CHECK ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


func _check_blast() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.teleport(Vector3.ZERO, Vector3.BACK)
	var dummy := DUMMY_SCENE.instantiate() as Node3D
	dummy.position = Vector3(0.0, 0.0, 2.5)
	add_child(dummy)
	await _frames(5)
	# Mở khóa tạm trong tiến trình rồi trả lại, không ghi save (SaveManager chỉ ghi khi progress_changed)
	GameState.progress.abilities.append(BLAST_DATA)
	var area := player.wind_blast
	var vfx := area.get_node("WindBlastVfx") as WindBlastVfx
	var burst := vfx.get_node("Burst") as WindBurstVfx
	var pool := vfx.get_node("ImpactPool") as WindImpactPool
	var pool_children := pool.get_child_count()
	_check(not burst.is_processing(), "burst ngủ khi chưa thổi")

	Input.action_press(&"skill")
	await _frames(2)
	Input.action_release(&"skill")
	_check(player.state_machine.current_state.name == PlayerState.WIND_BLAST, "bấm skill vào state WindBlast")
	_check(burst.charging, "gồng bắt đầu khi vào state")
	await _seconds(BLAST_DATA.active_start + 0.05)
	_check(burst.playing and not burst.charging, "bung đúng lúc activate, hết gồng")
	var launch := burst.global_position
	await _frames(4)
	_check(pool.get_child_count() == pool_children, "pool không tạo thêm node")
	var busy := 0
	for child in pool.get_children():
		if (child as WindBurstVfx).playing:
			busy += 1
	_check(busy == 1, "trúng hình nộm phát đúng 1 bụi từ pool")
	player.teleport(Vector3(3.0, 0.0, 0.0), Vector3.BACK)
	await _frames(2)
	_check(burst.global_position.is_equal_approx(launch), "cú bung đứng yên khi nhân vật đi chỗ khác")
	await _seconds(burst.style.duration + 0.1)
	_check(not burst.playing and not burst.is_processing(), "bung xong thì ngủ")

	# Bị ngắt giữa lúc gồng: phần gồng phải tắt ngay
	await _seconds(BLAST_DATA.cooldown + 0.3)
	Input.action_press(&"skill")
	await _frames(2)
	Input.action_release(&"skill")
	_check(burst.charging, "gồng lần 2")
	player.state_machine.transition_to(PlayerState.IDLE)
	await _frames(1)
	_check(not burst.charging and not burst.playing, "bị ngắt trước khi bung thì tắt gồng")

	GameState.progress.abilities.erase(BLAST_DATA)
	player.queue_free()
	dummy.queue_free()
	await _frames(2)


func _check_steady_zone() -> void:
	var zone := ZONE_SCENE.instantiate() as WindZone
	zone.position = Vector3(20.0, 1.5, 0.0)
	add_child(zone)
	await _frames(3)
	var vfx := zone.get_node("WindZoneVfx") as WindZoneVfx
	_check(not zone.is_physics_processing(), "vùng gió đều không xử lý mỗi frame")
	_check(not vfx.is_processing(), "VFX vùng gió đều không chạy script mỗi frame")
	var strokes := vfx.get_node("Strokes") as MultiMeshInstance3D
	_check(strokes.visible and strokes.multimesh.instance_count > 0, "luồng ngang có nét")
	_check(strokes.multimesh.instance_count <= vfx.style.gust_max_strokes, "số nét có giới hạn")
	var motes := vfx.get_node("Motes") as MultiMeshInstance3D
	_check(motes.multimesh.instance_count <= vfx.style.max_motes, "số lá/hạt có giới hạn")
	_check((vfx.get_node("Ground") as Node3D).visible, "có dấu trên mặt đất")
	var ground_y := (vfx.get_node("Ground") as Node3D).global_position.y
	_check(absf(ground_y - vfx.style.ground_offset) < 0.05, "dấu mặt đất nằm sát sàn")
	var mm := strokes.multimesh
	zone.size = Vector3(4.0, 3.0, 8.0)
	await _frames(2)
	_check(strokes.multimesh == mm, "đổi cấu hình cùng số lượng không dựng lại MultiMesh")
	var updraft := ZONE_SCENE.instantiate() as WindZone
	updraft.data = preload("res://resources/wind/wind_updraft.tres")
	updraft.size = Vector3(3.0, 3.0, 6.0)
	updraft.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(28.0, 3.0, 0.0))
	add_child(updraft)
	await _frames(3)
	var up_vfx := updraft.get_node("WindZoneVfx") as WindZoneVfx
	_check(updraft.is_vertical(), "cột gió được nhận là thẳng đứng")
	_check(updraft.get_wind_at(updraft.global_position).y > 0.0, "cột gió đẩy lên")
	_check((up_vfx.get_node("Strokes") as MultiMeshInstance3D).multimesh.instance_count == up_vfx.style.updraft_strokes, "cột gió dùng số nét riêng")
	var ring := up_vfx.get_node("Ground") as Node3D
	_check(ring.visible and absf(ring.global_position.y - up_vfx.style.ground_offset) < 0.05, "vòng chân cột gió nằm trên sàn")
	zone.queue_free()
	updraft.queue_free()
	await _frames(2)


## Lực và hình dùng chung đầu gió: chạy tay _physics_process để kiểm soát thời gian
func _check_pulse_zone() -> void:
	var zone := ZONE_SCENE.instantiate() as WindZone
	var data := WindData.new()
	data.pulse_enabled = true
	data.on_time = 0.4
	data.off_time = 1.0
	data.warning_time = 0.15
	data.sweep_time = 0.25
	data.sweep_exponent = 1.6
	zone.data = data
	zone.size = Vector3(4.0, 3.0, 8.0)
	zone.position = Vector3(-20.0, 1.5, 0.0)
	add_child(zone)
	zone.set_physics_process(false)
	await _frames(2)
	var vfx := zone.get_node("WindZoneVfx") as WindZoneVfx
	var strokes := vfx.get_node("Strokes") as Node3D
	var a := zone.to_global(Vector3(0.0, 0.0, 3.9))
	var mid := zone.global_position
	var b := zone.to_global(Vector3(0.0, 0.0, -3.9))
	zone.call(&"_physics_process", 0.05)
	_check(not zone.get_wind_at(a).is_zero_approx() and zone.get_wind_at(mid).is_zero_approx(), "đầu gió bắt đầu ở A, phía trước chưa có lực")
	zone.call(&"_physics_process", 0.15)
	_check(not zone.get_wind_at(mid).is_zero_approx() and zone.get_wind_at(b).is_zero_approx(), "đầu gió tới giữa trước B")
	zone.call(&"_physics_process", 0.07)
	_check(not zone.get_wind_at(b).is_zero_approx(), "đầu gió tới B sau sweep_time")
	zone.call(&"_physics_process", 0.15)
	await _frames(2)
	_check(not zone.active and zone.get_wind_at(a).is_zero_approx() and not zone.get_wind_at(b).is_zero_approx(), "tắt: A hết lực, đuôi gió còn ở B")
	_check(strokes.visible, "đuôi gió còn hiện sau khi tắt")
	zone.call(&"_physics_process", 0.3)
	await _frames(3)
	_check(not zone.has_flow_in_transit() and not strokes.visible and not vfx.is_processing(), "đuôi ra hết thì VFX ẩn và ngủ")
	zone.call(&"_physics_process", 0.62)
	await _frames(2)
	_check(zone.warning and vfx.is_processing(), "báo trước đánh thức VFX")
	_check(zone.get_wind_at(a).is_zero_approx(), "báo trước chưa có lực")
	var material := (vfx.get_node("Strokes") as GeometryInstance3D).material_override as ShaderMaterial
	_check(is_equal_approx(material.get_shader_parameter(&"sweep_time"), data.sweep_time), "lực và shader chung sweep_time")
	_check(is_equal_approx(material.get_shader_parameter(&"cycle_time"), zone.get_flow_phase()), "lực và shader chung pha")
	zone.queue_free()
	await _frames(2)


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	add_child(floor_body)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failed = true
		print("FAIL ", label)


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true, true).timeout
