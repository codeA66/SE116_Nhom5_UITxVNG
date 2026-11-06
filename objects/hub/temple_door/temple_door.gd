class_name TempleDoor
extends StaticBody3D
## Cửa Đền Trung Tâm: chặn lối cho tới khi đủ điều kiện (phá đảo cả 4 khu). Mở = ẩn cánh cửa, tắt va chạm.

signal opened

@export var conditions: Array[UnlockCondition] = []

var _open: bool = false

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _watcher: ProgressWatcher = $ProgressWatcher


func _ready() -> void:
	_watcher.changed.connect(_refresh)
	_set_open(UnlockCondition.all_met(conditions), true)


func is_open() -> bool:
	return _open


func _refresh() -> void:
	_set_open(UnlockCondition.all_met(conditions), false)


func _set_open(open: bool, initial: bool) -> void:
	var was_open := _open
	_open = open
	_shape.set_deferred(&"disabled", open)
	_mesh.visible = not open
	if open and not was_open and not initial:
		opened.emit()
