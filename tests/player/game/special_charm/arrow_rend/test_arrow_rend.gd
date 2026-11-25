extends Node
## UC1 Sân thử có bùa 3 ô và hình nộm 100 máu. Bắn ghim, kiếm trúng mới rút, tối đa 6 tên.
## UC2 ForgeBoss tính theo cặp tên và giữ mũi lẻ. Khiên hoặc i-frame bảo toàn tên.
## UC3 Ưng Nhãn ghim đủ hai mũi, Hỏa Tiễn ghim theo tên cung, Phẫn Nộ cộng dồn sát thương với Đoạt Tiễn.
## UC4 Song Trảm rút ở nhát trúng đầu tiên. Thiên Kích chỉ nạp từ tên, kể cả khi đang ghim.
## UC5 Tháo bùa, hết hạn và chết đều thu hồi hiệu ứng.

const SANDBOX: PackedScene = preload("res://tests/player/game/charms/combat/combat_charm_sandbox.tscn")
const BOSS: PackedScene = preload("res://entities/bosses/forge_boss/forge_boss.tscn")
const REND: StringName = &"arrow_rend_charm"
const KEEN: StringName = &"keen_eye_charm"
const FIRE: StringName = &"fire_arrow_charm"
const WRATH: StringName = &"wrath_charm"
const SONG_TRAM: StringName = &"threefold_slash_charm"
const SKYSTRIKE: StringName = &"skystrike_charm"

var _view: SubViewport
var _stage: Node3D
var _player: Player
var _pool: ObjectPool
var _dummy: TrainingDummy
var _spare: TrainingDummy
var _aim: Vector3
var _cursor: InputEventMouseMotion = InputEventMouseMotion.new()
var _fails: int
var _capture_dir: String = ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveManager.block_saving()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--capture":
		_capture_dir = args[1]
	_view = SubViewport.new()
	_view.size = Vector2i(1280, 720)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_view.notify_mouse_entered()
	var display: TextureRect = TextureRect.new()
	display.texture = _view.get_texture()
	display.size = Vector2(_view.size)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	_stage = SANDBOX.instantiate() as Node3D
	_view.add_child(_stage)
	await _frames(80)
	_player = _stage.get_node(^"Player") as Player
	_dummy = _stage.get_node(^"DummyBow") as TrainingDummy
	_spare = _stage.get_node(^"DummySword") as TrainingDummy
	var pickup: Node = _stage.get_node(^"ArrowRendCharm")
	var charm: CharmData = GameState.ITEMS.get_charm(REND)
	_check(charm != null and pickup.get(&"charm") == charm and charm.notch_cost == 3 and charm.rarity.sort_priority == 20,
		"TC1 Đoạt Tiễn bậc Đặc biệt, 3 ô và có vật nhặt")
	_check(_health(_dummy).max_health == 100, "TC1 hình nộm cung có đúng 100 máu")
	for id: StringName in [REND, KEEN, FIRE, WRATH, SONG_TRAM, SKYSTRIKE]:
		GameState.add_charm(GameState.ITEMS.get_charm(id))
	GameState.enter_charm_station()
	_check(GameState.equip_charm(REND) and GameState.get_used_notches() == 3, "TC1 checkpoint cho đeo bùa 3 ô")
	_pool = _player.get_node_or_null(^"ArrowRend/ArrowPool") as ObjectPool
	if _pool == null:
		_check(false, "TC1 thiếu pool hiệu ứng sau khi đeo")
		_finish()
		return
	await _test_normal_target()
	await _test_boss()
	await _test_other_charms()
	await _test_skystrike()
	await _test_cleanup()
	_finish()


func _test_normal_target() -> void:
	await _stand(_dummy, 4.2)
	var loss: int = await _shoot(_dummy)
	_check(loss == 2 and _active_arrows() == 1, "TC2 cung gây 2 máu và ghim một tên vào hình nộm")
	await _stand(_spare, 1.5)
	loss = await _slash(_spare)
	_check(loss == 1 and _active_arrows() == 1, "TC2 chém con khác chỉ gây 1 máu và không rút tên")
	await _frames(24)
	await _stand(_dummy, 1.5)
	var hurtbox: HurtboxComponent = _dummy.get_node(^"HurtboxComponent") as HurtboxComponent
	hurtbox.set_invincible(0.65)
	loss = await _slash(_dummy)
	_check(loss == 0 and _active_arrows() == 1, "TC2 i-frame chặn nhát kiếm và giữ tên trên hình nộm")
	await _frames(34)
	await _stand(_dummy, 1.6)
	loss = await _slash(_dummy)
	await _frames(24)
	_check(loss == 2 and _active_arrows() == 0, "TC2 kiếm 1 + rút tên 1 = 2 máu, hiệu ứng về pool")


