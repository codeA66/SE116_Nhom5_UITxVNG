extends Node
## Sân thử thùng phá được: Foxy có kiếm + cung + Thổi Gió, năng lượng bắt đầu từ 0, vài thùng gỗ quanh sân.
## Chơi tay: chém thùng -> mỗi nhát nạp 1 ô năng lượng, 3 nhát thì vỡ, 5 giây sau mọc lại.
## Bắn tên / thổi gió vào thùng: trừ máu, làm vỡ, nhưng không nạp năng lượng.
## Tắt tự lưu và đổi thư mục lưu khi mở sân: không ghi vào save thật đang chơi dở.

const STORAGE := "user://test_breakables/"
const CAPTURE_ARG: String = "--capture-breakables="
const MELEE_DISTANCE: float = 1.3
const MELEE_APPROACH: Vector3 = Vector3(0.8, 0.0, 0.6)
const SLOW_ACTION_WAIT: float = 0.86

@export var weapons: Array[Resource] = []
@export var abilities: Array[Resource] = []

var _capture_dir: String
var _player: Player
var _failed: int = 0


func _enter_tree() -> void:
	SaveManager.use_storage_dir(STORAGE)
	for progress_signal: Signal in [GameState.progress_changed, GameState.progress_committed]:
		if progress_signal.is_connected(SaveManager.save_game):
			progress_signal.disconnect(SaveManager.save_game)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARG):
			_capture_dir = argument.trim_prefix(CAPTURE_ARG)
	if _capture_dir.is_empty():
		return
	var fast: Breakable = _crate(4)
	var permanent: Breakable = _crate(6)
	fast.data = fast.data.duplicate() as BreakableData
	fast.data.respawn_time = 0.01
	fast.data.max_hits = 1
	permanent.data = permanent.data.duplicate() as BreakableData
	permanent.data.respawn_time = 0.0
	permanent.data.max_hits = 20


func _ready() -> void:
	for weapon in weapons:
		GameState.add_weapon(weapon as WeaponData)
	if not weapons.is_empty():
		GameState.set_weapon(weapons[0] as WeaponData)
	for ability in abilities:
		GameState.unlock_ability(ability as AbilityData)
	_empty_energy.call_deferred()
	if not _capture_dir.is_empty():
		_capture_run.call_deferred()


func _empty_energy() -> void:
	var player := get_parent().get_node_or_null(^"Player") as Player
	if player:
		player.energy.set_current(0)


