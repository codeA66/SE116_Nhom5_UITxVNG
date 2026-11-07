extends Node3D
## Test kẻ gác cổng thu tiền. Bấm phím thật, player thật, tiến trình giả trong bộ nhớ, không ghi save thật.
## Chạy: mở test_gatekeeper.tscn rồi F6, hoặc headless. Chụp ảnh: chạy có cửa sổ kèm -- --shots=<thư mục>.
##
## ===== USE CASE =====
## UC1  Vào map chưa trả: hoạt ảnh Idle, rào đóng, tia vật lý xuyên lối đi bị rào chặn.
## UC2  Thiếu tiền: vẫn hỏi giá, bấm Trả -> không trừ tiền, chạy Refuse, câu từ chối ghi số đang có; rào vẫn đóng.
## UC3  Chọn Thôi -> câu tiễn, rào vẫn đóng, tiền giữ nguyên. Esc lúc chọn -> thoát hẳn, không mất tiền.
## UC4  Bị đánh lúc đang hỏi -> cắt ngang, không mất tiền, trả điều khiển.
## UC5  Đủ tiền, bấm Trả -> trừ đúng giá, bật cờ, câu cảm ơn, StepAside rồi IdleAside, rào mở (tia đi qua), trả điều khiển.
## UC6  Nói lại sau khi trả -> câu "đã trả", không hỏi tiền, tiền không đổi.
## UC7  Hai cổng cùng map: trả cổng A, cổng B vẫn đóng, cờ B chưa bật.
## UC8  Nạp lại map khi cờ đã bật: đứng sẵn IdleAside, rào mở ngay, không hỏi tiền.
## UC9  Giá cực đoan: 0 (trả được khi không có tiền), rất lớn (từ chối), đúng bằng số đang có (trả được, còn 0).

const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const KEEPER_SCENE: PackedScene = preload("res://entities/npcs/gatekeeper/gatekeeper.tscn")
const BARRIER_SCENE: PackedScene = preload("res://entities/npcs/gatekeeper/toll_barrier/toll_barrier.tscn")
const JADE := &"soul_jade"
const FLAG_A := &"test.toll.a"
const FLAG_B := &"test.toll.b"

var _fails: int = 0
var _shots: String = ""
var _player: Player
var _keeper_a: Gatekeeper
var _barrier_a: TollBarrier
var _keeper_b: Gatekeeper
var _barrier_b: TollBarrier


func _ready() -> void:
	for save_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if save_signal.is_connected(SaveManager.save_game):
			save_signal.disconnect(SaveManager.save_game)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var saved := GameState.progress
	GameState.replace_progress(PlayerProgress.new())
	_build_world()
	# Chờ cáo đáp đất: chỉ state trên mặt đất mới nhận nút tương tác
	await _physics(45)
	await _uc1_closed()
	await _uc2_not_enough()
	await _uc3_decline_and_cancel()
	await _uc4_damage()
	await _uc5_pay()
	await _uc6_after_paid()
	_uc7_other_gate()
	await _uc8_reload()
	await _uc9_extreme_prices()
	GameState.replace_progress(saved)
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	floor_body.add_child(mesh)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var pair_a := _spawn_pair(Vector3.ZERO, FLAG_A)
	_keeper_a = pair_a[0]
	_barrier_a = pair_a[1]
	var pair_b := _spawn_pair(Vector3(20, 0, 0), FLAG_B)
	_keeper_b = pair_b[0]
	_barrier_b = pair_b[1]
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector3(2.6, 0, 1.6)
	add_child(_player)


## Rào ở origin, kẻ gác cổng đứng phía +X của rào (bước sang +X là ra xa lối đi)
func _spawn_pair(origin: Vector3, flag: StringName) -> Array:
	var barrier := BARRIER_SCENE.instantiate() as TollBarrier
	barrier.position = origin
	add_child(barrier)
	var keeper := KEEPER_SCENE.instantiate() as Gatekeeper
	keeper.position = origin + Vector3(2.6, 0, -0.6)
	keeper.barrier = barrier
	(keeper.get_node("TollService") as TollService).paid_flag = flag
	add_child(keeper)
	return [keeper, barrier]


func _toll(keeper: Gatekeeper) -> TollService:
	return keeper.get_node("TollService") as TollService


func _jade() -> int:
	return GameState.get_currency(JADE)


## add_currency không nhận số âm: bớt tiền thì dùng spend_currency
func _set_jade(amount: int) -> void:
	var delta := amount - _jade()
	if delta > 0:
		GameState.add_currency(JADE, delta)
	elif delta < 0:
		GameState.spend_currency(JADE, -delta)


func _text(keeper: Gatekeeper) -> String:
	return (keeper.get_dialogue_box().get_node("Box/Panel/Margin/Content/Text") as Label).text


