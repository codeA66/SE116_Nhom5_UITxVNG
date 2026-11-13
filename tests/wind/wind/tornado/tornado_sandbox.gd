extends Node
## Sân thử Lốc xoáy (Thổi gió cấp 2): có sẵn kiếm + Thổi gió cấp 1, hai Ấn Gió nằm trên sân.
## Chơi tay: nhặt 2 Ấn Gió (F) -> Tab, trang Nguyên tố -> chuột phải / F trên thẻ Gió để nâng cấp -> E thả lốc.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.
## Chạy `-- --verify` để tự bấm phím thật và đo hành vi rồi thoát (0 = đạt).

const SEAL: ItemData = preload("res://resources/player/items/upgrades/wind_seal.tres")
const STORAGE := "user://test_wind_tornado/"

@export var weapons: Array[Resource] = []
@export var abilities: Array[Resource] = []

var _failed: int = 0
var _bursts: Array[Vector3] = []
var _hits: Dictionary[Node, int] = {}


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for progress_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if progress_signal.is_connected(SaveManager.save_game):
			progress_signal.disconnect(SaveManager.save_game)


func _ready() -> void:
	for weapon in weapons:
		GameState.add_weapon(weapon as WeaponData)
	if not weapons.is_empty():
		GameState.set_weapon(weapons[0] as WeaponData)
	for ability in abilities:
		GameState.unlock_ability(ability as AbilityData)
		# Sân luôn bắt đầu ở cấp 1 để thử đúng đường nâng cấp
		GameState.progress.ability_levels.erase((ability as AbilityData).id)
	GameState.progress.items.erase(SEAL.id)
	if OS.get_cmdline_user_args().has("--verify"):
		_verify.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _press_skill() -> void:
	Input.action_press(&"skill")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"skill")


func _watch(target: Node) -> void:
	_hits[target] = 0
	(target.get_node(^"HurtboxComponent") as HurtboxComponent).hurt.connect(
		func(_info: DamageInfo, _taken: int) -> void: _hits[target] += 1)


