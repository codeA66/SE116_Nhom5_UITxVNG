extends Node
## Unit test cho FireBurnGate (viết TRƯỚC khi code theo quy trình TDD).
## Chạy: mở tests/fire/fire_burn_gate/test_fire_burn_gate.tscn rồi F6, hoặc headless.
## Tự ngắt kết nối SaveManager, không ghi save thật.
##
## ===== USE CASE =====
## UC1 Cháy lan tỏa tròn: kích hoạt nguồn -> cửa đứng yên (không chìm), burn_progress tăng 0->1, hết thời gian thì ẩn và tắt va chạm.
## UC2 Ngắt tia giữa chừng: tắt nguồn khi đang cháy dở -> lửa rút về 0, cửa còn nguyên và va chạm vẫn bật.
## UC3 Đóng lại sau khi mở: sau khi mở xong mà nguồn tắt -> cửa đóng lại, bật va chạm, phát signal closed.
## UC4 Thông số cực đoan: open_time = 0.05, retract_time = 0.05 vẫn chạy sạch, giá trị hữu hạn.
## UC5 Tích hợp t3_01_li_foundry.tscn: TutorialGate & ShortcutGate dùng FireBurnGate (2.4 s), brick_rise_time <= 1.0 s.
##
## ===== TEST CASE =====
## TC1 (UC1) open_time=0.25: sau 0.12 s thì 0 < burn_progress < 1 và tia đâm xuyên qua lỗ (BeamSurface + va chạm tắt sớm);
##           sau 0.35 s thì is_open=true, burn_progress=1.0, burn_plate ẩn, flame_symbols ẩn, opened=1, Visual.position.y giữ nguyên.
## TC2 (UC2) Bật nguồn 0.10 s rồi tắt (retract_time=0.15): sau 0.25 s thì burn_progress=0.0, is_open=false, va chạm bật, opened=0.
## TC3 (UC3) Mở xong rồi tắt nguồn: is_open=false, va chạm bật, closed=1, burn_plate hiện lại; set_sealed(true) giữ plate + icon ẩn.
## TC4 (UC4) open_time=0.05, retract_time=0.05: mở và rút lửa không lỗi, is_finite(get_burn_progress()).
## TC5 (UC5) Nạp t3_01_li_foundry.tscn: TutorialGate & ShortcutGate gắn fire_burn_gate.gd với open_time=2.4,
##           đủ burn_plate + 2 flame_symbols; LiFoundry.brick_rise_time <= 1.0.

const GATE_SCRIPT_PATH := "res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/beam_receiver/fire_burn_gate.gd"
const SHADER_PATH := "res://assets/shaders/fire/door_burn_dissolve.gdshader"
const FOUNDRY_SCENE_PATH := "res://levels/zone_3_fire/level_3/rooms/tier_3/t3_01_li_foundry.tscn"

var _fails: int = 0
var _gate_script: Script


class MockGateSource extends Node:
	signal activated
	signal deactivated
	var active: bool = false

	func is_active() -> bool:
		return active

	func set_state(value: bool) -> void:
		if value == active:
			return
		active = value
		if active:
			activated.emit()
		else:
			deactivated.emit()


