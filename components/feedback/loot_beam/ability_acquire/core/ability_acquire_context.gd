class_name AbilityAcquireContext
extends RefCounted
## Chụp trạng thái trước trình diễn để hủy ở bất kỳ pha nào cũng trả lại chính xác.
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
var data: Tuning
var actor: Node3D
var visual: Node3D
var ability: AbilityData
var initial_transform: Transform3D
var previous_paused: bool = false
var previous_controls: bool = false
var committed: bool = false
var active: bool = false
var _shake_mode: int = Node.PROCESS_MODE_INHERIT
var _shake_trauma: float = 0.0
var _camera: Camera3D
var _camera_offsets: Vector3
var _facing_from: float = 0.0
var _facing_to: float = 0.0
var _shake_nodes: Array[Node] = []
var _shake_modes: PackedInt32Array = PackedInt32Array()
## Không nâng thân vật lý: giữ nguyên chân đứng và vị trí checkpoint.
func begin(target: Node3D, ability_data: AbilityData, tree: SceneTree) -> void:
	actor = target
	ability = ability_data
	visual = target.get_node_or_null(^"Model") as Node3D
	if visual == null: visual = target
	initial_transform = visual.transform
	previous_paused = tree.paused
	previous_controls = bool(actor.get("controls_enabled")) if actor.has_method(&"set_controls_enabled") else false
	_shake_mode = ScreenShake.process_mode
	_shake_trauma = ScreenShake.trauma
	ScreenShake.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = actor.get_viewport().get_camera_3d()
	_facing_from = visual.rotation.y
	_facing_to = _facing_from
	_shake_nodes.clear()
	_shake_modes.clear()
	if _camera != null:
		var toward_camera: Vector3 = _camera.global_position-visual.global_position
		toward_camera.y = 0.0
		var visual_parent: Node3D = visual.get_parent() as Node3D
		if visual_parent != null: toward_camera = visual_parent.global_basis.inverse()*toward_camera
		if not toward_camera.is_zero_approx(): _facing_to = atan2(toward_camera.x,toward_camera.z)
		_camera_offsets = Vector3(_camera.h_offset, _camera.v_offset, _camera.rotation.z)
		for node: Node in _camera.get_children():
			if node is CameraShake:
				_shake_nodes.append(node)
				_shake_modes.append(node.process_mode)
				node.process_mode = Node.PROCESS_MODE_ALWAYS
	if actor.has_method(&"set_controls_enabled"): actor.call(&"set_controls_enabled", false)
	committed = false
	active = true
	if data.freeze_world: tree.paused = true
## Vị trí local cũ được giữ để không làm trôi gốc model sau nhiều lần phát.
func lift(amount: float) -> void:
	if is_instance_valid(visual):
		visual.position = initial_transform.origin + Vector3.UP * data.lift_height * amount
## Model dùng +Z làm phía trước; chỉ xoay phần nhìn, giữ nguyên root vật lý và trả transform khi hủy.
func face_viewer(progress: float) -> void:
	if not data.face_camera or not is_instance_valid(visual): return
	var t: float = clampf(progress,0.0,1.0)
	visual.rotation.y = lerp_angle(_facing_from,_facing_to,t*t*(3.0-2.0*t))
## Không để một lần hủy trả pause/control về giá trị mặc định sai với người gọi.
func restore(tree: SceneTree) -> void:
	if not active: return
	if is_instance_valid(visual): visual.transform = initial_transform
	if is_instance_valid(actor) and actor.has_method(&"set_controls_enabled"):
		actor.call(&"set_controls_enabled", previous_controls)
	if data.freeze_world: tree.paused = previous_paused
	ScreenShake.process_mode = _shake_mode as Node.ProcessMode
	ScreenShake.trauma = minf(ScreenShake.trauma, _shake_trauma)
	for index: int in range(_shake_nodes.size()):
		if is_instance_valid(_shake_nodes[index]): _shake_nodes[index].process_mode = _shake_modes[index] as Node.ProcessMode
	if is_instance_valid(_camera):
		_camera.h_offset = _camera_offsets.x
		_camera.v_offset = _camera_offsets.y
		_camera.rotation.z = _camera_offsets.z
	active = false
