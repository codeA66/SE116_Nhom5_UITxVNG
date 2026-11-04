extends Node
## Unit test hồi phục ở checkpoint qua RestoreComponent (hiệu ứng hồi máu đã bỏ theo yêu cầu). Viết TRƯỚC khi code (TDD).
## Chuyển từ test_loot_drop sang đây, thêm phần component.
## Chạy: mở tests/player/game/restore/test_restore.tscn rồi F6, hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1  Chạm checkpoint -> hồi đầy máu và năng lượng; chạm lại (ra rồi vào) vẫn hồi.
## UC2  Checkpoint không biết bên trong người chơi: chỉ gọi RestoreComponent; thêm thứ cần hồi (bình máu...) thì nghe signal restored,
##      không sửa checkpoint. Thêm nguồn hồi khác (suối hồi máu) dùng lại component.
## UC3  Thứ không có RestoreComponent đi vào checkpoint (quái, hình nộm) -> không lỗi, không hồi.
## UC4  RestoreComponent thiếu máu hoặc năng lượng (thực thể chỉ có một trong hai) -> hồi phần có, không lỗi.
##
## ===== TEST CASE =====
## TC1  (UC1)  Máu 1, năng lượng 0, bước vào checkpoint -> đầy cả hai; restored phát đúng 1 lần.
## TC2  (UC1)  Ra rồi vào lại khi mất máu -> hồi đầy lần nữa, restored phát thêm 1 lần.
## TC3  (UC2)  RestoreComponent.find_on(player) tìm được component; gọi restore_all() trực tiếp (không checkpoint) -> đầy máu + năng lượng.
## TC4  (UC3)  Hình nộm (không có RestoreComponent) bị đặt vào checkpoint -> không lỗi, không hồi.
## TC5  (UC4)  RestoreComponent chỉ có health (energy trống) -> hồi máu, không lỗi; chỉ có energy -> hồi năng lượng.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
const CHECKPOINT := "res://objects/core/checkpoint/checkpoint.tscn"

var _fails: int = 0
var _lv: Node
var _p: Player
var _cp: Node3D
var _restored: int = 0


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


func _run() -> void:
	await _setup()
	await _tc1_touch()
	await _tc2_again()
	_tc3_direct()
	await _tc4_no_component()
	await _tc5_partial()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _setup() -> void:
	GameState.replace_progress(PlayerProgress.new())
	_lv = (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(_lv)
	await _wait(1.0)
	_p = _lv.get_node("Player") as Player
	_p.get_node("HurtboxComponent").set_invincible(9999.0)
	var restore := RestoreComponent.find_on(_p)
	_check(restore != null, "setup: player có RestoreComponent")
	if restore:
		restore.restored.connect(func() -> void: _restored += 1)
	_cp = (load(CHECKPOINT) as PackedScene).instantiate() as Node3D
	_cp.set(&"checkpoint_id", &"test_restore")
	_lv.add_child(_cp)
	_cp.global_position = _p.global_position + Vector3(-6, 0, 4)
	await _wait(0.2)


func _tc1_touch() -> void:
	_p.health.set_current_health(1)
	_p.energy.set_current(0)
	var before := _restored
	_p.global_position = _cp.global_position
	await _wait(0.3)
	_check(_p.health.current_health == _p.health.max_health, "TC1: chạm checkpoint -> đầy máu (%d/%d)" % [_p.health.current_health, _p.health.max_health])
	_check(_p.energy.current == _p.energy.get_max(), "TC1: đầy năng lượng (%d/%d)" % [_p.energy.current, _p.energy.get_max()])
	_check(_restored == before + 1, "TC1: restored phát đúng 1 lần (%d)" % (_restored - before))


func _tc2_again() -> void:
	_p.global_position = _cp.global_position + Vector3(8, 0, 0)
	await _wait(0.3)
	_p.health.set_current_health(2)
	var before := _restored
	_p.global_position = _cp.global_position
	await _wait(0.3)
	_check(_p.health.current_health == _p.health.max_health, "TC2: chạm lại -> hồi đầy lần nữa")
	_check(_restored == before + 1, "TC2: restored phát thêm 1 lần")
	_p.global_position = _cp.global_position + Vector3(8, 0, 0)


func _tc3_direct() -> void:
	_p.health.set_current_health(1)
	_p.energy.set_current(0)
	RestoreComponent.find_on(_p).restore_all()
	_check(_p.health.current_health == _p.health.max_health and _p.energy.current == _p.energy.get_max(), "TC3: restore_all() trực tiếp -> đầy cả hai (dùng lại cho suối hồi máu)")


func _tc4_no_component() -> void:
	await _wait(3.0)
	var dummy := _lv.get_node("Dummy1") as Node3D
	var home := dummy.global_position
	var restored_before := _restored
	dummy.global_position = _cp.global_position
	await _wait(0.3)
	_check(RestoreComponent.find_on(dummy) == null, "TC4: hình nộm không có RestoreComponent")
	_check(_restored == restored_before, "TC4: hình nộm vào checkpoint -> không hồi, không lỗi")
	dummy.global_position = home


func _tc5_partial() -> void:
	var only_health := RestoreComponent.new()
	only_health.health = _p.health
	add_child(only_health)
	_p.health.set_current_health(1)
	only_health.restore_all()
	_check(_p.health.current_health == _p.health.max_health, "TC5: chỉ có health -> hồi máu, không lỗi")
	var only_energy := RestoreComponent.new()
	only_energy.energy = _p.energy
	add_child(only_energy)
	_p.energy.set_current(0)
	only_energy.restore_all()
	_check(_p.energy.current == _p.energy.get_max(), "TC5: chỉ có energy -> hồi năng lượng, không lỗi")
	only_health.queue_free()
	only_energy.queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
