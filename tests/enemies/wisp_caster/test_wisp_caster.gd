extends Node3D
## Test Quái 3 (WispCaster) bằng hành vi thật: vật lý, va chạm, kiếm / tên / gió của player thật.
## Chạy: APPDATA/LOCALAPPDATA trỏ vào .godot/wisp_runtime (để không ghi save thật), rồi
##   godot --headless --path . res://tests/enemies/wisp_caster/test_wisp_caster.tscn [-- mục1 mục2 ...]
## Không đưa tên mục thì chạy tất cả. Tên mục: xem SECTIONS.

const CASTER_SCENE: PackedScene = preload("res://entities/enemies/palace/wisp_caster/wisp_caster.tscn")
const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/_base/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const KILL_ZONE_SCENE: PackedScene = preload("res://objects/core/kill_zone/kill_zone.tscn")
const SPIKE_SCENE: PackedScene = preload("res://objects/combat/hazards/spike_trap.tscn")
const WIND_ZONE_SCENE: PackedScene = preload("res://objects/wind_puzzle/wind_zone/wind_zone.tscn")
const SWORD: WeaponData = preload("res://resources/combat/weapons/sword.tres")
const BOW: WeaponData = preload("res://resources/combat/weapons/bow.tres")
const WIND_BLAST: AbilityData = preload("res://abilities/wind_blast/wind_blast.tres")
const WIND_UPDRAFT: WindData = preload("res://resources/world/wind/wind/wind_updraft.tres")
const CASTER_DATA_PATH := "res://resources/enemies/wisp_caster/wisp_caster.tres"
const ORB_DATA_PATH := "res://resources/enemies/wisp_caster/orb/wisp_caster_orb.tres"

const HOME_Z := 12.0
const PLAYER_HOME := Vector3(-6.0, 0.0, 12.0)
## Sai số float / safe_margin vật lý: chạm sàn đúng 0 không phải xuyên (xuyên thật sâu cỡ cm trở lên)
const CLEAR_EPSILON: float = 0.005

var _failed: int = 0
var _checks: int = 0
var _tick: int = 0
var _player: Player
var _spawned: Array[Node] = []
var _temp_statics: Array[Node] = []
var _arena_hurt_layers: bool = false


## Một mục = một hàm async. Thêm mục mới: thêm hàm và một dòng ở đây.
func _sections() -> Dictionary[String, Callable]:
	return {
		"hover": _t_hover_idle,
		"traverse": _t_traverse,
		"pit_wind": _t_pit_and_wind,
		"hazards": _t_hazards,
		"blocker": _t_blocker,
		"updraft": _t_updraft,
		"death": _t_death,
		"weapons": _t_weapons_hit,
		"cast": _t_cast_timing,
		"orb_world": _t_orb_world,
		"no_los": _t_no_los,
		"interrupt": _t_interrupt,
		"pool": _t_pool,
		"reflect": _t_reflect_range,
		"reflect_aim": _t_reflect_aim,
		"teleport_flow": _t_teleport_flow,
		"teleport_triggers": _t_teleport_triggers,
		"hidden": _t_hidden_phase,
		"finder": _t_finder_stress,
		"extreme_hover": _t_extreme_hover,
		"extreme_orb": _t_extreme_orb,
		"extreme_finder": _t_extreme_finder,
		"extreme_teleport": _t_extreme_teleport,
		"extreme_wind": _t_extreme_wind,
		"perf": _t_perf,
	}


# Trạng thái thử nghiệm: giữ nguyên vị trí / đi theo vận tốc đặt tay, để đo riêng hover mà không bị AI chen vào
class TestDrive extends EnemyState:
	var drive: Vector3 = Vector3.ZERO

	func physics_update(delta: float) -> void:
		enemy.apply_gravity(delta)
		enemy.velocity.x = drive.x
		enemy.velocity.z = drive.z


# Ghi lại sự kiện của một quái (tick, tên) để kiểm thứ tự / thời điểm
class Watcher extends RefCounted:
	var states: Array = []
	var orbs: Array = []
	var teleports: Array = []
	var tick_source: Callable
	var _caster: WispCaster

	func _init(caster: WispCaster, source: Callable) -> void:
		tick_source = source
		_caster = caster
		caster.state_machine.state_changed.connect(_on_state)
		caster.orb_fired.connect(_on_orb)
		caster.teleported.connect(_on_teleport)

	func _on_state(_from: StringName, to: StringName) -> void:
		states.append([tick_source.call(), String(to)])

	func _on_orb(orb: SpiritOrb) -> void:
		orbs.append([tick_source.call(), orb])

	func _on_teleport(from: Vector3, to: Vector3) -> void:
		# Ghi vị trí player lúc dịch chuyển: player có thể bị cầu đẩy lùi giữa chừng, vị trí cuối bài không còn đúng
		var target_pos: Vector3 = _caster.target.global_position if is_instance_valid(_caster.target) else Vector3.INF
		teleports.append([tick_source.call(), from, to, target_pos])

	func first_tick_of(state_name: String, after: int = -1) -> int:
		for entry: Array in states:
			if entry[1] == state_name and entry[0] > after:
				return entry[0]
		return -1

	func count_state(state_name: String) -> int:
		var count := 0
		for entry: Array in states:
			if entry[1] == state_name:
				count += 1
		return count

	func state_names() -> Array:
		return states.map(func(e: Array) -> String: return e[1])


func _ready() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	_tick += 1


func _run() -> void:
	var sandbox := ProjectSettings.globalize_path("res://.godot/wisp_runtime/").replace("\\", "/").to_lower()
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox):
		push_error("TestWispCaster: đặt APPDATA/LOCALAPPDATA vào .godot/wisp_runtime để bảo vệ save thật.")
		get_tree().quit(2)
		return
	_build_arena()
	GameState.replace_progress(PlayerProgress.new())
	GameState.set_weapon(SWORD)
	GameState.add_weapon(BOW)
	GameState.unlock_ability(WIND_BLAST)
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
	print("WISP_CASTER ", "FAILED (%d / %d)" % [_failed, _checks] if _failed > 0 else "PASSED (%d checks)" % _checks)
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


