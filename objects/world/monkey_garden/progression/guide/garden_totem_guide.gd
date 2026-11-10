class_name GardenTotemGuide
extends Node3D
signal read_completed
signal reading_closed
const MARKER: Texture2D = preload("res://assets/ui/map_wind/tier3/guide_marker.svg")
@export_multiline var instructions: String
@export var title: String = "LỜI NHẮN TỪ VƯỜN KHỈ"
@export var initially_enabled: bool = true
@export var arrow_height: float = 5.3
@export var bob_speed: float = 8.5
@export var bob_amplitude: float = 0.2
var has_been_read: bool = false
var interaction: InteractableComponent
var _arrow: Node3D
var _popup: ItemDiscoveryPopup
var _actor: Player
var _clock: float = 0.0

func _ready() -> void:
	# Neo theo tọa độ thế giới: totem được scale lớn không kéo to cả UI và vùng F.
	top_level = true; global_transform = Transform3D(Basis.IDENTITY,(get_parent() as Node3D).global_position)
	_arrow = _make_arrow()
	add_child(_arrow); _arrow.position.y = arrow_height
	interaction = InteractableComponent.new(); interaction.name = "InteractableComponent"
	interaction.collision_layer = 32; interaction.collision_mask = 0
	interaction.prompt_text = "Đọc hướng dẫn"; interaction.prompt_offset = Vector3.UP * 2
	interaction.interaction_priority = 10
	var collision: CollisionShape3D = CollisionShape3D.new(); var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.5; collision.shape = sphere; collision.position.y = 1
	interaction.add_child(collision); add_child(interaction); interaction.interacted.connect(_open)
	_build_panel(); set_enabled(initially_enabled); set_process_input(false)

func _build_panel() -> void:
	_popup = ItemDiscoveryPopup.new()
	_popup.allow_cancel = true
	add_child(_popup)
	_popup.dismissed.connect(_finish_reading)

func set_enabled(value: bool) -> void:
	interaction.enabled = value; _arrow.visible = value and not has_been_read
	set_process(_arrow.visible)

func _process(delta: float) -> void:
	_clock += delta
	_arrow.position.y = arrow_height + sin(_clock * bob_speed) * bob_amplitude
	_arrow.scale = Vector3.ONE * (1.0 + sin(_clock * bob_speed) * 0.035)

func _open(actor: Node3D) -> void:
	if _popup.visible or not actor is Player: return
	_actor = actor as Player
	_popup.present_text.call_deferred(_actor,title,instructions)

func is_reading() -> bool:
	return _popup.visible

func close() -> void:
	_popup.close()

func _finish_reading() -> void:
	if not has_been_read:
		has_been_read = true; _arrow.hide(); set_process(false); read_completed.emit()
	reading_closed.emit()

func _make_arrow() -> Node3D:
	var result: MeshInstance3D = MeshInstance3D.new()
	var mesh: QuadMesh = QuadMesh.new(); mesh.size = Vector2(0.96,1.44)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = MARKER; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.mesh = mesh; result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result
