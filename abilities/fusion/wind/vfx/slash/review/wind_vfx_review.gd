extends Node
## DONE: so sánh đúng instance nằm sẵn trong Player, không thêm VFX thứ hai.
## NOT DONE: fixture không thay cho benchmark toàn map/export với cache sạch.
## NOTES: --before ảnh cũ; --perf mới đo; --output= thư mục bằng chứng.
@export_group("Review")
@export var element_id: StringName = &"wind"
@export_enum("slash", "charge") var review_mode: String = "slash"
@export var output: String = "user://sword_upgrade"
@export var settle_time: float = 0.5
@export var cleanup_time: float = 3.0
@export var sample_fraction: float = 0.65
@export_group("Performance")
@export var measure_duration: float = 2.0
@export var stress_targets: int = 8
@export var stress_health: int = 1000
@export var swing_interval: float = 0.25
@export var measure_active_time: float = 0.12
@export var direction: Vector3 = Vector3(1.0, 0.0, 1.0).normalized()
var player: Player
var vfx: Node3D
var enemy: Enemy
var fails: int = 0
var _before: bool = false
var _perf: bool = false
var _visual_only: bool = false
var _headless: bool = false
var _floor: MeshInstance3D
var _saved: PlayerProgress
var _weapon: WeaponData
var _hit_count: int = 0
var _zone: MeshInstance3D
var _startup_captured: bool = false

## Chờ autoload trước khi thay tiến trình trong RAM.
func _ready() -> void:
	_run.call_deferred()

## Mỗi cặp ảnh dùng cùng pose, camera và thời điểm active.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--before": _before = true
		if arg == "--perf": _perf = true
		if arg == "--visual-only": _visual_only = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(output)
	_saved = GameState.progress.snapshot()
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	_weapon = load("res://resources/combat/weapons/sword.tres") as WeaponData
	GameState.set_weapon(_weapon)
	GameState.unlock_ability(load("res://abilities/wind_blast/wind_blast.tres") as AbilityData)
	GameState.unlock_ability(load("res://abilities/flame_breath/flame_breath.tres") as AbilityData)
	GameState.unfuse(WeaponData.Slot.SWORD)
	_setup_floor()
	await _make_player({})
	if review_mode == "charge":
		await _run_charge_review()
		print("WIND_CHARGE_RESULT fails=", fails)
		GameState.replace_progress(_saved)
		get_tree().quit(1 if fails else 0)
		return
	if _perf:
		await _measure()
	else:
		for light: bool in [false, true]:
			(_floor.material_override as StandardMaterial3D).albedo_color = Color(0.73, 0.71, 0.65) if light else Color(0.13, 0.17, 0.20)
			for fused: bool in [false, true]:
				if fused: _check(GameState.fuse(element_id, WeaponData.Slot.SWORD), "ghép thật")
				else: GameState.unfuse(WeaponData.Slot.SWORD)
				for index: int in range(_weapon.combo.size()):
					await _swing(index, "%s_%s_%d" % ["bright" if light else "dark", "fused" if fused else "plain", index + 1])
		if not _before:
			await _test_hits()
			await _test_filters()
			await _test_extremes()
		await get_tree().create_timer(cleanup_time).timeout
		_check(_clean(), "ba giây sạch, pool trả hết")
		await _capture("after_three")
	print("SWORD_REVIEW element=", element_id, " before=", _before, " fails=", fails)
	GameState.replace_progress(_saved)
	get_tree().quit(1 if fails else 0)

## Đổi export trước add_child để giữ đúng thứ tự child/parent ready khi stress test.
func _make_player(settings: Dictionary) -> void:
	if is_instance_valid(player): player.free()
	player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	var path: String = "WindBowChargeVfx" if review_mode == "charge" else ("FireSwordVfx" if element_id == &"fire" else "WindSwordSlashVfx")
	vfx = player.get_node(path) as Node3D
	for key: String in settings: vfx.set(key, settings[key])
	add_child(player)
	player.set_controls_enabled(false)
	player.set_physics_process(false)
	player.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	player.hitbox.hit.connect(_on_hit)
	if not _headless and not _perf and not _startup_captured:
		_startup_captured = true
		for frame: int in range(3):
			await _capture("startup_%d" % frame)
	await get_tree().create_timer(settle_time).timeout
	_check(not vfx.is_processing(), "ready từ cây Player thật và idle")