## Chờ tới khi pred() đúng, tối đa max_frames; trả về có đúng không
func _wait_until(pred: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _now() -> int:
	return _tick


func _place_player(pos: Vector3, facing: Vector3) -> void:
	_player.teleport(pos + Vector3.UP * 0.05, facing)
	(_player.get_node("CameraRig") as CameraRig).snap()
	_player.health.heal_full()


func _cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	for node in _temp_statics:
		if is_instance_valid(node):
			node.queue_free()
	_temp_statics.clear()
	for child in get_children():
		if child is SpiritOrb:
			child.queue_free()
	Input.action_release(&"attack")
	Input.action_release(&"skill")


func _fresh_data() -> CasterEnemyData:
	return ResourceLoader.load(CASTER_DATA_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as CasterEnemyData


func _orb_data(speed: float, reflect_mult: float) -> SpiritOrbData:
	var orb_data := ResourceLoader.load(ORB_DATA_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as SpiritOrbData
	orb_data.speed = speed
	orb_data.reflect_speed_mult = reflect_mult
	return orb_data


func _add_drive_state(enemy: Enemy) -> void:
	var state := TestDrive.new()
	state.name = "TestDrive"
	var machine := enemy.get_node("StateMachine")
	machine.add_child(state)
	state.owner = enemy


## drive = true: quái đứng trong state TestDrive (vận tốc đặt tay), không có AI
func _spawn_caster(pos: Vector3, data: CasterEnemyData = null, drive: bool = true) -> WispCaster:
	var caster := CASTER_SCENE.instantiate() as WispCaster
	if data != null:
		caster.data = data
	if drive:
		_add_drive_state(caster)
	caster.position = pos
	add_child(caster)
	_spawned.append(caster)
	if drive:
		await _frames(2)
		caster.state_machine.transition_to(&"TestDrive")
	return caster


func _spawn_dummy(pos: Vector3, drive: bool = true) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	if drive:
		_add_drive_state(enemy)
	enemy.position = pos
	add_child(enemy)
	_spawned.append(enemy)
	if drive:
		await _frames(2)
		enemy.state_machine.transition_to(&"TestDrive")
	return enemy


func _set_drive(enemy: Enemy, velocity: Vector3) -> void:
	(enemy.get_node("StateMachine/TestDrive") as TestDrive).drive = velocity


func _launch_orb(caster: WispCaster, orb_data: SpiritOrbData, pos: Vector3, direction: Vector3) -> SpiritOrb:
	var orb := caster.pool.acquire() as SpiritOrb
	if not orb.finished.is_connected(caster.pool.release):
		orb.finished.connect(caster.pool.release)
	orb.launch(caster.data.attack, orb_data, pos, direction, caster)
	return orb


func _has_overlay(enemy: Enemy) -> bool:
	for node in enemy.model.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).material_overlay != null:
			return true
	return false


func _hp(enemy: Enemy) -> int:
	return enemy.health.current_health


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- Sân thử

func _build_arena() -> void:
	# Nền chính (x -30..6), nền đông (x 12..40), giữa là vực x 6..12
	_box(Vector3(-12, -0.5, 0), Vector3(36, 1, 60), 1, Color("4c6a58"))
	_box(Vector3(26, -0.5, 0), Vector3(28, 1, 60), 1, Color("4c6a58"))
	# Cao nguyên cao 3 m (x -30..-20), bậc cao 0.5 m (x -14..-11), cùng dọc z = 0
	_box(Vector3(-25, 1.5, 0), Vector3(10, 3, 6), 1, Color("6a6a58"))
	_box(Vector3(-12.5, 0.25, 0), Vector3(3, 0.5, 6), 1, Color("6a6a58"))
	# Rào chặn quái / player vô hình layer 9 (player_blocker) ở mép bắc
	_box(Vector3(0, 1.5, -25), Vector3(60, 3, 0.3), 256, Color(0.8, 0.2, 0.2, 0.3))
	# Cột, khối chặn layer 9, hàng rào mỏng cho bài kiểm tra chọn điểm
	_box(Vector3(-5, 2, -6), Vector3(1.6, 4, 1.6), 1, Color("7a7a7a"))
	_box(Vector3(-8, 2, -3), Vector3(1.6, 4, 1.6), 1, Color("7a7a7a"))
	_box(Vector3(-2, 1.5, -8), Vector3(3, 3, 3), 256, Color(0.8, 0.2, 0.2, 0.3))
	_fence = _box(Vector3(-6, 1, 4), Vector3(6, 2, 0.2), 1, Color("a08a5a"))
	# Vực chết người dưới khoảng trống
	var pit := KILL_ZONE_SCENE.instantiate() as KillZone
	pit.position = Vector3(9, -6, 0)
	pit.size = Vector3(6, 2, 60)
	pit.lethal = true
	pit.collision_mask = 6
	add_child(pit)
	# Gai chết người
	var spike := SPIKE_SCENE.instantiate() as Area3D
	spike.position = Vector3(-18, 0, 15)
	add_child(spike)
	# Cột gió nâng
	var updraft := WIND_ZONE_SCENE.instantiate() as WindZone
	updraft.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(-18, 3, -15))
	updraft.data = WIND_UPDRAFT
	updraft.size = Vector3(2, 2, 6)
	updraft.fade_toward_end = true
	add_child(updraft)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("14242e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.5
	add_child(world)


func _box(at: Vector3, dimensions: Vector3, layer: int, color: Color, temp: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	add_child(body)
	if temp:
		_temp_statics.append(body)
	return body


## Độ cao mặt đất dọc z = 0 (NAN = vực)
func _ground_at(x: float) -> float:
	if x < -20.0:
		return 3.0
	if x < -14.0:
		return 0.0
	if x < -11.0:
		return 0.5
	if x < 6.0:
		return 0.0
	if x < 12.0:
		return NAN
	return 0.0


# ---------------------------------------------------------------- Bay / hover

func _t_hover_idle() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-2, 0, -10), null, false)
	await _frames(120)
	var low := INF
	var high := -INF
	var floor_frames := 0
	for i in 180:
		await get_tree().physics_frame
		low = minf(low, caster.global_position.y)
		high = maxf(high, caster.global_position.y)
		if caster.is_on_floor():
			floor_frames += 1
	_check(low >= 0.45 and high <= 0.55, "đứng yên 3 s: y = đất + 0.5 ± 0.05", "y %.3f..%.3f" % [low, high])
	_check(floor_frames == 0, "đứng yên: is_on_floor() luôn false", "%d frame" % floor_frames)


## Đo chuyển động bay dọc đường cao nguyên -> vách 3 m -> bậc 0.5 m -> vực
func _traverse(caster: WispCaster, from_x: float, to_x: float, speed: float = 3.0) -> Dictionary:
	_set_drive(caster, Vector3(speed, 0, 0))
	var windows: Array = [[-27.0, -21.5, 3.0], [-17.0, -14.9, 0.0], [-12.6, -11.3, 0.5], [-9.0, 5.0, 0.0], [7.0, 11.0, 0.0], [14.0, 19.0, 0.0]]
	var result := {"max_vy": 0.0, "max_dvy": 0.0, "floor_frames": 0, "min_clear": INF, "window_err": 0.0, "alive": true, "frames": 0, "vy_flips": 0}
	var previous_vy := 0.0
	var previous_sign := 0
	for i in int((to_x - from_x) / speed * 60.0) + 120:
		await get_tree().physics_frame
		if not is_instance_valid(caster) or caster.is_dead():
			result["alive"] = false
			break
		var x := caster.global_position.x
		if x >= to_x:
			break
		var y := caster.global_position.y
		var vy := caster.velocity.y
		result["frames"] += 1
		result["max_vy"] = maxf(result["max_vy"], absf(vy))
		result["max_dvy"] = maxf(result["max_dvy"], absf(vy - previous_vy))
		previous_vy = vy
		if absf(vy) > 0.05:
			var sign_now := 1 if vy > 0.0 else -1
			if previous_sign != 0 and sign_now != previous_sign:
				result["vy_flips"] += 1
			previous_sign = sign_now
		if caster.is_on_floor():
			result["floor_frames"] += 1
			result["floor_at"] = "x=%.2f y=%.3f" % [caster.global_position.x, caster.global_position.y]
		var ground := _ground_at(x)
		if not is_nan(ground):
			result["min_clear"] = minf(result["min_clear"], y - ground)
		for window: Array in windows:
			if x >= window[0] and x <= window[1]:
				var err := absf(y - (window[2] + 0.5))
				if err > result["window_err"]:
					result["window_err"] = err
					result["worst"] = "x=%.2f y=%.3f g=%.1f" % [x, y, window[2]]
	return result


func _t_traverse() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-28, 3.5, 0))
	await _frames(40)
	var r: Dictionary = await _traverse(caster, -28.0, 19.0)
	_check(r["alive"], "bay qua cao nguyên, vách 3 m, bậc 0.5 m, vực: còn sống", "frames %d" % r["frames"])
	_check(r["max_vy"] <= 4.05, "tốc độ đứng ≤ 4 m/s", "max |vy| %.3f" % r["max_vy"])
	_check(r["max_dvy"] <= 1.0, "không giật (đổi vận tốc đứng mỗi frame nhỏ)", "max Δvy/frame %.3f" % r["max_dvy"])
	_check(r["window_err"] <= 0.05, "y bám đất + 0.5 ở các đoạn phẳng / trên vực", "sai lệch lớn nhất %.3f tại %s" % [r["window_err"], r.get("worst", "")])
	_check(r["floor_frames"] <= 3, "không chạm sàn khi bay (cho phép vài frame sượt góc bậc cao đúng bằng hover_height)", "%d frame %s" % [r["floor_frames"], r.get("floor_at", "")])
	_check(r["min_clear"] >= -CLEAR_EPSILON, "không lọt xuống sàn", "khoảng hở nhỏ nhất %.3f" % r["min_clear"])


