class_name LoadingScreen
extends CanvasLayer
## Giữ tranh và hiệu ứng trên màn hình trong lúc thay scene.

const WIND: ZoneData = preload("res://resources/world/zones/elements/wind.tres")
const FIRE: ZoneData = preload("res://resources/world/zones/elements/fire.tres")
const WIND_ART: Texture2D = preload("res://assets/ui/loading/wind_pass.webp")
const FIRE_ART: Texture2D = preload("res://assets/ui/loading/fire_route.webp")
const WIND_RIDER: Texture2D = preload("res://assets/ui/loading/wind_pass_rider.png")
const FIRE_CART: Texture2D = preload("res://assets/ui/loading/fire_cart.png")
const WALK_FRAMES: int = 4
const RESOURCE_SHARE: float = 0.88

@export_group("Hành trình")
@export var wind_crossing_time: float = 6.5
@export var fire_crossing_time: float = 5.1
@export var walk_frame_time: float = 0.13
@export var wind_path_start: Vector2 = Vector2(0.24, 0.85)
@export var wind_path_end: Vector2 = Vector2(0.70, 0.493)
@export var fire_track_height: float = 0.752
@export var rider_height: Vector2 = Vector2(0.27, 0.105)
@export var cart_height: float = 0.23

@export_group("Tiến độ")
@export var progress_response: float = 5.0
@export var marker_pulse_speed: float = 3.5

@export_group("Hạt")
@export var wind_speed: Vector2 = Vector2(145.0, 220.0)
@export var ember_speed: Vector2 = Vector2(35.0, 105.0)
@export var ember_origin: Vector2 = Vector2(0.73, 0.61)

var _is_fire: bool = false
var _elapsed: float = 0.0
var _target_progress: float = 0.0
var _atlas: AtlasTexture = AtlasTexture.new()

@onready var _root: Control = $Root
@onready var _art: TextureRect = $Root/Art
@onready var _particles: CPUParticles2D = $Root/Particles
@onready var _traveler: Sprite2D = $Root/Traveler
@onready var _progress: ProgressBar = $Root/Progress
@onready var _marker: ColorRect = $Root/Progress/Marker
@onready var _wheel_material: ShaderMaterial = _traveler.material as ShaderMaterial
@onready var _mist: ColorRect = $Root/WindMist
@onready var _mist_material: ShaderMaterial = _mist.material as ShaderMaterial
@onready var _art_material: ShaderMaterial = _art.material as ShaderMaterial
@onready var _rider_material: ShaderMaterial = _mist.get_meta(&"rider_material") as ShaderMaterial


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_traveler()
	_progress.value = move_toward(_progress.value, _target_progress, progress_response * delta)
	_update_marker()


func supports_zone(path: String) -> bool:
	return path == WIND.scene_path or path == FIRE.scene_path


func present(path: String, duration: float) -> void:
	_is_fire = path == FIRE.scene_path
	_elapsed = 0.0
	_target_progress = 0.0
	_progress.value = 0.0
	_progress.modulate = Color("#ffd29a") if _is_fire else Color("#e4f4da")
	_art.texture = FIRE_ART if _is_fire else WIND_ART
	_art_material.set_shader_parameter(&"fire", _is_fire)
	_mist.visible = not _is_fire
	_traveler.modulate.a = 1.0
	_atlas.atlas = WIND_RIDER
	_traveler.texture = FIRE_CART if _is_fire else _atlas
	_traveler.material = _wheel_material if _is_fire else _rider_material
	_configure_particles(_is_fire)
	_update_traveler()
	_update_marker()
	_root.modulate.a = 0.0
	show()
	set_process(true)
	_particles.restart()
	_particles.emitting = true
	await _fade_to(1.0, duration)


func dismiss(duration: float) -> void:
	await _fade_to(0.0, duration)
	_particles.emitting = false
	set_process(false)
	hide()


func set_load_progress(fraction: float) -> void:
	_target_progress = maxf(_target_progress, clampf(fraction, 0.0, 1.0) * RESOURCE_SHARE)


func complete_load() -> void:
	_target_progress = 1.0
	_progress.value = 1.0
	_update_marker()