## Giữ nhánh cung vì scene review charge đã kế thừa fixture này từ trước.
func _run_charge_review() -> void:
	GameState.add_weapon(load("res://resources/combat/weapons/bow.tres") as WeaponData)
	GameState.fuse(&"wind", WeaponData.Slot.BOW)
	player.begin_bow_aim()
	for amount: float in [0.0, 0.5, 1.0]:
		player.set_bow_draw(amount)
		await get_tree().create_timer(0.1).timeout
		_check(vfx.is_processing(), "cung wind hiện theo lực kéo")
		await _capture("bow_draw_%d" % roundi(amount * 100.0))
	player.release_bow()
	player.end_bow_aim()
	await get_tree().create_timer(cleanup_time).timeout
	_check(_clean(), "cung release sạch")
	player.begin_bow_aim()
	player.set_bow_draw(0.5)
	player.end_bow_aim()
	await get_tree().create_timer(cleanup_time).timeout
	_check(_clean(), "cung cancel sạch")
	GameState.fuse(&"fire", WeaponData.Slot.BOW)
	player.begin_bow_aim()
	player.set_bow_draw(1.0)
	player.end_bow_aim()
	await get_tree().create_timer(settle_time).timeout
	_check(_clean(), "cung wind bỏ qua fire")

## Dùng marker thật và hitbox thật giống state Attack, không gọi hit giả.
func _swing(index: int, label: String) -> void:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.face_instantly(direction)
	var attack: AttackData = _weapon.combo[index]
	player.hitbox.set_reach(_weapon.attack_range)
	player.play_action(attack.animation, attack.anim_speed, 0.0)
	var start: float = player.get_action_marker_time(attack.animation, attack.hit_start_marker)
	var end: float = player.get_action_marker_time(attack.animation, attack.hit_end_marker)
	if start >= 0.0 and end > start:
		start /= attack.anim_speed
		end /= attack.anim_speed
	else:
		start = attack.active_start
		end = attack.active_end
	await get_tree().create_timer(start).timeout
	player.hitbox.activate(attack, end - start)
	player.notify_melee_active(attack, index, _weapon.combo.size(), direction, end - start)
	await get_tree().create_timer((end - start) * sample_fraction).timeout
	if not _before and label == "enemy_contact":
		_check((vfx.call("get_hit_pool") as ObjectPool).get_active_count() > 0, "hit burst hiện trong lượt va chạm")
	await _capture(label)
	if label == "enemy_contact":
		await get_tree().create_timer(0.08).timeout
		await _capture("enemy_contact_tail")
	await get_tree().create_timer((end - start) * (1.0 - sample_fraction)).timeout
	player.hitbox.deactivate()
	await get_tree().create_timer(settle_time).timeout

## Enemy thật đứng trong vùng đánh; AI tắt để pose giữa các ảnh không trôi.
func _test_hits() -> void:
	GameState.fuse(element_id, WeaponData.Slot.SWORD)
	enemy = (load("res://entities/enemies/palace/enemy_1/enemy_1.tscn") as PackedScene).instantiate() as Enemy
	add_child(enemy)
	enemy.position = direction * 1.2
	enemy.set_physics_process(false)
	enemy.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame
	await get_tree().physics_frame
	_hit_count = 0
	await _swing(0, "enemy_contact")
	_check(_hit_count > 0, "enemy hurtbox nhận hit vật lý thật")
	await get_tree().create_timer(cleanup_time).timeout
	_check(_clean(), "hit burst về pool và nghỉ")
	enemy.queue_free()
	await get_tree().process_frame
	if element_id == &"fire":
		_setup_zone()
		await _swing(_weapon.combo.size() - 1, "finisher_zone")
		_zone.hide()
	await get_tree().create_timer(cleanup_time).timeout
	_check(_clean(), "hit burst về pool và nghỉ")

## Lọc cả không ghép và nguyên tố còn lại.
func _test_filters() -> void:
	GameState.unfuse(WeaponData.Slot.SWORD)
	await _swing(0, "filter_unfused")
	_check(_clean(), "unfused không phát family này")
	GameState.fuse(&"wind" if element_id == &"fire" else &"fire", WeaponData.Slot.SWORD)
	await _swing(0, "filter_other")
	_check(_clean(), "nguyên tố khác không phát family này")

