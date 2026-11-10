extends Node
## Unit test: đòn xuyên bất tử (tick cháy, bẫy) không được RÚT NGẮN thời gian bất tử đang có (dash, hồi sinh).
## Viết TRƯỚC khi sửa HurtboxComponent (TDD). Chạy: mở tests/player/hurtbox/test_hurtbox_invincibility.tscn rồi F6,
## hoặc headless. Tự ngắt tự lưu, không ghi save thật.
##
## ===== USE CASE =====
## UC1 Đang bất tử (dash) mà trúng đòn xuyên bất tử: vẫn mất máu, nhưng thời gian bất tử còn lại KHÔNG bị cắt ngắn.
## UC2 Đòn thường lúc đang bất tử: bị chặn như cũ.
## UC3 Đòn (thường hoặc xuyên) lúc không bất tử: sau đòn có bất tử đúng invincibility_time như cũ.
## UC4 Đòn xuyên bất tử lúc bất tử còn ít hơn invincibility_time: kéo lên invincibility_time (lấy cái dài hơn).
## UC5 Chơi thật: player đang dash (bất tử) trúng tick cháy -> một đòn chém thường ngay sau, vẫn trong thời gian dash, bị chặn.
## UC6 Thông số cực đoan: invincibility_time = 0 và = 5 s vẫn đúng các luật trên.
##
## ===== TEST CASE =====
## TC1 (UC1) Hurtbox riêng (invincibility_time 0.5), set_invincible(2.0), đòn xuyên: máu -1, bất tử còn > 1.5 s.
## TC2 (UC2) set_invincible(2.0), đòn thường: không mất máu, receive_hit trả false.
## TC3 (UC3) Không bất tử, đòn thường: -1 máu, bất tử ~0.5 s; không bất tử, đòn xuyên: -1 máu, bất tử ~0.5 s.
## TC4 (UC4) set_invincible(0.1), đòn xuyên: bất tử thành ~0.5 s (không bị giữ 0.1).
## TC5 (UC5) Player thật trong sân thử bấm dash, giữa dash nhận tick cháy (DamageInfo FIRE xuyên bất tử): mất 1 máu;
##           ngay sau đó (vẫn trong thời gian dash) một đòn thường bị chặn.
## TC6 (UC6) invincibility_time = 0: set_invincible(1.0) + đòn xuyên -> bất tử còn > 0.9 s; không bất tử + đòn -> không bất tử.
##           invincibility_time = 5: set_invincible(1.0) + đòn xuyên -> bất tử ~5 s.
## TC7 (UC7) Cáo đứng yên trúng tick cháy (staggers = false): mất 1 máu, nháy, KHÔNG vào state Hurt.
## TC8 (UC7) Cáo đứng yên trúng đòn thường (staggers = true): vẫn vào Hurt như cũ.
## TC9 (UC7) Cáo đang dash trúng tick cháy: vẫn ở state Dash (tick không huỷ dash).
##
## UC7 (thêm 2026-10-31) Cáo bị tick cháy (đòn không làm khựng) giống quái: chỉ nháy + mất máu, không khựng, không huỷ dash.

const SANDBOX := "res://tests/fire/sandbox/fire_sandbox.tscn"
## Sai số khi so thời gian bất tử còn lại (vài khung vật lý)
const EPS := 0.1

var _fails: int = 0


func _ready() -> void:
	# Không để test ghi đè save thật đang chơi dở
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_run.call_deferred()


## Chạy lần lượt mọi test case rồi in RESULT
func _run() -> void:
	_tc1_piercing_keeps_longer()
	_tc2_normal_blocked()
	_tc3_not_invincible()
	_tc4_extends_short()
	_tc6_extremes()
	await _tc5_player_dash()
	await _tc7_to_tc9_player_reaction()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _tc1_piercing_keeps_longer() -> void:
	var hb := _new_hurtbox(0.5)
	hb.set_invincible(2.0)
	var hp := hb.health.current_health
	var taken := hb.receive_hit(_hit(true))
	_check(taken and hb.health.current_health == hp - 1, "TC1: đang bất tử, đòn xuyên vẫn -1 máu")
	_check(hb.get_invincible_time() > 2.0 - EPS, "TC1: bất tử còn lại không bị cắt ngắn (%.2f s, mong ~2.0)" % hb.get_invincible_time())
	hb.free()


func _tc2_normal_blocked() -> void:
	var hb := _new_hurtbox(0.5)
	hb.set_invincible(2.0)
	var hp := hb.health.current_health
	_check(not hb.receive_hit(_hit(false)) and hb.health.current_health == hp, "TC2: đang bất tử, đòn thường bị chặn")
	hb.free()


func _tc3_not_invincible() -> void:
	for pierce: bool in [false, true]:
		var hb := _new_hurtbox(0.5)
		var hp := hb.health.current_health
		hb.receive_hit(_hit(pierce))
		_check(hb.health.current_health == hp - 1 and absf(hb.get_invincible_time() - 0.5) < EPS, "TC3: không bất tử, đòn %s -> -1 máu, bất tử %.2f s (mong 0.5)" % ["xuyên" if pierce else "thường", hb.get_invincible_time()])
		hb.free()


func _tc4_extends_short() -> void:
	var hb := _new_hurtbox(0.5)
	hb.set_invincible(0.1)
	hb.receive_hit(_hit(true))
	_check(absf(hb.get_invincible_time() - 0.5) < EPS, "TC4: bất tử còn 0.1 s + đòn xuyên -> lấy cái dài hơn (%.2f s, mong 0.5)" % hb.get_invincible_time())
	hb.free()


