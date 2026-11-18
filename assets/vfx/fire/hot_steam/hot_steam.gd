class_name HotSteam
extends Node3D
## Hướng hơi đi từ đá ngoài mép vào đúng vùng nguy hiểm, kể cả khi miệng phun xoay.

signal jet_ready

const DEFAULT_DATA: HotSteamData = preload("res://assets/vfx/fire/hot_steam/hot_steam_data.tres")

@export var data: HotSteamData = DEFAULT_DATA

var _rock_material: ShaderMaterial

@onready var _rock: Node3D = $Rock
@onready var _jet: CPUParticles3D = $Jet
@onready var _wisps: CPUParticles3D = $Wisps
@onready var _fill_timer: Timer = $FillTimer


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	_rock_material = ShaderMaterial.new()
	_rock_material.shader = preload("res://assets/vfx/fire/hot_steam/magma_rock.gdshader")
	for child: Node in _rock.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		mesh.material_override = _rock_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(false)
	set_physics_process(false)
	_fill_timer.timeout.connect(_on_jet_ready)
	set_resting()


func configure(source_offset: Vector3, hazard_size: Vector3) -> void:
	var size: Vector3 = data.rock_size.abs().max(Vector3.ONE * 0.05)
	# Kích thước gốc đo từ rock_small_001.glb, tránh làm méo bố cục khi đổi cỡ đá.
	_rock.scale = size / Vector3(1.689927, 2.301599, 1.837325)
	_rock.position = source_offset
	var direction: Vector3 = Vector3(-source_offset.x, 0.0, -source_offset.z).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var nozzle: Vector3 = source_offset + Vector3.UP * size.y * 0.82
	nozzle += direction * minf(size.x, size.z) * 0.28
	var reach: float = absf(nozzle.x * direction.x) + absf(nozzle.z * direction.z)
	reach += absf(direction.x) * hazard_size.x * 0.5 + absf(direction.z) * hazard_size.z * 0.5
	var lifetime: float = maxf(data.lifetime, 0.1)
	_setup_emitter(_jet, data.jet_particles, lifetime, nozzle, direction, maxf(reach, 0.1) / lifetime)
	_setup_emitter(_wisps, data.warning_particles, lifetime, nozzle, direction, data.warning_speed)
	_wisps.scale_amount_min *= 0.55
	_wisps.scale_amount_max *= 0.55
	set_resting()


func set_resting() -> void:
	_stop_emitters()
	_rock_material.set_shader_parameter(&"heat", data.resting_glow)


func set_warning() -> void:
	_stop_emitters()
	_rock_material.set_shader_parameter(&"heat", data.warning_glow)
	_start_emitter(_wisps)


func set_active() -> void:
	_stop_emitters()
	_rock_material.set_shader_parameter(&"heat", 1.0)
	_start_emitter(_jet)
	# Chờ hạt đi hết chiều dài vùng phun rồi mới báo cho vent bật nguy hiểm.
	_fill_timer.start(_jet.lifetime)


func _on_jet_ready() -> void:
	jet_ready.emit()


func _setup_emitter(emitter: CPUParticles3D, count: int, lifetime: float,
		nozzle: Vector3, direction: Vector3, speed: float) -> void:
	emitter.amount = clampi(count, 1, 96)
	emitter.lifetime = lifetime
	emitter.position = nozzle
	emitter.direction = (direction + Vector3.UP * data.jet_lift).normalized()
	emitter.spread = data.spread_degrees
	emitter.gravity = Vector3.UP * data.buoyancy
	emitter.initial_velocity_min = maxf(speed, 0.01) * 0.9
	emitter.initial_velocity_max = maxf(speed, 0.01) * 1.1
	emitter.scale_amount_min = maxf(data.cloud_size, 0.05) * 0.7
	emitter.scale_amount_max = maxf(data.cloud_size, 0.05) * 1.2


func _start_emitter(emitter: CPUParticles3D) -> void:
	emitter.show()
	emitter.restart()
	emitter.emitting = true


func _stop_emitters() -> void:
	_fill_timer.stop()
	_jet.emitting = false
	_wisps.emitting = false
	# Ẩn cả hạt còn sống để hết nhịp gây hại là đường nhìn thông thoáng ngay.
	_jet.hide()
	_wisps.hide()
