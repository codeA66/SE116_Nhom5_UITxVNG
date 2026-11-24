extends Node3D
## UC1 Kiếm, tên trượt và tên bị chặn không nạp. Mỗi tên làm mất máu thật chỉ nạp một điểm.
## UC2 R chỉ nhận trên sàn khi rảnh. Từ lúc bắt đầu tới khi đáp, cáo bất tử và AI mất mục tiêu.
## UC3 Bắn một lần trừ đúng máu trong bán kính. Hết giờ, Esc hoặc tháo đeo không giữ điểm.
## TC1–4 Đăng ký, nạp bằng tên thật, chặn đòn thật và mất mục tiêu lúc bay.
## TC5–8 Vụ nổ trong/ngoài vùng, đáp về chỗ cũ, timeout, tháo bùa và HUD.
## TC9–12 Trần thấp, menu, giữa đòn, Esc, thông số lệch và khiên của ForgeBoss.
## TC13–16 Kiếm thật, R giữa dash/trên vực, tháo bùa lúc bay, Ếch Hoả Vương, chết giữa lượt.
## UC4 Sân chơi tay bắt đầu tay không. Nhặt đồ bằng tương tác và đeo bùa tại miếu.
## TC17 Nhặt kiếm, cung, bùa; vào miếu để đeo; chém hình nộm để hồi linh lực.

const CHARM_PATH: String = "res://resources/player/items/charms/special/timebreak_charm.tres"
const CHARM_ID: StringName = &"skystrike_charm"
const HERO: PackedScene = preload("res://entities/player/player.tscn")
const ENEMY: PackedScene = preload("res://entities/enemies/palace/enemy_1/enemy_1.tscn")
const BOW: BowData = preload("res://resources/combat/weapons/bow.tres")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const DASH: AbilityData = preload("res://abilities/dash/dash.tres")
const ULTIMATE: StringName = &"charm_ultimate"
const TARGET: Vector3 = Vector3(0.0, 0.0, -6.2)
const PREVIEW_IMPACT: Vector3 = Vector3(-2.2, 0.0, -6.4)

@export var manual_preview: bool = false

var _player: Player
var _target: Enemy
var _outside: Enemy
var _controller: Node
var _checks: int = 0
var _fails: int = 0
var _capture_dir: String = ""


