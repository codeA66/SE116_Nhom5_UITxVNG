class_name GardenOfferingWarp
extends Node3D
## Hố quay về bàn tế trong cùng scene; không tạo lại player hay đổi inventory.

signal travelled(player: Player)

@export var challenge: Node
@export var destination: Node3D
@export_range(0.5, 3.0, 0.1) var radius: float = 1.25
@export_range(0.1, 2.0, 0.05) var appear_time: float = 0.6
@export_range(0.0, 4.0, 0.1) var drop_height: float = 1.2
@export var swirl_color: Color = Color(0.33,0.76,0.66)

var _active: bool = false
var _travelling: bool = false
var _material: ShaderMaterial

@onready var _visual: MeshInstance3D = $Visual
@onready var _rim: MeshInstance3D = $RimGlow
@onready var _suction: CPUParticles3D = $Suction
@onready var _landing: LandingPuff = $LandingPuff
@onready var _interaction: InteractableComponent = $InteractableComponent
@onready var _wooden_rim: MeshInstance3D = $WoodenRim

func _ready() -> void:
	set_process(false); set_physics_process(false)
	# Dùng lại hình phễu và LandingPuff của các tier trước, mỗi hố có material tween riêng.
	_material = _visual.material_override.duplicate() as ShaderMaterial
	_visual.material_override = _material
	_material.set_shader_parameter(&"tint",swirl_color)
	_material.set_shader_parameter(&"radius",radius)
	_material.set_shader_parameter(&"depth",radius*1.3)
	(_visual.mesh as QuadMesh).size = Vector2.ONE*radius*2.0
	(_rim.mesh as QuadMesh).size = Vector2.ONE*radius*3.5
	var halo: ShaderMaterial = _rim.material_override.duplicate() as ShaderMaterial
	halo.set_shader_parameter(&"glow_color",swirl_color); _rim.material_override = halo
	_suction.emission_ring_radius = radius*0.95; _suction.emission_ring_inner_radius = radius*0.8
	_suction.color = swirl_color
	_wooden_rim.scale = Vector3(radius,1,radius)
	var reach: CollisionShape3D = $InteractableComponent/Reach
	var volume: CylinderShape3D = reach.shape.duplicate() as CylinderShape3D
	volume.radius = radius+0.15; reach.shape = volume
	# Điểm đáp ở bàn tế vẫn phải chạy hết VFX sau khi phòng xuất phát đã ngủ.
	_landing.process_mode = Node.PROCESS_MODE_PAUSABLE
	_interaction.interacted.connect(_request_travel)
	_interaction.availability_check = _can_travel
	_set_active(false)
	if not is_instance_valid(challenge) or not is_instance_valid(destination):
		push_warning("%s thiếu thử thách hoặc điểm về bàn tế" % get_path()); return
	challenge.connect(&"cleared",_reveal)
	if bool(challenge.call(&"is_cleared")): _reveal()

func is_active() -> bool:
	return _active

func _set_active(value: bool) -> void:
	_active = value
	_visual.visible = value; _rim.visible = value; _wooden_rim.visible = value
	_suction.emitting = value; _interaction.enabled = value

func _reveal() -> void:
	if _active: return
	_set_active(true)
	_material.set_shader_parameter(&"appear",0.01)
	_material.set_shader_parameter(&"flash",0.8)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_material,^"shader_parameter/appear",1.0,appear_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material,^"shader_parameter/flash",0.0,appear_time)

func _can_travel(actor: Node3D) -> bool:
	return _active and not _travelling and actor is Player and not actor.health.is_dead() and actor.controls_enabled and not SceneManager.is_busy()

func _request_travel(actor: Node3D) -> void:
	if not _can_travel(actor): return
	_travelling = true
	var player: Player = actor as Player
	player.set_controls_enabled(false)
	_material.set_shader_parameter(&"flash",1.0)
	create_tween().tween_property(_material,^"shader_parameter/flash",0.0,appear_time)
	var target: Vector3 = destination.global_position
	var facing: Vector3 = -destination.global_basis.z; facing.y = 0
	_landing.open_sky(target,drop_height)
	await SceneManager.warp_player(player,target+Vector3.UP*drop_height,facing)
	if is_instance_valid(player):
		_landing.play_on_landing(player,target)
		player.set_controls_enabled(true)
		travelled.emit(player)
	_travelling = false
