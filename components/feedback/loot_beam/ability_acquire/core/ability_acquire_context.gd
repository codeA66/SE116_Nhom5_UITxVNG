class_name AbilityAcquireContext
extends RefCounted
## Chụp trạng thái trước trình diễn để hủy ở bất kỳ pha nào cũng trả lại chính xác.
const Tuning = preload("res://resources/feedback/ability_acquire/ability_acquire_data.gd")
const GLOW_SHADER: Shader = preload("res://assets/shaders/screen/ability_acquire/spatial/acquire_actor_glow.gdshader")
## Áp sát tối đa: tránh FOV quá hẹp làm méo hình
const MAX_CAMERA_PUSH := 0.9
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
var _camera_fov: float = 0.0
var _camera_size: float = 0.0
var _facing_from: float = 0.0
var _facing_to: float = 0.0
var _shake_nodes: Array[Node] = []
var _shake_modes: PackedInt32Array = PackedInt32Array()
var _skeleton: Skeleton3D
var _skeleton_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _pose_indices: PackedInt32Array = PackedInt32Array()
var _pose_initial: Array[Quaternion] = []
var _pose_target: Array[Quaternion] = []
var _hidden: Array[Node3D] = []
var _hidden_states: PackedByteArray = PackedByteArray()
var _last_pose_weight: float = -1.0
var _last_camera_push: float = -1.0
var _lift_amount: float = 0.0
## Áp sát thêm do pha tụ / bùng / hạ xuống điều khiển, cộng vào phần áp sát theo độ nâng
var _push_extra: float = 0.0
var _glow_material: ShaderMaterial
var _glow_meshes: Array[GeometryInstance3D] = []
var _glow_previous: Array[Material] = []
## Không nâng thân vật lý: giữ nguyên chân đứng và vị trí checkpoint.
func begin(target: Node3D, ability_data: AbilityData, tree: SceneTree) -> void:
	actor = target
	ability = ability_data
	visual = target.get_node_or_null(data.visual_path) as Node3D
	if visual == null: visual = target.get_node_or_null(data.fallback_visual_path) as Node3D
	if visual == null: visual = target
	initial_transform = visual.transform
	_last_camera_push = -1.0
	_lift_amount = 0.0
	_push_extra = 0.0
	_prepare_glow()
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
		_camera_fov = _camera.fov
		_camera_size = _camera.size
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
	_prepare_pose()
	_hidden.clear()
	_hidden_states.clear()
	for visual_name: String in data.hidden_visual_names:
		for node: Node in actor.find_children(visual_name,"Node3D",true,false):
			var piece: Node3D = node as Node3D
			_hidden.append(piece)
			_hidden_states.append(1 if piece.visible else 0)
			piece.hide()
	committed = false
	active = true
	if data.freeze_world: tree.paused = true
## Vị trí local cũ được giữ để không làm trôi gốc model sau nhiều lần phát.
func lift(amount: float) -> void:
	if is_instance_valid(visual):
		visual.position = initial_transform.origin + Vector3.UP * data.lift_height * amount
	_lift_amount = amount
	_apply_camera()
## Áp sát thêm (0..1) cộng vào phần theo độ nâng; pha tụ tăng dần, pha hạ xuống trả về 0
func set_focus_push(extra: float) -> void:
	_push_extra = maxf(extra, 0.0)
	_apply_camera()
## Giữ rung màn hình đúng một mức (tăng hoặc giảm): ScreenShake chỉ cộng dồn nên hạ mức thì ghi thẳng trauma.
func hold_shake(level: float) -> void:
	level = clampf(level, 0.0, ScreenShake.MAX_TRAUMA)
	if level > ScreenShake.trauma: ScreenShake.add_trauma(level - ScreenShake.trauma)
	else: ScreenShake.trauma = level
## Cáo sáng lên theo năng lượng hút vào (lớp phủ cộng sáng, không đổi vật liệu gốc)
func set_actor_glow(amount: float) -> void:
	if _glow_material == null: return
	_glow_material.set_shader_parameter(&"strength", maxf(amount, 0.0))
## Phóng theo tan(FOV/2) để độ áp sát đúng tỉ lệ phóng (0.8 = to gấp 5), camera trực giao thì đổi size
func _apply_camera() -> void:
	if not is_instance_valid(_camera): return
	var push: float = clampf(clampf(data.camera_push,0.0,0.65)*clampf(_lift_amount,0.0,1.0)+_push_extra,0.0,MAX_CAMERA_PUSH)
	if is_equal_approx(push,_last_camera_push): return
	var zoom: float = 1.0-push
	_camera.fov = rad_to_deg(2.0*atan(tan(deg_to_rad(_camera_fov)*0.5)*zoom))
	_camera.size = _camera_size*zoom
	_last_camera_push = push
## Gắn lớp phủ sáng lên mọi mesh của cáo một lần mỗi lượt; restore trả lại lớp phủ cũ
func _prepare_glow() -> void:
	_glow_meshes.clear()
	_glow_previous.clear()
	if _glow_material == null:
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = GLOW_SHADER
	_glow_material.set_shader_parameter(&"glow_color", ability.accent_color if ability != null else data.fallback_accent)
	_glow_material.set_shader_parameter(&"rim_power", data.actor_glow_rim_power)
	_glow_material.set_shader_parameter(&"strength", 0.0)
	for node: Node in visual.find_children("*","MeshInstance3D",true,false):
		var mesh: GeometryInstance3D = node as GeometryInstance3D
		_glow_meshes.append(mesh)
		_glow_previous.append(mesh.material_overlay)
		mesh.material_overlay = _glow_material
