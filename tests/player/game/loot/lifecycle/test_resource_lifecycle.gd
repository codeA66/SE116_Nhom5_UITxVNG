extends Node3D
## UC1: nhiều người dùng cùng mesh/cache, bỏ cache không hủy tài nguyên còn đang dùng.
## UC2: owner ra khỏi cây thì nhả tài nguyên; registry yếu không giữ Resource đã hết người dùng.
## UC3: nạp fusion trước _ready vẫn được đăng ký; cache hình học thật dùng owner chung.
## UC4: modifier thêm/gỡ đúng một lần, hai cheat dev không để sót callback.
## TC1: owner tồn tại từ lúc khởi động, nghỉ khi rảnh; bucket/resource giữ cùng instance.
## TC2: bỏ entry khi mesh còn ở MeshInstance3D -> mesh sống; gỡ consumer -> mesh được giải phóng.
## TC3: gỡ owner -> WeakRef của mesh hết hiệu lực; registry tự bỏ Resource đã hết tham chiếu.
## TC4: fusion nạp sẵn có trong registry; hai lần gọi WindVfxGeometry.quad() dùng cùng mesh của owner.
## TC5: sát thương 3 -> thêm modifier giảm 1 hai lần vẫn chỉ trừ 2 -> tháo lại trừ 3.
## TC6: bật/tắt từng cheat rồi kiểm tra số modifier trở lại ban đầu.
## TC7: tiến trình con nạp/gỡ map rồi thoát thật; kiểm cả log sau khi RenderingServer dừng.
## UC5 / TC8: đọc dạng kỹ năng gốc không tự giữ resource; bản nâng cấp vẫn cache và được nhả cùng dữ liệu gốc.

const OWNER_SCRIPT: String = "res://components/core/object_pool/shared_resources/shared_resources.gd"
var _fails: int = 0
var _checks: int = 0
var _shared: Node


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--ability-cache-only"):
		_run_ability_cache.call_deferred()
	elif OS.get_cmdline_user_args().has("--shutdown-worker"):
		_run_worker.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	_shared = get_tree().root.get_node_or_null(^"SharedResources")
	_check(_shared != null, "TC1 owner có sẵn lúc khởi động")
	if _shared == null:
		_finish()
		return
	_check(not _shared.is_processing() and not _shared.is_physics_processing(), "TC1 owner không xử lý mỗi frame")
	await _resource_ownership()
	await _weak_registry()
	_actual_geometry()
	_damage_modifiers()
	_dev_cheats()
	_ability_cache_lifetime()
	# CI kiểm vòng đời cache riêng; phép kiểm thoát toàn engine vẫn chạy mặc định và không hạ điều kiện PASS.
	if not OS.get_cmdline_user_args().has("--unit"):
		_shutdown_log()
	_finish()


func _resource_ownership() -> void:
	var owner_script: Script = load(OWNER_SCRIPT) as Script
	var cache: Node = owner_script.new() as Node
	add_child(cache)
	var bucket: Dictionary = cache.call(&"get_bucket", &"test.bucket")
	bucket[&"count"] = 7
	var same_bucket: Dictionary = cache.call(&"get_bucket", &"test.bucket")
	_check(same_bucket.get(&"count") == 7, "TC1 bucket dùng chung dữ liệu")
	var mesh_ref: WeakRef = _attach_mesh(cache)
	cache.call(&"release_resource", &"test.mesh")
	_check(mesh_ref.get_ref() != null, "TC2 bỏ cache không hủy mesh còn ở consumer")
	get_node(^"MeshConsumer").queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(mesh_ref.get_ref() == null, "TC2 mesh được nhả khi consumer cuối mất")
	var owned_ref: WeakRef = _store_mesh(cache)
	cache.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(owned_ref.get_ref() == null, "TC3 gỡ owner nhả tài nguyên do nó giữ")


func _attach_mesh(cache: Node) -> WeakRef:
	var mesh: QuadMesh = QuadMesh.new()
	cache.call(&"store_resource", &"test.mesh", mesh)
	_check(cache.call(&"get_resource", &"test.mesh") == mesh, "TC1 lấy lại đúng instance mesh")
	var consumer: MeshInstance3D = MeshInstance3D.new()
	consumer.name = &"MeshConsumer"
	consumer.mesh = mesh
	consumer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(consumer)
	return weakref(mesh)