func _update_traveler() -> void:
	var art_size: Vector2 = _art.texture.get_size()
	var fit: float = maxf(_art.size.x / art_size.x, _art.size.y / art_size.y)
	var drawn: Vector2 = art_size * fit
	var origin: Vector2 = (_art.size - drawn) * 0.5
	if not _is_fire:
		_update_wind_traveler(drawn, origin)
		return
	var cycle: float = fposmod(_elapsed / fire_crossing_time + 0.24, 1.0)
	var x: float = lerpf(-0.18, 1.18, cycle)
	var sprite_height: float = drawn.y * cart_height
	var bounce: float = pow(absf(sin(_elapsed * 8.0)), 3.0)
	_traveler.scale = Vector2.ONE * sprite_height / _traveler.texture.get_height()
	_traveler.position = origin + drawn * Vector2(x, fire_track_height) - Vector2(0.0, sprite_height * 0.5 + bounce * drawn.y * 0.009)
	_traveler.rotation = bounce * 0.024
	_wheel_material.set_shader_parameter(&"angle", (x + 0.18) * drawn.x / (sprite_height * 0.128))


func _update_wind_traveler(drawn: Vector2, origin: Vector2) -> void:
	var cycle: float = fposmod(_elapsed / wind_crossing_time + 0.13, 1.0)
	var frame_width: float = WIND_RIDER.get_width() / float(WALK_FRAMES)
	var frame: int = int(_elapsed / walk_frame_time) % WALK_FRAMES
	var region: Rect2 = Rect2(frame_width * frame, 0.0, frame_width, WIND_RIDER.get_height())
	if _atlas.region != region:
		_atlas.region = region
		_rider_material.set_shader_parameter(&"frame_origin", float(frame) / WALK_FRAMES)
	var travel: float = 1.0 - pow(1.0 - cycle, 1.5)
	var position_uv: Vector2 = wind_path_start.lerp(wind_path_end, travel)
	var camera: float = sin(_elapsed * 0.62)
	_art_material.set_shader_parameter(&"camera_drift", camera)
	var bridge_depth: float = smoothstep(0.37, 0.92, position_uv.y)
	position_uv.x += camera * lerpf(0.006, 0.023, bridge_depth)
	var sprite_height: float = drawn.y * lerpf(rider_height.x, rider_height.y, travel)
	var bob: float = absf(sin(_elapsed * PI / (2.0 * walk_frame_time))) * sprite_height * 0.017
	_traveler.scale = Vector2.ONE * sprite_height / WIND_RIDER.get_height()
	_traveler.position = origin + drawn * position_uv - Vector2(0.0, sprite_height * 0.5 + bob)
	_traveler.rotation = 0.0
	_traveler.modulate.a = smoothstep(0.0, 0.12, cycle) * (1.0 - smoothstep(0.76, 0.99, cycle))
	_mist_material.set_shader_parameter(&"travel_phase", cycle)


func _update_marker() -> void:
	_marker.position.x = _progress.size.x * _progress.value - _marker.size.x * 0.5
	_marker.modulate.a = 1.0 if _progress.value >= 1.0 else 0.72 + 0.28 * sin(_elapsed * marker_pulse_speed)


func _configure_particles(is_fire: bool) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var speeds: Vector2 = ember_speed if is_fire else wind_speed
	_particles.initial_velocity_min = speeds.x
	_particles.initial_velocity_max = speeds.y
	_particles.position = viewport_size * ember_origin if is_fire else viewport_size * Vector2(0.77, 0.52)
	_particles.emission_rect_extents = viewport_size * (Vector2(0.13, 0.10) if is_fire else Vector2(0.58, 0.40))
	_particles.direction = Vector2.UP if is_fire else Vector2(-1.0, -0.2)
	_particles.gravity = Vector2(13.0, -8.0) if is_fire else Vector2.ZERO
	_particles.spread = 42.0 if is_fire else 9.0
	_particles.color = Color("#ffb264") if is_fire else Color("#819e8e")


func _fade_to(alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_root, ^"modulate:a", alpha, duration)
	await tween.finished