func _verify() -> void:
	var zone := get_parent() as ZoneRoot
	if not zone.is_combat_ready():
		await zone.combat_ready
	var player := zone.get_node(^"Player") as Player
	var wind := abilities[0] as SkillData
	var pool := player.get_node(^"StateMachine/WindTornado/Pool") as ObjectPool
	for tornado: WindTornado in pool.get_children():
		tornado.burst.connect(func(at: Vector3) -> void: _bursts.append(at))
	# Quái trong sân chỉ để chơi tay: bản đo dùng hình nộm đứng yên cho số đo ổn định
	for node in zone.get_children():
		if node is Enemy:
			node.queue_free()
	await _wait(0.3)

	# --- Cấp 1 vẫn là Thổi gió, 1 ô
	_check(player.get_skill_form(wind) is WindBlastData, "cấp 1: dạng đang dùng là Thổi gió")
	_check(not GameState.can_upgrade_ability(wind), "chưa có Ấn Gió thì chưa nâng được")

	# --- Nhặt vật phẩm thật qua tương tác rồi nâng cấp
	for pickup_name: String in ["SealA", "SealB"]:
		var pickup := zone.get_node(pickup_name) as ItemPickup
		(pickup.get_node(^"InteractableComponent") as InteractableComponent).interacted.emit(player)
	await get_tree().process_frame
	_check(GameState.get_item_count(SEAL) == 2, "nhặt 2 vật phẩm -> có 2 Ấn Gió (có %d)" % GameState.get_item_count(SEAL))
	_check(zone.get_node_or_null(^"SealA") == null, "vật phẩm đã nhặt biến mất")
	_check(GameState.upgrade_ability(wind), "đủ Ấn Gió thì nâng cấp được")
	_check(GameState.get_ability_level(wind) == 2 and GameState.get_item_count(SEAL) == 0, "lên cấp 2, Ấn Gió bị trừ hết")
	var form := player.get_skill_form(wind) as WindTornadoData
	_check(form != null and form.energy_cost == 2, "cấp 2: dạng đang dùng là Lốc xoáy, tốn 2 ô")
	if form == null:
		get_tree().quit(1)
		return

	# --- Thả lốc bằng phím thật về phía hàng hình nộm (-Z)
	var near := zone.get_node(^"DummyNear") as Node3D
	var side := zone.get_node(^"DummySide") as Node3D
	var far := zone.get_node(^"DummyFar") as Node3D
	for dummy: Node in [near, side, far]:
		_watch(dummy)
	player.face_instantly(Vector3.FORWARD)
	var energy_before := player.energy.current
	var start := player.global_position
	await _press_skill()
	await _wait(0.1)
	_check(player.state_machine.current_state.name == &"WindTornado", "bấm E vào state WindTornado (đang ở %s)" % player.state_machine.current_state.name)
	_check(energy_before - player.energy.current == 2, "trừ 2 ô năng lượng (trừ %d)" % (energy_before - player.energy.current))
	await _wait(0.4)
	_check(pool.get_active_count() == 1, "có đúng 1 cơn lốc đang chạy")
	await _wait(form.travel_distance / form.travel_speed + 0.3)
	_check(_bursts.size() == 1, "lốc nổ đúng 1 lần (%d)" % _bursts.size())
	if _bursts.size() == 1:
		var travelled := Vector2(_bursts[0].x - start.x, _bursts[0].z - start.z).length()
		var expected := form.spawn_offset + form.travel_distance
		_check(absf(travelled - expected) < 0.4, "nổ sau khi đi hết quãng đường: %.2f m (mong %.2f)" % [travelled, expected])
	_check(_hits[near] == 1, "hình nộm trên đường lốc (ngoài tầm nổ): quẹt 1 lần (%d)" % _hits[near])
	_check(_hits[far] == 2, "hình nộm ở điểm nổ: quẹt 1 + nổ 1 = 2 (%d)" % _hits[far])
	_check(_hits[side] == 0, "hình nộm lệch 6 m: không trúng (%d)" % _hits[side])
	await _wait(form.linger + 0.4)
	_check(pool.get_active_count() == 0, "lốc tan xong trả về pool")
	_check(pool.get_total_created() == 1, "không tạo thêm cơn lốc ngoài pool (%d)" % pool.get_total_created())

	# --- Gặp tường thì nổ sớm (tường ở x = 8)
	await _wait(1.0)
	player.energy.set_current(player.energy.get_max())
	_bursts.clear()
	player.teleport(Vector3(2, 0, 6), Vector3.RIGHT)
	await _wait(0.2)
	player.face_instantly(Vector3.RIGHT)
	await _press_skill()
	await _wait(2.2)
	_check(_bursts.size() == 1 and _bursts[0].x < 8.0 and _bursts[0].x > 6.5, "gặp tường nổ sớm trước mặt tường: x = %s" % (str(snappedf(_bursts[0].x, 0.01)) if _bursts.size() == 1 else "không nổ"))

	# --- Thông số cực đoan: quãng đường 0, bán kính rất nhỏ / rất lớn
	for extreme: Array in [[0.0, 0.05, 0.05], [3.0, 15.0, 15.0], [40.0, 0.5, 0.5]]:
		await _wait(1.6)
		player.energy.set_current(player.energy.get_max())
		form.travel_distance = extreme[0]
		form.pull_radius = extreme[1]
		form.burst_radius = extreme[2]
		form.stops_at_walls = false
		_bursts.clear()
		player.teleport(Vector3(0, 0, 10), Vector3.BACK)
		await _wait(0.2)
		await _press_skill()
		await _wait(extreme[0] / form.travel_speed + 1.0)
		_check(_bursts.size() == 1, "cực đoan quãng %.1f / bán kính %.2f: vẫn nổ đúng 1 lần (%d)" % [extreme[0], extreme[1], _bursts.size()])
		await _wait(form.linger + 0.3)
		_check(pool.get_active_count() == 0, "cực đoan: lốc trả về pool")

	print("TORNADO VERIFY: %s" % ("OK" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
