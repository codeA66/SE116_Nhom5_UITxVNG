extends Node
## Test khu trung tâm (bản khối xám). Chạy: mở test_hub.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1  Chơi mới -> xuất hiện ở quảng trường (START_ZONE = hub).
## UC2  Cổng Gió khóa khi chưa có chìa: không đi xuyên qua được, cổng dịch chuyển tắt, bảng ghi "Cần chìa khóa".
## UC3  Nhặt chìa (bấm tương tác thật) -> cổng Gió mở, phát opened đúng 1 lần.
## UC4  Phá khu Gió (cờ) -> dấu Gió sáng; cổng Lửa vẫn đóng vì khu Lửa chưa có scene; cổng Băng còn khóa.
## UC5  Đủ 4 khu -> cửa đền mở (tắt va chạm).
## UC6  Lưu / nạp lại -> chìa không xuất hiện lại, cổng Gió vẫn mở.
## UC7  Bước vào cổng Gió đã mở -> SceneManager bắt đầu chuyển sang khu Gió.

const HUB := "res://levels/temple_center/hub/hub.tscn"

var _fails: int = 0
var _hub: Node3D
var _p: Player


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	# Bỏ đoạn camera giới thiệu (khóa điều khiển ~8 s); đoạn này kiểm tra riêng bằng ảnh chụp
	GameState.set_flag(&"hub.intro_seen")
	_check(SceneManager.START_ZONE == HUB, "UC1: START_ZONE là khu trung tâm")
	await _load_hub()
	await _uc1_spawn()
	await _uc2_locked()
	await _uc3_key()
	await _uc4_wind_cleared()
	await _uc5_temple()
	await _uc6_reload()
	await _uc7_enter_gate()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _load_hub() -> void:
	if is_instance_valid(_hub):
		_hub.queue_free()
		await get_tree().process_frame
	_hub = (load(HUB) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_hub)
	await _wait(1.0)
	_p = _hub.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)


func _gate(name_: String) -> ZoneGate:
	return _hub.get_node("Gates/" + name_) as ZoneGate


func _uc1_spawn() -> void:
	var d := _p.global_position.distance_to(Vector3(-14, 0, 16))
	_check(d < 1.0, "UC1: player ở điểm start (lệch %.2f m)" % d)


func _uc2_locked() -> void:
	var gate := _gate("WindGate")
	_check(not gate.is_open(), "UC2: cổng Gió đang khóa")
	_check((gate.get_node("Label") as Label3D).text.contains("Cần chìa"), "UC2: bảng ghi cần chìa ('%s')" % (gate.get_node("Label") as Label3D).text.replace("\n", " / "))
	# Va chạm thật: đứng trước cổng, đẩy vào trong 1.2 s, không được lọt qua mặt cổng
	var inward := -gate.global_basis.z
	_p.teleport(gate.global_position - inward * 3.0, inward)
	await _wait(0.2)
	var t := 0.0
	while t < 1.2:
		_hold_move(inward)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_release_move()
	var depth := (_p.global_position - gate.global_position).dot(inward)
	_check(depth < 0.0 and not SceneManager.is_busy(), "UC2: đẩy vào cổng khóa bị chặn (vị trí so với mặt cổng %.2f m, chuyển khu=%s)" % [depth, SceneManager.is_busy()])
	for n in ["FireGate", "IceGate", "ThunderGate"]:
		_check(not _gate(n).is_open(), "UC2: %s khóa" % n)


func _uc3_key() -> void:
	var gate := _gate("WindGate")
	var opened := [0]
	gate.opened.connect(func() -> void: opened[0] += 1)
	var key := _hub.get_node("KeyPedestal/WindKey") as Node3D
	_p.teleport(key.global_position + Vector3(0, 0, 1.4), Vector3(0, 0, -1))
	await _wait(0.4)
	Input.action_press(&"interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"interact")
	await _wait(0.3)
	_check(GameState.has_flag(&"hub.wind_key"), "UC3: bấm tương tác -> có chìa")
	_check(not is_instance_valid(key), "UC3: chìa biến mất khỏi bệ")
	_check(gate.is_open() and opened[0] == 1, "UC3: cổng Gió mở, opened phát %d lần" % opened[0])


func _uc4_wind_cleared() -> void:
	var seal := _hub.get_node("Temple/SealWind") as ElementSeal
	_check(not seal.is_lit(), "UC4: dấu Gió tối khi chưa phá khu")
	GameState.set_flag(&"zone.wind.cleared")
	await get_tree().process_frame
	_check(seal.is_lit(), "UC4: phá khu Gió -> dấu Gió sáng")
	_check(not (_hub.get_node("Temple/SealFire") as ElementSeal).is_lit(), "UC4: dấu Lửa vẫn tối")
	var fire := _gate("FireGate")
	_check(not fire.is_open() and (fire.get_node("Label") as Label3D).text.contains("Chưa mở"), "UC4: cổng Lửa đóng vì khu chưa có scene ('%s')" % (fire.get_node("Label") as Label3D).text.replace("\n", " / "))
	_check(not _gate("IceGate").is_open(), "UC4: cổng Băng còn khóa")


func _uc5_temple() -> void:
	var door := _hub.get_node("Temple/TempleDoor") as TempleDoor
	_check(not door.is_open(), "UC5: cửa đền đóng khi mới phá 1 khu")
	for id in [&"zone.fire.cleared", &"zone.ice.cleared"]:
		GameState.set_flag(id)
	await get_tree().process_frame
	_check(not door.is_open(), "UC5: 3 khu vẫn chưa mở cửa đền")
	GameState.set_flag(&"zone.thunder.cleared")
	await _wait(0.1)
	var shape := door.get_node("CollisionShape3D") as CollisionShape3D
	_check(door.is_open() and shape.disabled, "UC5: đủ 4 khu -> cửa đền mở, tắt va chạm")


func _uc6_reload() -> void:
	var data := SaveManager.to_dict(GameState.progress)
	var restored := SaveManager.from_dict(data)
	# Bỏ cờ phá khu để cổng Gió quay lại trạng thái chỉ phụ thuộc chìa
	GameState.replace_progress(restored)
	await _load_hub()
	_check(not _hub.has_node("KeyPedestal/WindKey"), "UC6: nạp lại -> chìa không xuất hiện lại")
	_check(_gate("WindGate").is_open(), "UC6: nạp lại -> cổng Gió vẫn mở")


func _uc7_enter_gate() -> void:
	var gate := _gate("WindGate")
	var inward := -gate.global_basis.z
	_p.teleport(gate.global_position - inward * 3.0, inward)
	await _wait(0.2)
	var t := 0.0
	while t < 1.5 and not SceneManager.is_busy():
		_hold_move(inward)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(SceneManager.is_busy(), "UC7: bước vào cổng Gió -> bắt đầu chuyển khu (sau %.2f s)" % t)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


## Giữ phím di chuyển thật theo hướng thế giới (quy đổi qua góc camera giống Player.get_move_direction)
func _hold_move(dir: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var x := dir.dot(right)
	var y := -dir.dot(forward)
	_release_move()
	if x > 0.0: Input.action_press(&"move_right", x)
	elif x < 0.0: Input.action_press(&"move_left", -x)
	if y > 0.0: Input.action_press(&"move_back", y)
	elif y < 0.0: Input.action_press(&"move_forward", -y)


func _release_move() -> void:
	for a in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(a)
