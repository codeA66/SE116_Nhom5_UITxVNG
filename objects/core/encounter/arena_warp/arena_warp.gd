class_name ArenaWarp
extends Node3D
## Phễu gió dưới sàn phòng đánh: ẩn cho tới khi trận thắng, player bước vào thì dịch chuyển ra destination
## (thả từ trên cao xuống, đáp đất có bụi). Nạp lại map khi trận đã thắng thì hiện sẵn. Nhiều cặp trong một map:
## mỗi phễu trỏ tới điểm đến riêng bằng tham chiếu, không phát tin chung.

@export var encounter: Encounter
## Điểm player đáp xuống (hướng -Z của node = hướng player quay mặt)
@export var destination: Node3D
## Thả player cao hơn điểm đến bấy nhiêu mét để rơi "bộp" xuống
@export var drop_height: float = 4.0
@export var radius: float = 1.6:
	set(value):
		radius = value
		if is_node_ready():
			_apply_radius()

@export_group("Hình")
@export var swirl_color: Color = Color(0.6, 0.88, 1.0)
@export_range(0.0, 4.0, 0.05) var swirl_intensity: float = 1.8
## Độ sâu giả của phễu so với bán kính
@export_range(0.3, 4.0, 0.05) var depth_ratio: float = 1.5
@export_range(0.05, 2.0, 0.05) var appear_time: float = 0.6
## Phễu co lại còn bấy nhiêu khi player bước vào
@export_range(0.0, 1.0, 0.05) var enter_shrink: float = 0.35
@export_range(0.05, 2.0, 0.05) var enter_time: float = 0.3
## Hạt bị hút: số hạt đặt trong scene; gia tốc hút tỉ lệ theo bán kính
@export var suction_accel_per_m: float = 3.0

var _material: ShaderMaterial

@onready var _visual: MeshInstance3D = $Visual
@onready var _rim_glow: MeshInstance3D = $RimGlow
@onready var _suction: CPUParticles3D = $Suction
@onready var _trigger: Area3D = $Trigger
@onready var _shape: CollisionShape3D = $Trigger/CollisionShape3D
@onready var _landing: LandingPuff = $LandingPuff


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	# Mỗi phễu tween appear / flash riêng nên cần material riêng
	_material = (_visual.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_material.set_shader_parameter(&"tint", swirl_color)
	_material.set_shader_parameter(&"intensity", swirl_intensity)
	_visual.material_override = _material
	_apply_radius()
	_trigger.body_entered.connect(_on_body_entered)
	if encounter == null or destination == null:
		push_warning("%s thiếu encounter hoặc destination: phễu không hoạt động" % get_path())
		_set_active(false)
		return
	var won := not encounter.persistent_id.is_empty() and GameState.has_flag(encounter.persistent_id)
	_set_active(won)
	if not won:
		encounter.cleared.connect(_on_cleared, CONNECT_ONE_SHOT)


func is_active() -> bool:
	return _visual.visible


func _on_cleared() -> void:
	_set_active(true)
	_material.set_shader_parameter(&"appear", 0.01)
	_material.set_shader_parameter(&"flash", 1.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_material, ^"shader_parameter/appear", 1.0, appear_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material, ^"shader_parameter/flash", 0.0, appear_time)


func _set_active(active: bool) -> void:
	_visual.visible = active
	_rim_glow.visible = active
	# Ẩn thì tắt hạt và dò va chạm: không tốn xử lý
	_suction.emitting = active
	_trigger.set_deferred(&"monitoring", active)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	var player := body as Player
	# Phễu chớp sáng rồi co lại trong lúc màn tối dần, mở lại sau khi player đã đi
	_material.set_shader_parameter(&"flash", 1.0)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_material, ^"shader_parameter/flash", 0.0, enter_time)
	tween.tween_property(_material, ^"shader_parameter/appear", enter_shrink, enter_time)
	tween.chain().tween_property(_material, ^"shader_parameter/appear", 1.0, appear_time)
	var facing := -destination.global_basis.z
	facing.y = 0.0
	var target := destination.global_position
	_landing.open_sky(target, drop_height)
	await SceneManager.warp_player(player, target + Vector3.UP * drop_height, facing)
	_landing.play_on_landing(player, target)


func _apply_radius() -> void:
	(_visual.mesh as QuadMesh).size = Vector2.ONE * radius * 2.0
	# Vũng sáng loang ra ngoài miệng phễu: giả ánh sáng hắt lên sàn
	(_rim_glow.mesh as QuadMesh).size = Vector2.ONE * radius * 3.5
	_material.set_shader_parameter(&"radius", radius)
	_material.set_shader_parameter(&"depth", radius * depth_ratio)
	(_shape.shape as CylinderShape3D).radius = radius * 0.7
	_suction.emission_ring_radius = radius * 0.95
	_suction.emission_ring_inner_radius = radius * 0.8
	_suction.radial_accel_min = -suction_accel_per_m * radius
	_suction.radial_accel_max = -suction_accel_per_m * radius