func _t_pit_and_wind() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(4.5, 0, 5), null, false)
	await _frames(90)
	caster.wind_receiver.push(Vector3(12, 0, 0))
	await _frames(40)
	var over_pit := caster.global_position.x > 6.2 and caster.global_position.x < 11.8
	_check(over_pit, "thổi ngang đẩy quái ra giữa vực", "x = %.2f" % caster.global_position.x)
	var low := INF
	var high := -INF
	for i in 150:
		await get_tree().physics_frame
		if not is_instance_valid(caster):
			break
		low = minf(low, caster.global_position.y)
		high = maxf(high, caster.global_position.y)
	_check(is_instance_valid(caster) and not caster.is_dead(), "bay trên vực: KillZone không giết quái", "")
	_check(low >= 0.45 and high <= 0.55, "bay trên vực: độ cao giữ ±0.05", "y %.3f..%.3f" % [low, high])
	# Đối chứng: quái thường (base) rơi xuống vực thì bị KillZone giết
	var control := await _spawn_dummy(Vector3(9, 1, 8), false)
	await _wait_until(func() -> bool: return control.is_dead(), 120)
	_check(control.is_dead(), "đối chứng: quái thường rơi vực bị KillZone giết (sân thử đúng)")


func _t_hazards() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var control := await _spawn_dummy(Vector3(-18, 0, 15), false)
	await _frames(90)
	_check(not is_instance_valid(control) or control.is_dead(), "đối chứng: quái thường đứng trên gai chết người thì chết (sân thử đúng)")
	var caster := await _spawn_caster(Vector3(-18, 0, 15), null, false)
	await _frames(150)
	_check(not caster.is_dead() and _hp(caster) == 3, "quái bay trong vùng gai lethal: không chết, HP nguyên", "HP %d" % _hp(caster))


func _t_blocker() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-5, 0, -20))
	await _frames(40)
	_set_drive(caster, Vector3(0, 0, -3))
	await _frames(240)
	var z := caster.global_position.z
	# Rào layer 9 dày 0.3 tại z = -25: thân (r 0.35) dừng ở z = -25 + 0.15 + 0.35 = -24.5
	_check(z >= -24.55 and z <= -23.9, "đi vào khối chặn layer 9: bị chặn (D5)", "z = %.3f" % z)


func _t_updraft() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-18, 0, -15), null, false)
	await _frames(40)
	var peak := 0.0
	for i in 150:
		await get_tree().physics_frame
		peak = maxf(peak, caster.global_position.y)
	_check(peak > 1.5, "đứng trong cột gió đứng: bị nâng", "đỉnh y = %.2f" % peak)
	var lifted_y := caster.global_position.y
	# Về lại hover_height bị giới hạn bởi max_vertical_speed (4 m/s): thời gian cần = độ cao / 4
	var allowed := int((lifted_y - 0.5) / caster.caster_data.hover.max_vertical_speed * 60.0) + 30
	var frames_back := await _frames_to_settle(caster, Vector3(-12, lifted_y, -15))
	_check(frames_back >= 0 and frames_back <= allowed, "ra khỏi cột gió: về hover_height theo đúng max_vertical_speed", "từ y=%.2f sau %d frame (giới hạn %d)" % [lifted_y, frames_back, allowed])
	var mid_back := await _frames_to_settle(caster, Vector3(-18, 2.0, -15 + 8))
	_check(mid_back >= 0 and mid_back <= 60, "ra khỏi cột gió từ độ cao 2 m: về hover_height trong ≤ 1 s", "sau %d frame" % mid_back)


func _frames_to_settle(caster: WispCaster, from: Vector3) -> int:
	caster.teleport(from)
	for i in 200:
		await get_tree().physics_frame
		if absf(caster.global_position.y - 0.5) <= 0.05:
			return i
	return -1


func _t_death() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-2, 0, -10), null, false)
	await _frames(90)
	caster.health.take_damage(99)
	await _frames(40)
	_check(is_instance_valid(caster) and caster.is_on_floor() and caster.global_position.y < 0.02, "chết trên đất: xác rơi xuống đất", "y = %.3f" % caster.global_position.y)
	await _frames(60)
	_check(not is_instance_valid(caster), "xác bị xoá sau corpse_time")
	var over_pit := await _spawn_caster(Vector3(9, 2, 10), null, false)
	await _frames(30)
	var y_before := over_pit.global_position.y
	over_pit.health.take_damage(99)
	await _frames(40)
	_check(is_instance_valid(over_pit) and over_pit.global_position.y < y_before - 1.0, "chết trên vực: xác rơi", "y %.2f -> %.2f" % [y_before, over_pit.global_position.y])
	await _frames(60)
	_check(not is_instance_valid(over_pit), "xác trên vực bị xoá sau corpse_time")


func _t_weapons_hit() -> void:
	GameState.set_weapon(SWORD)
	await _frames(5)
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -1.2))
	await _frames(70)
	await _tap(&"attack")
	await _frames(40)
	_check(_hp(caster) < 3, "kiếm chém trúng quái đang lơ lửng", "HP %d" % _hp(caster))
	GameState.set_weapon(BOW)
	await _frames(5)
	var archer_target := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6))
	await _frames(70)
	await _tap(&"attack")
	await _frames(100)
	_check(_hp(archer_target) < 3, "tên bắn trúng quái đang lơ lửng", "HP %d" % _hp(archer_target))
	GameState.set_weapon(SWORD)


# ---------------------------------------------------------------- Bắn cầu

