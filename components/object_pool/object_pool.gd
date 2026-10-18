class_name ObjectPool
extends Node
## Pool đối tượng dùng lại (đạn, hiệu ứng trúng đòn...) thay cho instantiate() / queue_free() mỗi lần.
## Đối tượng là con của pool. Tuỳ chọn có hai hàm: pool_acquired() khi lấy ra, pool_released() khi nhả về
## (bật / tắt process, monitoring...). Không có thì pool chỉ ẩn / hiện Node3D.
## Nhả về: đối tượng tự phát signal rồi gọi release(), pool không đoán.

@export var scene: PackedScene
## Số đối tượng tạo sẵn; thiếu thì tạo thêm
@export var initial_size: int = 3

var _free: Array[Node] = []
var _active: Array[Node] = []
var _total_created: int = 0


func _ready() -> void:
	for i in initial_size:
		_free.append(_create())


## Lấy một đối tượng; hết đối tượng rảnh thì tạo thêm
func acquire() -> Node:
	var node: Node = _free.pop_back() if not _free.is_empty() else _create()
	_active.append(node)
	if node is Node3D:
		(node as Node3D).visible = true
	if node.has_method(&"pool_acquired"):
		node.call(&"pool_acquired")
	return node


func release(node: Node) -> void:
	var index := _active.find(node)
	if index == -1:
		return
	_active.remove_at(index)
	_free.append(node)
	_deactivate(node)


func release_all() -> void:
	while not _active.is_empty():
		release(_active[0])


## Bản sao danh sách đối tượng đang dùng (cấp phát: chỉ gọi khi cần, không gọi mỗi frame)
func get_active() -> Array[Node]:
	return _active.duplicate()


## Bỏ đối tượng khỏi pool và chuyển sang cha khác (đối tượng sống tiếp độc lập, tự xoá khi xong)
func detach(node: Node, new_parent: Node) -> void:
	var index := _active.find(node)
	if index == -1:
		return
	_active.remove_at(index)
	if node.has_method(&"pool_detached"):
		node.call(&"pool_detached")
	node.reparent(new_parent, true)


## Tổng số đối tượng pool đã tạo (kiểm tra không tạo thêm khi đủ)
func get_total_created() -> int:
	return _total_created


## Đối tượng lấy ra lâu nhất (để tái dùng khi đặt trần số lượng); null nếu không có
func get_oldest_active() -> Node:
	return null if _active.is_empty() else _active[0]


func get_active_count() -> int:
	return _active.size()


func _create() -> Node:
	var node := scene.instantiate()
	_total_created += 1
	add_child(node)
	_deactivate(node)
	return node


func _deactivate(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	if node.has_method(&"pool_released"):
		node.call(&"pool_released")