func _test_boss() -> void:
	var boss: Boss1 = BOSS.instantiate() as Boss1
	boss.position = Vector3(9.0, 0.0, -6.0)
	_stage.add_child(boss)
	boss.set_physics_process(false)
	boss.get_node(^"StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(8)
	await _stand(boss, 5.0)
	for index: int in 3:
		await _shoot(boss, 45)
		_check(_active_arrows() == index + 1, "TC3 tên %d ghim trên ForgeBoss" % (index + 1))
	await _stand(boss, 1.9)
	var loss: int = await _slash(boss, "05_rut_ten_boss")
	await _frames(28)
	_check(loss == 2 and _active_arrows() == 1, "TC3 boss ba tên mất 2 máu: kiếm 1 + rút một cặp 1, còn một tên")
	await _stand(boss, 5.0)
	await _shoot(boss, 45)
	await _stand(boss, 1.9)
	boss.activate_invulnerable_shield()
	loss = await _slash(boss)
	_check(loss == 0 and _active_arrows() == 2, "TC3 khiên boss chặn đòn và giữ cả cặp tên")
	boss.queue_free()
	await _frames(8)
	_check(_active_arrows() == 0, "TC3 boss rời sân, hiệu ứng thu hồi")


func _test_other_charms() -> void:
	_check(GameState.equip_charm(KEEN) and GameState.get_used_notches() == 4, "TC4 Ưng Nhãn và Đoạt Tiễn vừa 4 ô")
	await _stand(_dummy, 4.2)
	for index: int in 4:
		var loss: int = await _shoot(_dummy, 49)
		_check(loss == 4 and _active_arrows() == mini((index + 1) * 2, 6),
			"TC4 hai mũi Ưng Nhãn ở lượt %d, chặn tại 6 tên" % (index + 1))
	await _stand(_dummy, 1.8)
	await _capture("01_ghim_6_mui")
	var full: int = await _slash(_dummy, "02_rut_6_mui")
	await _frames(30)
	await _capture("03_sau_khi_rut")
	_check(full == 7 and _active_arrows() == 0, "TC4 kiếm 1 + rút sáu tên 6 = 7 máu")
	GameState.unequip_charm(KEEN)
	_check(GameState.equip_charm(FIRE), "TC5 đeo cùng Hỏa Tiễn")
	await _stand(_dummy, 4.2)
	var fire_loss: int = await _shoot(_dummy, 49)
	_check(fire_loss >= 2 and _active_arrows() == 1, "TC5 một mũi Hỏa Tiễn chỉ ghim đúng một tên")
	await _frames(100)
	_check(_active_arrows() == 1, "TC5 hiệu ứng cháy không tự ghim thêm tên")
	GameState.unequip_charm(FIRE)
	GameState.progress.charm_notches = 5
	_check(GameState.equip_charm(WRATH), "TC6 đeo cùng Phẫn Nộ với tổng 5 ô mở khóa")
	var player_hurt: HurtboxComponent = _player.get_node(^"HurtboxComponent") as HurtboxComponent
	var damage: DamageInfo = DamageInfo.new(1)
	damage.staggers = false
	player_hurt.receive_hit(damage)
	var wrath_arrow: int = await _shoot(_dummy, 35)
	_check(wrath_arrow == 3 and _active_arrows() == 2, "TC6 Phẫn Nộ +1 sát thương cung nhưng chỉ ghim thêm một tên")
	await _stand(_dummy, 1.6)
	var wrath_sword: int = await _slash(_dummy)
	await _frames(26)
	_check(wrath_sword == 4 and _active_arrows() == 0, "TC6 kiếm 1 + Phẫn Nộ 1 + hai tên 2 = 4 máu")
	GameState.unequip_charm(WRATH)
	_check(GameState.equip_charm(SONG_TRAM), "TC7 đeo cùng Song Trảm với tổng 5 ô mở khóa")
	await _stand(_dummy, 4.2)
	await _shoot(_dummy)
	await _stand(_dummy, 1.6)
	var first: int = await _slash(_dummy)
	await _frames(52)
	await _stand(_dummy, 1.6)
	var second: int = await _slash(_dummy)
	await _frames(22)
	_check(first == 2 and second == 1 and _active_arrows() == 0,
		"TC7 hai lần chém khi đeo Song Trảm mất %d rồi %d máu; chỉ nhát đầu rút tên" % [first, second])
	GameState.unequip_charm(SONG_TRAM)


func _test_skystrike() -> void:
	GameState.progress.charm_notches = 6
	_check(GameState.equip_charm(SKYSTRIKE) and GameState.get_used_notches() == 6, "TC8 hai bùa Đặc biệt cần đủ 6 ô")
	var skystrike: CharmUltimate = _player.get_node_or_null(^"CharmUltimate") as CharmUltimate
	if skystrike == null:
		_check(false, "TC8 thiếu trạng thái nạp Thiên Kích")
		return
	await _stand(_dummy, 4.2)
	await _shoot(_dummy)
	_check(skystrike.get_charge() == 1 and _active_arrows() == 1, "TC8 một mũi vừa nạp Thiên Kích vừa ghim đúng một tên")
	await _stand(_dummy, 1.6)
	var loss: int = await _slash(_dummy)
	await _frames(30)
	_check(loss == 2 and _active_arrows() == 0 and skystrike.get_charge() == 1,
		"TC8 rút tên gây sát thương và giữ nguyên điểm Thiên Kích")
	GameState.unequip_charm(SKYSTRIKE)


func _test_cleanup() -> void:
	await _stand(_dummy, 4.2)
	await _shoot(_dummy)
	_check(_active_arrows() == 1 and GameState.unequip_charm(REND) and _active_arrows() == 0,
		"TC9 tháo bùa thu hồi ngay tên ghim")
	_check(_player.get_node_or_null(^"ArrowRend") == null, "TC9 tháo bùa gỡ controller khỏi Player")
	_check(GameState.equip_charm(REND), "TC9 đeo lại tại checkpoint")
	_pool = _player.get_node(^"ArrowRend/ArrowPool") as ObjectPool
	await _shoot(_dummy, 45)
	_check(_active_arrows() == 1, "TC9 đeo lại không sót tên từ lần trước")
	await _frames(500)
	_check(_active_arrows() == 0, "TC9 tên hết hạn sau 8 giây")
	await _shoot(_dummy, 45)
	_check(_active_arrows() == 1, "TC9 có tên trước khi player chết")
	_player.health.take_damage(_player.health.current_health)
	await _frames(2)
	_check(_active_arrows() == 0, "TC9 player chết thu hồi tên")


func _stand(target: Node3D, distance: float) -> void:
	_aim = target.global_position
	_player.teleport(_aim + Vector3(0.0, 0.2, distance), Vector3.FORWARD)
	_player.face_instantly(Vector3.FORWARD)
	await _aim_frames(12)


func _shoot(target: Node3D, wait_after: int = 37) -> int:
	_player.energy.set_current(_player.energy.get_max())
	var previous: int = _health(target).current_health
	Input.action_press(&"aim")
	await _aim_frames(29)
	Input.action_release(&"aim")
	await _aim_frames(wait_after)
	return previous - _health(target).current_health


func _slash(target: Node3D, picture: String = "") -> int:
	var previous: int = _health(target).current_health
	Input.action_press(&"attack")
	await _aim_frames(2)
	Input.action_release(&"attack")
	for _index: int in 30:
		await _aim_frames(1)
		var loss: int = previous - _health(target).current_health
		if loss > 0:
			if not picture.is_empty():
				await _aim_frames(2)
				await _capture(picture)
			return loss
	return previous - _health(target).current_health


func _aim_frames(count: int) -> void:
	for _index: int in count:
		var camera: Camera3D = _view.get_camera_3d()
		if camera:
			var point: Vector3 = _aim
			point.y = _player.global_position.y
			_cursor.position = camera.unproject_position(point)
			_cursor.global_position = _cursor.position
			_view.push_input(_cursor, true)
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().physics_frame


func _health(target: Node3D) -> HealthComponent:
	return target.get_node(^"HealthComponent") as HealthComponent


func _active_arrows() -> int:
	return _pool.get_active_count()


func _capture(label: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = _view.get_texture().get_image()
	_check(image.save_png(_capture_dir.path_join(label + ".png")) == OK, "Ảnh " + label)


func _check(ok: bool, label: String) -> void:
	print("REND ", "PASS " if ok else "FAIL ", label)
	if not ok:
		_fails += 1


func _finish() -> void:
	print("REND RESULT fails=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)