func _t_cast_timing() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var watcher := Watcher.new(caster, _now)
	var overlay_log: Array[bool] = []
	var tick_log: Array[int] = []
	var hp_before := _player.health.current_health
	var fired := false
	var cast_tick := -1
	var fire_tick := -1
	for i in 400:
		await get_tree().physics_frame
		overlay_log.append(_has_overlay(caster))
		tick_log.append(_tick)
		if cast_tick < 0:
			cast_tick = watcher.first_tick_of("CastOrb")
		if not watcher.orbs.is_empty():
			fire_tick = watcher.orbs[0][0]
			fired = true
			break
	_check(fired, "quái tự vào CastOrb và bắn khi thấy player", "state: %s" % str(watcher.state_names()))
	if not fired:
		return
	_check(abs((fire_tick - cast_tick) - 42) <= 1, "từ lúc vào CastOrb tới lúc bắn = 0.7 s ± 1 frame", "%d frame (cần 42)" % (fire_tick - cast_tick))
	var telegraph_ok := true
	for i in tick_log.size():
		if tick_log[i] >= cast_tick + 2 and tick_log[i] <= fire_tick - 2 and not overlay_log[i]:
			telegraph_ok = false
	_check(telegraph_ok, "telegraph bật suốt pha niệm")
	await _frames(4)
	_check(not _has_overlay(caster), "telegraph tắt sau khi bắn")
	# Player đứng yên: quả cầu trúng, mất đúng 1 máu, 1 lần
	await _frames(100)
	var lost := hp_before - _player.health.current_health
	_check(lost == 1, "player đứng yên: quả cầu trúng, mất đúng 1 máu một lần", "mất %d" % lost)
	caster.queue_free()
	await _frames(5)
	# Player chạy ngang sau khoá hướng: quả cầu trượt, không đuổi theo
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var evader := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var watch2 := Watcher.new(evader, _now)
	hp_before = _player.health.current_health
	await _wait_until(func() -> bool: return watch2.first_tick_of("CastOrb") >= 0, 300)
	var enter_tick := watch2.first_tick_of("CastOrb")
	await _wait_until(func() -> bool: return _tick >= enter_tick + 33, 120)
	# Dời ngang 3 m ngay sau mốc khoá hướng (0.5 s = 30 frame)
	_place_player(PLAYER_HOME + Vector3(3, 0, 0), Vector3.FORWARD)
	await _wait_until(func() -> bool: return not watch2.orbs.is_empty(), 60)
	var orb: SpiritOrb = watch2.orbs[0][1]
	var start := orb.global_position
	await _frames(40)
	var travelled := orb.global_position - start
	await _frames(100)
	_check(_player.health.current_health == hp_before, "player dời ngang sau khoá hướng: quả cầu trượt, không mất máu", "HP %d -> %d" % [hp_before, _player.health.current_health])
	_check(absf(travelled.x) < 0.8 and travelled.z > 3.0, "quả cầu bay thẳng theo hướng đã khoá, không đuổi theo", "dịch chuyển %s" % str(travelled))


func _t_orb_world() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-12, 0, 0))
	await _frames(40)
	# Tường world dày 0.3: quả cầu nổ, không xuyên
	var wall := _box(Vector3(-12, 1.5, -6), Vector3(6, 3, 0.3), 1, Color("888888"), true)
	var orb := _launch_orb(caster, caster.caster_data.orb, Vector3(-12, 1.1, -0.5), Vector3(0, 0, -1))
	await _frames(70)
	var z_a := orb.global_position.z
	await _frames(10)
	var z_b := orb.global_position.z
	_check(z_a > -5.95 and is_equal_approx(z_a, z_b), "quả cầu gặp tường world: dừng/nổ, không xuyên", "z %.3f -> %.3f (mặt tường -5.85)" % [z_a, z_b])
	wall.queue_free()
	await _frames(30)
	# Khối chặn layer 9: bay xuyên (D4)
	var block := _box(Vector3(-12, 1.5, -6), Vector3(6, 3, 0.3), 256, Color(0.8, 0.2, 0.2, 0.3), true)
	var orb2 := _launch_orb(caster, caster.caster_data.orb, Vector3(-12, 1.1, -0.5), Vector3(0, 0, -1))
	await _frames(60)
	_check(orb2.global_position.z < -7.0, "quả cầu gặp khối chặn layer 9: bay xuyên (D4)", "z = %.2f" % orb2.global_position.z)
	block.queue_free()


func _t_no_los() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	# Tường che giữa quái (z = 5.5) và player (z = 12), giữ nguyên suốt bài kiểm tra
	var wall := _box(Vector3(-6, 2, PLAYER_HOME.z - 3.3), Vector3(14, 4, 0.3), 1, Color("888888"), true)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var watcher := Watcher.new(caster, _now)
	var blocked_shots: Array[int] = [0]
	var space := get_world_3d().direct_space_state
	caster.orb_fired.connect(func(orb: SpiritOrb) -> void:
		var ray := PhysicsRayQueryParameters3D.create(orb.global_position, _player.global_position + Vector3.UP, 1)
		if not space.intersect_ray(ray).is_empty():
			blocked_shots[0] += 1)
	var start_tick := _tick
	await _frames(80)
	_check(watcher.orbs.is_empty(), "tường che giữa quái và player: không bắn", "bắn %d quả, state %s" % [watcher.orbs.size(), str(watcher.state_names())])
	await _wait_until(func() -> bool: return watcher.first_tick_of("Teleport") >= 0, 200)
	var teleport_tick := watcher.first_tick_of("Teleport")
	_check(teleport_tick >= 0 and teleport_tick - start_tick >= 85, "mất đường bắn > 1.5 s: dịch chuyển", "Teleport sau %d frame" % (teleport_tick - start_tick))
	await _frames(500)
	_check(blocked_shots[0] == 0 and not watcher.orbs.is_empty(), "sau khi dịch chuyển tới chỗ có đường bắn mới bắn; mọi quả đều có đường bắn thật (tia độc lập)", "bắn %d quả, bị che %d" % [watcher.orbs.size(), blocked_shots[0]])
	wall.queue_free()


func _t_interrupt() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var watcher := Watcher.new(caster, _now)
	await _wait_until(func() -> bool: return watcher.first_tick_of("CastOrb") >= 0, 300)
	await _frames(20)
	var shots_before := watcher.orbs.size()
	caster.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _player))
	await _frames(2)
	_check(not (caster.get_node("Model/OrbSpawn/ChargeOrb") as Node3D).visible, "bị chém lúc niệm: quả đang niệm bị huỷ")
	await _frames(55)
	_check(watcher.orbs.size() == shots_before, "bị chém lúc niệm: không bắn ra sau đó (trong 0.9 s)", "state %s" % str(watcher.state_names()))
	_check(watcher.state_names().has("Hurt"), "bị chém lúc niệm: vào Hurt")


