extends Node
## UC: nhặt/đeo Hỏa Tiễn tại checkpoint, bắn lửa không cần kỹ năng lửa, ghép với Ưng Nhãn rồi tháo.
## TC: dữ liệu; tên thường/lửa; sát thương/phí; cháy thật; hai tên; hết năng lượng; gỡ; đổi khu; chết; dữ liệu rỗng.
## TC17 đo pixel ở khung đầu sau khi tái dùng VFX, vì tọa độ node đúng vẫn có thể che giấu lỗi nội suy.
## F6 scene cùng tên. Chỉ kiểm thử bùa; không thiết lập hay kiểm thử fusion vũ khí.

const SANDBOX: PackedScene = preload("res://tests/player/game/charms/combat/combat_charm_sandbox.tscn")
const PLAYER: PackedScene = preload("res://entities/player/player.tscn")
const CHARM: CharmData = preload("res://resources/player/items/charms/combat/fire_arrow_charm.tres")
const KEEN: CharmData = preload("res://resources/player/items/charms/combat/keen_eye_charm.tres")
const STORAGE: String = "user://test_fire_bow_charm/"
const TARGET_HEALTH: int = 99
const TARGET_DISTANCE: float = 6.0
const HOLD_FRAMES: int = 30
const SHOT_WAIT: float = 0.8
const CAPTURE_ARG: String = "--capture-dir="
const FIRE_TRAIL: PackedScene = preload("res://assets/vfx/fire/fire_arrow/fire_arrow_trail.tscn")
const RENDER_TEST_SIZE: Vector2i = Vector2i(640, 360)
const REUSE_SAMPLES: int = 16
const RENDER_POSITION_TOLERANCE: float = 4.0
const PARTICLE_DRAIN_WAIT: float = 0.65

var _failures: int = 0
var _checks: int = 0
var _view: SubViewport
var _level: Node3D
var _player: Player
var _target: Node3D
var _health: HealthComponent
var _burnable: BurnableComponent
var _aim: InputEventMouseMotion = InputEventMouseMotion.new()
var _shot_frames: Array[int] = []
var _fiery_shots: Array[bool] = []
var _seen_arrows: Dictionary[Node, bool] = {}
var _capture_dir: String = ""
var _capture_volley: bool = false
var _last_damage: int = 0
var _last_cost: int = 0
var _draw_element: StringName


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for event: Signal in [GameState.progress_changed, GameState.progress_committed, GameState.tutorials_changed]:
		if event.is_connected(SaveManager.save_game):
			event.disconnect(SaveManager.save_game)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARG):
			_capture_dir = argument.trim_prefix(CAPTURE_ARG)
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
	set_physics_process(false)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_player):
		return
	var camera: Camera3D = _view.get_camera_3d()
	if camera:
		# Chuột giả nằm trong viewport thử, không di chuyển con trỏ của người dùng.
		var point: Vector3 = _target.global_position
		point.y = _player.global_position.y
		_aim.position = camera.unproject_position(point)
		_aim.global_position = _aim.position
		_view.push_input(_aim, true)