func _state(npc: Npc) -> StringName:
	return npc.state_machine.current_state.name


func _anim(keeper: Gatekeeper) -> StringName:
	return keeper.animation_player.current_animation if keeper.animation_player else &""


## Tia vật lý thật xuyên qua giữa lối đi của rào
func _blocked(barrier: TollBarrier) -> bool:
	var from := barrier.global_position + Vector3(0, 0.9, -2.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, 4.0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.collider as Node).get_parent() == barrier


func _uc1_closed() -> void:
	_check(_keeper_a.animation_player != null, "UC1: tìm thấy AnimationPlayer của model")
	_check(_anim(_keeper_a) == &"Idle", "UC1: hoạt ảnh Idle (%s)" % _anim(_keeper_a))
	_check(not _barrier_a.is_open() and _blocked(_barrier_a), "UC1: rào đóng, lối đi bị chặn")
	await _shot("closed")


func _open_question(keeper: Gatekeeper) -> void:
	await _until_grounded()
	await _press(&"interact")
	await _settle(keeper)
	await _press(&"interact")
	for i in 120:
		if _state(keeper) == &"Serve" or _state(keeper) == &"Idle":
			break
		await get_tree().physics_frame
	await _settle(keeper)


func _uc2_not_enough() -> void:
	_set_jade(10)
	await _open_question(_keeper_a)
	_check(_state(_keeper_a) == &"Serve", "UC2: hết lời chào -> hỏi tiền (%s)" % _state(_keeper_a))
	var question := _text(_keeper_a)
	_check(question.contains("50") and question.contains("10"), "UC2: câu hỏi ghi giá và số đang có ('%s')" % question)
	await _shot("question")
	await _press(&"interact")
	await _physics(4)
	_check(_jade() == 10, "UC2: thiếu tiền -> không trừ (%d)" % _jade())
	_check(_anim(_keeper_a) == &"Refuse", "UC2: chạy Refuse (%s)" % _anim(_keeper_a))
	await _settle(_keeper_a)
	_check(_text(_keeper_a).contains("Có 10"), "UC2: câu từ chối ghi số đang có ('%s')" % _text(_keeper_a))
	await _press(&"interact")
	await _physics(6)
	_check(_state(_keeper_a) == &"Idle" and _player.controls_enabled, "UC2: xong -> Idle, trả điều khiển")
	_check(_blocked(_barrier_a) and not GameState.has_flag(FLAG_A), "UC2: rào vẫn đóng, chưa bật cờ")


func _uc3_decline_and_cancel() -> void:
	await _open_question(_keeper_a)
	await _press(&"ui_down")
	await _press(&"interact")
	await _settle(_keeper_a)
	_check(_text(_keeper_a).contains("ngắm"), "UC3: chọn Thôi -> câu tiễn ('%s')" % _text(_keeper_a))
	await _press(&"interact")
	await _physics(6)
	_check(_jade() == 10 and _blocked(_barrier_a), "UC3: Thôi -> tiền giữ nguyên, rào đóng")
	await _open_question(_keeper_a)
	await _press(&"ui_cancel")
	await _physics(6)
	_check(_state(_keeper_a) == &"Idle" and _player.controls_enabled and _jade() == 10, "UC3: Esc lúc chọn -> thoát hẳn, không mất tiền")


func _uc4_damage() -> void:
	_set_jade(70)
	await _open_question(_keeper_a)
	_player.health.take_damage(1)
	await _physics(6)
	_check(_state(_keeper_a) == &"Idle" and _player.controls_enabled, "UC4: bị đánh -> cắt ngang, trả điều khiển")
	_check(_jade() == 70 and _blocked(_barrier_a), "UC4: không mất tiền, rào đóng")
	_player.health.heal_full()
	await _wait(1.6)


func _uc5_pay() -> void:
	await _open_question(_keeper_a)
	await _press(&"interact")
	await _physics(4)
	_check(_jade() == 20, "UC5: trừ đúng 50 (còn %d)" % _jade())
	_check(GameState.has_flag(FLAG_A), "UC5: bật cờ đã trả")
	_check(_anim(_keeper_a) == &"Accept", "UC5: chạy Accept (%s)" % _anim(_keeper_a))
	await _settle(_keeper_a)
	_check(_text(_keeper_a).contains("Qua đi"), "UC5: câu cảm ơn ('%s')" % _text(_keeper_a))
	await _press(&"interact")
	await _physics(4)
	await _wait(_face_turn_wait())
	_check(_anim(_keeper_a) == &"StepAside", "UC5: bước sang bên (%s)" % _anim(_keeper_a))
	_check(not _player.controls_enabled, "UC5: còn khóa điều khiển lúc bước sang")
	await _shot("step_aside")
	await _wait(2.2)
	_check(_anim(_keeper_a) == &"IdleAside", "UC5: xong -> IdleAside (%s)" % _anim(_keeper_a))
	_check(_barrier_a.is_open() and not _blocked(_barrier_a), "UC5: rào mở, lối đi thông")
	var gap := absf(_root_bone_x(_keeper_a) - _barrier_a.global_position.x)
	_check(gap > 2.6 + 1.0, "UC5: bước RA XA rào (gốc model cách tâm rào %.2f m)" % gap)
	var shadow_gap := absf((_keeper_a.get_node("Shadow") as Node3D).global_position.x - _barrier_a.global_position.x)
	_check(absf(shadow_gap - gap) < 0.5, "UC5: bóng đi theo chân (bóng %.2f m, gốc %.2f m)" % [shadow_gap, gap])
	_check(_state(_keeper_a) == &"Idle" and _player.controls_enabled, "UC5: trả điều khiển")
	await _shot("open")


