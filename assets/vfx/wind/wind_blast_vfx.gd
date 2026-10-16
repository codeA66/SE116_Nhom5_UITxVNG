class_name WindBlastVfx
extends Node3D
## Hình ảnh của kỹ năng thổi gió. Chỉ nghe signal của WindBlastArea (cha), không chứa logic đẩy:
## gồng khi charge_started, bung khi blast_started, bụi tại vật khi pushed.
## Cú bung đặt top_level nên đứng yên tại chỗ thổi, không trôi theo nhân vật.

## Khoảng dò mặt đất dưới chân khi thổi; không có đất (đang trên không) thì bỏ vòng sóng
@export var ground_check_distance: float = 1.2
@export_flags_3d_physics var ground_mask: int = 1

var _area: WindBlastArea
var _ground_query: PhysicsRayQueryParameters3D

@onready var _burst: WindBurstVfx = $Burst
@onready var _impacts: WindImpactPool = $ImpactPool
@onready var _sound: AudioStreamPlayer3D = get_node_or_null(^"../Sound") as AudioStreamPlayer3D


func _ready() -> void:
	_area = get_parent() as WindBlastArea
	if _area == null:
		push_error("%s phải là con của WindBlastArea" % get_path())
		return
	_burst.top_level = true
	_ground_query = PhysicsRayQueryParameters3D.new()
	_ground_query.collision_mask = ground_mask
	_area.charge_started.connect(_on_charge_started)
	_area.blast_started.connect(_on_blast_started)
	_area.blast_stopped.connect(_on_blast_stopped)
	_area.pushed.connect(_on_pushed)


func _on_charge_started(data: WindBlastData) -> void:
	_snap_to_area()
	_burst.start_charge(data.active_start)


func _on_blast_started(data: WindBlastData) -> void:
	_snap_to_area()
	_burst.set_reach(data.reach)
	_burst.play(_has_ground_below())
	if _sound and _sound.stream:
		_sound.play()


## Phát cả lúc hết khoảng thổi và lúc rời state (2 lần): chỉ dừng phần gồng nếu bị ngắt trước khi bung
func _on_blast_stopped() -> void:
	if _burst.charging:
		_burst.stop_charge()


func _on_pushed(receiver: WindReceiverComponent) -> void:
	_impacts.play_at(receiver.global_position, _flat_forward())


func _snap_to_area() -> void:
	var forward := _flat_forward()
	var origin := _area.global_position
	_burst.global_transform = Transform3D(Basis.looking_at(-forward, Vector3.UP), origin)


func _flat_forward() -> Vector3:
	var forward := _area.global_basis.z
	forward.y = 0.0
	return forward.normalized() if not forward.is_zero_approx() else Vector3.BACK


func _has_ground_below() -> bool:
	var origin := _area.global_position + Vector3.UP * 0.2
	_ground_query.from = origin
	_ground_query.to = origin + Vector3.DOWN * ground_check_distance
	return not get_world_3d().direct_space_state.intersect_ray(_ground_query).is_empty()
