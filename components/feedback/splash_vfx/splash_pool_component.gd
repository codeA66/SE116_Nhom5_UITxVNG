class_name SplashPoolComponent
extends Node
## Phát hiệu ứng bắn (splash) dùng pool: vùng hazard (dung nham, vực) chỉ gọi play(vị trí).
## Scene hiệu ứng cần có hàm play(position: Vector3) và signal finished (phát khi xong, pool nhận lại).
## Pool tạo lười ở lần phát đầu: vùng chưa từng có ai chạm thì không tốn node nào.

@export var splash_scene: PackedScene
## Số hiệu ứng tạo sẵn; chạm liên tiếp nhiều hơn thì pool tạo thêm
@export var pool_size: int = 2

var _pool: ObjectPool


func play(world_position: Vector3) -> void:
	if splash_scene == null:
		return
	if _pool == null:
		_pool = ObjectPool.new()
		_pool.scene = splash_scene
		_pool.initial_size = pool_size
		# Nối finished -> release một lần cho mỗi slot (kể cả slot tạo thêm sau)
		_pool.configure_instance = _connect_release
		add_child(_pool)
	var splash: Node = _pool.acquire()
	splash.call(&"play", world_position)


func get_pool() -> ObjectPool:
	return _pool


func _connect_release(node: Node) -> void:
	node.connect(&"finished", func() -> void: _pool.release(node))