func _run() -> void:
	_level = SANDBOX.instantiate() as Node3D
	_level.get_node("Sandbox").set("abilities", [] as Array[Resource])
	_view.add_child(_level)
	await _wait(1.0)
	_bind_player(_level.get_node("Player") as Player)
	_target = _level.get_node("DummyBow") as Node3D
	_health = _target.get_node("HealthComponent") as HealthComponent
	_burnable = _target.get_node("BurnableComponent") as BurnableComponent
	_health.set_max_health(TARGET_HEALTH, true)
	set_physics_process(true)
	_check(GameState.ITEMS.get_charm(CHARM.id) == CHARM and CHARM.notch_cost == 1 and CHARM.rarity == null,
		"TC1 bùa thường, một ô khắc, có trong catalog")
	_check(not GameState.has_ability(&"flame_breath"), "TC2 chưa mở kỹ năng lửa")
	GameState.add_charm(CHARM)
	GameState.add_charm(KEEN)
	await _shoot()
	var base_damage: int = _last_damage
	_check(_shot_frames.size() == 1 and _fiery_shots == [false] and not _burnable.is_burning(),
		"TC3 không bùa: một tên thường, mục tiêu không cháy")
	_check(base_damage > 0 and _last_cost == 1, "TC3 tên thường thực sự trúng, tốn một linh lực")
	await _at_checkpoint()
	_check(GameState.can_change_charms(), "TC4 chạm vùng checkpoint thật để đổi bùa")
	_check(GameState.equip_charm(CHARM.id), "TC4 đeo Hỏa Tiễn")
	_capture_volley = true
	await _shoot()
	_capture_volley = false
	_check(_draw_element == &"fire" and _fiery_shots == [true], "TC5 tụ lực và tên bay đều có lửa")
	_check(_burnable.is_burning() and _burnable.get_source() == _player,
		"TC6 va chạm thật châm cháy mục tiêu, nguồn là player")
	_check(_last_damage == base_damage and _last_cost == 1,
		"TC7 giữ nguyên sát thương tên và phí một linh lực")
	_check(_count_effects(&"EmberLight", true) > 0 and _count_effects(&"FireArrowHitVfx", true) > 0,
		"TC8 trúng để lại đốm sáng và hiệu ứng bùng lửa")
	_check(_count_effects(&"FireArrowTrail", true) == 0 and _count_effects(&"FireTouch", true) == 0,
		"TC8 vệt bay và vùng đốt đã kết thúc sau va chạm")
	await _at_checkpoint()
	_check(GameState.equip_charm(KEEN.id), "TC9 đeo cùng Ưng Nhãn")
	_capture_volley = true
	await _shoot()
	_capture_volley = false
	_check(_fiery_shots == [true, true], "TC9 cả hai tên có lửa")
	_check(_shot_frames.size() == 2 and absf(float(_shot_frames[1] - _shot_frames[0]) / Engine.physics_ticks_per_second - 0.2) < 0.001,
		"TC9 hai phát cách nhau 0,20 giây")
	_check(_last_damage == base_damage * 2 and _last_cost == 1, "TC9 hai tên thực sự trúng, tổng một linh lực")
	await _shoot(false)
	_check(_shot_frames.is_empty() and _last_cost == 0, "TC10 hết linh lực không bắn, không tạo lửa")
	await _at_checkpoint()
	_check(GameState.unequip_charm(CHARM.id), "TC11 tháo Hỏa Tiễn")
	await _shoot()
	_check(_fiery_shots == [false, false] and not _burnable.is_burning() and _player.get_bow_imbue() == null,
		"TC11 Ưng Nhãn còn đeo: hai tên trở lại thường, không sót nguồn lửa")
	await _at_checkpoint()
	GameState.unequip_charm(KEEN.id)
	var effect: BowImbueEffect = CHARM.effects[0] as BowImbueEffect
	var pooled_before: int = _pooled_instances()
	for index: int in range(20):
		effect.apply(_player)
		effect.remove(_player)
	_check(_player.get_bow_imbue() == null, "TC12 đeo/tháo 20 lần không sót nguồn")
	_check(_pooled_instances() == pooled_before, "TC12 đeo/tháo dùng lại pool, không tạo thêm VFX")
	var empty: BowImbueEffect = BowImbueEffect.new()
	empty.apply(_player)
	_check(_player.get_bow_imbue() == null, "TC13 cấu hình null không bật buff")
	var invalid: FusionData = FusionData.new()
	invalid.weapon_slot = WeaponData.Slot.SWORD
	_player.register_bow_imbue(&"invalid", invalid)
	_check(_player.get_bow_imbue() == null, "TC13 dữ liệu sai loại hoặc thiếu nguyên tố bị từ chối")
	_player.register_bow_imbue(&"", effect.get_infusion())
	_check(_player.get_bow_imbue() == null, "TC13 nguồn rỗng không đăng ký")
	for index: int in range(100):
		effect.apply(_player)
	effect.remove(_player)
	_check(_player.get_bow_imbue() == null, "TC14 áp trùng 100 lần, gỡ một lần hết hẳn")
	GameState.equip_charm(CHARM.id)
	await _replace_player()
	_check(_player.get_bow_imbue() == effect.get_infusion(), "TC15 player mới khôi phục bùa đang đeo")
	await _shoot()
	_check(_fiery_shots == [true] and _burnable.is_burning(), "TC15 player mới bắn lửa và đốt trúng thật")
	await _at_checkpoint()
	GameState.unequip_charm(CHARM.id)
	await _replace_player()
	await _shoot()
	_check(_fiery_shots == [false] and not _burnable.is_burning(), "TC15 đổi khu sau tháo không khôi phục nhầm lửa")
	await _at_checkpoint()
	GameState.equip_charm(CHARM.id)
	_player.energy.set_current(_player.energy.get_max())
	Input.action_press(&"aim")
	await _frames(HOLD_FRAMES)
	_check(_player.get_node("FireBowVfx").is_processing(), "TC16 đang tụ lực lửa trước đòn kết liễu")
	_player.health.take_damage(_player.health.current_health)
	_check(_player.get_bow_imbue() == null, "TC16 chết không còn buff cung hoạt động")
	await _wait(0.4)
	_check(not (_player.get_node("FireBowVfx") as Node).is_processing(), "TC16 tụ lực tắt sau chết")
	set_physics_process(false)
	Input.action_release(&"aim")
	_level.queue_free()
	_player = null
	_target = null
	await _frames(2)
	await _tc17_pooled_first_frame()
	print("FIRE_BOW_CHARM RESULT checks=%d fails=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _tc17_pooled_first_frame() -> void:
	# Tách thế giới để màu HUD, lửa đang cháy hay đốm sáng cũ không lẫn vào phép đo pixel.
	_view.own_world_3d = true
	_view.size = RENDER_TEST_SIZE
	var stage: Node3D = Node3D.new()
	_view.add_child(stage)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 18.0, 15.0)
	camera.fov = 40.0
	stage.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = FIRE_TRAIL
	pool.initial_size = 1
	stage.add_child(pool)
	var trail: FireArrowTrail = pool.acquire() as FireArrowTrail
	trail.finished.connect(pool.release.bind(trail))
	var first_instance: int = trail.get_instance_id()
	var emitter: Node3D = Node3D.new()
	emitter.position = Vector3(-5.0, 1.0, 0.0)
	stage.add_child(emitter)
	trail.start(emitter)
	await _wait(0.22)
	emitter.queue_free()
	await _wait(PARTICLE_DRAIN_WAIT)
	var misplaced: int = 0
	var max_gap: float = 0.0
	var same_slot: bool = true
	for sample: int in range(REUSE_SAMPLES):
		trail = pool.acquire() as FireArrowTrail
		same_slot = same_slot and trail.get_instance_id() == first_instance
		emitter = Node3D.new()
		emitter.position = Vector3(5.0 if sample % 2 == 0 else -5.0, 1.0, 0.0)
		stage.add_child(emitter)
		trail.start(emitter)
		# Không reset trong test: lời gọi start() của production phải tự giữ đúng khung đầu.
		await RenderingServer.frame_post_draw
		var snapshot: Image = _view.get_texture().get_image()
		var measured: Vector2 = _fire_pixel_center(snapshot)
		var expected: Vector2 = camera.unproject_position(emitter.global_position + Vector3(0.0, 0.0, -trail.head_back))
		var gap: float = measured.distance_to(expected)
		max_gap = maxf(max_gap, gap)
		var correct: bool = measured != Vector2.INF and gap <= RENDER_POSITION_TOLERANCE
		if not correct:
			misplaced += 1
		_check(correct, "TC17 khung đầu lượt %d: lệch %.2f px (tối đa %.1f)" % [sample + 1, gap, RENDER_POSITION_TOLERANCE])
		if not _capture_dir.is_empty() and (sample < 2 or not correct):
			var saved: Error = snapshot.save_png(_capture_dir.path_join("reuse_first_%02d.png" % sample))
			_check(saved == OK, "ảnh khung đầu tái dùng %d" % sample)
		emitter.queue_free()
		await _wait(PARTICLE_DRAIN_WAIT)
	_check(same_slot and pool.get_total_created() == 1, "TC17 16 lượt dùng đúng một slot, không tạo thêm VFX")
	_check(pool.get_active_count() == 0 and not trail.is_processing(), "TC17 VFX kết thúc và trả về pool")
	print("FIRE_BOW_RENDER samples=%d misplaced=%d max_gap_px=%.3f" % [REUSE_SAMPLES, misplaced, max_gap])
	stage.queue_free()
	await _frames(2)


