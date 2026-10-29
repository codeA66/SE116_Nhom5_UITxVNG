class_name EncounterBarrier
extends Node3D
## Ấn phong ấn chắn cửa phòng đánh: trận bắt đầu thì dựng lên (có va chạm), sau đó đóng mãi. Ra khỏi phòng
## bằng ArenaWarp. Nạp lại map khi trận đã thắng thì dựng sẵn. Nghe signal của Encounter, không kiểm tra mỗi frame.
## Hình: dải ấn trên sàn ngưỡng cửa + vài vòng ấn đứng xếp lớp theo độ dày cửa (nhìn chéo vẫn thấy khối) + hạt trôi.
## Đặt ở cửa, gán encounter; kích thước chỉnh bằng size, không sửa Encounter.

## Cửa rộng hơn cao: xếp nhiều vòng cạnh nhau, tối đa chừng này
const MAX_RINGS_ACROSS := 6

@export var encounter: Encounter
## Rộng x cao của màn chắn (m); va chạm dày thickness
@export var size: Vector2 = Vector2(4.0, 4.0):
	set(value):
		size = value
		if is_node_ready():
			_apply_size()
@export var thickness: float = 0.6
## Rung màn hình khi ấn sập
@export_range(0.0, 1.0, 0.01) var close_trauma: float = 0.2

@export_group("Hình")
@export var seal_color: Color = Color(0.55, 0.82, 1.0)
@export_range(0.0, 4.0, 0.05) var seal_intensity: float = 1.4
## Tốc độ quay vòng ký hiệu (vòng / giây); các lớp kề nhau quay ngược chiều
@export_range(0.0, 1.0, 0.01) var ring_spin: float = 0.12
## Số lớp vòng xếp theo độ dày cửa
@export_range(1, 4) var ring_layers: int = 2
## Tỉ lệ vòng so với ô cửa
@export_range(0.3, 1.0, 0.01) var ring_fill: float = 0.92
@export_range(0.05, 2.0, 0.05) var draw_time: float = 0.25
@export_range(0.05, 2.0, 0.05) var ring_pop_time: float = 0.18
@export_range(0.05, 2.0, 0.05) var flash_time: float = 0.35

var _floor_mat: ShaderMaterial
## Hai material cho hai chiều quay, dùng chung cho mọi vòng thay vì mỗi vòng một bản
var _ring_mats: Array[ShaderMaterial] = []
var _ring_mesh: QuadMesh
## Quầng đứng + vũng sáng sàn dùng chung một material (cùng chớp lúc sập)
var _glow_mat: ShaderMaterial

@onready var _visual: Node3D = $Visual
@onready var _halo: MeshInstance3D = $Visual/Halo
@onready var _floor_glow: MeshInstance3D = $Visual/FloorGlow
@onready var _floor: MeshInstance3D = $Visual/FloorSeal
@onready var _ring_root: Node3D = $Visual/Rings
@onready var _motes: CPUParticles3D = $Visual/Motes
@onready var _shape: CollisionShape3D = $Blocker/CollisionShape3D


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_build_materials()
	_apply_size()
	if encounter == null:
		push_warning("%s chưa gán encounter: không bao giờ chắn" % get_path())
		_set_closed(false)
		return
	var won := not encounter.persistent_id.is_empty() and GameState.has_flag(encounter.persistent_id)
	_set_closed(won)
	if not won:
		encounter.started.connect(_close, CONNECT_ONE_SHOT)


func is_closed() -> bool:
	return _visual.visible