func _uc6_after_paid() -> void:
	await _press(&"interact")
	await _settle(_keeper_a)
	_check(_text(_keeper_a).contains("Trả rồi"), "UC6: nói lại -> câu đã trả ('%s')" % _text(_keeper_a))
	await _press(&"interact")
	await _physics(8)
	_check(_state(_keeper_a) == &"Idle" and _jade() == 20, "UC6: không hỏi tiền, tiền không đổi (%s, %d)" % [_state(_keeper_a), _jade()])


func _uc7_other_gate() -> void:
	_check(_blocked(_barrier_b) and not GameState.has_flag(FLAG_B) and not _keeper_b.is_passage_open(), "UC7: cổng B vẫn đóng")


func _uc8_reload() -> void:
	var pair := _spawn_pair(Vector3(-20, 0, 0), FLAG_A)
	var keeper: Gatekeeper = pair[0]
	await _physics(4)
	_check(keeper.is_passage_open() and (pair[1] as TollBarrier).is_open(), "UC8: cờ đã bật -> mở sẵn khi vào map")
	_check(_anim(keeper) == &"IdleAside", "UC8: đứng sẵn IdleAside (%s)" % _anim(keeper))
	_check(not _blocked(pair[1]), "UC8: lối đi thông ngay")
	_check(keeper.get_service() == null, "UC8: không còn dịch vụ thu tiền")


func _uc9_extreme_prices() -> void:
	var cases := [[0, 0, true], [999999, 70, false], [35, 35, true]]
	var index := 0
	for case: Array in cases:
		var pair := _spawn_pair(Vector3(-12 + index * 12, 0, 20), StringName("test.toll.extreme%d" % index))
		var keeper: Gatekeeper = pair[0]
		_toll(keeper).price = case[0]
		_set_jade(case[1])
		_player.teleport(keeper.global_position + Vector3(0, 0, 1.6))
		await _until_grounded()
		await _open_question(keeper)
		await _press(&"interact")
		await _physics(4)
		var expect_paid: bool = case[2]
		var expected_jade: int = case[1] - case[0] if expect_paid else case[1]
		_check(_toll(keeper).is_paid() == expect_paid and _jade() == expected_jade,
			"UC9: giá %d, có %d -> %s, còn %d" % [case[0], case[1], "trả được" if expect_paid else "từ chối", _jade()])
		await _settle(keeper)
		await _press(&"interact")
		await _wait(2.4 if expect_paid else 0.3)
		_check(_player.controls_enabled, "UC9: giá %d -> trả điều khiển" % case[0])
		index += 1


## Chỉ state trên mặt đất mới nhận nút tương tác: chờ cáo đáp đất và Interactor nhận mục tiêu
func _face_turn_wait() -> float:
	return _keeper_a.face_reset_time + 0.15


func _until_grounded() -> void:
	for i in 120:
		if _player.is_on_floor() and _player.interactor.current != null and _player.state_machine.current_state.name in [&"Idle", &"Run"]:
			break
		await get_tree().physics_frame
	await _physics(2)


## Vị trí thật (đã chạy hoạt ảnh) của xương "root" của model, theo trục X thế giới
func _root_bone_x(keeper: Gatekeeper) -> float:
	var skeleton := keeper.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skeleton.find_bone("root")
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin.x


func _settle(keeper: Gatekeeper) -> void:
	var box := keeper.get_dialogue_box()
	# Chờ hộp thoại mở (nhịp khung hình khác nhau giữa headless và có cửa sổ) rồi chờ chữ hiện xong
	for i in 120:
		if box.is_open() and box.visible:
			break
		await get_tree().physics_frame
	for i in 600:
		if not box.is_processing():
			break
		await get_tree().physics_frame
	await _physics(2)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _physics(2)


func _shot(name_: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _wait(0.3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join("toll_%s.png" % name_))


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