func _store_mesh(cache: Node) -> WeakRef:
	var mesh: QuadMesh = QuadMesh.new()
	cache.call(&"store_resource", &"test.owned", mesh)
	return weakref(mesh)


func _weak_registry() -> void:
	var cache: Node = (load(OWNER_SCRIPT) as Script).new() as Node
	add_child(cache)
	_register_temporary(cache)
	var live: Array = cache.call(&"get_registered", &"test.registry")
	_check(live.is_empty(), "TC3 registry không giữ Resource đã hết người dùng")
	var effects: Array = _shared.call(&"get_registered", &"fusion.effects")
	_check(not effects.is_empty(), "TC4 fusion nạp trước _ready đã vào registry")
	cache.queue_free()
	await get_tree().process_frame


func _register_temporary(cache: Node) -> void:
	var resource: Resource = Resource.new()
	cache.call(&"register_weak", &"test.registry", resource)
	cache.call(&"register_weak", &"test.registry", resource)
	var registered: Array = cache.call(&"get_registered", &"test.registry")
	_check(registered.size() == 1 and registered[0] == resource, "TC3 registry không đăng ký trùng")


func _actual_geometry() -> void:
	var factory: Script = load("res://assets/vfx/wind/shared/wind_vfx_geometry.gd") as Script
	var first: Resource = factory.call(&"quad") as Resource
	var second: Resource = factory.call(&"quad") as Resource
	_check(first == second, "TC4 mesh hình học thật vẫn được chia sẻ")
	_check(_shared.call(&"get_resource", &"wind.geometry.quad") == first, "TC4 mesh thật thuộc owner chung")


func _damage_modifiers() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10
	add_child(health)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.health = health
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	add_child(hurtbox)
	var script: Script = hurtbox.get_script() as Script
	var info: DamageInfo = DamageInfo.new(3)
	hurtbox.receive_hit(info)
	_check(health.current_health == 7, "TC5 chưa có modifier: sát thương 3")
	health.heal_full()
	script.call(&"add_damage_modifier", _reduce_damage)
	script.call(&"add_damage_modifier", _reduce_damage)
	hurtbox.receive_hit(info)
	_check(health.current_health == 8, "TC5 thêm hai lần vẫn chỉ giảm 1 sát thương")
	script.call(&"remove_damage_modifier", _reduce_damage)
	health.heal_full()
	hurtbox.receive_hit(info)
	_check(health.current_health == 7, "TC5 gỡ modifier trả lại sát thương gốc")
	hurtbox.queue_free()
	health.queue_free()


func _reduce_damage(_hurtbox: Area3D, _info: RefCounted, damage: int) -> int:
	return maxi(damage - 1, 0)


func _dev_cheats() -> void:
	var modifiers: Array = _shared.call(&"get_damage_modifiers")
	var before: int = modifiers.size()
	for path: String in ["res://dev/cheats/god_mode.gd", "res://dev/cheats/one_hit_kill.gd"]:
		var cheat: RefCounted = (load(path) as Script).new() as RefCounted
		_check(cheat != null, "TC6 " + path.get_file() + ": nạp được cheat")
		if cheat == null:
			continue
		cheat.call(&"apply", null)
		cheat.call(&"apply", null)
		_check(modifiers.size() == before + 1, "TC6 " + path.get_file() + ": bật không đăng ký trùng")
		cheat.call(&"remove", null)
		_check(modifiers.size() == before, "TC6 " + path.get_file() + ": tắt không sót callback")


func _run_ability_cache() -> void:
	_ability_cache_lifetime()
	_finish()


func _ability_cache_lifetime() -> void:
	var identity_ref: WeakRef = _resolve_identity_form()
	_check(identity_ref.get_ref() == null, "TC8 dạng gốc không tự giữ resource sau khi hết consumer")
	var copied_refs: Array[WeakRef] = _resolve_copied_form()
	_check(copied_refs[0].get_ref() == null, "TC8 dữ liệu gốc được nhả sau khi dùng dạng nâng cấp")
	_check(copied_refs[1].get_ref() == null, "TC8 bản sao nâng cấp được nhả cùng cache")


func _resolve_identity_form() -> WeakRef:
	var ability: AbilityData = AbilityData.new()
	_check(ability.resolve(0) == ability, "TC8 cấp 0 được kẹp về đúng dạng gốc")
	_check(ability.resolve(1000000) == ability, "TC8 cấp rất lớn vẫn trả đúng dạng gốc khi chưa có nâng cấp")
	return weakref(ability)