func _ready() -> void:
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	var has_files: bool = ResourceLoader.exists(GATE_SCRIPT_PATH) and ResourceLoader.exists(SHADER_PATH)
	_check(has_files, "setup: tồn tại fire_burn_gate.gd và door_burn_dissolve.gdshader")
	if not has_files:
		print("RESULT fails=%d" % _fails)
		get_tree().quit(1)
		return

	_gate_script = load(GATE_SCRIPT_PATH) as Script
	_check(_gate_script != null, "setup: nạp được fire_burn_gate.gd")
	if _gate_script == null:
		print("RESULT fails=%d" % _fails)
		get_tree().quit(1)
		return

	await _tc1_burn_to_open()
	await _tc2_retract_midway()
	await _tc3_close_after_open()
	await _tc4_extreme_timings()
	_tc5_foundry_integration()

	print("RESULT fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _tc1_burn_to_open() -> void:
	var bundle: Dictionary = _build_gate(0.25, 0.15)
	var gate: StaticBody3D = bundle["gate"]
	var source: MockGateSource = bundle["source"]
	var plate: MeshInstance3D = bundle["plate"]
	var visual: Node3D = bundle["visual"]
	var shape: CollisionShape3D = bundle["shape"]
	var beam_shape: CollisionShape3D = bundle["beam_shape"]
	var symbols: Array = bundle["symbols"]
	var counts: Dictionary = bundle["counts"]
	add_child(source)
	add_child(gate)
	await _frames(2)

	var base_y: float = visual.position.y
	source.set_state(true)
	await _wait(0.12)
	var mid_prog: float = float(gate.call(&"get_burn_progress"))
	var mid_ok: bool = (
		mid_prog > 0.0
		and mid_prog < 1.0
		and shape.disabled
		and beam_shape.disabled
		and is_equal_approx(visual.position.y, base_y)
	)

	await _wait(0.24)
	var end_prog: float = float(gate.call(&"get_burn_progress"))
	var symbols_hidden: bool = not (symbols[0] as Node3D).visible and not (symbols[1] as Node3D).visible
	var end_ok: bool = (
		bool(gate.get(&"is_open"))
		and is_equal_approx(end_prog, 1.0)
		and not plate.visible
		and symbols_hidden
		and shape.disabled
		and beam_shape.disabled
		and int(counts["opened"]) == 1
		and is_equal_approx(visual.position.y, base_y)
	)
	_check(mid_ok and end_ok, "TC1: cửa cháy lan tỏa tròn 0->1 đứng yên tại chỗ rồi ẩn và tắt va chạm + BeamSurface")

	gate.queue_free()
	source.queue_free()
	await _frames(1)


func _tc2_retract_midway() -> void:
	var bundle: Dictionary = _build_gate(0.3, 0.12)
	var gate: StaticBody3D = bundle["gate"]
	gate.set(&"beam_pierce_threshold", 0.6)
	var source: MockGateSource = bundle["source"]
	var plate: MeshInstance3D = bundle["plate"]
	var shape: CollisionShape3D = bundle["shape"]
	var counts: Dictionary = bundle["counts"]
	add_child(source)
	add_child(gate)
	await _frames(2)

	source.set_state(true)
	await _wait(0.10)
	source.set_state(false)
	await _wait(0.25)

	var ok: bool = (
		is_equal_approx(float(gate.call(&"get_burn_progress")), 0.0)
		and not bool(gate.get(&"is_open"))
		and not shape.disabled
		and plate.visible
		and int(counts["opened"]) == 0
	)
	_check(ok, "TC2: ngắt tia giữa chừng thì lửa rút về 0, cửa vẫn chặn")

	gate.queue_free()
	source.queue_free()
	await _frames(1)


func _tc3_close_after_open() -> void:
	var bundle: Dictionary = _build_gate(0.12, 0.1)
	var gate: StaticBody3D = bundle["gate"]
	var source: MockGateSource = bundle["source"]
	var plate: MeshInstance3D = bundle["plate"]
	var shape: CollisionShape3D = bundle["shape"]
	var symbols: Array = bundle["symbols"]
	var counts: Dictionary = bundle["counts"]
	add_child(source)
	add_child(gate)
	await _frames(2)

	source.set_state(true)
	await _wait(0.2)
	source.set_state(false)
	await _frames(2)

	var close_ok: bool = (
		not bool(gate.get(&"is_open"))
		and not shape.disabled
		and plate.visible
		and int(counts["closed"]) == 1
	)
	# Kiểm tra niêm phong cứng: icon lửa và SealPlate không được hiện lại khi nguồn phát deactivated.
	source.set_state(true)
	await _wait(0.05)
	gate.call(&"set_sealed", true)
	source.set_state(false)
	await _frames(2)
	var sealed_ok: bool = (
		not plate.visible
		and not (symbols[0] as Node3D).visible
		and not (symbols[1] as Node3D).visible
	)
	_check(close_ok and sealed_ok, "TC3: đóng lại sau mở và set_sealed(true) giữ icon lửa + SealPlate ẩn")

	gate.queue_free()
	source.queue_free()
	await _frames(1)


func _tc4_extreme_timings() -> void:
	var bundle: Dictionary = _build_gate(0.05, 0.05)
	var gate: StaticBody3D = bundle["gate"]
	var source: MockGateSource = bundle["source"]
	add_child(source)
	add_child(gate)
	await _frames(2)

	source.set_state(true)
	await _wait(0.1)
	var p_open: float = float(gate.call(&"get_burn_progress"))
	source.set_state(false)
	await _wait(0.1)
	var p_close: float = float(gate.call(&"get_burn_progress"))

	var ok: bool = is_finite(p_open) and is_finite(p_close) and is_equal_approx(p_open, 1.0) and is_equal_approx(p_close, 0.0)
	_check(ok, "TC4: thông số cực đoan open_time=0.05, retract_time=0.05 chạy ổn định")

	gate.queue_free()
	source.queue_free()
	await _frames(1)


func _tc5_foundry_integration() -> void:
	var scene: PackedScene = load(FOUNDRY_SCENE_PATH) as PackedScene
	if scene == null:
		_check(false, "TC5: nạp được t3_01_li_foundry.tscn")
		return
	var foundry: Node = scene.instantiate()
	var tut: Node = foundry.get_node_or_null(^"TutorialGate")
	var shortcut: Node = foundry.get_node_or_null(^"ShortcutGate")

	var tut_ok: bool = (
		tut != null
		and tut.get_script() == _gate_script
		and is_equal_approx(float(tut.get(&"open_time")), 2.4)
		and tut.get(&"burn_plate") != null
		and (tut.get(&"flame_symbols") as Array).size() == 2
	)
	var sc_ok: bool = (
		shortcut != null
		and shortcut.get_script() == _gate_script
		and is_equal_approx(float(shortcut.get(&"open_time")), 2.4)
		and shortcut.get(&"burn_plate") != null
		and (shortcut.get(&"flame_symbols") as Array).size() == 2
	)
	var rise_ok: bool = float(foundry.get(&"brick_rise_time")) <= 1.0
	_check(tut_ok and sc_ok and rise_ok, "TC5: t3_01_li_foundry dùng FireBurnGate 2.4 s và brick_rise_time <= 1.0 s")
	foundry.free()


func _build_gate(open_time: float, retract_time: float) -> Dictionary:
	var source: MockGateSource = MockGateSource.new()
	var gate: StaticBody3D = _gate_script.new() as StaticBody3D
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = &"CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(4.0, 3.9, 0.4)
	shape.shape = box_shape
	gate.add_child(shape)

	var visual: Node3D = Node3D.new()
	visual.name = &"Visual"
	gate.add_child(visual)

	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.name = &"SealPlate"
	plate.mesh = BoxMesh.new()
	visual.add_child(plate)

	var beam_area: Area3D = Area3D.new()
	beam_area.name = &"BeamSurface"
	var beam_shape: CollisionShape3D = CollisionShape3D.new()
	beam_shape.name = &"CollisionShape3D"
	beam_shape.shape = BoxShape3D.new()
	beam_area.add_child(beam_shape)
	visual.add_child(beam_area)

	var sym_a: Node3D = Node3D.new()
	sym_a.name = &"FireFront"
	visual.add_child(sym_a)
	var sym_b: Node3D = Node3D.new()
	sym_b.name = &"FireBack"
	visual.add_child(sym_b)

	var sources: Array[Node] = [source]
	var symbols: Array[Node3D] = [sym_a, sym_b]
	gate.set(&"sources", sources)
	gate.set(&"burn_plate", plate)
	gate.set(&"beam_surface", beam_area)
	gate.set(&"flame_symbols", symbols)
	gate.set(&"open_time", open_time)
	gate.set(&"retract_time", retract_time)

	var counts: Dictionary = {"opened": 0, "closed": 0}
	gate.connect(&"opened", func() -> void: counts["opened"] += 1)
	gate.connect(&"closed", func() -> void: counts["closed"] += 1)

	return {
		"gate": gate,
		"source": source,
		"plate": plate,
		"visual": visual,
		"shape": shape,
		"beam_shape": beam_shape,
		"symbols": symbols,
		"counts": counts,
	}


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
