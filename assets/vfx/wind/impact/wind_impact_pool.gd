class_name WindImpactPool
extends Node3D
## Pool bụi khi gió trúng vật: tạo sẵn khi vào scene và dùng lại.
## Pool hết chỗ thì bỏ qua hiệu ứng mới, không tạo thêm node trong lúc chơi.

@export var impact_scene: PackedScene
@export var pool_size: int = 6

var _idle: Array[WindImpactVfx] = []


func _ready() -> void:
	# Bụi đứng yên tại chỗ trúng, không đi theo nhân vật đang di chuyển/xoay
	top_level = true
	if impact_scene == null:
		push_error("%s chưa gán impact_scene" % get_path())
		return
	for index in pool_size:
		var impact := impact_scene.instantiate() as WindImpactVfx
		impact.seed_value = 101 + index * 7
		add_child(impact)
		impact.finished.connect(_on_impact_finished.bind(impact))
		_idle.append(impact)


## Trả về false nếu pool đang hết chỗ
func play_at(world_position: Vector3, direction: Vector3) -> bool:
	if _idle.is_empty():
		return false
	_idle.pop_back().play_at(world_position, direction)
	return true


func _on_impact_finished(impact: WindImpactVfx) -> void:
	_idle.append(impact)