func _fire_pixel_center(snapshot: Image) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for y: int in range(snapshot.get_height()):
		for x: int in range(snapshot.get_width()):
			var pixel: Color = snapshot.get_pixel(x, y)
			if pixel.r > 0.6 and pixel.g > 0.15 and pixel.b < 0.65:
				sum += Vector2(x, y)
				count += 1
	return sum / float(count) if count > 0 else Vector2.INF


func _bind_player(user: Player) -> void:
	_player = user
	_player.bow_projectile_fired.connect(_on_shot)
	_player.fusion_bow_draw.connect(_on_draw)


func _replace_player() -> void:
	Input.action_release(&"aim")
	var previous: Player = _player
	_player = null
	previous.get_parent().remove_child(previous)
	previous.queue_free()
	await _frames(2)
	var user: Player = PLAYER.instantiate() as Player
	user.name = "Player"
	_level.add_child(user)
	_bind_player(user)
	await _wait(0.5)


func _at_checkpoint() -> void:
	Input.action_release(&"aim")
	_player.teleport((_level.get_node("CharmCheckpoint") as Node3D).global_position + Vector3.UP * 0.1)
	await _frames(12)


func _shoot(refill: bool = true) -> void:
	await _wait(0.8)
	_burnable.extinguish()
	_health.heal_full()
	_shot_frames.clear()
	_fiery_shots.clear()
	_seen_arrows.clear()
	_draw_element = &""
	_player.teleport(_target.global_position + Vector3(0.0, 0.1, TARGET_DISTANCE), Vector3.FORWARD)
	await _frames(10)
	_player.energy.set_current(_player.energy.get_max() if refill else 0)
	var energy_before: int = _player.energy.current
	var health_before: int = _health.current_health
	Input.action_press(&"aim")
	await _frames(HOLD_FRAMES)
	if _capture_volley:
		await _capture("draw.png")
	Input.action_release(&"aim")
	await _wait(SHOT_WAIT)
	_last_cost = energy_before - _player.energy.current
	_last_damage = health_before - _health.current_health
	print("FIRE_BOW_MEASURE shots=%d damage=%d energy=%d fire=%s" % [_shot_frames.size(), _last_damage, _last_cost, _fiery_shots])
	if _capture_volley:
		await _capture("impact_%d.png" % _shot_frames.size())