func _tc6_extremes() -> void:
	var hb := _new_hurtbox(0.0)
	hb.set_invincible(1.0)
	hb.receive_hit(_hit(true))
	_check(hb.get_invincible_time() > 1.0 - EPS, "TC6: invincibility_time 0, bất tử 1 s + đòn xuyên -> còn %.2f s (mong ~1.0)" % hb.get_invincible_time())
	hb.free()
	hb = _new_hurtbox(0.0)
	hb.receive_hit(_hit(false))
	_check(not hb.is_invincible(), "TC6: invincibility_time 0, không bất tử + đòn -> không bất tử")
	hb.free()
	hb = _new_hurtbox(5.0)
	hb.set_invincible(1.0)
	hb.receive_hit(_hit(true))
	_check(absf(hb.get_invincible_time() - 5.0) < EPS, "TC6: invincibility_time 5, bất tử 1 s + đòn xuyên -> %.2f s (mong 5)" % hb.get_invincible_time())
	hb.free()


func _tc5_player_dash() -> void:
	GameState.replace_progress(PlayerProgress.new())
	var lv := (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(lv)
	await _wait(1.0)
	var p := lv.get_node("Player") as Player
	p.teleport(Vector3(15, 0.2, 15), Vector3.FORWARD)
	await _f(8)
	var hb := p.get_node("HurtboxComponent") as HurtboxComponent
	var health := hb.health
	health.current_health = health.max_health
	Input.action_press(&"dash")
	await _f(2)
	Input.action_release(&"dash")
	await _f(2)
	var dash_left := hb.get_invincible_time()
	_check(dash_left > 0.05, "TC5: đang dash -> bất tử (%.2f s)" % dash_left)
	var hp := health.current_health
	var tick := DamageInfo.new(1, DamageInfo.Type.FIRE, Vector3.ZERO, null)
	tick.staggers = false
	tick.ignores_invincibility = true
	hb.receive_hit(tick)
	_check(health.current_health == hp - 1, "TC5: tick cháy giữa dash -> -1 máu")
	_check(hb.get_invincible_time() > dash_left - EPS, "TC5: bất tử của dash không bị cắt (%.2f -> %.2f s)" % [dash_left, hb.get_invincible_time()])
	hp = health.current_health
	_check(not hb.receive_hit(_hit(false)) and health.current_health == hp, "TC5: đòn chém thường ngay sau (vẫn trong dash) bị chặn")
	lv.queue_free()


func _tc7_to_tc9_player_reaction() -> void:
	await _f(2)
	GameState.replace_progress(PlayerProgress.new())
	var lv := (load(SANDBOX) as PackedScene).instantiate()
	get_tree().root.add_child(lv)
	await _wait(1.0)
	var p := lv.get_node("Player") as Player
	p.teleport(Vector3(15, 0.2, 15), Vector3.FORWARD)
	await _f(8)
	var hb := p.get_node("HurtboxComponent") as HurtboxComponent
	var health := hb.health
	health.current_health = health.max_health
	# TC7: tick cháy lúc đứng yên
	var hp := health.current_health
	hb.receive_hit(_tick())
	await _f(2)
	# Player không có hàm public "đang nháy": đọc biến nội bộ chỉ trong test
	var blinking: bool = float(p.get(&"_blink_time_left")) > 0.0
	_check(health.current_health == hp - 1, "TC7: tick cháy -> -1 máu")
	_check(_state(p) != "Hurt", "TC7: tick cháy không làm khựng (state %s)" % _state(p))
	_check(blinking, "TC7: tick cháy vẫn nháy")
	await _wait(1.0)
	# TC8: đòn thường lúc đứng yên (hết bất tử của tick trước)
	hb.receive_hit(_hit(false))
	await _f(2)
	_check(_state(p) == "Hurt", "TC8: đòn thường vẫn làm khựng (state %s)" % _state(p))
	await _wait(1.5)
	# TC9: tick cháy giữa dash
	Input.action_press(&"dash")
	await _f(2)
	Input.action_release(&"dash")
	await _f(2)
	var before := _state(p)
	hb.receive_hit(_tick())
	await _f(2)
	_check(before == "Dash" and _state(p) == "Dash", "TC9: đang dash trúng tick cháy vẫn dash (%s -> %s)" % [before, _state(p)])
	lv.queue_free()


# ---------- tiện ích ----------

## Tick cháy: 1 sát thương lửa, không khựng, xuyên bất tử (giống BurnableComponent gây ra)
func _tick() -> DamageInfo:
	var info := DamageInfo.new(1, DamageInfo.Type.FIRE, Vector3.ZERO, null)
	info.staggers = false
	info.ignores_invincibility = true
	return info


func _state(p: Player) -> String:
	return String(p.state_machine.current_state.name)

## Hurtbox + HealthComponent riêng (10 máu), invincibility_time cho trước, đã vào cây để _physics_process chạy
func _new_hurtbox(invincibility_time: float) -> HurtboxComponent:
	var health := HealthComponent.new()
	health.max_health = 10
	var hb := HurtboxComponent.new()
	hb.health = health
	hb.invincibility_time = invincibility_time
	hb.add_child(health)
	add_child(hb)
	return hb


## Đòn 1 sát thương; pierce = xuyên bất tử
func _hit(pierce: bool) -> DamageInfo:
	var info := DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, null)
	info.ignores_invincibility = pierce
	return info


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _f(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
