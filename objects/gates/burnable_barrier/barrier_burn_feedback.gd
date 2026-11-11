class_name BarrierBurnFeedback
extends Node
## Hình ảnh khi vật cản đốt được (CageShield...) bị đốt: lửa hạt bốc lên dọc các mặt, gỗ ngả màu nóng rồi cháy xém,
## đèn hắt sáng, và khi tan thì các mặt đổ ra ngoài kèm bụi khói. Chỉ lo phần hình; logic cháy / tan do BurnableBarrier lo.
## Thêm vật cản mới dùng lại: đặt node này + vài FlameFeedback làm con của Flames, không sửa code.
## Hiệu năng: chỉ nghe signal (ignited / extinguished / burned_away), không có _process; hạt và đèn chỉ chạy lúc cháy.

@export_group("Nối dây")
@export var barrier: BurnableBarrier
@export var burnable: BurnableComponent
## Node chứa các mảnh hình của rào (mỗi mảnh là con trực tiếp, gốc ở chân mảnh)
@export var visual: Node3D
## Node cha của các FlameFeedback (mỗi mặt một cái)
@export var flames_root: Node
## Đèn hắt sáng chung cho cả rào (null = không đèn)
@export var light: OmniLight3D
@export_range(0.0, 8.0, 0.05) var light_energy: float = 2.4
@export_group("Cháy xém")
## Màu phủ lúc mới bắt lửa (cam nóng, hơi trong)
@export var heat_color: Color = Color(1.0, 0.45, 0.12, 0.3)
## Màu phủ lúc cháy gần hết (than đen)
@export var char_color: Color = Color(0.03, 0.02, 0.02, 0.8)
@export_group("Sập")
## Mỗi mảnh đổ ra ngoài bấy nhiêu độ trước khi biến mất
@export_range(0.0, 90.0, 1.0) var collapse_angle: float = 75.0

var _flames: Array[FlameFeedback] = []
var _meshes: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D
var _char_tween: Tween


func _ready() -> void:
	_flames.assign(flames_root.find_children("*", "FlameFeedback", true, false))
	for i: int in _flames.size():
		# Chỉ mặt đầu giữ đèn: nhiều đèn chồng nhau chỉ tốn mà không đẹp hơn
		_flames[i].setup(null, light if i == 0 else null, light_energy)
	_meshes.assign(visual.find_children("*", "MeshInstance3D", true, false))
	if light:
		light.visible = false
	burnable.ignited.connect(_on_ignited)
	burnable.extinguished.connect(_on_extinguished)
	barrier.burned_away.connect(_on_burned_away)


func _on_ignited() -> void:
	if light:
		light.visible = true
	for flame: FlameFeedback in _flames:
		flame.ignite()
	_ensure_overlay()
	_overlay.albedo_color = heat_color
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = _overlay
	var duration: float = burnable.data.duration if burnable.data else 2.0
	if _char_tween:
		_char_tween.kill()
	_char_tween = create_tween()
	_char_tween.tween_property(_overlay, ^"albedo_color", char_color, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_extinguished() -> void:
	if light:
		light.visible = false
	for flame: FlameFeedback in _flames:
		flame.extinguish()


## Mỗi mảnh đổ ra xa tâm, quay quanh chân mảnh; thời gian bằng vanish_time của rào để khớp lúc hình bị ẩn
func _on_burned_away() -> void:
	var angle: float = deg_to_rad(collapse_angle)
	for piece: Node in visual.get_children():
		var node: Node3D = piece as Node3D
		if node == null:
			continue
		var outward: Vector3 = Vector3(node.position.x, 0.0, node.position.z)
		if outward.length_squared() < 0.0001:
			continue
		# Quay quanh trục (lên × hướng ra ngoài) thì đỉnh mảnh nghiêng ra phía ngoài
		var axis: Vector3 = Vector3.UP.cross(outward.normalized())
		var base_basis: Basis = node.basis
		create_tween().tween_method(
				func(value: float) -> void: node.basis = Basis(axis, value) * base_basis,
				0.0, angle, barrier.vanish_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _ensure_overlay() -> void:
	if _overlay:
		return
	_overlay = StandardMaterial3D.new()
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