func _on_shot(_primary: bool) -> void:
	_shot_frames.append(Engine.get_physics_frames())
	var fiery: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"arrows"):
		var arrow: ArrowProjectile = node as ArrowProjectile
		if arrow and arrow.is_physics_processing() and not _seen_arrows.has(arrow):
			_seen_arrows[arrow] = true
			for visual: Node in _player.find_children("*", "FireArrowTrail", true, false):
				var trail: FireArrowTrail = visual as FireArrowTrail
				if trail.is_processing() and trail.global_position.is_equal_approx(arrow.global_position):
					fiery = true
	_fiery_shots.append(fiery)
	if _capture_volley:
		_capture_flight(_shot_frames.size())


func _on_draw(element_id: StringName, _amount: float) -> void:
	_draw_element = element_id


func _capture_flight(index: int) -> void:
	await _frames(2)
	await _capture("flight_%d_%d.png" % [_player.get_bow_projectile_count(), index])


func _capture(filename: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var result: Error = _view.get_texture().get_image().save_png(_capture_dir.path_join(filename))
	_check(result == OK, "ảnh " + filename)


func _count_effects(type_name: StringName, active_only: bool) -> int:
	var count: int = 0
	for node: Node in _player.find_children("*", String(type_name), true, false):
		if not active_only or (node is EmberLight and (node as EmberLight).is_lit()) or node.is_processing() or node.is_physics_processing():
			count += 1
	return count


func _pooled_instances() -> int:
	var count: int = 0
	for node: Node in _player.find_children("*", "ObjectPool", true, false):
		count += (node as ObjectPool).get_total_created()
	return count


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print(("PASS " if condition else "FAIL ") + label)
