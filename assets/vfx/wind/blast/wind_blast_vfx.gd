class_name WindBlastVfx
extends Node3D
## Phần phụ của kỹ năng thổi gió: bụi tại vật bị thổi trúng (pool) và âm thanh lúc bung.
## Hình lốc xoáy chính nằm ở WindBlastCone (dưới gốc Player). Chỉ nghe signal của WindBlastArea (cha).

var _area: WindBlastArea

@onready var _impacts: WindImpactPool = $ImpactPool
@onready var _sound: AudioStreamPlayer3D = get_node_or_null(^"../Sound") as AudioStreamPlayer3D


func _ready() -> void:
	_area = get_parent() as WindBlastArea
	if _area == null:
		push_error("%s phải là con của WindBlastArea" % get_path())
		return
	_area.blast_started.connect(_on_blast_started)
	_area.pushed.connect(_on_pushed)


func _on_blast_started(_data: WindBlastData) -> void:
	if _sound and _sound.stream:
		_sound.play()


func _on_pushed(receiver: WindReceiverComponent) -> void:
	_impacts.play_at(receiver.global_position, _flat_forward())


func _flat_forward() -> Vector3:
	var forward := _area.global_basis.z
	forward.y = 0.0
	return forward.normalized() if not forward.is_zero_approx() else Vector3.BACK