func _enter_tree() -> void:
	# Reset trước khi các vật nhặt kiểm tra quyền sở hữu trong _ready.
	if manual_preview:
		SaveManager.use_storage_dir("user://test_special_charm/sandbox")
		SaveManager.block_saving()
	else:
		SaveManager.use_storage_dir("user://test_special_charm")
	GameState.replace_progress(PlayerProgress.new())


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var charm: CharmData = load(CHARM_PATH) as CharmData if ResourceLoader.exists(CHARM_PATH) else null
	_check(charm != null and GameState.ITEMS.get_charm(CHARM_ID) == charm, "TC1 Bùa đăng ký trong catalog")
	_check(InputMap.has_action(ULTIMATE), "TC1 Có hành động Thiên Kích")
	if charm == null or not InputMap.has_action(ULTIMATE):
		_finish()
		return
	_check(charm.notch_cost == 3 and charm.rarity != null and charm.rarity.sort_priority == 20,
		"TC1 Đặc biệt, 3 ô khắc")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 1 and args[0] == "--capture":
		_capture_dir = args[1]
	if not manual_preview:
		GameState.add_weapon(SWORD)
		GameState.add_weapon(BOW)
		GameState.set_weapon(SWORD)
		GameState.add_charm(charm)
	_target = _add_enemy(TARGET)
	_outside = _add_enemy(TARGET + Vector3.RIGHT * 9.0)
	_player = HERO.instantiate() as Player
	if manual_preview:
		_player.position = Vector3(0.0, 0.0, 3.7)
	add_child(_player)
	_player.add_to_group(&"player")
	if manual_preview:
		if "--verify-sandbox" in args:
			await _verify_sandbox()
			_finish()
		else:
			print("THIEN_KICH TEST: F nhặt kiếm, cung và bùa. Tab ở checkpoint để đeo. Bắn quái trước mặt rồi bấm R khi đầy.")
		return
	GameState.enter_charm_station()
	_check(GameState.equip_charm(CHARM_ID), "TC1 Đeo được tại trạm")
	await _frames(32)
	_controller = _player.get_node_or_null(^"CharmUltimate")
	_check(is_instance_valid(_controller), "TC1 Có bộ điều khiển khi đeo")
	if _controller == null:
		_finish()
		return
	if "--edges" in args:
		await _verify_cast_edges()
		_finish()
		return
	_check(_meter_visible(), "TC2 Đeo bùa hiện vòng nạp")
	_press(ULTIMATE)
	await _frames(3)
	_check(not _casting(), "TC2 Chưa đầy không dùng được R")
	_target.hurtbox.invulnerable = true
	await _fire_bow()
	_check(_charge() == 0, "TC2 Tên bị bất tử chặn không nạp")
	_target.hurtbox.invulnerable = false
	var initial_hp: int = _target.health.current_health
	for index: int in 12:
		await _fire_bow()
		_check(_charge() == index + 1, "TC3 Mũi tên thật %d nạp đúng một điểm" % (index + 1))
		if index == 5:
			await _capture("01_dang_nap")
	_check(_target.health.current_health < initial_hp, "TC3 Máu quái đã giảm vì tên")
	await _capture("02_day")
	var takeoff: Vector3 = _player.global_position
	_check(_target.has_target(), "TC4 Quái đang thấy cáo trước khi bay")
	_move_cursor(PREVIEW_IMPACT)
	_press(ULTIMATE)
	await _frames(16)
	_check(_casting() and _player.global_position.y > takeoff.y + 0.2, "TC4 R thực sự nâng thân cáo")
	_check(not _target.has_target(), "TC4 Quái mất mục tiêu")
	var health_before: int = _player.health.current_health
	_player.receive_environment_hit(DamageInfo.new(2))
	_player.on_lethal_zone_entered()
	_check(_player.health.current_health == health_before, "TC4 Bất tử với đòn và vùng chết")
	await _capture("03_canhsang")
	await _frames(28)
	_move_cursor(PREVIEW_IMPACT)
	await _frames(9)
	await _capture("04_ngam")
	var target_before: int = _target.health.current_health
	var outside_before: int = _outside.health.current_health
	_press(&"charm_ultimate_confirm")
	await _frames(2)
	await _capture("05a_luc_nha")
	await _frames(3)
	await _capture("05b_vong_co")
	await _frames(2)
	await _capture("05_mui_ban")
	await _capture_contact(target_before)
	await _frames(5)
	await _capture("06a_loi_lua")
	await _frames(5)
	await _capture("06b_song_va_bui")
	await _frames(9)
	await _capture("06c_mep_song_10m")
	await _frames(19)
	await _capture("06d_vet_ran")
	await _frames(9)
	_check(_target.health.current_health == target_before - 4, "TC5 Quái trong vòng mất đúng 4 máu")
	_check(_outside.health.current_health == outside_before, "TC5 Quái ngoài vòng không mất máu")
	_check(_charge() == 0 and not _casting(), "TC5 Xả thanh và kết thúc sau một phát")
	_check(_player.global_position.distance_to(takeoff) < 0.15, "TC6 Tiếp đất đúng chỗ cất cánh")
	_check(_target.has_target(), "TC6 Quái bắt lại mục tiêu sau khi đáp")
	await _capture("07_tiep_dat")
	await _frames(16)
	await _capture("08_sau_no_1s")
	await _frames(68)
	await _capture("09_sau_no_2s")
	_player.receive_environment_hit(DamageInfo.new(1))
	_check(_player.health.current_health == health_before - 1, "TC6 Đáp rồi nhận sát thương bình thường")
	_player.health.heal_full()
	await _frames(64)
	for index: int in 12:
		await _fire_bow()
	_press(ULTIMATE)
	await _frames(270)
	_check(_charge() == 0 and not _casting(), "TC7 Hết giờ mất tích và hạ xuống")
	await _fire_bow()
	_check(GameState.unequip_charm(CHARM_ID), "TC8 Tháo được tại trạm")
	await _frames(2)
	_check(not _meter_visible(), "TC8 Tháo bùa ẩn vòng nạp")
	_check(GameState.equip_charm(CHARM_ID), "TC8 Đeo lại được")
	await _frames(2)
	_check(_charge() == 0 and _meter_visible(), "TC8 Đeo lại bắt đầu từ 0")
	if "--extremes" in args:
		await _verify_extremes()
	_finish()


