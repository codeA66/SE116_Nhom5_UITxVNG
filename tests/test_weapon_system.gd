extends Node3D
## Chạy với APPDATA/LOCALAPPDATA trong .godot/weapon_runtime để không đụng save cá nhân.

const PLAYER := preload("res://entities/player/player.tscn")
const PICKUP := preload("res://objects/pickups/weapon_pickup.tscn")
const DUMMY := preload("res://objects/training_dummy/training_dummy.tscn")
const SWORD := preload("res://resources/weapons/sword.tres")
const BOW := preload("res://resources/weapons/bow.tres")

var _failed := false
var _shots := 0
var _player: Player
var _target: TrainingDummy
var _camera: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sandbox := ProjectSettings.globalize_path("res://.godot/weapon_runtime/").replace("\\", "/").to_lower()
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox):
		push_error("TestWeaponSystem: đặt APPDATA/LOCALAPPDATA trong .godot/weapon_runtime để bảo vệ save cá nhân.")
		get_tree().quit(2)
		return
	GameState.replace_progress(PlayerProgress.new())
	child_entered_tree.connect(_on_child_entered)
	_build_stage()
	_player = PLAYER.instantiate() as Player
	add_child(_player)
	_camera.make_current()
	var sword := _make_pickup(SWORD, Vector3(-1, 0, 0), &"weapon_test.sword")
	var bow := _make_pickup(BOW, Vector3(1, 0, 0), &"weapon_test.bow")
	_player.teleport(Vector3(-1, 0.05, 0.9), Vector3.BACK)
	await _frames(20)
	_check(_player.get_weapon() == null, "fresh player starts unarmed")
	_check(not _slot(0).owned and not _slot(1).owned, "both HUD slots start locked")
	_check((InputMap.action_get_events(&"weapon_1")[0] as InputEventKey).physical_keycode == KEY_1, "key 1 mapped")
	_check((InputMap.action_get_events(&"weapon_2")[0] as InputEventKey).physical_keycode == KEY_2, "key 2 mapped")
	await _capture("pickups")
	await _tap(&"interact")
	await _frames(70)
	_check(not is_instance_valid(sword) and _player.get_weapon() == SWORD, "F picks up sword and equips it")
	await _tap(&"weapon_2")
	_check(_player.get_weapon() == SWORD and _slot(0).selected, "cannot select an unowned bow")
	_player.teleport(Vector3(1, 0.05, 0.9), Vector3.BACK)
	await _frames(10)
	await _tap(&"interact")
	await _frames(70)
	_check(not is_instance_valid(bow) and _player.get_weapon() == BOW, "F picks up bow and equips it")
	_check(GameState.progress.weapons.size() == 2, "picking bow keeps sword in inventory")
	_check(_slot(1).selected and not _slot(0).selected, "only bow socket glows")
	_check(not (_player.model.find_child("Sword", true, false) as Node3D).visible, "sword mesh hidden while using bow")
	_check(_player.get_node("WeaponSocket").get_child_count() == 1, "one bow attached to hand")
	await _capture("bow_equipped")
	await _tap(&"weapon_1")
	_check(_player.get_weapon() == SWORD and _slot(0).selected, "key 1 switches back to sword")
	await _frames(2)
	_check(_player.get_node("WeaponSocket").get_child_count() == 0, "switching removes held bow")
	await _capture("sword_equipped")
	_player.teleport(Vector3.ZERO, Vector3.BACK)
	_target = DUMMY.instantiate() as TrainingDummy
	_target.position = Vector3(0, 0, 1.2)
	add_child(_target)
	await _frames(10)
	await _tap(&"attack")
	await _frames(30)
	_check(_target_health() == 4 and _shots == 0, "sword still damages once without firing arrows")
	await _tap(&"weapon_2")
	_reset_target(Vector3(0, 0, 6))
	_player.teleport(Vector3.ZERO, Vector3.BACK)
	await _frames(10)
	await _tap(&"attack")
	await _frames(7)
	_check(_shots == 0, "bow has a draw windup")
	await _capture("bow_draw")
	await _tap(&"weapon_1")
	_check(_player.get_weapon() == BOW, "switch during attack waits for action to finish")
	await _frames(45)
	_check(_shots == 1 and _target_health() == 4, "one arrow damages distant target exactly once")
	_check(_player.get_weapon() == SWORD and _slot(0).selected, "queued switch applies after shot")
	_check(_player.health.current_health == 5, "arrow cannot damage its owner")
	await _tap(&"weapon_2")
	_reset_target(Vector3(0, 0, 5))
	_player.teleport(Vector3.ZERO, Vector3.BACK)
	var wall := _box(Vector3(0, 1, 2), Vector3(3, 2, 0.03), Color("486070"))
	await _frames(10)
	await _tap(&"attack")
	await _frames(45)
	_check(_target_health() == 5 and get_tree().get_nodes_in_group(&"arrows").is_empty(), "thin wall blocks arrow and damage")
	wall.position.z = 0.30
	await _frames(5)
	await _tap(&"attack")
	await _frames(45)
	_check(_target_health() == 5, "wall between body and muzzle also blocks arrow")
	wall.queue_free()
	await _frames(4)
	_player.face_instantly(Vector3.FORWARD)
	await _tap(&"attack")
	await _frames(120)
	_check(get_tree().get_nodes_in_group(&"arrows").is_empty(), "missed arrows expire")
	var before_cancel := _shots
	await _tap(&"attack")
	_player.state_machine.transition_to(PlayerState.HURT)
	await _frames(45)
	_check(_shots == before_cancel, "interrupted draw does not fire a delayed arrow")
	await _tap(&"weapon_1")
	await _tap(&"weapon_2")
	_check(SaveManager.save_game(), "save writes successfully")
	GameState.replace_progress(PlayerProgress.new())
	_check(SaveManager.load_game(), "save loads successfully")
	_check(GameState.progress.weapons.size() == 2 and _player.get_weapon() == BOW and _slot(1).selected, "save restores both weapons and selected socket")
	var legacy: PlayerProgress = SaveManager._deserialize({"version": 2, "weapon": SWORD.resource_path})
	_check(legacy.get_weapon_in_slot(WeaponData.Slot.SWORD) == SWORD, "v2 save migrates existing sword")
	var saved_bow := _make_pickup(BOW, Vector3(1, 0, 0), &"weapon_test.bow")
	await _frames(3)
	_check(not is_instance_valid(saved_bow), "picked-up bow stays absent after reload")
	_player.queue_free()
	await _frames(3)
	_player = PLAYER.instantiate() as Player
	add_child(_player)
	await _frames(5)
	_check(_player.get_weapon() == BOW and _player.get_node("WeaponSocket").get_child_count() == 1, "new player restores equipped bow on scene transition")
	print("WEAPON_SYSTEM ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


func _slot(index: int) -> WeaponSlot:
	return _player.get_node("HUD/WeaponSlots/" + ("SwordSlot" if index == 0 else "BowSlot")) as WeaponSlot


func _make_pickup(weapon: WeaponData, at: Vector3, id: StringName) -> WeaponPickup:
	var pickup := PICKUP.instantiate() as WeaponPickup
	pickup.weapon = weapon
	pickup.persistent_id = id
	pickup.position = at
	add_child(pickup)
	return pickup


func _reset_target(at: Vector3) -> void:
	_target.global_position = at
	_target.velocity = Vector3.ZERO
	(_target.get_node("HealthComponent") as HealthComponent).heal_full()
	_target.reset_physics_interpolation()


func _target_health() -> int:
	return (_target.get_node("HealthComponent") as HealthComponent).current_health


func _on_child_entered(node: Node) -> void:
	if node is ArrowProjectile:
		_shots += 1


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	_failed = _failed or not condition


func _build_stage() -> void:
	_box(Vector3(0, -0.15, 0), Vector3(30, 0.3, 30), Color("344e53"))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.2
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("14242e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.5
	add_child(world)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.position = Vector3(4, 4, 7)
	_camera.look_at(Vector3(0, 0.8, 0))
	_camera.fov = 38


func _box(at: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
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
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	add_child(body)
	return body


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/weapon_%s.png" % label)
