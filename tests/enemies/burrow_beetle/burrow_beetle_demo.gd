extends ZoneRoot
## F6 để chơi. Chạy với -- --verify-beetle để kiểm tra luồng phản đạn bằng E.

const WIND: WindBlastData = preload("res://abilities/wind_blast/wind_blast.tres")

var _failures: int
var _shots: int
var _shot_alignment: float

@onready var _beetle: BurrowBeetle = $BurrowBeetle


func _ready() -> void:
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.replace_progress(PlayerProgress.new())
	GameState.unlock_ability(WIND)
	await super._ready()
	if OS.get_cmdline_user_args().has("--verify-beetle"):
		_verify.call_deferred()


func _verify() -> void:
	var player := get_node(^"Player") as Player
	var skin := _beetle.get_node(^"Model/Visual/BeetleSkin")
	var anim := skin.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: StringName in [&"Rise", &"Idle", &"Attack", &"Burrow", &"Hidden", &"Death"]:
		_check(anim.has_animation(clip), "Imported clip: %s" % clip)
	_beetle.seed_fired.connect(func(seed: StoneSeed) -> void:
		_shots += 1
		var muzzle_offset := seed.global_position - _beetle.global_position
		muzzle_offset.y = 0.0
		_shot_alignment = muzzle_offset.normalized().dot(_beetle.direction_to_target())
	)
	# Khoảng cách tính theo thông số của Bọ: đổi burrow_distance / rise_distance thì test vẫn đúng
	var inside := _beetle.burrow_distance - 0.4
	var between := (_beetle.burrow_distance + _beetle.rise_distance) * 0.5
	player.teleport(Vector3(0.0, 0.05, inside), Vector3.FORWARD)
	await get_tree().create_timer(1.75).timeout
	_check(_beetle.state_machine.current_state.name == &"Burrow" and anim.assigned_animation == &"Hidden", "Foxy cách %.1f m (trong tầm chui %.1f m): bọ chui xuống" % [inside, _beetle.burrow_distance])
	_check(_beetle.hurtbox.invulnerable and _shots == 0, "Bọ nấp không bắn và không nhận sát thương")
	player.teleport(Vector3(0.0, 0.05, between), Vector3.FORWARD)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_beetle.state_machine.current_state.name == &"Burrow", "Foxy cách %.1f m (giữa tầm chui và tầm trồi): bọ vẫn nấp" % between)
	player.teleport(Vector3(0.0, 0.05, _beetle.rise_distance + 1.0), Vector3.FORWARD)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(anim.assigned_animation == &"Rise", "Foxy lùi ra: bọ phát hoạt ảnh trồi lên")
	for i in 120:
		if _beetle.state_machine.current_state.name == &"Attack":
			break
		await get_tree().physics_frame
	var side_step := Vector3(3.5, 0.05, 6.6)
	player.teleport(side_step, Vector3.FORWARD)
	for i in 150:
		if _shots > 0:
			break
		await get_tree().physics_frame
	_check(_shots == 1 and anim.assigned_animation == &"Attack", "Mỗi lần Attack bắn đúng một viên đá")
	_check(_shot_alignment > 0.98, "Mõm Bọ quay theo Foxy khi Foxy đổi vị trí trong lúc lấy đà")
	_check(not _beetle.hurtbox.receive_hit(DamageInfo.new(4)), "Mai đá chặn sát thương thường")
	if _shots > 0:
		player.face_instantly(-_beetle.direction_to_target())
		Input.action_press(&"skill")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release(&"skill")
		for i in 120:
			if _beetle.is_dead():
				break
			await get_tree().physics_frame
		_check(_beetle.is_dead() and anim.assigned_animation == &"Death", "Nhấn E phản viên đá và kích hoạt Death")
		await get_tree().create_timer(1.65).timeout
		_check(is_instance_valid(_beetle) and _beetle.is_dead(), "Xác nằm lại trong hoạt ảnh lật ngửa")
		await get_tree().create_timer(1.45).timeout
		_check(not is_instance_valid(_beetle), "Xác biến mất sau khi hết clip")
	print("BEETLE RESULT fails=", _failures)
	get_tree().quit(_failures)


func _check(passed: bool, message: String) -> void:
	print("PASS " if passed else "FAIL ", message)
	if not passed:
		_failures += 1