## Pose được tính trước từ hướng xương thật; vòng nóng chỉ nội suy quaternion, không chạy animation gameplay.
func ceremony_pose(amount: float, clock: float = 0.0, squash: float = 0.0) -> void:
	var weight: float = clampf(amount*data.pose_strength,0.0,1.0)
	if is_instance_valid(_skeleton) and not is_equal_approx(weight,_last_pose_weight):
		for slot: int in range(_pose_indices.size()):
			_skeleton.set_bone_pose_rotation(_pose_indices[slot],_pose_initial[slot].slerp(_pose_target[slot],weight))
		_last_pose_weight = weight
	if is_instance_valid(visual):
		visual.position.y += sin(clock*data.float_speed)*data.float_amplitude*clampf(amount,0.0,1.0)
		var compression: float = clampf(squash*data.landing_squash,0.0,0.5)
		visual.scale = initial_transform.basis.get_scale()*Vector3(1.0+compression*0.5,1.0-compression,1.0+compression*0.5)
## Model dùng +Z làm phía trước; chỉ xoay phần nhìn, giữ nguyên root vật lý và trả transform khi hủy.
func face_viewer(progress: float) -> void:
	if not data.face_camera or not is_instance_valid(visual): return
	var t: float = clampf(progress,0.0,1.0)
	visual.rotation.y = lerp_angle(_facing_from,_facing_to,t*t*(3.0-2.0*t))
## Không để một lần hủy trả pause/control về giá trị mặc định sai với người gọi.
func restore(tree: SceneTree) -> void:
	if not active: return
	if is_instance_valid(visual): visual.transform = initial_transform
	for index: int in range(_glow_meshes.size()):
		if is_instance_valid(_glow_meshes[index]): _glow_meshes[index].material_overlay = _glow_previous[index]
	_glow_meshes.clear()
	_glow_previous.clear()
	_push_extra = 0.0
	if is_instance_valid(_skeleton):
		for slot: int in range(_pose_indices.size()): _skeleton.set_bone_pose_rotation(_pose_indices[slot],_pose_initial[slot])
		_skeleton.force_update_all_bone_transforms()
		_skeleton.process_mode = _skeleton_mode
	for slot: int in range(_hidden.size()):
		if is_instance_valid(_hidden[slot]): _hidden[slot].visible = _hidden_states[slot] == 1
	if is_instance_valid(actor) and actor.has_method(&"set_controls_enabled"):
		actor.call(&"set_controls_enabled", previous_controls)
	if data.freeze_world: tree.paused = previous_paused
	ScreenShake.process_mode = _shake_mode as Node.ProcessMode
	ScreenShake.trauma = minf(ScreenShake.trauma, _shake_trauma)
	for index: int in range(_shake_nodes.size()):
		if is_instance_valid(_shake_nodes[index]): _shake_nodes[index].process_mode = _shake_modes[index] as Node.ProcessMode
	if is_instance_valid(_camera):
		_camera.fov = _camera_fov
		_camera.size = _camera_size
		_camera.h_offset = _camera_offsets.x
		_camera.v_offset = _camera_offsets.y
		_camera.rotation.z = _camera_offsets.z
	active = false
## Chuyển hướng từng đoạn tay/chân trong không gian rig; không đoán trục Euler của xương nhập từ Blender.
func _prepare_pose() -> void:
	_skeleton = null
	_pose_indices.clear()
	_pose_initial.clear()
	_pose_target.clear()
	_last_pose_weight = -1.0
	if not data.pose_enabled or data.pose_children.is_empty(): return
	for node: Node in visual.find_children("*","Skeleton3D",true,false):
		var candidate: Skeleton3D = node as Skeleton3D
		if candidate.find_bone(String(data.pose_children.keys()[0])) >= 0:
			_skeleton = candidate
			break
	if _skeleton == null: return
	_skeleton_mode = _skeleton.process_mode
	_skeleton.process_mode = Node.PROCESS_MODE_ALWAYS
	var model_to_rig: Basis = _skeleton.global_basis.inverse()*visual.global_basis
	for bone_name: StringName in data.pose_children:
		if not data.pose_directions.has(bone_name): continue
		var index: int = _skeleton.find_bone(String(bone_name))
		var child: int = _skeleton.find_bone(String(data.pose_children[bone_name]))
		if index < 0 or child < 0: continue
		_skeleton.force_update_all_bone_transforms()
		var current: Transform3D = _skeleton.get_bone_global_pose(index)
		var from: Vector3 = _skeleton.get_bone_global_pose(child).origin-current.origin
		var toward: Vector3 = model_to_rig*data.pose_directions[bone_name]
		if from.is_zero_approx() or toward.is_zero_approx(): continue
		var desired: Basis = Basis(Quaternion(from.normalized(),toward.normalized()))*current.basis
		var parent: int = _skeleton.get_bone_parent(index)
		var parent_basis: Basis = _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var target_rotation: Quaternion = (parent_basis.inverse()*desired).orthonormalized().get_rotation_quaternion()
		_pose_indices.append(index)
		_pose_initial.append(_skeleton.get_bone_pose_rotation(index))
		_pose_target.append(target_rotation)
		_skeleton.set_bone_pose_rotation(index,target_rotation)
	for slot: int in range(_pose_indices.size()): _skeleton.set_bone_pose_rotation(_pose_indices[slot],_pose_initial[slot])
	_skeleton.force_update_all_bone_transforms()
