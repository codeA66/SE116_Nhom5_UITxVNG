class_name PowerConduit
extends Node3D
## Dòng sáng chạy dọc rãnh trên sàn từ nguồn (ổ đá, cần gạt...) tới đích (cổng...): người chơi nhìn theo vệt sáng
## mà biết thứ mình vừa bật đã mở cái gì, không cần cắt cảnh khoá điều khiển.
## Bản thân nó là nguồn kích hoạt: sáng tới cuối rãnh thì is_active() = true và phát activated
## (gán node này vào ô Sources của cổng thay cho nguồn gốc). Chỉ nghe đúng nguồn được gán.

signal activated

## Nguồn bật dòng sáng: node có signal "activated" và hàm is_active()
@export var source: Node
## Các điểm của rãnh theo toạ độ cục bộ (nằm trên sàn): điểm đầu cạnh nguồn, điểm cuối chân đích
@export var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -4)])
## Thời gian vệt sáng chạy hết rãnh (giây)
@export_range(0.1, 10.0, 0.05) var travel_time: float = 1.2
@export var width: float = 0.16
## Rãnh tối luôn hiện (gợi ý trước có đường nối); để trống thì không vẽ rãnh
@export var groove_material: Material
@export var glow_material: Material

@export_group("Camera")
## Cuối rãnh nằm ngoài màn hình thì camera liếc tới (không khoá điều khiển)
@export var peek_camera: bool = true
@export_range(0.1, 5.0, 0.1) var peek_hold: float = 1.6

var _active: bool = false
## Mỗi đoạn một trục xoay đặt ở đầu đoạn: kéo dài trục z từ 0 lên 1 là vệt sáng lan dọc đoạn
var _pivots: Array[Node3D] = []
var _lengths: Array[float] = []


func _ready() -> void:
	_build()
	if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
		push_error("%s: nguồn %s không có signal activated / hàm is_active()" % [get_path(), source])
		return
	# Đã bật từ lần chơi trước (đọc save): sáng sẵn, không chạy lại hiệu ứng
	if source.call(&"is_active"):
		for pivot in _pivots:
			pivot.scale.z = 1.0
		_active = true
		return
	source.connect(&"activated", _run, CONNECT_ONE_SHOT)


func is_active() -> bool:
	return _active


func _build() -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var basis := Basis.looking_at(b - a, Vector3.UP)
		if groove_material:
			var groove := _strip(width * 1.7, 0.012, length, groove_material)
			groove.transform = Transform3D(basis, (a + b) * 0.5)
			add_child(groove)
		var pivot := Node3D.new()
		pivot.transform = Transform3D(basis, a)
		# Không đặt đúng 0: basis suy biến
		pivot.scale.z = 0.001
		add_child(pivot)
		var glow := _strip(width, 0.02, length, glow_material)
		glow.position.z = -length * 0.5
		pivot.add_child(glow)
		_pivots.append(pivot)
		_lengths.append(length)


func _strip(w: float, h: float, length: float, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, h, length)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _run() -> void:
	if peek_camera and not points.is_empty():
		get_tree().call_group(CameraRig.GROUP, &"peek_at", to_global(points[points.size() - 1]), peek_hold + travel_time)
	var total := 0.0
	for length in _lengths:
		total += length
	var tween := create_tween()
	for i in _pivots.size():
		var t := travel_time * _lengths[i] / maxf(total, 0.01)
		tween.tween_property(_pivots[i], "scale:z", 1.0, t)
	tween.finished.connect(_arrive)


func _arrive() -> void:
	_active = true
	activated.emit()
