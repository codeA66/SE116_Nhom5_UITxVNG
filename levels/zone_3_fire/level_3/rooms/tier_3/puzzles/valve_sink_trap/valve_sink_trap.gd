class_name ValveSinkTrap
extends Node
## Bẫy nghe sự kiện van, không phụ thuộc tên F hay cấu trúc riêng của phòng.

const DEFAULT_DATA: ValveSinkTrapData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/valve_sink_trap/valve_sink_trap_data.tres")

@export var valve: KhamReturnValve
@export var floor_body: StaticBody3D
@export var falling_visuals: Array[Node3D] = []
@export var data: ValveSinkTrapData = DEFAULT_DATA

var triggered: bool = false
var _enabled: bool = false
var _tween: Tween


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	valve.activated.connect(_on_activated)
	set_process(false)
	set_physics_process(false)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and _tween != null:
		_tween.kill()


func _on_activated(_player: Player) -> void:
	if not _enabled or triggered:
		return
	triggered = true
	valve.set_enabled(false)
	# Đổi va chạm hoãn tới cuối lượt vật lý, không thêm nhịp chờ sập.
	floor_body.set_deferred(&"collision_layer", 0)
	_tween = create_tween().set_parallel(true)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for visual: Node3D in falling_visuals:
		_tween.tween_property(visual, ^"position:y", visual.position.y - maxf(data.fall_depth, 0.5), maxf(data.fall_time, 0.05))
