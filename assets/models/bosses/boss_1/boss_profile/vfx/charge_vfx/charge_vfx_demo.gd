extends Node3D
## Xem thử visual và Charge VFX mà không kích hoạt AI hoặc sát thương.

@export_group("Nội dung xem thử")
@export var visual_scene: PackedScene = preload("../../boss.tscn")
@export var replay_action: StringName = &"jump"
@export_range(0.0, 10.0) var autoplay_delay: float = 0.8
@export_group("Góc nhìn")
@export var camera_position: Vector3 = Vector3(1.70, 1.37, 2.65)
@export var camera_target: Vector3 = Vector3(0.0, 0.66, 0.0)
@export_range(0.1, 10.0) var camera_size: float = 1.9

var _player: AnimationPlayer

func _ready() -> void:
	var visual: Node3D = visual_scene.instantiate() as Node3D
	add_child(visual)
	_player = visual.get_node("AnimationPlayer") as AnimationPlayer
	_player.animation_finished.connect(_on_animation_finished)
	_create_stage()
	get_tree().create_timer(autoplay_delay).timeout.connect(play_charge)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(replay_action) and not event.is_echo():
		play_charge()

func play_charge() -> void:
	_player.play(&"Charge", 0.12)
	_player.seek(0.0, true)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Charge":
		_player.play(&"Idle", 0.16)

func _create_stage() -> void:
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.position = camera_position
	camera.look_at(camera_target)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.current = true
	var light: DirectionalLight3D = DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	add_child(fill)
	fill.rotation_degrees = Vector3(-25.0, 145.0, 0.0)
	fill.light_color = Color(0.57, 0.72, 1.0)
	fill.light_energy = 0.35
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.085, 0.10)
	material.roughness = 0.9
	floor_mesh.material_override = material
	add_child(floor_mesh)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.035, 0.045, 0.06)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.63, 0.70, 0.82)
	environment.environment.ambient_light_energy = 0.50
	add_child(environment)