## Giá trị cực trị phải vẫn hữu hạn, trong tầm và dọn được.
func _test_extremes() -> void:
	var cases: Array[Dictionary] = [
		{"inner_ratio": 0.94, "arc_degrees": 20.0, "curl_amount": 0.005, "strand_count": 1},
		{"inner_ratio": 0.05, "arc_degrees": 300.0, "curl_amount": 0.4, "strand_count": 8}
	]
	if element_id == &"fire":
		cases[0]["tongue_count"] = 1.0
		cases[0]["tongue_size"] = 0.005
		cases[1]["tongue_count"] = 12.0
		cases[1]["tongue_size"] = 0.4
	for index: int in range(cases.size()):
		await _make_player(cases[index])
		GameState.fuse(element_id, WeaponData.Slot.SWORD)
		await _swing(0, "extreme_%d" % index)
		await get_tree().create_timer(cleanup_time).timeout
		_check(_clean(), "cực trị sạch")
	await _make_player({})
	GameState.fuse(element_id, WeaponData.Slot.SWORD)

## Giữ camera gốc, chỉ thay màu nền để kiểm tra tương phản.
func _setup_floor() -> void:
	_floor = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	_floor.mesh = plane
	_floor.material_override = StandardMaterial3D.new()
	add_child(_floor)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, -30.0, 0.0)
	add_child(sun)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.05, 0.07, 0.09)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.7
	add_child(world)

## Hộp giới hạn chỉ vẽ trong review, đọc đúng resource FireTouch.
func _setup_zone() -> void:
	var data: FusionData = load("res://resources/combat/fusion/fire/sword_fire.tres") as FusionData
	for effect: FusionEffect in data.effects:
		if effect is IgniteOnLastHitEffect:
			var ignite: IgniteOnLastHitEffect = effect as IgniteOnLastHitEffect
			_zone = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = ignite.area_size
			_zone.mesh = box
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.2, 0.8, 0.9, 0.12)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_zone.material_override = mat
			_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_zone)
			_zone.global_transform = Transform3D(Basis.looking_at(-direction), direction * ignite.forward + Vector3.UP * ignite.height)
			return

## Bộ đếm quan sát không tác động damage hoặc nhận hit.
func _on_hit(_target: HurtboxComponent) -> void:
	_hit_count += 1