func _verify_sandbox() -> void:
	await _frames(36)
	_check(not _player.has_weapon() and _player.get_bow() == null
		and not GameState.owns_charm(CHARM_ID), "TC17 Sân tay bắt đầu tay không")
	await _capture("00_san_nhat_do")
	await _interact_with(^"Gear/Sword")
	await _frames(75)
	_check(GameState.get_weapon() == SWORD and not has_node(^"Gear/Sword"), "TC17 F nhặt và cầm kiếm thật")
	await _interact_with(^"Gear/Bow")
	await _frames(75)
	_check(_player.get_bow() == BOW and not has_node(^"Gear/Bow"), "TC17 F nhặt cung thật")
	await _interact_with(^"Gear/Charm")
	_check(GameState.owns_charm(CHARM_ID) and not has_node(^"Gear/Charm"), "TC17 F nhặt bùa thật")
	_check(not GameState.can_change_charms(), "TC17 Ở ngoài miếu chưa thể đổi bùa")
	_player.global_position = ($Training/Checkpoint as Node3D).global_position
	await _frames(8)
	_check(GameState.can_change_charms() and GameState.equip_charm(CHARM_ID), "TC17 Miếu mở quyền đeo")
	await _frames(8)
	_check(_meter_visible(), "TC17 Đeo bùa từ pickup hiện thanh nạp")
	var dummy: TrainingDummy = $Training/Dummy
	var dummy_health: HealthComponent = dummy.get_node(^"HealthComponent") as HealthComponent
	_player.teleport(dummy.global_position + Vector3(0.0, 0.2, 1.4), Vector3.FORWARD)
	await _frames(12)
	# Căn vị trí theo chuột thật vì viewport gốc vẫn ưu tiên vị trí con trỏ hệ điều hành.
	for attempt: int in 3:
		var facing: Vector3 = _player.get_mouse_aim_direction()
		if facing.is_zero_approx():
			break
		var toward_dummy: Vector3 = dummy.global_position - _player.global_position
		toward_dummy.y = 0.0
		if toward_dummy.normalized().dot(facing) > 0.96:
			break
		_player.teleport(dummy.global_position + Vector3.UP * 0.2 - facing * 1.4, facing)
		await _frames(12)
	_player.energy.set_current(0)
	var before: int = dummy_health.current_health
	await _hold(&"attack")
	await _frames(38)
	_check(dummy_health.current_health < before and _player.energy.current > 0,
		"TC17 Chém hình nộm thật hồi linh lực (máu %d → %d, linh lực %d)"
		% [before, dummy_health.current_health, _player.energy.current])
	_check(not GameState.can_change_charms(), "TC17 Rời miếu đóng quyền đổi bùa")


func _interact_with(path: NodePath) -> void:
	var pickup: Node3D = get_node_or_null(path) as Node3D
	if pickup == null:
		return
	_player.global_position = pickup.global_position
	await _frames(10)
	await _hold(&"interact")
	await _frames(8)


