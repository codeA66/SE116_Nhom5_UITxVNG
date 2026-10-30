extends SceneTree
## Test tự động kiểm tra logic Boss 1 (khóa máu, khiên bất tử, phản đòn cầu lửa, i-frames).

const Boss1Class = preload("res://entities/bosses/boss_1/boss_1.gd")

func _init() -> void:
	print("\n=== BẮT ĐẦU KIỂM TRA BOSS 1: DỊ THÚ THA HOÁ ===")
	call_deferred(&"_run_tests")


func _run_tests() -> void:
	var boss_scene := load("res://entities/bosses/boss_1/boss_1.tscn") as PackedScene
	if boss_scene == null:
		printerr("FAIL: Không thể load entities/bosses/boss_1/boss_1.tscn")
		quit(1)
		return
	
	var boss: Node = boss_scene.instantiate()
	root.add_child(boss)
	
	# Đợi 1 frame để _ready chạy xong
	await process_frame
	
	var pass_count: int = 0
	var total_tests: int = 8
	
	# Test 1: Khởi tạo máu và I-Frames ban đầu
	if boss.health.current_health == 20 and is_equal_approx(boss.hurtbox.invincibility_time, 0.6):
		print("PASS [1/8]: Máu ban đầu = 20 HP, I-Frames = 0.6s chuẩn xác.")
		pass_count += 1
	else:
		printerr("FAIL [1/8]: Khởi tạo thất bại: HP=%d, iframe=%f" % [boss.health.current_health, boss.hurtbox.invincibility_time])
	
	# Test 2: Chém thường xuống mốc 50% (10 HP) -> Khóa máu & Bật khiên tầng 1
	var sword_hit := DamageInfo.new(10, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	boss.hurtbox.receive_hit(sword_hit)
	
	if boss.health.current_health == 10 and boss.is_shielded and boss.shield_stacks == 1 and boss.current_phase == 2:
		print("PASS [2/8]: Khóa máu 50% chuẩn xác (10 HP), đã bật khiên (stacks=1), chuyển Phase 2.")
		pass_count += 1
	else:
		printerr("FAIL [2/8]: Khóa máu 50% lỗi: HP=%d, shielded=%s, stacks=%d" % [boss.health.current_health, boss.is_shielded, boss.shield_stacks])
	
	# Test 3: Khiên bất tử bảo vệ - nhận thêm sát thương nhưng máu không đổi
	var spam_hit := DamageInfo.new(5, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	boss.hurtbox.receive_hit(spam_hit)
	if boss.health.current_health == 10:
		print("PASS [3/8]: Khiên bất tử hoạt động - sát thương bị vô hiệu hóa hoàn toàn.")
		pass_count += 1
	else:
		printerr("FAIL [3/8]: Khiên bất tử bị lọt sát thương: HP=%d" % boss.health.current_health)
	
	# Test 4: Phản đòn cầu lửa trúng Boss -> Phá vỡ khiên mốc 50%
	boss.on_fireball_hit(null)
	if not boss.is_shielded and boss.shield_stacks == 0 and boss.state_machine.current_state.name == "Stunned":
		print("PASS [4/8]: Phản cầu lửa phá vỡ khiên 50% -> Boss bị Stunned.")
		pass_count += 1
	else:
		printerr("FAIL [4/8]: Phá khiên 50% lỗi: shielded=%s, state=%s" % [str(boss.is_shielded), boss.state_machine.current_state.name])
	
	# Hết thời gian I-frame 0.6s của người chơi trước khi chém nhát tiếp theo
	boss.hurtbox.set_invincible(0.0)
	boss.hurtbox._invincible_timer = 0.0
	
	# Test 5: Tiếp tục chém xuống mốc 20% (<= 4 HP) -> Khóa máu, HỒI PHỤC LÊN 40% (8 HP), Bật khiên tầng 2 (stacks=2), x2 Sát thương
	var slash_down := DamageInfo.new(6, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	boss.hurtbox.receive_hit(slash_down)
	if boss.health.current_health == 8 and boss.is_shielded and boss.shield_stacks == 2 and boss.current_phase == 3 and boss.melee_attack_data.damage == 2:
		print("PASS [5/8]: Khóa máu 20% & Hồi máu lên 40% chuẩn xác (8 HP), bật khiên (stacks=2), x2 sát thương (Melee damage=2), chuyển Phase 3.")
		pass_count += 1
	else:
		printerr("FAIL [5/8]: Khóa máu 20% lỗi: HP=%d, shielded=%s, stacks=%d, melee_dmg=%d" % [boss.health.current_health, str(boss.is_shielded), boss.shield_stacks, boss.melee_attack_data.damage])
	
	# Test 6: Phản cầu lửa lần 1 ở mốc 20% -> Khiên nứt (còn stacks=1, chưa mất khiên)
	boss.on_fireball_hit(null)
	if boss.is_shielded and boss.shield_stacks == 1:
		print("PASS [6/8]: Phản cầu lửa lần 1 ở mốc 20% -> Khiên nứt (stacks=1), Boss vẫn được bảo vệ.")
		pass_count += 1
	else:
		printerr("FAIL [6/8]: Phản cầu lần 1 lỗi: shielded=%s, stacks=%d" % [str(boss.is_shielded), boss.shield_stacks])
	
	# Test 7: Phản cầu lửa lần 2 ở mốc 20% -> Phá vỡ khiên hoàn toàn & TẮT I-FRAMES
	boss.on_fireball_hit(null)
	if not boss.is_shielded and boss.shield_stacks == 0 and is_zero_approx(boss.hurtbox.invincibility_time):
		print("PASS [7/8]: Phản cầu lửa lần 2 -> Khiên vỡ hoàn toàn, I-Frames đã TẮT (0.0s) cho Phase Cuối.")
		pass_count += 1
	else:
		printerr("FAIL [7/8]: Phá khiên lần 2 lỗi: shielded=%s, iframe=%f" % [str(boss.is_shielded), boss.hurtbox.invincibility_time])
	
	# Hết thời gian I-frame
	boss.hurtbox.set_invincible(0.0)
	boss.hurtbox._invincible_timer = 0.0
	
	# Test 8: Dồn sát thương kết liễu 8 HP còn lại -> Boss chết (Dead state)
	var kill_hit := DamageInfo.new(8, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	boss.hurtbox.receive_hit(kill_hit)
	if boss.health.is_dead() and boss.state_machine.current_state.name == "Dead":
		print("PASS [8/8]: Hạ gục 8 HP còn lại thành công -> Boss vào state Dead.")
		pass_count += 1
	else:
		printerr("FAIL [8/8]: Hạ gục thất bại: is_dead=%s, state=%s" % [str(boss.health.is_dead()), boss.state_machine.current_state.name])
	
	print("\n=== KẾT QUẢ: %d/%d TESTS ĐẠT ===" % [pass_count, total_tests])
	boss.queue_free()
	
	if pass_count == total_tests:
		quit(0)
	else:
		quit(1)