## Chỉ renderer thật mới có screenshot.
func _capture(label: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	if not _before and label.contains("fused"):
		var mesh: MeshInstance3D = vfx.get_node("Arc" if element_id == &"fire" else "Ribbons") as MeshInstance3D
		var mat: ShaderMaterial = mesh.material_override as ShaderMaterial
		print("CAPTURE_STATE ", label, " clock=", mat.get_shader_parameter("clock"), " dissolve=", mat.get_shader_parameter("dissolve"))
	_check(get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "ảnh " + label)

## Kiểm tra visibility/process và toàn bộ pool của instance.
func _clean() -> bool:
	if vfx.is_processing(): return false
	if not vfx.has_method("is_visual_idle"): return true
	if not bool(vfx.call("is_visual_idle")): return false
	var pool: ObjectPool = vfx.call("get_hit_pool") as ObjectPool
	for child: Node in pool.get_children():
		if child.is_processing() or (child as Node3D).visible: return false
	return true

## Cửa sổ đầu đo ngay lượt fused đầu tiên sau warmup; các cặp sau so plain/fused cùng cảnh.
func _measure() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	player.face_instantly(direction)
	player.hitbox.set_reach(_weapon.attack_range)
	await _measure_window("startup_idle", false, false)
	await _measure_window("first_fused_after_ready", true, false)
	for cycle: int in range(2):
		await _measure_window("plain_%d" % cycle, false, false)
		await _measure_window("fused_%d" % cycle, true, false)
	if _visual_only:
		await get_tree().create_timer(cleanup_time).timeout
		_check(_clean(), "isolation hết ba giây sạch")
		return
	await _measure_window("finisher_plain", false, false)
	await _measure_window("finisher_fused", true, false)
	var crowd: Array[Enemy] = []
	for index: int in range(stress_targets):
		var target: Enemy = (load("res://entities/enemies/palace/enemy_1/enemy_1.tscn") as PackedScene).instantiate() as Enemy
		add_child(target)
		target.set_physics_process(false)
		target.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
		target.position = direction * 1.1 + Vector3(direction.z, 0.0, -direction.x) * float(index % 3 - 1) * 0.12
		var health: HealthComponent = target.get_node("HealthComponent") as HealthComponent
		health.max_health = stress_health
		health.heal_full()
		crowd.append(target)
	await get_tree().create_timer(settle_time).timeout
	_hit_count = 0
	await _measure_window("crowd_plain", false, true)
	await _measure_window("crowd_fused", true, true)
	_check(_hit_count >= stress_targets * 4, "stress có nhiều lượt va chạm vật lý thật")
	var pool: ObjectPool = vfx.call("get_hit_pool") as ObjectPool
	var total: int = pool.get_total_created()
	await get_tree().create_timer(cleanup_time).timeout
	_check(total == int(vfx.get("hit_pool_size")), "pool không tạo thêm dù nhiều enemy trúng liên tiếp")
	_check(_clean(), "stress hết ba giây pool trả đủ và nghỉ")
	print("SWORD_POOL total=", total, " active=", pool.get_active_count(), " actual_hits=", _hit_count)
	for target: Enemy in crowd: target.queue_free()

## Mảng đo cấp phát trước cửa sổ; không chụp hoặc ghi log trong từng frame.
func _measure_window(label: String, fused: bool, crowd: bool) -> void:
	if fused or _visual_only: GameState.fuse(element_id, WeaponData.Slot.SWORD)
	else: GameState.unfuse(WeaponData.Slot.SWORD)
	var settle_last: int = Time.get_ticks_usec()
	var settle_max_ms: float = 0.0
	for frame: int in range(3):
		await RenderingServer.frame_post_draw
		var settle_now: int = Time.get_ticks_usec()
		settle_max_ms = maxf(settle_max_ms, float(settle_now - settle_last) / 1000.0)
		settle_last = settle_now
	print("SWORD_STATE_SETTLE ", label, " isolated=", _visual_only, " max_frame_ms=", settle_max_ms)
	var samples: PackedFloat64Array = PackedFloat64Array()
	samples.resize(4000)
	await get_tree().process_frame
	var last: int = Time.get_ticks_usec()
	var start: int = last
	var count: int = 0
	var clock: float = 0.0
	var max_draws: float = 0.0
	var active_left: float = 0.0
	var max_pool_active: int = 0
	var max_hook_us: int = 0
	var first_hook_us: int = -1
	var combo_index: int = _weapon.combo.size() - 1 if label.contains("finisher") else 0
	var attack: AttackData = _weapon.combo[combo_index]
	while float(Time.get_ticks_usec() - start) / 1000000.0 < measure_duration and count < samples.size():
		if clock <= 0.0:
			var hook_started: int = Time.get_ticks_usec()
			if label == "startup_idle":
				pass
			elif _visual_only:
				if fused: player.fusion_melee_swing.emit(element_id, attack, combo_index, _weapon.combo.size(), direction, measure_active_time)
			else:
				player.hitbox.deactivate()
				player.hitbox.activate(attack, measure_active_time)
				player.notify_melee_active(attack, combo_index, _weapon.combo.size(), direction, measure_active_time)
			clock = swing_interval
			active_left = measure_active_time
			var hook_us: int = Time.get_ticks_usec() - hook_started
			max_hook_us = maxi(max_hook_us, hook_us)
			if first_hook_us < 0: first_hook_us = hook_us
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		samples[count] = ms
		clock -= ms / 1000.0
		active_left -= ms / 1000.0
		if active_left <= 0.0 and player.hitbox.is_active(): player.hitbox.deactivate()
		_floor.rotation.y += 0.00001
		max_draws = maxf(max_draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		max_pool_active = maxi(max_pool_active, (vfx.call("get_hit_pool") as ObjectPool).get_active_count())
		last = now
		count += 1
	var first_ms: float = samples[0]
	var first_five_peak_ms: float = 0.0
	for index: int in range(mini(count, 5)):
		first_five_peak_ms = maxf(first_five_peak_ms, samples[index])
	samples.resize(count)
	samples.sort()
	var total: float = 0.0
	for value: float in samples: total += value
	print("SWORD_PERF ", element_id, " ", label, " crowd=", crowd, " fps=", 1000.0 * count / total, " first_ms=", first_ms, " first_five_peak_ms=", first_five_peak_ms, " median_ms=", samples[count >> 1], " p95_ms=", samples[mini(count - 1, floori(count * 0.95))], " worst_ms=", samples[count - 1], " max_draws=", max_draws, " max_pool_active=", max_pool_active)
	print("SWORD_HOOK ", label, " isolated=", _visual_only, " first_us=", first_hook_us, " max_us=", max_hook_us)
	player.hitbox.deactivate()
	await get_tree().create_timer(settle_time).timeout

## Gom mọi lỗi để không che nhánh thất bại sau lỗi đầu tiên.
func _check(passed: bool, label: String) -> void:
	if not passed: fails += 1
	print("PASS " if passed else "FAIL ", label)
