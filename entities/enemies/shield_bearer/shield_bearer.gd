class_name ShieldBearer
extends Enemy
## Hộ Vệ Khiên: chậm, nặng, khiên chặn đòn từ phía trước, đập khiên tạo sóng kích vòng. Không bị gió thổi bay.
## Hành vi nằm ở các state trong states/ (ShieldAdvance, ShieldBlock, ShieldSlam); script này giữ khiên, sóng và VFX.

## Phát khi khiên chạm đất: chỗ cắm âm thanh, rung camera (đã nối với ScreenShake ở _ready)
signal slammed(position: Vector3)

## Độ cao nâng vòng báo phạm vi khỏi mặt đất để khỏi z-fight (m)
const PREVIEW_LIFT := 0.04
## Phần dư của plane vòng báo so với đường kính sóng (m)
const PREVIEW_PADDING := 0.4

@export_group("Feedback")
## Rung màn hình khi khiên đập đất (0..1)
@export_range(0.0, 1.0) var slam_trauma: float = 0.4

@onready var guard: DirectionalHitGuard = $HurtboxComponent/ShieldGuard
@onready var guarded_hurtbox: GuardedHurtboxComponent = hurtbox as GuardedHurtboxComponent
@onready var shockwave: GroundShockwave = $GroundShockwave
@onready var shockwave_origin: Marker3D = $Model/ShockwaveOrigin
@onready var _slam_preview: MeshInstance3D = $SlamPreview
@onready var _preview_material: ShaderMaterial = _slam_preview.material_override as ShaderMaterial
@onready var _block_sparks: GPUParticles3D = $Model/BlockSparks
@onready var _wind_deflect: GPUParticles3D = $Model/WindDeflect


func _ready() -> void:
	super()
	assert(data is ShieldBearerData, "%s cần ShieldBearerData" % name)
	assert(guarded_hurtbox != null, "%s: HurtboxComponent phải dùng GuardedHurtboxComponent" % name)
	guarded_hurtbox.blocked.connect(_on_blocked)
	slammed.connect(_on_slammed)
	if wind_receiver:
		# Gió không đẩy được (wind_multiplier = 0) nhưng vẫn báo cho người chơi biết gió có trúng
		wind_receiver.pushed.connect(_on_wind_deflected)
	_configure_slam_preview()
	_slam_preview.visible = false


func shield_data() -> ShieldBearerData:
	return data as ShieldBearerData


## Bật / tắt khả năng chặn đòn của khiên
func set_guard(on: bool) -> void:
	guard.enabled = on


func launch_shockwave() -> void:
	var origin := shockwave_origin.global_position
	shockwave.launch(origin, shield_data().shockwave, self)
	slammed.emit(origin)


func show_slam_preview(on: bool) -> void:
	if on:
		_slam_preview.global_position = shockwave_origin.global_position + Vector3.UP * PREVIEW_LIFT
		_preview_material.set_shader_parameter(&"preview_progress", 0.0)
	_slam_preview.visible = on


## progress 0..1: vòng báo đậm dần tới lúc đập
func update_slam_preview(progress: float) -> void:
	_preview_material.set_shader_parameter(&"preview_progress", progress)


func _configure_slam_preview() -> void:
	var wave := shield_data().shockwave
	if wave == null:
		return
	var size := 2.0 * wave.max_radius + PREVIEW_PADDING
	_slam_preview.scale = Vector3(size, 1.0, size)
	_preview_material.set_shader_parameter(&"plane_size", size)
	_preview_material.set_shader_parameter(&"radius", wave.max_radius)


func _on_blocked(info: DamageInfo, _guard: HitGuard) -> void:
	var push := info.knockback * shield_data().block_pushback_scale
	push.y = 0.0
	velocity += push
	# Bị đánh từ xa (tên bắn) thì quay sang đuổi người đánh, giống khi trúng đòn
	if info.source is Node3D and target == null and not is_dead():
		target = info.source as Node3D
	_block_sparks.restart()
	var current := state_machine.current_state.name
	if current == chase_state or current == ShieldBearerState.SHIELD_BLOCK:
		state_machine.transition_to(ShieldBearerState.SHIELD_BLOCK)


func _on_wind_deflected(_impulse: Vector3) -> void:
	_wind_deflect.restart()


func _on_slammed(_position: Vector3) -> void:
	ScreenShake.add_trauma(slam_trauma)
