class_name CutawayZone
extends Area3D
## Cắt tường / mái kiểu The Sims: player bước vào vùng thì ẩn các node targets (mái, tường cao phía camera)
## để nhìn vào trong; ra khỏi vùng thì hiện lại. Chỉ đổi hình, va chạm của tường vẫn giữ.
## Vùng là nhiều hộp (boxes, tọa độ thế giới). Hiệu năng: chỉ nghe body_entered/exited, không có _process.

signal opened
signal closed

## Các hộp phủ vùng (AABB theo tọa độ thế giới)
@export var boxes: Array[AABB] = []
## Node bị ẩn khi player ở trong vùng
@export var targets: Array[Node3D] = []

var is_open: bool = false

var _player: Node3D
var _inside: int = 0


func _ready() -> void:
	monitorable = false
	for box: AABB in boxes:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var b: BoxShape3D = BoxShape3D.new()
		b.size = box.size
		shape.shape = b
		add_child(shape)
		shape.global_position = box.get_center()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Đếm số hộp đang chạm: đi qua chỗ hai hộp chồng nhau không bị nháy
func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player = body
	_inside += 1
	if _inside == 1:
		_set_open(true)


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		_set_open(false)


func _set_open(open: bool) -> void:
	is_open = open
	for t: Node3D in targets:
		if is_instance_valid(t):
			t.visible = not open
	if open:
		opened.emit()
	else:
		closed.emit()