func _t_pool() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-6, 0, 0))
	await _frames(30)
	var initial := caster.pool.get_total_created()
	for round_index in 2:
		for i in 20:
			caster.fire_orb(Vector3.UP)
			await _frames(6)
		_info("pool vòng %d" % (round_index + 1), "tạo %d, đang dùng %d" % [caster.pool.get_total_created(), caster.pool.get_active_count()])
		await _frames(260)
		if round_index == 0:
			var after_first := caster.pool.get_total_created()
			var orb_nodes := 0
			for child in caster.pool.get_children():
				if child is SpiritOrb:
					orb_nodes += 1
			_check(after_first <= 20 and orb_nodes == after_first, "20 lần bắn liên tục: số node SpiritOrb = số đã tạo ≤ 20", "ban đầu %d, sau vòng 1: %d, node %d" % [initial, after_first, orb_nodes])
			_check(caster.pool.get_active_count() == 0, "vòng 1 xong: mọi quả đã về pool", "đang dùng %d" % caster.pool.get_active_count())
			_tick_snapshot = after_first
	_check(caster.pool.get_total_created() == _tick_snapshot, "vòng 2 (20 lần bắn nữa): không instantiate thêm", "%d -> %d" % [_tick_snapshot, caster.pool.get_total_created()])


var _tick_snapshot: int = 0
## Hàng rào mỏng z = 4 (bài chọn điểm / tầm nhìn); chắn đường bay cầu phản nên bài phản tắt nó tạm
var _fence: StaticBody3D


# ---------------------------------------------------------------- Phản cầu bằng gió

## Quả cầu đứng yên (speed ~ 0) đặt trước mặt player, bấm E, kiểm có bị phản không
func _t_reflect_range() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-6, 0, -28))
	await _frames(20)
	for distance in [1.0, 3.0, 5.0, 5.5]:
		_place_player(PLAYER_HOME, Vector3.FORWARD)
		await _frames(60)
		var orb := _launch_orb(caster, _orb_data(0.001, 1.0), PLAYER_HOME + Vector3(0, 1.0, -distance), Vector3.FORWARD)
		await _frames(2)
		var before_material := (orb.get_node("Core") as MeshInstance3D).material_override
		await _tap(&"skill")
		await _frames(40)
		var expected: bool = distance <= 5.0
		_check(orb.is_reflected() == expected, "bấm E khi quả cầu cách %.1f m: %s" % [distance, "bị phản" if expected else "không phản"], "reflected=%s" % str(orb.is_reflected()))
		if distance == 1.0:
			var after_material := (orb.get_node("Core") as MeshInstance3D).material_override
			_check(before_material == orb.hostile_material and after_material == orb.reflected_material, "màu đổi sang trắng xanh khi phản (material đổi đúng)")
		orb.dissipate()
		await _frames(25)
		await _frames(60)


## Quả phản trúng quái mục tiêu / lệch hướng / aim assist. Quả đứng yên nhưng reflect_speed_mult = 10500 => bay 10.5 m/s sau phản
func _t_reflect_aim() -> void:
	_fence.collision_layer = 0
	var shooter := await _spawn_caster(Vector3(-6, 0, -28))
	var reflect_point := PLAYER_HOME + Vector3(0, 1.0, -3)
	# A: mục tiêu thẳng hướng thổi; quái caster làm mục tiêu để xem Hurt -> Teleport
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var victim := await _spawn_caster(Vector3(-6, 0, 1))
	victim.target = _player
	var watcher := Watcher.new(victim, _now)
	await _frames(60)
	var orb := _launch_orb(shooter, _orb_data(0.001, 10500.0), reflect_point, Vector3.FORWARD)
	await _frames(2)
	await _tap(&"skill")
	await _frames(100)
	_check(_hp(victim) == 2, "phản thẳng về quái: trúng, quái mất đúng 1 máu", "HP %d" % _hp(victim))
	_check(orb.is_reflected(), "quả đã bị phản")
	await _frames(120)
	var names := watcher.state_names()
	_check(names.has("Hurt") and names.has("Teleport") and names.find("Teleport") > names.find("Hurt"), "quái bị cầu phản trúng: Hurt rồi Teleport", str(names))
	victim.queue_free()
	await _frames(70)
	# B: lệch 40 độ: không bẻ hướng (mục tiêu ngoài 25 độ); C: lệch 15 độ: bẻ hướng trúng
	for case: Array in [["lệch 40° (không bẻ hướng)", 40.0, 3], ["lệch 15° (aim assist bẻ trúng)", 15.0, 2]]:
		_place_player(PLAYER_HOME, Vector3.FORWARD)
		await _frames(60)
		var angle := deg_to_rad(case[1] as float)
		var target_pos := reflect_point + Vector3(sin(angle), 0, -cos(angle)) * 8.0
		target_pos.y = 0.0
		var dummy := await _spawn_dummy(target_pos)
		await _frames(2)
		var orb2 := _launch_orb(shooter, _orb_data(0.001, 10500.0), reflect_point, Vector3.FORWARD)
		await _frames(2)
		await _tap(&"skill")
		await _frames(100)
		_check(_hp(dummy) == case[2], "phản %s: HP quái mẫu = %d" % [case[0], case[2]], "HP %d" % _hp(dummy))
		dummy.queue_free()
		orb2.dissipate()
		await _frames(80)
	# D: quả đã phản không làm player mất máu dù bay qua player; quái mẫu trúng cũng mất 1 máu đã kiểm ở A/C
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	await _frames(60)
	var orb3 := _launch_orb(shooter, _orb_data(0.001, 10500.0), reflect_point, Vector3.FORWARD)
	await _frames(2)
	await _tap(&"skill")
	await _frames(6)
	var hp_before := _player.health.current_health
	_player.teleport(Vector3(PLAYER_HOME.x, 0.05, PLAYER_HOME.z - 7.0), Vector3.FORWARD)
	await _frames(60)
	_check(orb3.is_reflected() and _player.health.current_health == hp_before, "quả đã phản bay qua player: không làm player mất máu", "HP %d -> %d" % [hp_before, _player.health.current_health])
	_fence.collision_layer = 1


# ---------------------------------------------------------------- Dịch chuyển

func _t_teleport_flow() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var watcher := Watcher.new(caster, _now)
	await _frames(1800)
	var names := watcher.state_names()
	_info("chuỗi state", str(names))
	_check(watcher.teleports.size() >= 4, "chạy 30 s: dịch chuyển nhiều lần", "%d lần" % watcher.teleports.size())
	# Số quả giữa các lần dịch chuyển
	var shots_between: Array[int] = []
	var last_tick := 0
	var all_two := true
	for entry: Array in watcher.teleports:
		var count := 0
		for orb_entry: Array in watcher.orbs:
			if orb_entry[0] > last_tick and orb_entry[0] <= entry[0]:
				count += 1
		shots_between.append(count)
		if count != 2:
			all_two = false
		last_tick = entry[0]
	_check(all_two, "luôn dịch chuyển sau đúng 2 quả", str(shots_between))
	var spacing_ok := true
	var min_spacing := 99999
	for i in range(1, watcher.teleports.size()):
		var gap: int = watcher.teleports[i][0] - watcher.teleports[i - 1][0]
		min_spacing = mini(min_spacing, gap)
		if gap < 180:
			spacing_ok = false
	_check(spacing_ok, "hai lần dịch chuyển cách nhau ≥ 3 s", "nhỏ nhất %d frame (cần ≥ 180)" % min_spacing)
	# Sau khi dịch chuyển xong: quả đầu tiên sớm nhất 1.2 s sau khi hiện ra (hiện ra xong = dịch chuyển + 21 frame)
	var first_shot_gap := 99999
	for entry: Array in watcher.teleports:
		for orb_entry: Array in watcher.orbs:
			if orb_entry[0] > entry[0]:
				first_shot_gap = mini(first_shot_gap, orb_entry[0] - entry[0] - 21)
				break
	_check(first_shot_gap >= 71, "sau Appear ≥ 1.2 s mới có quả đầu tiên", "%d frame (cần ≥ 72)" % first_shot_gap)
	var bad_points := 0
	var fallback := 0
	for entry: Array in watcher.teleports:
		var from: Vector3 = entry[1]
		var to: Vector3 = entry[2]
		if from.is_equal_approx(to):
			fallback += 1
			continue
		var ring := _flat(to, entry[3] if entry[3] != Vector3.INF else _player.global_position)
		if ring < 5.4 or ring > 8.1 or _flat(from, to) < 3.0:
			bad_points += 1
	_check(bad_points == 0, "điểm hiện ra nằm trên vòng 5.5–8 m quanh player và cách chỗ cũ ≥ 3 m", "sai %d, hiện lại chỗ cũ %d" % [bad_points, fallback])


