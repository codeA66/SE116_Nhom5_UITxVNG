extends Node3D
## Chạy với user data riêng: bài kiểm tra thực sự ghi/đọc checkpoint.

const CHECKPOINT_SCENE: PackedScene = preload("res://objects/core/checkpoint/checkpoint.tscn")
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")

var _failed: bool = false
var _player: Player
var _walk: Vector3 = Vector3.ZERO


func _ready() -> void:
	_run.call_deferred()


func _physics_process(delta: float) -> void:
	if is_instance_valid(_player):
		_player.velocity = Vector3(_walk.x, _player.velocity.y - 20.0 * delta, _walk.z)
		_player.move_and_slide()


func _run() -> void:
	var sandbox_root: String = ProjectSettings.globalize_path("res://.godot/shrine_runtime/").replace("\\", "/").to_lower()
	var user_directory: String = OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not user_directory.begins_with(sandbox_root):
		push_error("TestWindShrine: cần APPDATA/LOCALAPPDATA trỏ vào .godot/shrine_runtime để bảo vệ save cá nhân.")
		get_tree().quit(2)
		return
	GameState.replace_progress(PlayerProgress.new())
	_build_floor()
	var first: Checkpoint = _make_checkpoint(&"shrine_first", Vector3(-2, 0, 0))
	var second: Checkpoint = _make_checkpoint(&"shrine_second", Vector3(2, 0, 0))
	var first_visual: WindShrineVisual = first.get_node("WindShrineVisual") as WindShrineVisual
	var second_visual: WindShrineVisual = second.get_node("WindShrineVisual") as WindShrineVisual
	await _frames(4)
	_check(is_zero_approx(first_visual.active_level) and is_zero_approx(second_visual.active_level), "hai đền ngủ khi chưa có checkpoint")
	_check(not first_visual.is_processing() and not first.is_processing(), "không cập nhật script mỗi frame")
	var first_crystal: MeshInstance3D = first_visual.get_node("Model/Wind_Shrine/Crystal") as MeshInstance3D
	var second_crystal: MeshInstance3D = second_visual.get_node("Model/Wind_Shrine/Crystal") as MeshInstance3D
	_check(first_crystal.mesh == second_crystal.mesh and first_crystal.material_override != second_crystal.material_override, "chia sẻ mesh, trạng thái material độc lập")
	_check(not (first_visual.get_node("Aura") as MeshInstance3D).visible, "đền ngủ không hiện aura")
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector3(-4.8, 0.1, 0)
	add_child(_player)
	_player.set_physics_process(false)
	_walk = Vector3.RIGHT * 3.0
	await _frames(50)
	_walk = Vector3.ZERO
	await _frames(40)
	_check(first.is_active() and not second.is_active(), "player đi vào Trigger thực sự kích hoạt đền thứ nhất")
	_check(is_equal_approx(first_visual.active_level, 1.0) and is_zero_approx(second_visual.active_level), "chỉ đền đang lưu sáng")
	_check(SaveManager.has_save(), "checkpoint ghi được save")
	_walk = Vector3.RIGHT * 3.0
	await _frames(80)
	_walk = Vector3.ZERO
	await _frames(40)
	_check(second.is_active() and not first.is_active(), "đi đến đền thứ hai thay điểm hồi sinh")
	_check(is_equal_approx(second_visual.active_level, 1.0) and is_zero_approx(first_visual.active_level), "đền cũ tan sáng, đền mới sáng")
	var spawn: SpawnPoint = SpawnPoint.find_in(self, GameState.get_checkpoint_spawn_id())
	_check(spawn != null and spawn == second.get_node("Spawn"), "điểm hồi sinh tìm đúng theo id")
	_player.teleport(Vector3(5, 0.1, 2), Vector3.FORWARD)
	await _frames(4)
	GameState.replace_progress(PlayerProgress.new())
	_check(is_zero_approx(second_visual.active_level), "thay tiến trình cập nhật trạng thái ngủ")
	_check(SaveManager.load_game(), "đọc lại checkpoint từ save")
	_check(second.is_active() and is_equal_approx(second_visual.active_level, 1.0), "đọc save khôi phục ngay đền đang sáng")
	_player.teleport(spawn.global_position + Vector3.UP * 0.1, spawn.get_facing())
	await _frames(40)
	_check(_player.is_on_floor() and _player.global_position.distance_to(spawn.global_position) < 0.2, "player hồi sinh đứng được ở tâm bệ")
	var preview: WindShrineVisual = preload("res://objects/core/checkpoint/wind_shrine_visual.tscn").instantiate() as WindShrineVisual
	preview.style = null
	preview.position = Vector3(0, 0, 8)
	preview.scale = Vector3(0.35, 0.5, 1.4)
	add_child(preview)
	var custom: WindShrineStyle = WindShrineStyle.new()
	custom.activation_time = 0.0
	custom.aura_opacity = 0.0
	custom.float_amplitude = 0.0
	preview.style = custom
	preview.set_active(true, null, 0.0)
	_check(is_equal_approx(preview.active_level, 1.0), "scale lệch, không lơ lửng, thời gian mở bằng 0")
	preview.set_active(false, null, -12.0)
	_check(is_zero_approx(preview.active_level), "tắt tức thì và xoay ngược")
	preview.queue_free()
	_player.teleport(second.global_position + Vector3(0.85, 0.1, 0.65), Vector3.FORWARD)
	await _frames(10)
	await _capture()
	print("WIND_SHRINE ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)


func _make_checkpoint(id: StringName, location: Vector3) -> Checkpoint:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	checkpoint.checkpoint_id = id
	checkpoint.position = location
	add_child(checkpoint)
	return checkpoint


func _build_floor() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	collider.shape = shape
	body.position.y = -0.1
	body.add_child(collider)
	add_child(body)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.31, 0.3)
	material.roughness = 1.0
	plane.material = material
	mesh.mesh = plane
	add_child(mesh)


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 0.65
	light.shadow_enabled = true
	add_child(light)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b8b9b5")
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.3
	add_child(environment)
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.fov = 30.0
	var target: Vector3 = Vector3(0, 0.7, 0)
	camera.position = target + Vector3(0, 0.766044, 0.642788) * 32.0
	camera.look_at(target)
	camera.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/wind_shrine_game.png")
	camera.position = target + Vector3(0.25, 0.766044, 0.592) * 17.0
	camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/wind_shrine_detail.png")


func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	_failed = _failed or not condition