func _resolve_copied_form() -> Array[WeakRef]:
	var ability: AbilityData = AbilityData.new()
	var upgrade: SkillUpgradeData = SkillUpgradeData.new()
	upgrade.overrides[&"energy_cost"] = 3
	ability.upgrades.append(upgrade)
	var form: AbilityData = ability.resolve(2)
	_check(form != ability and form.energy_cost == 3, "TC8 bản nâng cấp vẫn nhận đúng overrides")
	_check(ability.resolve(2) == form, "TC8 bản nâng cấp vẫn dùng chung instance cache")
	return [weakref(ability), weakref(form)]


func _shutdown_log() -> void:
	# Profile lồng dưới user:// làm đường dẫn shader cache vượt giới hạn Windows và gây lỗi giả trong test.
	var temporary: String = OS.get_environment("TEMP")
	if temporary.is_empty():
		temporary = OS.get_environment("TMPDIR")
	if temporary.is_empty():
		temporary = OS.get_user_data_dir().get_base_dir()
	var profile: String = temporary.path_join("foxy_rl_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(profile)
	var old_appdata: String = OS.get_environment("APPDATA")
	var old_local: String = OS.get_environment("LOCALAPPDATA")
	var old_xdg: String = OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("APPDATA", profile)
	OS.set_environment("LOCALAPPDATA", profile)
	OS.set_environment("XDG_DATA_HOME", profile)
	var args: PackedStringArray = ["--path", ProjectSettings.globalize_path("res://"),
		"res://tests/player/game/loot/lifecycle/test_resource_lifecycle.tscn"]
	if DisplayServer.get_name() == "headless":
		args.append("--headless")
	else:
		args.append_array(["--windowed", "--resolution", "1280x720"])
	args.append_array(["--", "--shutdown-worker"])
	var output: Array = []
	# Lỗi dọn GPU xuất hiện sau quit: phải đọc log của tiến trình đã đóng, không chỉ đếm node khi còn chạy.
	var exit_code: int = OS.execute(OS.get_executable_path(), args, output, true)
	OS.set_environment("APPDATA", old_appdata)
	OS.set_environment("LOCALAPPDATA", old_local)
	OS.set_environment("XDG_DATA_HOME", old_xdg)
	var done: bool = false
	var errors: int = 0
	for block: String in output:
		for line: String in block.split("\n"):
			if line.contains("RESOURCE_SHUTDOWN worker_done"):
				done = true
			if line.contains("ERROR:") or line.contains("ObjectDB instances were leaked"):
				errors += 1
				if errors <= 5:
					print("SHUTDOWN_LOG ", line)
	_check(exit_code == 0 and done, "TC7 tiến trình con thực sự nạp/gỡ map rồi thoát")
	_check(errors == 0, "TC7 không có lỗi trong log thoát (%d dòng)" % errors)


func _run_worker() -> void:
	SaveManager.use_storage_dir("user://resource_shutdown_worker")
	GameState.replace_progress(PlayerProgress.new())
	var ready: bool = await _worker_zone()
	for _frame_index: int in 5:
		await get_tree().process_frame
	if not ready:
		push_error("RESOURCE_SHUTDOWN map không đạt combat_ready trước timeout")
		get_tree().quit(1)
		return
	print("RESOURCE_SHUTDOWN worker_done")
	get_tree().quit()


func _worker_zone() -> bool:
	var scene: PackedScene = load("res://levels/zone_1_wind/level_1/level_1.tscn") as PackedScene
	var zone: Node3D = scene.instantiate() as Node3D
	zone.set(&"shader_warmup", null)
	get_tree().root.add_child(zone)
	get_tree().current_scene = zone
	var deadline: int = Time.get_ticks_msec() + 60000
	while not bool(zone.call(&"is_combat_ready")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ready: bool = bool(zone.call(&"is_combat_ready"))
	await get_tree().create_timer(2.0).timeout
	get_tree().current_scene = self
	zone.queue_free()
	return ready


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("%s %s" % ["PASS" if ok else "FAIL", message])


func _finish() -> void:
	print("RESOURCE_LIFECYCLE RESULT checks=%d fails=%d" % [_checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
