class_name RadialMagmaHazard
extends Node3D
## Quản lý 8 nhánh đá Magma tỏa tròn 360 độ từ tâm giậm đất của Boss.

signal finished

const MagmaHazardScript = preload("res://entities/bosses/boss_1/hazards/magma_spike/magma_hazard.gd")

@export var spoke_count: int = 8
@export var magma_hazard_scene: PackedScene

var _spikes: Array[Node3D] = []
var _active_count: int = 0


func _ready() -> void:
	set_as_top_level(true)
	_build_spokes()


func _build_spokes() -> void:
	if magma_hazard_scene == null:
		return
	
	for i: int in spoke_count:
		var spike: Node3D = magma_hazard_scene.instantiate() as Node3D
		spike.name = "Spoke_%d" % i
		if spike.has_signal(&"finished"):
			spike.connect(&"finished", _on_spoke_finished)
		add_child(spike)
		_spikes.append(spike)


func launch(origin: Vector3, attack_data: AttackData) -> void:
	if _spikes.is_empty():
		_build_spokes()
	
	# Tìm cao độ sàn đấu bằng raycast
	var floor_pos: Vector3 = origin
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * 2.0,
		origin + Vector3.DOWN * 10.0,
		1 # World / terrain collision mask
	)
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		floor_pos.y = (hit["position"] as Vector3).y
	
	global_position = floor_pos
	_active_count = _spikes.size()
	
	for i: int in _spikes.size():
		var angle: float = float(i) * (TAU / float(spoke_count))
		var facing: Vector3 = Vector3(cos(angle), 0.0, sin(angle)).normalized()
		if _spikes[i].has_method(&"start"):
			_spikes[i].call(&"start", attack_data, floor_pos, facing)


func cancel() -> void:
	for spike: Node3D in _spikes:
		if spike.has_method(&"cancel"):
			spike.call(&"cancel")
	_active_count = 0
	finished.emit()


func _on_spoke_finished() -> void:
	_active_count = maxi(_active_count - 1, 0)
	if _active_count == 0:
		finished.emit()