func _capture_run() -> void:
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if not zone.is_combat_ready():
		await zone.combat_ready
	_player = zone.get_node(^"Player") as Player
	if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
		push_error("Không tạo được thư mục ảnh: " + _capture_dir)
		get_tree().quit(1)
		return
	var crate: Breakable = _crate(1)
	var chunks: Node3D = crate.get_node(crate.debris_parts_root) as Node3D
	var panel: Node3D = chunks.get_node(^"FrontPanel") as Node3D
	var lid: Node3D = chunks.get_node(^"Lid") as Node3D
	var panel_rest: Transform3D = panel.transform
	var lid_rest: Transform3D = lid.transform
	await _stand_near(crate)
	await _capture("01_idle")
	for index: int in range(1, 4):
		var energy_before: int = _player.energy.current
		await _strike(crate)
		_check(_health_of(crate).current_health == 3 - index, "Kiếm trừ đúng một hit (%d/3)" % index)
		_check(_player.energy.current == energy_before + 1, "Kiếm cộng một Linh lực (%d/3)" % index)
		if index < 3:
			if index == 1:
				await _wait(0.04)
				await _capture("02a_hit_flash")
			await _wait(0.24)
			_check(not panel.transform.is_equal_approx(panel_rest), "Ván lệch sau hit %d" % index)
			_check(lid.transform.is_equal_approx(lid_rest) == (index == 1), "Nắp phân biệt hit 1 và hit 2")
			await _capture("0%d_hit_%d" % [index + 1, index])
			await _wait(SLOW_ACTION_WAIT)
			await _stand_near(crate)
	await _wait(0.10)
	await _capture("04_break")
	_check(crate.is_broken and not _is_solid(crate), "Vỡ thì va chạm và hurtbox tắt")
	_check(not _body_at(crate), "Tia vật lý đi qua chỗ thùng vỡ")
	await _wait(1.80)
	await _capture("05_rubble_2s")
	var landed: Transform3D = panel.transform
	_check(not landed.is_equal_approx(panel_rest), "Mảnh còn trên sàn sau 2 giây")
	await _wait(crate.data.respawn_time - 1.80 - 0.10 + 0.12)
	await _capture("06_rebuilding")
	_check(not panel.transform.is_equal_approx(landed) and not _is_solid(crate), "Mảnh chuyển động khi ráp, va chạm tắt")
	await _wait(0.75)
	await _capture("07_rebuilt")
	_check(_is_solid(crate) and panel.transform.is_equal_approx(panel_rest) and lid.transform.is_equal_approx(lid_rest), "Ráp xong về đúng transform và bật va chạm")
	_check(_body_at(crate), "Tia vật lý chạm thùng đã ráp")
	await _wait(2.5)
	await _capture("08_cleanup")
	_check(_is_solid(crate) and panel.transform.is_equal_approx(panel_rest), "Ổn định sau khi ráp")
	_check(not (crate.get_node(^"RebuildDust") as GPUParticles3D).emitting
		and not (crate.get_node(^"HitChips") as CPUParticles3D).emitting, "Emitter tắt sau khi ráp")
	await _check_fast_respawn()
	await _check_permanent_crate()
	await _check_ranged_hits()
	print("BREAKABLE_CAPTURE_RESULT fails=", _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _check_fast_respawn() -> void:
	var crate: Breakable = _crate(4)
	await _stand_near(crate)
	await _strike(crate)
	_check(crate.is_broken, "Thùng max_hits=1 vỡ sau một nhát")
	await _wait(0.12)
	_player.teleport(crate.global_position, Vector3.FORWARD)
	await _wait(0.90)
	_check(crate.is_broken and not _is_solid(crate), "Timer 0,01 giây chờ Foxy rời vùng, kể cả khi vào giữa lúc ráp")
	await _stand_near(crate)
	await _wait(0.88)
	_check(_is_solid(crate), "Thùng ráp lại sau khi Foxy đi ra")
	await _strike(crate)
	var broke: bool = crate.is_broken
	await _wait(0.88)
	_check(broke and _is_solid(crate), "Timer hết khi mảnh còn bay, ráp lại bình thường")


func _check_permanent_crate() -> void:
	var crate: Breakable = _crate(6)
	var health: HealthComponent = _health_of(crate)
	for index: int in range(20):
		await _stand_near(crate)
		await _strike(crate)
		if index < 19:
			await _wait(SLOW_ACTION_WAIT)
	_check(health.is_dead() and crate.is_broken, "max_hits=20 vỡ sau 20 cú chém")
	await _wait(1.5)
	var panel: Node3D = crate.get_node(crate.debris_parts_root).get_node(^"FrontPanel") as Node3D
	var landed: Transform3D = panel.transform
	await _wait(4.0)
	_check(crate.is_broken and not _is_solid(crate) and panel.transform.is_equal_approx(landed), "respawn_time=0 giữ mảnh và vùng đi xuyên")


func _check_ranged_hits() -> void:
	var crate: Breakable = _crate(8)
	await _stand_near(crate, 2.1)
	_player.energy.set_current(_player.energy.get_max())
	var initial: int = _player.energy.current
	var health: HealthComponent = _health_of(crate)
	var bow: BowData = _player.get_bow()
	var health_before: int = health.current_health
	Input.action_press(&"aim")
	await _wait(bow.draw_time + 0.2)
	Input.action_release(&"aim")
	await _wait(0.4)
	_check(health.current_health == health_before - bow.get_shot_damage(1.0), "Tên kéo đầy gây đúng sát thương")
	_check(_player.energy.current == initial - bow.energy_cost, "Tên chỉ tiêu Linh lực")
	var wind: WindBlastData = _player.get_ability(WindBlastData.ID) as WindBlastData
	initial = _player.energy.current
	health_before = health.current_health
	_aim_at(crate)
	Input.action_press(wind.input_action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(wind.input_action)
	await _wait(0.75)
	_check(health.current_health == maxi(health_before - wind.damage, 0), "Thổi Gió gây đúng sát thương")
	_check(_player.energy.current == initial - wind.energy_cost, "Thổi Gió chỉ tiêu Linh lực")


func _stand_near(crate: Breakable, distance: float = MELEE_DISTANCE) -> void:
	_player.teleport(crate.global_position + MELEE_APPROACH * distance, -MELEE_APPROACH)
	await _wait(0.10)
	_aim_at(crate)


func _strike(crate: Breakable) -> void:
	var health: HealthComponent = _health_of(crate)
	var previous: int = health.current_health
	_aim_at(crate)
	Input.action_press(&"attack")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"attack")
	# Giới hạn thời gian chờ để phiên chụp vẫn thoát nếu đòn trượt.
	var deadline: int = Engine.get_physics_frames() + 60
	while health.current_health == previous and Engine.get_physics_frames() < deadline:
		await get_tree().physics_frame
	await get_tree().physics_frame
	if health.current_health == previous:
		print("MISSED target=", crate.global_position, " player=", _player.global_position, " aim=", _player.get_mouse_aim_direction(), " facing=", _player.get_facing_direction(), " mouse=", get_viewport().get_mouse_position())


func _aim_at(crate: Breakable) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var viewport: Viewport = get_viewport()
	var screen_pos: Vector2 = camera.unproject_position(Vector3(crate.global_position.x, _player.global_position.y, crate.global_position.z))
	viewport.warp_mouse(screen_pos)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _capture(stamp: String) -> void:
	await RenderingServer.frame_post_draw
	var target: String = _capture_dir.path_join(stamp + ".png")
	var frame: Image = get_viewport().get_texture().get_image()
	_check(frame.save_png(target) == OK, "Viewport " + stamp)


func _is_solid(crate: Breakable) -> bool:
	var shape: CollisionShape3D = crate.get_node(^"CollisionShape3D") as CollisionShape3D
	var hurtbox: HurtboxComponent = crate.get_node(^"HurtboxComponent") as HurtboxComponent
	return not shape.disabled and hurtbox.monitorable and not crate.is_broken


func _body_at(crate: Breakable) -> bool:
	var start: Vector3 = crate.global_position + Vector3(0, 0.5, 0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		start + Vector3.BACK, start + Vector3.FORWARD, crate.collision_layer
	)
	var hit: Dictionary = crate.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == crate


func _health_of(crate: Breakable) -> HealthComponent:
	return crate.get_node(^"HealthComponent") as HealthComponent


func _crate(index: int) -> Breakable:
	return get_parent().get_node("Crate%d" % index) as Breakable


func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		_failed += 1
