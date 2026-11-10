class_name GardenOfferingRitual
extends Node3D
## Chỉ bật nguồn mở cổng sau khi mọi luồng sáng đã tới khóa.
signal activated
const RISE_VFX: PackedScene = preload("res://assets/vfx/wind/garden/offering_rise/offering_rise.tscn")
@export var pedestals: Array[OfferingPedestal] = []
@export var lock_target: MeshInstance3D
@export var boots: BananaItemPickup
@export_range(0.2, 3.0, 0.1) var rise_time: float = 0.95
@export_range(0.4, 5.0, 0.1) var flight_time: float = 1.6
@export_range(0.1, 1.0, 0.05) var morph_time: float = 0.3
@export var light_color: Color = Color(1,0.81,0.26)
var _started: bool = false
var _finished: bool = false
var _orbs: Array[MeshInstance3D] = []
var _rises: Array[GardenOfferingRise] = []

func _ready() -> void:
	set_process(false); set_physics_process(false)
	var material: StandardMaterial3D = StandardMaterial3D.new(); material.albedo_color = light_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.emission_enabled = true; material.emission = light_color*1.7
	var sphere: SphereMesh = SphereMesh.new(); sphere.radius = 0.15; sphere.height = 0.3; sphere.radial_segments = 12; sphere.rings = 6; sphere.material = material
	for pedestal: OfferingPedestal in pedestals:
		var rise: GardenOfferingRise = RISE_VFX.instantiate() as GardenOfferingRise
		pedestal.offering_anchor.add_child(rise); _rises.append(rise)
		var orb: MeshInstance3D = MeshInstance3D.new(); orb.mesh = sphere; orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(orb); orb.hide(); _orbs.append(orb)
		var trail: CPUParticles3D = CPUParticles3D.new(); trail.amount = 12; trail.lifetime = 0.32; trail.local_coords = false
		trail.mesh = sphere; trail.scale_amount_min = 0.1; trail.scale_amount_max = 0.3; trail.gravity = Vector3.ZERO; trail.emitting = false
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; orb.add_child(trail)
		pedestal.activated.connect(_placed.bind(pedestal))

func is_active() -> bool:
	return _finished

func restore_completed(items: Array[OfferingBanana]) -> void:
	if _finished: return
	_started = true; _finished = true
	for index: int in mini(items.size(),pedestals.size()):
		var pedestal: OfferingPedestal = pedestals[index]
		var item: OfferingBanana = items[index]
		item.reparent(pedestal.offering_anchor,false)
		item.position = Vector3.ZERO; item.on_offered(pedestal); item.set_available(true)
		pedestal.item = item; pedestal.interaction.enabled = false
		pedestal.status_glow.show()
	boots.reveal()

func _placed(pedestal: OfferingPedestal) -> void:
	_rises[pedestals.find(pedestal)].play(rise_time,light_color)
	for source: OfferingPedestal in pedestals:
		if not source.is_active(): return
	if _started: return
	_started = true
	get_tree().create_timer(rise_time,false).timeout.connect(_gather)

func _gather() -> void:
	var destination: Vector3 = lock_target.global_transform*lock_target.mesh.get_aabb().get_center()
	var tween: Tween = create_tween().set_parallel()
	for index: int in pedestals.size():
		var orb: MeshInstance3D = _orbs[index]
		var item: Node3D = pedestals[index].item
		var origin: Vector3 = pedestals[index].offering_anchor.global_position+Vector3.UP*0.65
		item.set_process(false); orb.global_position = origin; orb.scale = Vector3.ONE*0.01; orb.show()
		(orb.get_child(0) as CPUParticles3D).emitting = true
		tween.tween_property(item.get_node("Visual"),"scale",Vector3.ONE*0.01,morph_time)
		tween.tween_property(orb,"scale",Vector3.ONE,morph_time)
		tween.tween_callback(item.hide).set_delay(morph_time)
		tween.tween_method(_fly.bind(orb,origin,destination),0.0,1.0,flight_time).set_delay(morph_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_arrived)

func _fly(progress: float, orb: MeshInstance3D, origin: Vector3, destination: Vector3) -> void:
	orb.global_position = origin.lerp(destination,progress)+Vector3.UP*sin(progress*PI)*2
	orb.scale = Vector3.ONE*lerpf(1.0,0.45,progress)

func _arrived() -> void:
	for orb: MeshInstance3D in _orbs: (orb.get_child(0) as CPUParticles3D).emitting = false; orb.hide()
	_finished = true; boots.reveal(); activated.emit()