func _hold(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _verify_extremes() -> void:
	var tuning: SkystrikeData = _controller.get(&"data") as SkystrikeData
	tuning.hits_to_fill = 1
	tuning.aim_time = 0.5
	tuning.radius = 1.0
	await _fire_bow()
	_check(_charge() == 1, "TC9 Ngưỡng 1 tên vừa trúng là đầy")
	_player.set_attack_blocked_by_ui(true)
	_press(ULTIMATE)
	await _frames(5)
	_check(not _casting() and _charge() == 1, "TC9 R bị chặn khi menu chiếm input")
	_player.set_attack_blocked_by_ui(false)
	var ceiling: StaticBody3D = _low_ceiling()
	await _frames(3)
	_press(ULTIMATE)
	await _frames(6)
	_check(not _casting() and _charge() == 1, "TC9 Trần thấp chặn R và giữ năng lượng")
	ceiling.queue_free()
	await _frames(2)
	_player.state_machine.transition_to(PlayerState.ATTACK)
	_press(ULTIMATE)
	await _frames(4)
	_check(not _casting() and _charge() == 1, "TC9 R không cắt ngang một nhát kiếm")
	await _frames(60)
	var hp: int = _target.health.current_health
	var outside_hp: int = _outside.health.current_health
	_press(ULTIMATE)
	await _frames(37)
	_move_cursor(TARGET)
	await _frames(2)
	_press(&"charm_ultimate_confirm")
	await _frames(33)
	await _capture("10_song_1m")
	await _frames(11)
	await _capture("11_vet_chay_1m")
	await _frames(11)
	_check(_target.health.current_health == hp - 4 and _outside.health.current_health == outside_hp,
		"TC10 Bán kính 1 m đánh đúng tâm trong cửa ngắm 0,5 s")
	await _fire_bow()
	_press(ULTIMATE)
	await _frames(40)
	_press(&"pause")
	await _frames(50)
	_check(not _casting() and _charge() == 0 and not get_tree().paused,
		"TC10 Esc hạ xuống, mất nạp, không bật menu")

	tuning.hits_to_fill = 50
	tuning.aim_time = 10.0
	tuning.radius = 12.0
	_target.health.max_health = 300
	_target.health.heal_full()
	for index: int in 50:
		await _fire_bow()
		if index == 48:
			_check(_charge() == 49, "TC11 49 tên chưa đầy ngưỡng 50")
	_check(_charge() == 50, "TC11 50 mũi tên thật vừa đủ")
	var boss_scene: PackedScene = load("res://entities/bosses/forge_boss/forge_boss.tscn") as PackedScene
	var boss: Boss1 = boss_scene.instantiate() as Boss1
	boss.position = TARGET + Vector3(9, 0, -1)
	add_child(boss)
	boss.set_physics_process(false)
	await _frames(4)
	_check(boss.target_player == _player, "TC11 ForgeBoss đang nhắm cáo")
	_press(ULTIMATE)
	await _frames(280)
	_check(_casting() and boss.target_player == null, "TC11 Cửa ngắm 10 s còn mở và boss mất mục tiêu")
	_move_cursor(TARGET)
	await _frames(2)
	var boss_hp: int = boss.health.current_health
	outside_hp = _outside.health.current_health
	_press(&"charm_ultimate_confirm")
	await _frames(33)
	await _capture("12_song_12m")
	await _frames(11)
	await _capture("13_vet_chay_12m")
	await _frames(16)
	_check(boss.health.current_health == boss_hp - 4 and _outside.health.current_health == outside_hp - 4,
		"TC11 Bán kính 12 m gây đúng 4 máu lên cả ForgeBoss và lính")
	_check(boss.target_player == _player, "TC11 ForgeBoss nhắm lại khi cáo đáp")

	tuning.hits_to_fill = 1
	boss.activate_invulnerable_shield()
	await _fire_bow()
	_press(ULTIMATE)
	await _frames(38)
	_move_cursor(TARGET)
	await _frames(2)
	boss_hp = boss.health.current_health
	_press(&"charm_ultimate_confirm")
	await _frames(58)
	_check(boss.health.current_health == boss_hp and boss.is_shielded, "TC12 Thiên Kích tôn trọng khiên của ForgeBoss")


func _verify_cast_edges() -> void:
	for index: int in 8:
		GameState.unequip_charm(CHARM_ID)
		GameState.equip_charm(CHARM_ID)
	GameState.unequip_charm(CHARM_ID)
	await _frames(3)
	_check(_player.get_node_or_null(^"CharmUltimate") == null and not _meter_visible(),
		"TC13 Đeo tháo liên tục không để lại controller hoặc HUD")
	GameState.equip_charm(CHARM_ID)
	_controller = _player.get_node_or_null(^"CharmUltimate")
	var tuning: SkystrikeData = _controller.get(&"data") as SkystrikeData
	tuning.hits_to_fill = 1
	GameState.unlock_ability(DASH)
	var origin: Vector3 = _player.global_position
	var enemy_hp: int = _target.health.current_health
	_target.global_position = origin + Vector3.FORWARD * 1.25
	_player.face_instantly(Vector3.FORWARD)
	await _frames(3)
	_player.hitbox.activate(SWORD.combo[0])
	_player.hitbox.try_hit(_target.hurtbox)
	_player.hitbox.deactivate()
	await _frames(10)
	_check(_target.health.current_health < enemy_hp and _charge() == 0, "TC13 Kiếm thật gây sát thương mà không nạp")
	_target.global_position = TARGET
	_player.teleport(origin, Vector3.FORWARD)
	await _frames(5)
	await _fire_bow()
	_player.state_machine.transition_to(PlayerState.DASH)
	_press(ULTIMATE)
	await _frames(5)
	_check(not _casting() and _charge() == 1, "TC14 R không cắt ngang dash")
	_player.teleport(Vector3(19.0, 3.0, 0.0), Vector3.FORWARD)
	await _frames(4)
	_press(ULTIMATE)
	await _frames(5)
	_check(not _casting() and _charge() == 1, "TC14 R không cất cánh trên vực")
	_player.teleport(origin, Vector3.FORWARD)
	await _frames(13)

	var toad_scene: PackedScene = load("res://entities/bosses/fire_toad/fire_toad.tscn") as PackedScene
	var toad: FireToad = toad_scene.instantiate() as FireToad
	toad.position = TARGET + Vector3(9, 0, -1)
	var seat: Marker3D = Marker3D.new()
	seat.position = toad.position
	add_child(seat)
	toad.throne = seat
	add_child(toad)
	_check(toad.find_target() == _player, "TC15 Ếch nhìn thấy cáo trước khi bay")
	_press(ULTIMATE)
	await _frames(24)
	var rain_pool: ObjectPool = toad.get_node(^"RainPool") as ObjectPool
	var rain_before: int = rain_pool.get_active_count()
	toad.drop_fireball(origin, 0.3, 1.0)
	_check(_casting() and toad.find_target() == null and rain_pool.get_active_count() == rain_before,
		"TC15 Ếch mất mục tiêu và không sinh mưa cầu khi cáo đang bay")
	_check(GameState.unequip_charm(CHARM_ID), "TC15 Tháo bùa lúc đang bay")
	await _frames(80)
	_check(not _casting() and not _meter_visible() and _player.get_node_or_null(^"CharmUltimate") == null,
		"TC15 Hạ xuống và trả VFX về pool khi tháo bùa")
	_check(toad.find_target() == _player, "TC15 Ếch tìm lại cáo sau khi đáp")
	GameState.equip_charm(CHARM_ID)
	await _fire_bow()
	_controller = _player.get_node_or_null(^"CharmUltimate")
	var pool: ObjectPool = _controller.get_node(^"VfxPool") as ObjectPool
	_press(ULTIMATE)
	await _frames(43)
	_check(_casting(), "TC16 Chuẩn bị tình huống chết giữa lượt")
	# Đi thẳng qua Health trong test để mô phỏng một nguồn kết liễu bắt buộc.
	_player.health.take_damage(_player.health.current_health)
	_press(ULTIMATE)
	await _frames(2)
	_check(not _casting() and _charge() == 0 and pool.get_active_count() == 0,
		"TC16 Chết dọn sạch VFX và R không kích hoạt lại")


func _low_ceiling() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(3.0, 0.25, 3.0)
	shape.shape = box
	body.position = _player.global_position + Vector3.UP * 2.3
	body.add_child(shape)
	add_child(body)
	return body


func _add_enemy(at: Vector3) -> Enemy:
	var enemy: Enemy = ENEMY.instantiate() as Enemy
	enemy.position = at
	add_child(enemy)
	enemy.health.max_health = 120
	enemy.health.heal_full()
	enemy.hurtbox.invincibility_time = 0.0
	# Giữ mục tiêu tại chỗ để đo đúng biên nổ, cảm biến vẫn chạy bằng Area3D.
	enemy.set_physics_process(false)
	return enemy


func _fire_bow() -> void:
	_player.energy.set_current(_player.energy.get_max())
	_player.turn_bow_toward(TARGET - _player.global_position, -1.0, 0.0)
	_player.shoot_bow(1.0)
	await _frames(27)


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event, true)
	event = InputEventAction.new()
	event.action = action
	get_viewport().push_input(event, true)


func _move_cursor(point: Vector3) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = camera.unproject_position(point)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)


func _charge() -> int:
	_controller = _player.get_node_or_null(^"CharmUltimate")
	return int(_controller.call(&"get_charge")) if _controller else 0


func _casting() -> bool:
	return bool(_controller.call(&"is_casting")) if is_instance_valid(_controller) else false


func _meter_visible() -> bool:
	var ring: Control = _player.get_node_or_null(^"HUD/EnergyBar/SpecialChargeRing") as Control
	return ring != null and ring.visible


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame


func _capture_contact(health_before: int) -> void:
	# Chụp ngay khi quái mất máu vì chớp trắng chỉ tồn tại vài frame.
	for _frame: int in 14:
		if _target.health.current_health < health_before:
			break
		await _frames(1)
	await _capture("06_vu_no")


func _capture(label: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	print("THIEN_KICH CAPTURE ", label, " ",
		error_string(image.save_png(_capture_dir.path_join(label + ".png"))))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_fails += 1
	print("THIEN_KICH ", "PASS " if condition else "FAIL ", label)


func _finish() -> void:
	print("THIEN_KICH RESULT checks=", _checks, " fails=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)
