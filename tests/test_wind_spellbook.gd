extends Node3D
## Kiểm tra bằng input thật của game, chỉ ghi save vào sandbox riêng.

const BOOK_SCENE: PackedScene = preload("res://objects/pickups/ability_pickup.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const WIND_DATA: WindBlastData = preload("res://abilities/wind_blast/wind_blast.tres")
const PICKUP_ID: StringName = &"test_wind_spellbook.pickup"

var _failed: bool = false
var _blasts: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var sandbox: String = ProjectSettings.globalize_path("res://.godot/spellbook_runtime/").replace("\\", "/").to_lower()
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(sandbox):
		push_error("TestWindSpellbook: đặt APPDATA/LOCALAPPDATA trong .godot/spellbook_runtime để bảo vệ save cá nhân.")
		get_tree().quit(2)
		return
	GameState.replace_progress(PlayerProgress.new())
	_build_floor()
	var book: AbilityPickup = _make_book()
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(0.85, 0.1, 1.1)
	add_child(player)
	await _frames(50)
	_check(not player.has_ability(WindBlastData.ID), "chưa có kỹ năng trước khi nhặt")
	var visual: WindSpellbookVisual = book.get_node("Visual") as WindSpellbookVisual
	var start_angle: float = visual.rotation.y
	await _frames(30)
	_check(absf(visual.rotation.y - start_angle) > 0.1, "sách xoay tại chỗ")
	_check(not visual.is_processing(), "VFX không có vòng lặp script mỗi frame")
	_check((visual.get_node("Motes") as CPUParticles3D).amount <= 16, "số hạt được giới hạn")
	_check(player.interactor.current == book.get_node("InteractableComponent"), "player nhận đúng mục tiêu nhặt qua Area3D")
	await _capture(book, player)
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	await _frames(4)
	_check(player.has_ability(WindBlastData.ID), "input interact mở khóa kỹ năng gió")
	_check(GameState.has_flag(PICKUP_ID), "lưu cờ đã nhặt")
	_check(not is_instance_valid(book), "sách và toàn bộ gió được xóa khi nhặt")
	_check(SaveManager.has_save(), "tiến trình được ghi xuống save")
	player.wind_blast.blast_started.connect(_on_blast_started)
	Input.action_press(&"skill")
	await _frames(2)
	Input.action_release(&"skill")
	await _frames(40)
	_check(_blasts == 1, "sử dụng được kỹ năng vừa nhặt")
	GameState.replace_progress(PlayerProgress.new())
	_check(SaveManager.load_game() and player.has_ability(WindBlastData.ID), "đọc save khôi phục kỹ năng")
	var saved_book: AbilityPickup = _make_book()
	await _frames(4)
	_check(not is_instance_valid(saved_book), "tải lại không sinh sách đã nhặt")
	print("WIND_SPELLBOOK ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


func _make_book() -> AbilityPickup:
	var book: AbilityPickup = BOOK_SCENE.instantiate() as AbilityPickup
	book.ability = WIND_DATA
	book.persistent_id = PICKUP_ID
	add_child(book)
	return book


func _on_blast_started(_data: WindBlastData) -> void:
	_blasts += 1


func _build_floor() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(12, 0.2, 12)
	collision.shape = shape
	floor_body.position.y = -0.1
	floor_body.add_child(collision)
	add_child(floor_body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12, 12)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.31, 0.32)
	material.roughness = 1.0
	plane.material = material
	mesh_instance.mesh = plane
	add_child(mesh_instance)


func _capture(book: AbilityPickup, player: Player) -> void:
	if DisplayServer.get_name() == "headless":
		return
	book.spin_speed = 0.0
	(book.get_node("Visual") as Node3D).rotation.y = 0.25
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 0.65
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.5, 0.52, 0.54)
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.3
	add_child(environment)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.fov = 30.0
	var target: Vector3 = Vector3(0, 1.05, 0)
	camera.position = target + Vector3(0, 0.766044, 0.642788) * 32.0
	camera.look_at(target)
	camera.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/wind_spellbook_game.png")
	player.model.hide()
	camera.position = target + Vector3(0.35, 0.6, 1).normalized() * 4.0
	camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/wind_spellbook_detail.png")
	player.model.show()
	camera.queue_free()


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	_failed = _failed or not condition
