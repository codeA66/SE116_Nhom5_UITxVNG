extends Node3D
## Test Nhện Lửa + tơ bằng hành vi thật: vật lý, va chạm, input (đi, dash, kiếm, Phun lửa) của player thật.
## Chạy: APPDATA/LOCALAPPDATA trỏ vào .godot/spider_runtime (để không ghi save thật), rồi
##   godot --headless --path . res://tests/enemies/fire_spider/test_fire_spider.tscn [-- mục1 mục2 ...]
## Không đưa tên mục thì chạy tất cả. Tên mục: xem _sections().

const SPIDER_SCENE: PackedScene = preload("res://entities/enemies/volcano/fire_spider/fire_spider.tscn")
const PATCH_SCENE: PackedScene = preload("res://objects/combat/spider_web/web_patch.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const DASH: AbilityData = preload("res://abilities/dash/dash.tres")
const FLAME_BREATH: AbilityData = preload("res://abilities/flame_breath/flame_breath.tres")
const SPIDER_DATA_PATH := "res://resources/enemies/volcano/fire_spider/fire_spider.tres"
const PLAYER_HOME := Vector3(0.0, 0.0, 0.0)

## Quái thử đứng yên trong state này: đo riêng đạn tơ / tơ mà không bị AI chen vào
class TestHold extends State:
	var enemy: Enemy

	func physics_update(delta: float) -> void:
		enemy.apply_gravity(delta)
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0


var _failed: int = 0
var _checks: int = 0
var _player: Player
var _spawned: Array[Node] = []


## Một mục = một hàm async. Thêm mục mới: thêm hàm và một dòng ở đây.
func _sections() -> Dictionary[String, Callable]:
	return {
		"slow_dash": _t_slow_and_dash_lock,
		"sword": _t_sword_break,
		"fire": _t_fire_break,
		"bolt_hit": _t_bolt_hits_player,
		"bolt_dodge": _t_bolt_dash_dodge,
		"bolt_floor": _t_bolt_floor,
		"cap": _t_patch_cap,
		"ai": _t_ai_flow,
		"extreme_web": _t_extreme_web,
		"extreme_pounce": _t_extreme_pounce,
		"no_skills": _t_no_skill_data,
		"death": _t_death_midair,
	}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sandbox := ProjectSettings.globalize_path("res://.godot/spider_runtime/").replace("\\", "/").to_lower()
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox):
		push_error("TestFireSpider: đặt APPDATA/LOCALAPPDATA vào .godot/spider_runtime để bảo vệ save thật.")
		get_tree().quit(2)
		return
	_build_arena()
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(SWORD)
	GameState.unlock_ability(DASH)
	GameState.unlock_ability(FLAME_BREATH)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_HOME
	add_child(_player)
	await _frames(5)
	_player.health.max_health = 9999
	_player.health.heal_full()
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var sections := _sections()
	for section_name in sections:
		if not wanted.is_empty() and section_name not in wanted:
			continue
		print("=== ", section_name)
		_cleanup()
		_place_player(PLAYER_HOME, Vector3.FORWARD)
		await _frames(3)
		await (sections[section_name] as Callable).call()
		_cleanup()
	print("FIRE_SPIDER ", "FAILED (%d / %d)" % [_failed, _checks] if _failed > 0 else "PASSED (%d checks)" % _checks)
	get_tree().quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- Hạ tầng

