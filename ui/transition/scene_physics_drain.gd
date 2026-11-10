class_name ScenePhysicsDrain
extends RefCounted
## Ngừng logic và tháo bộ theo dõi trước khi SceneTree phát tree_exiting cho các body.
## Lưu trạng thái để có thể phục hồi scene nếu bước tải cảnh mới thất bại.
var _scene: WeakRef
var _mode: Node.ProcessMode
var _areas: Array[Area3D] = []
var _states: Array[Vector2i] = []

func prepare(scene: Node) -> void:
	if not is_instance_valid(scene): return
	_scene = weakref(scene); _mode = scene.process_mode
	var tree: SceneTree = scene.get_tree()
	for area: Area3D in scene.find_children("*","Area3D",true,false):
		_areas.append(area); _states.append(Vector2i(int(area.monitoring),int(area.monitorable)))
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for area: Area3D in _areas:
		if not is_instance_valid(area): continue
		area.set_deferred("monitoring",false)
		area.set_deferred("monitorable",false)
	# Chờ cả lượt flush: không gỡ scene trong khi engine còn danh sách body/area cũ.
	await tree.physics_frame
	await tree.physics_frame

func restore() -> void:
	for index: int in _areas.size():
		var area: Area3D = _areas[index]
		if not is_instance_valid(area): continue
		area.set_deferred("monitoring",bool(_states[index].x))
		area.set_deferred("monitorable",bool(_states[index].y))
	var scene: Node = _scene.get_ref() as Node if _scene else null
	if is_instance_valid(scene) and scene.is_inside_tree():
		var tree: SceneTree = scene.get_tree()
		# Cờ monitoring deferred phải trở lại trước khi logic được phép đọc overlap.
		await tree.physics_frame
		await tree.physics_frame
		if is_instance_valid(scene): scene.process_mode = _mode
	clear()

func clear() -> void:
	_scene = null; _areas.clear(); _states.clear()
