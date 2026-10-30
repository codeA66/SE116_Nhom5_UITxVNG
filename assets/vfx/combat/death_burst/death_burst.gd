class_name DeathBurst
extends Node3D
## Hiệu ứng quái chết (pool): lõi sáng lóe + mảnh vỡ low-poly tối viền sáng văng có trọng lực
## + vòng sóng mặt đất + đốm hồn bay lên tan dần. Vị trí truyền vào là chân quái.
## Xong thì tự nhả về pool qua signal finished của chùm hồn (sống lâu nhất).

@export_group("Layout")
## Độ cao tâm vụ nổ so với chân (m)
@export var center_height: float = 0.9

@export_group("Core")
@export var core_size: float = 1.7
@export var core_time: float = 0.34

@export_group("Ground Ring")
@export var ring_size: float = 3.6
@export var ring_time: float = 0.55

@export_group("Shards")
@export var shard_speed_min: float = 3.5
@export var shard_speed_max: float = 6.8
@export var shard_size_min: float = 0.6
@export var shard_size_max: float = 1.1
## Màu thân mảnh vỡ = màu hiệu ứng tối đi bấy nhiêu (0 = giữ nguyên, 1 = đen)
@export var shard_darken: float = 0.72

@export_group("Souls")
@export var soul_speed_min: float = 0.8
@export var soul_speed_max: float = 1.9
@export var soul_size_min: float = 0.2
@export var soul_size_max: float = 0.38

## Nâng vòng sóng khỏi mặt đất để khỏi z-fight (m)
const RING_LIFT := 0.04
## Lõi bắt đầu từ cỡ này (tỉ lệ so với core_size)
const CORE_START_SCALE := 0.35

var _core_age: float = 0.0
var _ring_age: float = 0.0
var _scale: float = 1.0

@onready var _shards: CPUParticles3D = $Shards
@onready var _souls: CPUParticles3D = $Souls
@onready var _core: MeshInstance3D = $Core
@onready var _ring: MeshInstance3D = $GroundRing
@onready var _shard_material: ShaderMaterial = _shards.material_override as ShaderMaterial
@onready var _soul_material: ShaderMaterial = _souls.material_override as ShaderMaterial
@onready var _core_material: ShaderMaterial = _core.material_override as ShaderMaterial
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial


func _ready() -> void:
	# Mảnh vỡ co lại ở cuối đời thay vì biến mất đột ngột
	_shards.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 1.0), Vector2(0.65, 0.9), Vector2(1.0, 0.0)])
	_souls.scale_amount_curve = FxUtil.make_curve([Vector2(0.0, 0.6), Vector2(0.3, 1.0), Vector2(1.0, 0.3)])
	_souls.color_ramp = FxUtil.make_alpha_gradient([[0.0, 0.0], [0.2, 1.0], [0.7, 0.8], [1.0, 0.0]])
	_souls.finished.connect(_on_finished)
	set_process(false)


func _process(delta: float) -> void:
	_core_age += delta
	_ring_age += delta
	var core_t := clampf(_core_age / core_time, 0.0, 1.0)
	var ring_t := clampf(_ring_age / ring_time, 0.0, 1.0)
	# Ease-out: bung nhanh rồi chậm dần
	var core_e := 1.0 - pow(1.0 - core_t, 3.0)
	_core.scale = Vector3.ONE * lerpf(CORE_START_SCALE, 1.0, core_e) * core_size * _scale
	_core_material.set_shader_parameter(&"progress", core_t)
	_ring_material.set_shader_parameter(&"progress", 1.0 - pow(1.0 - ring_t, 3.0))
	if core_t >= 1.0:
		_core.visible = false
	if ring_t >= 1.0:
		_ring.visible = false
	if core_t >= 1.0 and ring_t >= 1.0:
		set_process(false)


## feet_position: chân quái
func play(feet_position: Vector3, color: Color, effect_scale: float = 1.0) -> void:
	_scale = maxf(effect_scale, 0.01)
	global_position = feet_position
	var center := Vector3.UP * center_height * _scale
	_shards.position = center
	_souls.position = center
	_core.position = center
	_ring.position = Vector3.UP * RING_LIFT

	_shard_material.set_shader_parameter(&"rim_color", color)
	_shard_material.set_shader_parameter(&"base_color", color.darkened(shard_darken))
	_soul_material.set_shader_parameter(&"tint", color.lerp(Color.WHITE, 0.25))
	_core_material.set_shader_parameter(&"tint", color)
	_ring_material.set_shader_parameter(&"tint", color)
	_ring_material.set_shader_parameter(&"seed", randf() * TAU)

	_shards.initial_velocity_min = shard_speed_min * _scale
	_shards.initial_velocity_max = shard_speed_max * _scale
	_shards.scale_amount_min = shard_size_min * _scale
	_shards.scale_amount_max = shard_size_max * _scale
	_souls.initial_velocity_min = soul_speed_min * _scale
	_souls.initial_velocity_max = soul_speed_max * _scale
	_souls.scale_amount_min = soul_size_min * _scale
	_souls.scale_amount_max = soul_size_max * _scale

	_core_age = 0.0
	_ring_age = 0.0
	_core.visible = true
	_ring.visible = true
	_ring.scale = Vector3.ONE * ring_size * _scale
	_core.scale = Vector3.ONE * CORE_START_SCALE * core_size * _scale
	_core_material.set_shader_parameter(&"progress", 0.0)
	_ring_material.set_shader_parameter(&"progress", 0.0)
	_shards.restart()
	_souls.restart()
	set_process(true)


## ObjectPool gọi khi nhả về
func pool_released() -> void:
	if _shards == null:
		return
	_shards.emitting = false
	_souls.emitting = false
	set_process(false)


func _on_finished() -> void:
	var pool := get_parent() as ObjectPool
	if pool:
		pool.release(self)
