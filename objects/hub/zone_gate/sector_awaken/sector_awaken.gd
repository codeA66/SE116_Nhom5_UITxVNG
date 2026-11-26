class_name SectorAwaken
extends Node
## Khu nguyên tố ở Đền Tứ Linh: ngủ khi cổng khu còn khóa (cung điện phủ lớp tối, mạch năng lượng tắt, màn chắn cổng hiện),
## thức khi cổng mở. Lần đầu thấy khu mở thì chiếu lễ thức (awaken_started cho camera quay sang, lớp tối tan dần)
## rồi lưu cờ đã xem. Đọc trạng thái từ ZoneGate được gán (mỗi khu một cặp, không phát chung) nên thêm khu = thêm node.
## Hiệu năng: chỉ nghe signal opened của cổng và combat_ready của khu; lớp tối dùng chung một material mỗi khu.

## Bắt đầu lễ thức (camera cắt cảnh nối vào đây)
signal awaken_started
## Khu đã thức xong (cả khi thức sẵn lúc vào hub)
signal awakened

@export var gate: ZoneGate
## Các gốc chứa mesh bị phủ lớp tối khi ngủ (cung điện, ngọc nguyên tố trên quả cầu)
@export var dormant_roots: Array[Node3D] = []
## Chỉ hiện khi khu đã thức (mạch năng lượng chạy về tâm)
@export var awake_only: Array[Node3D] = []
## Màn chắn tối trong cổng, chỉ hiện khi khu ngủ
@export var veil: Node3D
## Lớp phủ lúc ngủ (nên trong suốt, không sáng). Mỗi khu dùng một bản sao để tan dần độc lập
@export var dormant_overlay: StandardMaterial3D
## Chiếu lễ thức khi thấy khu mở lần đầu. Tắt cho khu mở sẵn từ đầu game
@export var celebrate: bool = true
## Cờ lưu đã xem lễ thức = prefix + id khu
@export var seen_flag_prefix: String = "hub.awaken."
@export_group("Nhịp lễ thức")
## Chờ camera quay tới cung điện rồi mới tan lớp tối (s)
@export_range(0.0, 10.0, 0.05) var awaken_delay: float = 2.0
## Thời gian lớp tối tan hết (s)
@export_range(0.0, 10.0, 0.05) var awaken_time: float = 2.5

var _awake: bool = false
var _overlay: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _base_alpha: float = 1.0


func _ready() -> void:
	if gate == null:
		push_error("%s: chưa gán ZoneGate" % get_path())
		return
	_collect_meshes()
	if dormant_overlay:
		_overlay = dormant_overlay.duplicate() as StandardMaterial3D
		_base_alpha = _overlay.albedo_color.a
	# Cổng là anh em đứng trước trong cây nên thường đã sẵn sàng; chờ cho chắc khi thứ tự node đổi
	if not gate.is_node_ready():
		await gate.ready
	gate.opened.connect(_on_gate_opened)
	if not gate.is_open():
		_set_dormant(true)
	elif not celebrate or _seen():
		_finish_awake()
	else:
		# Khu đã mở từ trước nhưng chưa xem lễ thức: chiếu khi khu sẵn sàng (player đã đứng, màn đã sáng)
		_set_dormant(true)
		var zone := owner as ZoneRoot
		if zone and not zone.is_combat_ready():
			await zone.combat_ready
		_begin_awaken()


func is_awake() -> bool:
	return _awake


func _on_gate_opened() -> void:
	if _awake:
		return
	if celebrate and not _seen():
		_begin_awaken()
	else:
		_finish_awake()


func _begin_awaken() -> void:
	awaken_started.emit()
	if awaken_delay > 0.0:
		await get_tree().create_timer(awaken_delay, false).timeout
	if not is_inside_tree():
		return
	for node: Node3D in awake_only:
		if node:
			node.visible = true
	if veil:
		veil.visible = false
	if _overlay and awaken_time > 0.0:
		var tween := create_tween()
		tween.tween_property(_overlay, "albedo_color:a", 0.0, awaken_time)
		await tween.finished
	_finish_awake()


func _finish_awake() -> void:
	_set_dormant(false)
	if celebrate and gate.zone:
		GameState.set_flag(StringName(seen_flag_prefix + String(gate.zone.id)))
	awakened.emit()


func _set_dormant(dormant: bool) -> void:
	_awake = not dormant
	for node: Node3D in awake_only:
		if node:
			node.visible = not dormant
	if veil:
		veil.visible = dormant
	if _overlay:
		_overlay.albedo_color.a = _base_alpha
	var overlay: Material = _overlay if dormant else null
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = overlay


func _seen() -> bool:
	return gate.zone != null and GameState.has_flag(StringName(seen_flag_prefix + String(gate.zone.id)))


## Gom mesh một lần lúc vào cây (không tìm lại mỗi lần đổi trạng thái); bỏ màn chắn vì nó tự bật / tắt
func _collect_meshes() -> void:
	for root: Node3D in dormant_roots:
		if root == null:
			continue
		if root is MeshInstance3D and root != veil:
			_meshes.append(root as MeshInstance3D)
		for child: Node in root.find_children("*", "MeshInstance3D", true, false):
			if child != veil:
				_meshes.append(child as MeshInstance3D)