func _t_teleport_triggers() -> void:
	# Bị chém: Teleport ngay sau Hurt
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var watcher := Watcher.new(caster, _now)
	await _wait_until(func() -> bool: return caster.state_machine.current_state.name == &"KeepDistance", 200)
	var hit_tick := _tick
	caster.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _player))
	await _wait_until(func() -> bool: return watcher.first_tick_of("Teleport", hit_tick) >= 0, 120)
	var tele_tick := watcher.first_tick_of("Teleport", hit_tick)
	var names := watcher.state_names()
	_check(tele_tick >= 0 and tele_tick - hit_tick <= 40 and names.find("Hurt") < names.find("Teleport"), "bị đánh: Hurt rồi Teleport ngay", "sau %d frame; %s" % [tele_tick - hit_tick, str(names)])
	caster.queue_free()
	await _frames(5)
	# Áp sát < 3 m quá 0.5 s
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var panic_caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), null, false)
	var panic_watch := Watcher.new(panic_caster, _now)
	await _wait_until(func() -> bool: return panic_caster.state_machine.current_state.name == &"KeepDistance", 200)
	var placed_tick := _tick
	# Quái lùi ra khỏi vòng 3 m nếu player đứng yên, nên ghim player cách quái 2 m mỗi frame
	var panic_tick := -1
	for i in 300:
		_player.teleport(panic_caster.global_position + Vector3(0, 0.05, 2.0), Vector3.FORWARD)
		await get_tree().physics_frame
		panic_tick = panic_watch.first_tick_of("Teleport", placed_tick)
		if panic_tick >= 0:
			break
	# Đồng hồ hoảng loạn tính từ lần vào KeepDistance gần nhất (sau khi bắn xong), không phải từ lúc player tới
	var keep_tick := placed_tick
	for entry: Array in panic_watch.states:
		if entry[1] == "KeepDistance" and entry[0] < panic_tick:
			keep_tick = entry[0]
	_check(panic_tick >= 0 and panic_tick - keep_tick >= 28 and panic_tick - keep_tick <= 40, "player áp sát < 3 m quá 0.5 s: dịch chuyển", "sau %d frame kể từ lúc vào KeepDistance (cần 28-40)" % (panic_tick - keep_tick))


func _t_hidden_phase() -> void:
	# Player kề quái -> quái dịch chuyển; trong pha Hidden chém không có tác dụng
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -1.3), null, false)
	var watcher := Watcher.new(caster, _now)
	await _wait_until(func() -> bool: return caster.is_hidden(), 400)
	_check(caster.is_hidden(), "quái áp sát thì dịch chuyển và vào pha ẩn", str(watcher.state_names()))
	var hp_before := _hp(caster)
	var marker := caster.get_node("AppearMarker") as Node3D
	var marker_pos := marker.global_position
	_check(marker.visible and (caster.get_node("Model") as Node3D).visible == false, "pha ẩn: model ẩn, dấu hiệu dưới đất hiện")
	await _tap(&"attack")
	await _wait_until(func() -> bool: return not caster.is_hidden(), 60)
	_check(_hp(caster) == hp_before, "pha Hidden: chém không có tác dụng", "HP %d -> %d" % [hp_before, _hp(caster)])
	await _frames(2)
	_check(_flat(caster.global_position, marker_pos) < 0.05, "hiện ra đúng chỗ dấu hiệu đã báo", "lệch %.3f" % _flat(caster.global_position, marker_pos))
	_check(absf(marker_pos.y - (caster.global_position.y - 0.5 + 0.03)) < 0.1, "dấu hiệu nằm sát mặt đất bên dưới điểm hiện ra", "marker y %.3f, quái y %.3f" % [marker_pos.y, caster.global_position.y])
	caster.queue_free()
	await _frames(5)

	# Vanish vẫn đánh được; bị chém chen ngang Teleport -> không kẹt tàng hình
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var victim := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -1.3), null, false)
	await _wait_until(func() -> bool: return victim.state_machine.current_state.name == &"Teleport" and not victim.is_hidden(), 400)
	# Quái đã lùi ra trong lúc chờ hoảng loạn: đưa player sát trước mặt để kiếm chắc chắn với tới
	_place_player(victim.global_position + Vector3(0, 0, 1.0), Vector3.FORWARD)
	hp_before = _hp(victim)
	await _tap(&"attack")
	await _frames(30)
	_check(_hp(victim) < hp_before, "pha Vanish: vẫn đánh được", "HP %d -> %d" % [hp_before, _hp(victim)])
	# Bị chém xong quái dịch chuyển lại (Hurt -> Teleport): đợi xong vòng đó rồi mới kiểm cờ, giữa Vanish model đang co là đúng
	await _wait_until(func() -> bool: return victim.state_machine.current_state.name != &"Teleport", 300)
	await _frames(2)
	_check(not victim.is_hidden() and victim.collision_layer == 4 and victim.hurtbox.collision_layer == 4 and victim.hurtbox.monitorable and victim.model.visible and victim.model.scale.is_equal_approx(Vector3.ONE) and victim.wind_receiver.enabled, "bị chém chen ngang Vanish: hurtbox / va chạm / model bật đủ")
	victim.queue_free()
	await _frames(5)

	# Hurt chen ngang lúc Hidden (ép trực tiếp)
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var third := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -1.3), null, false)
	await _wait_until(func() -> bool: return third.is_hidden(), 400)
	third.state_machine.transition_to(&"Hurt")
	await _frames(4)
	_check(not third.is_hidden() and third.collision_layer == 4 and third.hurtbox.collision_layer == 4 and third.hurtbox.monitorable and third.model.visible and (third.get_node("AppearMarker") as Node3D).visible == false and third.wind_receiver.enabled, "Hurt chen ngang lúc Hidden: không kẹt tàng hình, dấu hiệu tắt")
	third.state_machine.transition_to(&"Blown")
	await _frames(2)
	await _frames(20)
	_check(not third.is_hidden(), "Blown chen ngang: không tàng hình")