func _check(condition: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if not condition:
		_failed += 1
	print("PASS " if condition else "FAIL ", label, ("  [" + detail + "]") if not detail.is_empty() else "")


func _info(label: String, detail: String) -> void:
	print("INFO ", label, "  [", detail, "]")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(time: float) -> void:
	await _frames(int(ceil(time * 60.0)))


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _place_player(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos + Vector3.UP * 0.05, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()
	_player.health.heal_full()
	_player.get_node("HurtboxComponent").set_invincible(0.0)


func _cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	for child in get_children():
		if child is WebPatch or child is WebBolt:
			child.queue_free()
	var entangle: WebEntangle = _player.get_node_or_null(NodePath(WebEntangle.NODE_NAME)) as WebEntangle
	if entangle:
		entangle.queue_free()
	for action in [&"attack", &"skill", &"skill_fire", &"dash", &"move_right", &"move_left", &"move_forward", &"move_back"]:
		Input.action_release(action)


func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	# Tường để đạn đập vào (bắc, z = -14)
	_box(Vector3(0, 1.5, -14), Vector3(30, 3, 0.5))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)


func _box(at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _fresh_data() -> FireSpiderData:
	var data := ResourceLoader.load(SPIDER_DATA_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FireSpiderData
	# Nhân bản web để đổi số trong một bài không rò sang bài khác
	data.web = data.web.duplicate() as WebData
	data.patrol_radius = 0.0
	return data


func _spawn_spider(pos: Vector3, data: FireSpiderData = null, dormant: bool = true) -> FireSpider:
	var spider := SPIDER_SCENE.instantiate() as FireSpider
	spider.data = data if data != null else _fresh_data()
	spider.position = pos
	if dormant:
		# Thêm state đứng yên và đặt làm state đầu trước khi vào cây: nhện không có AI
		var hold := TestHold.new()
		hold.name = "TestHold"
		hold.enemy = spider
		var machine: StateMachine = spider.get_node("StateMachine")
		machine.add_child(hold)
		machine.initial_state = hold
	add_child(spider)
	_spawned.append(spider)
	if dormant:
		spider.set_dormant(true)
	return spider


func _spawn_patch(pos: Vector3, data: WebData = null) -> WebPatch:
	var patch := PATCH_SCENE.instantiate() as WebPatch
	if data != null:
		patch.data = data
	add_child(patch)
	patch.global_position = pos
	return patch


## Tơ đã vỡ (đang co lại) hoặc đã bị xóa hẳn
func _gone(patch: Variant) -> bool:
	return not is_instance_valid(patch) or patch.is_broken


func _patches() -> Array[WebPatch]:
	var found: Array[WebPatch] = []
	for child in get_children():
		if child is WebPatch and not (child as WebPatch).is_broken:
			found.append(child as WebPatch)
	return found


func _entangled() -> bool:
	return WebEntangle.is_entangled_node(_player)


func _flat_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


## Giữ phím đi một lúc rồi đo tốc độ ngang ổn định
func _measure_run_speed() -> float:
	Input.action_press(&"move_right")
	await _frames(45)
	var speed := _flat_speed()
	Input.action_release(&"move_right")
	await _frames(20)
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	await _frames(3)
	return speed


## Bấm dash và cho biết player có vào state Dash không
func _try_dash() -> bool:
	_player.get_node("HurtboxComponent").set_invincible(0.0)
	await _tap(&"dash")
	var dashed := _player.state_machine.current_state.name == &"Dash"
	await _frames(25)
	return dashed


# ---------------------------------------------------------------- Bài kiểm

func _t_slow_and_dash_lock() -> void:
	var normal := await _measure_run_speed()
	_check(normal > 3.0, "đo được tốc độ chạy thường", "%.2f m/s" % normal)
	_check(await _try_dash(), "chưa dính tơ: dash được")
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	await _frames(40)
	var patch := _spawn_patch(Vector3(0, 0, 0))
	patch.entangle(_player)
	await _frames(5)
	_check(_entangled(), "dính tơ: WebEntangle báo đang dính")
	var slowed := await _measure_run_speed()
	var ratio := slowed / normal
	_check(absf(ratio - 0.3) < 0.04, "dính tơ: tốc độ còn 30%% (giảm 70%%)", "thường %.2f, dính %.2f, tỉ lệ %.3f" % [normal, slowed, ratio])
	_check(not await _try_dash(), "dính tơ: không dash được")
	_check(_player.dash_locked(), "player báo dash đang bị khóa")
	# Phá tơ thì mọi thứ về bình thường
	patch._break()
	await _frames(20)
	_check(not _entangled() and not _player.dash_locked(), "tơ bị phá: hết dính, hết khóa dash")
	var restored := await _measure_run_speed()
	_check(absf(restored - normal) < 0.1, "tơ bị phá: tốc độ trở lại bình thường", "%.2f so với %.2f" % [restored, normal])
	await _frames(40)
	_check(await _try_dash(), "tơ bị phá: dash lại được")


func _t_sword_break() -> void:
	_player.equip_weapon(SWORD)
	var patch := _spawn_patch(Vector3(0, 0, 0))
	var needed: int = patch.data.hits_to_break
	patch.entangle(_player)
	await _frames(5)
	var hp: HealthComponent = patch.get_node("HealthComponent")
	var landed := [0]
	var broke_after_hits := [-1]
	hp.damaged.connect(func(_amount: int) -> void: landed[0] += 1)
	hp.died.connect(func() -> void: broke_after_hits[0] = landed[0])
	var swings := 0
	# Mỗi nhát là bấm attack thật (chuyển state Attack); nhát hụt do đang hồi đòn thì chém tiếp
	while not _gone(patch) and swings < needed + 10:
		_player.energy.set_current(_player.energy.get_max())
		await _tap(&"attack")
		await _seconds(0.45)
		swings += 1
	_check(broke_after_hits[0] == needed, "chém kiếm xé tơ đúng sau %d nhát trúng (cần nhiều nhát)" % needed, "trúng %d nhát, bấm %d lần" % [landed[0], swings])
	_check(landed[0] == needed, "tơ không bị trúng thừa sau khi vỡ", "trúng %d" % landed[0])
	await _frames(30)
	_check(not _entangled(), "tơ vỡ: player hết dính")
	_check(not _player.dash_locked(), "tơ vỡ: hết khóa dash")


func _t_fire_break() -> void:
	var patch := _spawn_patch(Vector3(0, 0, 0))
	patch.entangle(_player)
	await _frames(5)
	_check(_entangled(), "dính tơ trước khi phun lửa")
	_player.energy.set_current(_player.energy.get_max())
	Input.action_press(&"skill_fire")
	await _frames(20)
	var state_name := String(_player.state_machine.current_state.name)
	Input.action_release(&"skill_fire")
	await _seconds(1.2)
	_info("state player khi bấm kỹ năng", state_name)
	_check(_gone(patch), "phun lửa (kỹ năng thật) phá tơ", "state player = %s" % state_name)
	_check(not _entangled(), "tơ cháy: player hết dính")
	# Tơ trên sàn cũng cháy khi lửa chạm
	var floor_patch := _spawn_patch(Vector3(0, 0, 3))
	_place_player(Vector3(0, 0, 0), Vector3(0, 0, 1))
	await _frames(5)
	_player.energy.set_current(_player.energy.get_max())
	Input.action_press(&"skill_fire")
	await _frames(30)
	Input.action_release(&"skill_fire")
	await _seconds(1.0)
	_info("tơ trên sàn cách 3 m", "bị phá=%s" % str(_gone(floor_patch)))


func _t_bolt_hits_player() -> void:
	var spider := _spawn_spider(Vector3(0, 0, 8))
	await _frames(3)
	spider.target = _player
	var bolt := spider.shoot_web(spider.web_aim_direction())
	var landed_on_player := [false]
	bolt.landed.connect(func(_patch: WebPatch, on_player: bool) -> void: landed_on_player[0] = on_player)
	await _seconds(1.5)
	_check(landed_on_player[0], "đạn tơ trúng player")
	_check(_entangled(), "đạn tơ trúng: player dính tơ ngay")
	var patches := _patches()
	_check(patches.size() == 1 and patches[0].is_attached(), "có đúng 1 tấm tơ và nó bám vào người", "số tấm: %d" % patches.size())
	if not patches.is_empty():
		var distance := patches[0].global_position.distance_to(_player.global_position)
		_check(distance < 0.2, "tấm tơ bám theo player", "cách %.3f m" % distance)
	_check(spider.get_node("WebPool").get_active_count() == 0, "đạn đã trả về pool")


func _t_bolt_dash_dodge() -> void:
	var spider := _spawn_spider(Vector3(0, 0, 8))
	await _frames(3)
	spider.target = _player
	# Player bất tử (như đang dash) khi đạn bay qua
	_player.get_node("HurtboxComponent").set_invincible(1.2)
	spider.shoot_web(spider.web_aim_direction())
	await _seconds(0.9)
	_check(not _entangled(), "dash xuyên qua đạn tơ: không dính")
	await _seconds(1.5)
	var patches := _patches()
	_check(patches.size() == 1 and not patches[0].is_attached(), "đạn bay tiếp rồi rớt thành tấm tơ trên sàn", "số tấm: %d" % patches.size())
	if not patches.is_empty():
		_info("tấm tơ rớt tại", str(patches[0].global_position))
	# Đứng sẵn trong tơ lúc còn bất tử: hết bất tử mới dính
	for patch in _patches():
		patch._break()
	await _frames(20)
	var floor_patch := _spawn_patch(Vector3(0, 0, 0))
	_player.get_node("HurtboxComponent").set_invincible(0.4)
	await _frames(10)
	_check(not _entangled(), "đứng trong tơ khi còn bất tử: chưa dính")
	await _seconds(0.6)
	_check(_entangled() and floor_patch.is_attached(), "hết bất tử mà còn trong tơ: dính")


func _t_bolt_floor() -> void:
	var spider := _spawn_spider(Vector3(0, 0, -8))
	await _frames(3)
	spider.face_instantly(Vector3(0, 0, -1))
	# Bắn thẳng vào tường z = -14 ở độ cao 1.0
	spider.shoot_web(Vector3(0, 0, -1))
	await _seconds(1.2)
	var patches := _patches()
	_check(patches.size() == 1, "đạn đập tường tạo 1 tấm tơ", "số tấm: %d" % patches.size())
	if not patches.is_empty():
		var position := patches[0].global_position
		_check(absf(position.y) < 0.15, "tấm tơ nằm sát sàn", "y = %.3f" % position.y)
		_check(position.z > -14.5 and position.z < -12.0, "tấm tơ nằm sát chân tường", "z = %.2f" % position.z)
		_check(not patches[0].is_attached() and not _entangled(), "rơi xa player: không dính ai")
	# Bắn lên trời: hết tuổi thọ rồi rớt
	for patch in _patches():
		patch._break()
	await _frames(30)
	spider.shoot_web(Vector3(0, 1, 0).normalized() + Vector3(0, 0, 0.3))
	await _seconds(2.0)
	_check(_patches().size() == 1, "đạn bắn lên cao hết tuổi thọ cũng thành tấm tơ", "số tấm: %d" % _patches().size())


func _t_patch_cap() -> void:
	var data: WebData = ResourceLoader.load("res://resources/combat/spider_web/spider_web.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as WebData
	var cap: int = data.max_patches
	for i in cap + 4:
		_spawn_patch(Vector3(-20.0 + i * 3.0, 0, -6.0))
		await _frames(2)
	await _seconds(0.6)
	_check(_patches().size() <= cap, "trần số tấm tơ: không vượt %d" % cap, "đang có %d" % _patches().size())
	# Tấm đang dính người không bị gỡ để nhường chỗ
	var attached := _spawn_patch(Vector3(0, 0, 0))
	attached.entangle(_player)
	await _frames(5)
	for i in cap + 4:
		_spawn_patch(Vector3(-20.0 + i * 3.0, 0, -9.0))
		await _frames(2)
	await _seconds(0.6)
	_check(not attached.is_broken and _entangled(), "tấm đang dính người không bị trần gỡ")


func _t_ai_flow() -> void:
	var spider := _spawn_spider(Vector3(0, 0, 8), null, false)
	var seen: Array[String] = []
	spider.state_machine.state_changed.connect(func(_from: StringName, to: StringName) -> void: seen.append(String(to)))
	var webs := [0]
	spider.web_fired.connect(func(_bolt: WebBolt) -> void: webs[0] += 1)
	var damage_taken := [0]
	_player.health.damaged.connect(func(amount: int) -> void: damage_taken[0] += amount)
	var web_at_entangle := -1.0
	var t := 0.0
	var entangled_seen := false
	while t < 20.0:
		await _frames(6)
		t += 0.1
		if _entangled() and not entangled_seen:
			entangled_seen = true
			web_at_entangle = t
	_info("chuỗi state của nhện", ",".join(seen.slice(0, 14)))
	_check("SpiderWebShot" in seen, "nhện phun tơ khi player ở tầm xa")
	_check(entangled_seen, "AI thật làm player dính tơ", "lúc %.1f s" % web_at_entangle)
	_check("SpiderPounce" in seen, "nhện nhảy vồ")
	_check("Attack" in seen, "nhện cắn khi tới gần")
	_check(damage_taken[0] > 0, "nhện gây sát thương cho player", "tổng %d" % damage_taken[0])
	# Player đứng yên dính tơ: không phun thêm tơ khi đã dính
	var webs_while_stuck: int = webs[0]
	_check(webs_while_stuck <= 2, "không phun chồng tơ khi player còn dính", "số lần phun: %d trong 20 s" % webs_while_stuck)


func _t_extreme_web() -> void:
	var normal := await _measure_run_speed()
	# Tốc độ cực đoan: 1.0 (không chậm) và 0.05 (gần như đứng yên)
	for scale in [1.0, 0.05]:
		var data: WebData = ResourceLoader.load("res://resources/combat/spider_web/spider_web.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as WebData
		data.speed_scale = scale
		var patch := _spawn_patch(Vector3(0, 0, 0), data)
		patch.entangle(_player)
		await _frames(5)
		var speed := await _measure_run_speed()
		_check(absf(speed / normal - scale) < 0.06, "speed_scale = %.2f: tốc độ đúng tỉ lệ" % scale, "tỉ lệ đo %.3f" % (speed / normal))
		patch._break()
		await _frames(30)
	# Số nhát cực đoan
	_player.equip_weapon(SWORD)
	for hits in [1, 20]:
		var data: WebData = ResourceLoader.load("res://resources/combat/spider_web/spider_web.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as WebData
		data.hits_to_break = hits
		var patch := _spawn_patch(Vector3(0, 0, 0), data)
		patch.entangle(_player)
		await _frames(5)
		var hp: HealthComponent = patch.get_node("HealthComponent")
		var landed := [0]
		hp.damaged.connect(func(_amount: int) -> void: landed[0] += 1)
		var swings := 0
		while not _gone(patch) and swings < hits + 12:
			_player.energy.set_current(_player.energy.get_max())
			await _tap(&"attack")
			await _seconds(0.4)
			swings += 1
		_check(_gone(patch) and landed[0] == hits, "hits_to_break = %d: vỡ đúng sau %d nhát trúng" % [hits, hits], "trúng %d, bấm %d lần" % [landed[0], swings])
		await _frames(30)
	# Bán kính cực đoan: nhỏ 0.3 và rộng 4.0, đứng sát mép
	for radius in [0.3, 4.0]:
		var data: WebData = ResourceLoader.load("res://resources/combat/spider_web/spider_web.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as WebData
		data.radius = radius
		# Dời player ra ngoài mép TRƯỚC khi đặt tơ: đặt tơ lên chỗ player còn đứng thì dính ngay
		_place_player(Vector3(5.0 + radius + 0.6, 0, 0), Vector3.FORWARD)
		await _frames(5)
		var patch := _spawn_patch(Vector3(5, 0, 0), data)
		await _frames(10)
		_info("radius %.1f" % radius, "player x=%.2f, patch x=%.2f, chồng=%s, web đang dính=%d" % [_player.global_position.x, patch.global_position.x, str(patch.overlaps_body(_player)), (_player.get_node(NodePath(WebEntangle.NODE_NAME)) as WebEntangle).get_web_count() if _player.has_node(NodePath(WebEntangle.NODE_NAME)) else 0])
		_check(not _entangled(), "radius %.1f: đứng ngoài mép tơ thì không dính" % radius)
		_place_player(Vector3(5.0 + radius - 0.15, 0, 0), Vector3.FORWARD)
		await _frames(15)
		_check(_entangled(), "radius %.1f: bước vào trong mép thì dính" % radius)
		patch._break()
		await _frames(30)


func _t_extreme_pounce() -> void:
	for air_time in [0.1, 2.0]:
		var data := _fresh_data()
		data.pounce_air_time = air_time
		data.web = null
		var spider := _spawn_spider(Vector3(0, 0, 6), data, false)
		var seen: Array[String] = []
		spider.state_machine.state_changed.connect(func(_from: StringName, to: StringName) -> void: seen.append(String(to)))
		var landings := [0]
		spider.pounce_landed.connect(func(_c: Vector3, _h: int) -> void: landings[0] += 1)
		await _seconds(14.0)
		_check(landings[0] >= 1, "pounce_air_time = %.1f: nhảy và đáp được" % air_time, "chuỗi: %s" % ",".join(seen.slice(0, 10)))
		_check(spider.is_on_floor() and absf(spider.global_position.y) < 0.2, "pounce_air_time = %.1f: nhện đứng lại trên sàn" % air_time, "y = %.2f" % spider.global_position.y)
		spider.queue_free()
		await _frames(5)
	# Tầm cực đoan: min > max thì không bao giờ nhảy, không treo
	var data := _fresh_data()
	data.pounce_min_range = 9.0
	data.pounce_max_range = 3.0
	data.web = null
	var spider := _spawn_spider(Vector3(0, 0, 6), data, false)
	var jumped := [false]
	spider.pounce_landed.connect(func(_c: Vector3, _h: int) -> void: jumped[0] = true)
	await _seconds(8.0)
	_check(not jumped[0], "pounce_min_range > pounce_max_range: không bao giờ nhảy")
	_check(spider.state_machine.current_state != null, "state machine vẫn chạy bình thường")


func _t_no_skill_data() -> void:
	# Thiếu dữ liệu kỹ năng: không có web / pounce_attack thì chỉ còn đuổi và cắn, không báo lỗi
	var data := _fresh_data()
	data.web = null
	data.pounce_attack = null
	var spider := _spawn_spider(Vector3(0, 0, 6), data, false)
	var seen: Array[String] = []
	spider.state_machine.state_changed.connect(func(_from: StringName, to: StringName) -> void: seen.append(String(to)))
	await _seconds(8.0)
	_check("SpiderWebShot" not in seen and "SpiderPounce" not in seen, "không có dữ liệu kỹ năng: không dùng kỹ năng đó", ",".join(seen.slice(0, 8)))
	_check("Attack" in seen, "vẫn cắn được")
	# Bị đánh chết bằng sát thương thường
	var hp := spider.get_node("HealthComponent") as HealthComponent
	spider.hurtbox.receive_hit(DamageInfo.new(999, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _player))
	await _seconds(0.3)
	_check(hp.is_dead(), "nhện hết máu thì chết")


func _t_death_midair() -> void:
	var spider := _spawn_spider(Vector3(0, 0, 8))
	await _frames(3)
	spider.target = _player
	var bolt := spider.shoot_web(spider.web_aim_direction())
	await _frames(10)
	_check(bolt.is_flying(), "đạn đang bay")
	spider.hurtbox.receive_hit(DamageInfo.new(999, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _player))
	await _seconds(1.0)
	_check(not bolt.is_flying(), "nhện chết: đạn tơ đang bay tan")
	_check(_patches().is_empty() and not _entangled(), "nhện chết: không tạo tơ, player không dính")
