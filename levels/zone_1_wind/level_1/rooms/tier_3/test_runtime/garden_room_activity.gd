class_name GardenRoomActivity
extends Area3D
## Camera tự cull hình học; vùng này chỉ ngủ logic, tránh cắt mất phòng còn trong khung hình.
@export var room: Node3D
@export_range(0.0, 80.0, 1.0) var extra_wake_margin: float = 20.0
var _nearby: bool = false
var _overview: bool = false

func _ready() -> void:
	add_to_group(&"tier3_room_activity")
	var collision: CollisionShape3D = $Trigger
	var volume: BoxShape3D = collision.shape.duplicate() as BoxShape3D
	volume.size += Vector3(extra_wake_margin*2,0,extra_wake_margin*2)
	collision.shape = volume
	for body: Node in room.find_children("*","StaticBody3D",true,false):
		(body as StaticBody3D).disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	body_entered.connect(_entered); body_exited.connect(_exited)
	_refresh.call_deferred()
	set_process(false); set_physics_process(false)

func set_overview(value: bool) -> void:
	_overview = value; _refresh()

func _entered(body: Node3D) -> void:
	if body is Player: _nearby = true; _refresh()

func _exited(body: Node3D) -> void:
	if body is Player: _nearby = false; _refresh()

func _refresh() -> void:
	room.show()
	room.process_mode = Node.PROCESS_MODE_INHERIT if _nearby or _overview else Node.PROCESS_MODE_DISABLED