## 200 lần chọn điểm trong sân có rào, khối layer 9, cột, vực; kiểm từng điểm bằng truy vấn độc lập
func _t_finder_stress() -> void:
	var caster := await _spawn_caster(Vector3(-10, 0, 0))
	caster.home_position = Vector3(-10, 0, 0)
	var data := caster.caster_data.teleport
	var space := get_world_3d().direct_space_state
	var camera := get_viewport().get_camera_3d()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = capsule
	shape_query.collision_mask = 261
	shape_query.exclude = [caster.get_rid()]
	var found := 0
	var failed := 0
	var violations: Dictionary = {"blocked": 0, "no_ground": 0, "pit": 0, "leash": 0, "los": 0, "screen": 0, "ring": 0, "jump": 0}
	var rejects: Dictionary = {}
	for i in 200:
		var player_pos := Vector3(randf_range(-22.0, 4.0), 0.0, randf_range(-16.0, 16.0))
		# Giữ player ngoài khối đặc để đứng được
		_place_player(player_pos, Vector3.FORWARD)
		var current := caster.global_position
		var point := caster.finder.find_point(_player.global_position, caster.home_position, current, data)
		for key: StringName in caster.finder.reject_counts:
			rejects[key] = rejects.get(key, 0) + caster.finder.reject_counts[key]
		if not caster.finder.has_found:
			failed += 1
			if not point.is_equal_approx(current):
				violations["jump"] += 1
			continue
		found += 1
		shape_query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 0.9, 0))
		if not space.intersect_shape(shape_query, 1).is_empty():
			violations["blocked"] += 1
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point + Vector3.DOWN * 1.0, 1)
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or absf(point.y - ((ground["position"] as Vector3).y + 0.5)) > 0.05:
			violations["no_ground"] += 1
		if point.x > 5.6 and point.x < 12.4:
			violations["pit"] += 1
		if _flat(point, caster.home_position) > caster.caster_data.leash_range - data.leash_margin + 0.001:
			violations["leash"] += 1
		var los := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.1, _player.global_position + Vector3.UP * 1.0, 1)
		if not space.intersect_ray(los).is_empty():
			violations["los"] += 1
		var chest := point + Vector3.UP * 1.1
		var screen := camera.unproject_position(chest)
		if camera.is_position_behind(chest) or not get_viewport().get_visible_rect().has_point(screen):
			violations["screen"] += 1
		var ring := _flat(point, _player.global_position)
		if ring < data.ring_min - 0.01 or ring > data.ring_max + 0.01:
			violations["ring"] += 1
		if _flat(point, current) < data.min_jump_distance - 0.01:
			violations["jump"] += 1
	_info("finder 200 lần", "tìm được %d, thất bại (hiện lại chỗ cũ) %d, loại theo điều kiện %s" % [found, failed, str(rejects)])
	var total_violations := 0
	for key in violations:
		total_violations += violations[key]
	_check(total_violations == 0, "200 lần chọn điểm: 0 điểm kẹt khối/rào, trên vực, ngoài leash, bị che, ngoài màn hình", str(violations))
	_check(found > 100, "đa số lần tìm ra điểm", "%d / 200" % found)


# ---------------------------------------------------------------- Thông số lệch / cực đoan

func _t_extreme_hover() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	for height in [0.0, 0.1, 3.0]:
		var data := _fresh_data()
		data.hover.hover_height = height
		var caster := await _spawn_caster(Vector3(-2, 0, -10), data)
		await _frames(150)
		var low := INF
		var high := -INF
		var floor_frames := 0
		for i in 120:
			await get_tree().physics_frame
			low = minf(low, caster.global_position.y)
			high = maxf(high, caster.global_position.y)
			if caster.is_on_floor():
				floor_frames += 1
		_check(low >= height - 0.03 and high <= height + 0.03, "hover_height %.1f: ổn định, không nảy / kẹt" % height, "y %.3f..%.3f, chạm sàn %d frame" % [low, high, floor_frames])
		_set_drive(caster, Vector3(2, 0, 0))
		var start_x := caster.global_position.x
		await _frames(60)
		_check(caster.global_position.x - start_x > 1.5, "hover_height %.1f: vẫn di chuyển được (không kẹt sàn)" % height, "đi được %.2f m" % (caster.global_position.x - start_x))
		if height == 3.0:
			_place_player(PLAYER_HOME, Vector3.FORWARD)
			var target := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -1.2), data)
			await _frames(80)
			await _tap(&"attack")
			await _frames(40)
			_info("hover_height 3.0", "kiếm chém hụt: HP quái %d / 3 (giới hạn thiết kế, không phải lỗi)" % _hp(target))
			target.queue_free()
		caster.queue_free()
		await _frames(5)
	for speed in [0.5, 50.0]:
		var data := _fresh_data()
		data.hover.max_vertical_speed = speed
		var caster := await _spawn_caster(Vector3(-28, 3.5, 0), data)
		await _frames(60)
		var r: Dictionary = await _traverse(caster, -28.0, 19.0)
		_check(r["alive"] and r["min_clear"] >= -CLEAR_EPSILON, "max_vertical_speed %.1f: không xuyên sàn" % speed, "khoảng hở nhỏ nhất %.3f" % r["min_clear"])
		_check(r["vy_flips"] <= 8, "max_vertical_speed %.1f: không rung (đảo chiều vận tốc đứng ít)" % speed, "đảo chiều %d lần, max |vy| %.2f, window_err %.3f" % [r["vy_flips"], r["max_vy"], r["window_err"]])
		caster.queue_free()
		await _frames(5)