func _close() -> void:
	_set_closed(true)
	_floor_mat.set_shader_parameter(&"draw", 0.0)
	for mat in _ring_mats:
		mat.set_shader_parameter(&"draw", 0.0)
	_ring_root.scale = Vector3(1.0, 0.01, 1.0)
	# Ấn sàn vẽ nét trước, rồi vòng đứng bật lên; chớp sáng tắt dần trong lúc đó
	var tween := create_tween()
	tween.tween_property(_floor_mat, ^"shader_parameter/draw", 1.0, draw_time)
	tween.tween_property(_ring_root, ^"scale", Vector3.ONE, ring_pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for mat in _ring_mats:
		tween.parallel().tween_property(mat, ^"shader_parameter/draw", 1.0, ring_pop_time)
	create_tween().tween_method(_set_pulse, 1.0, 0.0, draw_time + ring_pop_time + flash_time)
	if close_trauma > 0.0:
		ScreenShake.add_trauma(close_trauma)


func _set_closed(closed: bool) -> void:
	_visual.visible = closed
	# Ẩn thì tắt hạt: không tốn xử lý
	_motes.emitting = closed
	# Đổi trong lúc bắn signal vật lý (body_entered) phải hoãn
	_shape.set_deferred(&"disabled", not closed)


func _set_pulse(value: float) -> void:
	_floor_mat.set_shader_parameter(&"pulse", value)
	_glow_mat.set_shader_parameter(&"boost", value)
	for mat in _ring_mats:
		mat.set_shader_parameter(&"pulse", value)


func _build_materials() -> void:
	# Mỗi màn chắn tween draw / pulse riêng nên cần material riêng (chỉ 3 bản cho cả màn)
	var base := _floor.material_override as ShaderMaterial
	_floor_mat = base.duplicate() as ShaderMaterial
	_floor_mat.set_shader_parameter(&"strip", true)
	_floor.material_override = _floor_mat
	for dir: float in [1.0, -1.0]:
		var mat := base.duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"strip", false)
		mat.set_shader_parameter(&"spin", ring_spin * dir)
		_ring_mats.append(mat)
	var all: Array[ShaderMaterial] = [_floor_mat]
	all.append_array(_ring_mats)
	for mat in all:
		mat.set_shader_parameter(&"tint", seal_color)
		mat.set_shader_parameter(&"intensity", seal_intensity)
	_ring_mesh = QuadMesh.new()
	_glow_mat = (_halo.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_glow_mat.set_shader_parameter(&"glow_color", seal_color)
	_halo.material_override = _glow_mat
	# Vũng sàn cùng màu, không billboard: cần bản riêng vì khác cờ billboard
	var floor_glow := _glow_mat.duplicate() as ShaderMaterial
	floor_glow.set_shader_parameter(&"billboard", false)
	_floor_glow.material_override = floor_glow


## Dựng lại hình theo size; chỉ chạy lúc khởi tạo / đổi size, không chạy mỗi frame
func _apply_size() -> void:
	var box := _shape.shape as BoxShape3D
	box.size = Vector3(size.x, size.y, thickness)
	_shape.position.y = size.y * 0.5

	var floor_depth := maxf(thickness * 2.0, 0.8)
	(_floor.mesh as QuadMesh).size = Vector2(size.x, floor_depth)
	_floor_mat.set_shader_parameter(&"aspect", size.x / floor_depth)

	for ring in _ring_root.get_children():
		ring.free()
	var across := clampi(roundi(size.x / maxf(size.y, 0.01)), 1, MAX_RINGS_ACROSS)
	var cell := size.x / float(across)
	var diameter := minf(cell, size.y) * ring_fill
	_ring_mesh.size = Vector2(diameter, diameter)
	for layer in ring_layers:
		var z := 0.0 if ring_layers == 1 else lerpf(-thickness * 0.5, thickness * 0.5, float(layer) / float(ring_layers - 1))
		for i in across:
			var ring := MeshInstance3D.new()
			ring.mesh = _ring_mesh
			ring.material_override = _ring_mats[(i + layer) % 2]
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ring.position = Vector3(-size.x * 0.5 + (float(i) + 0.5) * cell, size.y * 0.5, z)
			_ring_root.add_child(ring)

	# Quầng quay mặt camera nên cửa nằm dọc hướng nhìn vẫn thấy khối sáng, không chỉ một vạch
	# Vuông theo chiều cao: quầng quay theo camera, lấy theo chiều rộng thì cửa rộng thành vệt ngang lệch hướng cửa
	(_halo.mesh as QuadMesh).size = Vector2.ONE * minf(size.y, size.x + 1.0) * 1.4
	_halo.position.y = size.y * 0.5
	(_floor_glow.mesh as QuadMesh).size = Vector2(size.x + 1.5, maxf(thickness * 4.0, 2.0))
	_motes.emission_box_extents = Vector3(size.x * 0.5, 0.05, thickness * 0.5)
	_motes.position.y = 0.1
