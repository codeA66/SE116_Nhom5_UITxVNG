extends Node
## Cửa khép lại ở map Gió phải kín hết bề ngang (lỗi 28/11/2026: song cửa ExitGate phòng thử thách Gió đóng rồi mà đi
## sát mép vẫn xuyên qua, vì hai cột đá hai bên chỉ có hình, không có va chạm).
## Đo bằng hình con cáo thật (capsule cùng cỡ player) trượt xuyên cửa ở từng vị trí ngang, va chạm thật trong map.
##
## ===== USE CASE =====
## UC1  Song cửa thử thách (trial_grille) và màn chắn xanh (encounter_barrier) đã đóng: không lọt ở bất kỳ vị trí ngang
##      nào, từ trong ra lẫn ngoài vào.
## UC2  Song cửa đang mở: vẫn đi qua được ở giữa cửa (va chạm cột mới không làm hẹp lối).
##
## ===== TEST CASE =====
## TC1 (UC1)  Mỗi cửa: đóng lại, quét capsule từ -6 m tới +6 m (bước 0,1 m) cả hai chiều -> 0 chỗ lọt.
## TC2 (UC2)  Mỗi song cửa: mở ra, capsule đi thẳng qua tâm cửa -> đi trọn quãng (không vướng).
## TC3        Tìm thấy ít nhất 3 song cửa và 2 màn chắn (đường quét không lặng lẽ bỏ sót).

const LEVEL := "res://levels/zone_1_wind/level_1/level_1.tscn"
const GRILLE := "trial_grille.gd"
const BARRIER := "encounter_barrier.gd"
## Cùng cỡ thân player (entities/_base/character.tscn)
const PLAYER_RADIUS := 0.35
const PLAYER_HEIGHT := 1.3
const SWEEP_HALF := 6.0
const SWEEP_STEP := 0.1

var _fails: int = 0


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var level := (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	for i in 60:
		await get_tree().physics_frame
	var grilles: Array[Node3D] = []
	var barriers: Array[Node3D] = []
	for n in level.find_children("*", "", true, false):
		var script := n.get_script() as Script
		if script == null:
			continue
		if script.resource_path.ends_with(GRILLE):
			grilles.append(n as Node3D)
		elif script.resource_path.ends_with(BARRIER):
			barriers.append(n as Node3D)
	_check(grilles.size() >= 3 and barriers.size() >= 2, "TC3: thấy %d song cửa, %d màn chắn" % [grilles.size(), barriers.size()])
	for g in grilles:
		g.call(&"set_open", false, false)
	for b in barriers:
		b.call(&"_set_closed", true)
	for i in 3:
		await get_tree().physics_frame
	for gate in grilles + barriers:
		var leaks := _leaks(gate)
		_check(leaks.is_empty(), "TC1: %s đóng kín (chỗ lọt: %s)" % [level.get_path_to(gate), leaks])
	for g in grilles:
		g.call(&"set_open", true, false)
	for i in 3:
		await get_tree().physics_frame
	for g in grilles:
		var free := _fraction(g, 0.0, 1.0)
		_check(free >= 0.999, "TC2: %s mở -> đi qua giữa cửa được (đi được %.0f%% quãng)" % [level.get_path_to(g), free * 100.0])
	print("RESULT fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## Các vị trí ngang (m, tính từ tâm cửa) mà capsule trượt xuyên trọn quãng qua mặt cửa
func _leaks(gate: Node3D) -> PackedStringArray:
	var out: PackedStringArray = []
	var steps := roundi(SWEEP_HALF / SWEEP_STEP)
	for k in range(-steps, steps + 1):
		var off := k * SWEEP_STEP
		for side: float in [-1.0, 1.0]:
			if _fraction(gate, off, side) >= 0.999:
				out.append("%.1f%s" % [off, "+" if side > 0.0 else "-"])
	return out


## Phần quãng capsule đi được khi trượt xuyên mặt cửa tại vị trí ngang off, xuất phát từ phía side
func _fraction(gate: Node3D, off: float, side: float) -> float:
	var cap := CapsuleShape3D.new()
	cap.radius = PLAYER_RADIUS
	cap.height = PLAYER_HEIGHT
	var normal := gate.global_basis.z.normalized()
	var start: Vector3 = gate.global_position + gate.global_basis.x.normalized() * off + normal * (2.5 * side) \
		+ Vector3.UP * (PLAYER_HEIGHT * 0.5 + 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = cap
	query.transform = Transform3D(Basis(), start)
	query.motion = -normal * (5.0 * side)
	query.collision_mask = 1
	var result := gate.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] if result.size() > 0 else 0.0


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