func _t_extreme_orb() -> void:
	_place_player(Vector3(-25, 0, 25), Vector3.FORWARD)
	var caster := await _spawn_caster(Vector3(-6, 0, 0))
	await _frames(20)
	for speed in [1.0, 25.0]:
		var wall := _box(Vector3(-6, 1.5, -6), Vector3(6, 3, 0.3), 1, Color("888888"), true)
		var orb := _launch_orb(caster, _orb_data(speed, 1.5), Vector3(-6, 1.1, -0.5), Vector3(0, 0, -1))
		var min_z := 0.0
		for i in 150:
			await get_tree().physics_frame
			min_z = minf(min_z, orb.global_position.z)
		_check(min_z > -5.9, "tốc độ cầu %.0f: không xuyên tường mỏng 0.3 m" % speed, "z nhỏ nhất %.3f (mặt tường -5.85)" % min_z)
		wall.queue_free()
		orb.dissipate()
		await _frames(60)
	# Phản ở tốc độ rất cao (25 × 1.5)
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	await _frames(40)
	var wall2 := _box(Vector3(-6, 1.5, 3), Vector3(6, 3, 0.3), 1, Color("888888"), true)
	var fast := _launch_orb(caster, _orb_data(0.001, 25000.0 * 1.5), PLAYER_HOME + Vector3(0, 1.0, -3), Vector3.FORWARD)
	await _frames(2)
	await _tap(&"skill")
	var min_z2 := 99.0
	for i in 60:
		await get_tree().physics_frame
		min_z2 = minf(min_z2, fast.global_position.z)
	_check(min_z2 > 3.0, "cầu đã phản 37.5 m/s: không xuyên tường mỏng", "z nhỏ nhất %.3f (mặt tường 3.15)" % min_z2)
	wall2.queue_free()
	# hit_radius 0.05 / 1.5, bay lệch player 1.0 m
	for radius in [0.05, 0.22, 1.5]:
		_place_player(PLAYER_HOME, Vector3.FORWARD)
		await _frames(30)
		var orb_data := _orb_data(7.0, 1.5)
		orb_data.hit_radius = radius
		var hp_before := _player.health.current_health
		# Cao hơn bán kính để cầu lớn không nổ ngay trên sàn lúc vừa bắn
		var miss := _launch_orb(caster, orb_data, PLAYER_HOME + Vector3(1.0, maxf(1.0, radius + 0.1), 5.0), Vector3(0, 0, -1))
		await _frames(120)
		var lost := hp_before - _player.health.current_health
		var expected := 1 if radius + 0.4 > 1.0 else 0
		_check(lost == expected, "hit_radius %.2f, bay lệch player 1.0 m: %s" % [radius, "trúng" if expected == 1 else "trượt"], "mất %d máu" % lost)
		miss.dissipate()
		await _frames(30)
	# reflect_aim_angle 0 / 180 với mục tiêu lệch 40 độ
	var reflect_point := PLAYER_HOME + Vector3(0, 1.0, -3)
	for aim_angle in [0.0, 180.0]:
		_place_player(PLAYER_HOME, Vector3.FORWARD)
		await _frames(60)
		var angle := deg_to_rad(40.0)
		var target_pos := reflect_point + Vector3(sin(angle), 0, -cos(angle)) * 8.0
		target_pos.y = 0.0
		var dummy := await _spawn_dummy(target_pos)
		var orb_data := _orb_data(0.001, 10500.0)
		orb_data.reflect_aim_angle = aim_angle
		await _frames(2)
		var orb := _launch_orb(caster, orb_data, reflect_point, Vector3.FORWARD)
		await _frames(2)
		await _tap(&"skill")
		await _frames(100)
		var expected_hp := 3 if aim_angle == 0.0 else 2
		_check(_hp(dummy) == expected_hp, "reflect_aim_angle %.0f, mục tiêu lệch 40°: %s" % [aim_angle, "không bẻ" if aim_angle == 0.0 else "bẻ trúng"], "HP %d" % _hp(dummy))
		dummy.queue_free()
		orb.dissipate()
		await _frames(60)


func _t_extreme_finder() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var configs: Array = [["ring_min > ring_max (8 / 5.5)", 8.0, 5.5, 12], ["candidate_count = 1", 5.5, 8.0, 1], ["ring_max = 50", 5.5, 50.0, 12], ["candidate_count = 0", 5.5, 8.0, 0]]
	for config: Array in configs:
		var data := _fresh_data()
		data.teleport.ring_min = config[1]
		data.teleport.ring_max = config[2]
		data.teleport.candidate_count = config[3]
		var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), data)
		await _frames(10)
		var start := Time.get_ticks_usec()
		var found := 0
		var invalid := 0
		for i in 50:
			var current := caster.global_position
			var point := caster.finder.find_point(_player.global_position, caster.home_position, current, data.teleport)
			if caster.finder.has_found:
				found += 1
			elif not point.is_equal_approx(current):
				invalid += 1
		var elapsed := (Time.get_ticks_usec() - start) / 1000.0
		_check(invalid == 0 and elapsed < 500.0, "%s: không treo, không lỗi, thất bại thì trả chỗ cũ" % config[0], "tìm ra %d / 50, %.1f ms cho 50 lần" % [found, elapsed])
		# Chạy thật trong AI: dịch chuyển hoàn tất và quái hiện lại hợp lệ
		var live := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -1.3), data, false)
		var watcher := Watcher.new(live, _now)
		await _wait_until(func() -> bool: return watcher.teleports.size() >= 1, 400)
		await _frames(30)
		_check(watcher.teleports.size() >= 1 and not live.is_hidden() and live.model.visible, "%s: dịch chuyển thật hoàn tất, quái hiện lại" % config[0], "teleports %d" % watcher.teleports.size())
		caster.queue_free()
		live.queue_free()
		await _frames(5)


func _t_extreme_teleport() -> void:
	# casts_before_teleport = 0 và 99: không dịch chuyển theo số quả (không có điều kiện khác)
	for casts in [0, 99]:
		_place_player(PLAYER_HOME, Vector3.FORWARD)
		var data := _fresh_data()
		data.casts_before_teleport = casts
		var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), data, false)
		var watcher := Watcher.new(caster, _now)
		await _frames(900)
		_check(watcher.orbs.size() >= 6 and watcher.teleports.is_empty(), "casts_before_teleport = %d: bắn liên tục, không dịch chuyển theo số quả" % casts, "bắn %d quả, dịch chuyển %d lần" % [watcher.orbs.size(), watcher.teleports.size()])
		caster.queue_free()
		await _frames(5)
	# teleport_on_hurt = false
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var data2 := _fresh_data()
	data2.teleport_on_hurt = false
	var caster2 := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -6.5), data2, false)
	var watcher2 := Watcher.new(caster2, _now)
	await _wait_until(func() -> bool: return caster2.state_machine.current_state.name == &"KeepDistance", 200)
	var tick := _tick
	caster2.hurtbox.receive_hit(DamageInfo.new(1, DamageInfo.Type.PHYSICAL, Vector3.ZERO, _player))
	await _frames(100)
	_check(watcher2.first_tick_of("Teleport", tick) < 0, "teleport_on_hurt = false: bị đánh không dịch chuyển", str(watcher2.state_names()))


func _t_extreme_wind() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var data := _fresh_data()
	data.wind_multiplier = 0.0
	var caster := await _spawn_caster(PLAYER_HOME + Vector3(0, 0, -3), data, false)
	await _frames(60)
	var pos_before := caster.global_position
	caster.wind_receiver.push(Vector3(0, 0, -12))
	await _frames(40)
	_check(_flat(caster.global_position, pos_before) < 1.0 and caster.state_machine.current_state.name != &"Blown", "wind_multiplier = 0: không bị thổi", "dịch chuyển %.2f m" % _flat(caster.global_position, pos_before))
	caster.queue_free()
	await _frames(5)
	# Vẫn phản được cầu
	var holder := await _spawn_caster(Vector3(-6, 0, -28), data)
	var orb := _launch_orb(holder, _orb_data(0.001, 1.0), PLAYER_HOME + Vector3(0, 1.0, -2.0), Vector3.FORWARD)
	await _frames(2)
	await _tap(&"skill")
	await _frames(40)
	_check(orb.is_reflected(), "wind_multiplier = 0 của quái: cầu vẫn bị phản (WindReceiver của cầu độc lập)")


func _t_perf() -> void:
	_place_player(PLAYER_HOME, Vector3.FORWARD)
	var base_time := await _measure_frames(240)
	for i in 5:
		await _spawn_caster(PLAYER_HOME + Vector3(-4 + i * 2.0, 0, -6.5), null, false)
	var five_time := await _measure_frames(240)
	_info("hiệu năng (headless)", "không quái: %.3f ms/frame, 5 quái: %.3f ms/frame" % [base_time, five_time])
	_check(five_time - base_time < 3.0, "5 quái cùng sân: tăng chi phí mỗi frame < 3 ms", "+%.3f ms" % (five_time - base_time))


func _measure_frames(count: int) -> float:
	await get_tree().physics_frame
	var start := Time.get_ticks_usec()
	for i in count:
		await get_tree().physics_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / count
