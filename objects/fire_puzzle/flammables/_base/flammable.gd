class_name Flammable
extends StaticBody3D
## Vật dễ cháy của câu đố lửa (dây leo, thùng gỗ, thùng dầu, cầu treo...): nguồn lửa bất kỳ (Phun lửa, Kiếm / Cung Lửa,
## lửa lan, nổ) làm BurnableComponent bắt lửa; cháy spread_delay giây thì lan sang vật dễ cháy khác trong spread_radius;
## cháy hết thời gian của BurnData thì cháy rụi (_burn_out: mặc định tan, tắt va chạm). Lớp con đổi cách cháy rụi
## (thùng dầu nổ, cầu treo sập) bằng cách ghi đè _on_burned_out(), không sửa file này.
## Có persistent_id: cháy rụi thì nhớ vĩnh viễn (ví dụ dây leo chắn lối ra). Không có: reset() dựng lại như cũ
## (FlammableReset gọi khi player rời phòng, để đốt nhầm không bị kẹt vĩnh viễn).
## Hiệu năng: không có _process; lửa lan dò nhóm "flammables" đúng một lần mỗi lần bắt lửa.

signal caught_fire
signal burned_out

const GROUP := &"flammables"

## Cờ lưu đã cháy rụi. Trống = dựng lại được bằng reset()
@export var persistent_id: StringName
@export_group("Lửa lan")
## Bắt lửa bao lâu thì lan sang vật khác (giây)
@export_range(0.0, 10.0, 0.05) var spread_delay: float = 1.0
## Lan tới vật dễ cháy có mép cách tâm vật này trong khoảng này (m)
@export_range(0.0, 20.0, 0.1) var spread_radius: float = 3.0
## Bán kính "thân" của vật: khoảng cách lửa lan tính tới mép (vật dài như cầu treo đặt lớn hơn)
@export_range(0.0, 10.0, 0.05) var body_radius: float = 0.6
@export_group("Hình")
## Thời gian co / chìm hình khi cháy rụi (giây)
@export_range(0.05, 3.0, 0.05) var vanish_time: float = 0.6

var is_burning: bool = false
var is_burned: bool = false

var _spread_timer: SceneTreeTimer
var _tween: Tween
var _visual_scale: Vector3 = Vector3.ONE

@onready var burnable: BurnableComponent = $BurnableComponent
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(GROUP)
	_visual_scale = _visual.scale
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_set_present(false)
		is_burned = true
		return
	burnable.ignited.connect(_on_ignited)
	burnable.extinguished.connect(_on_extinguished)


## Châm lửa trực tiếp (lửa lan, nổ). Đã cháy / đã rụi thì bỏ qua
func ignite(source: Node = null) -> void:
	if is_burning or is_burned:
		return
	burnable.ignite(source)


## Dựng lại như chưa cháy (vật không có persistent_id)
func reset() -> void:
	if not persistent_id.is_empty():
		return
	if _tween:
		_tween.kill()
	# Hạ cờ trước khi dập: extinguished bắn ngay lúc dập, không được tính là cháy rụi
	var was_burning := is_burning
	is_burning = false
	is_burned = false
	if was_burning:
		burnable.extinguish()
	_spread_timer = null
	_set_present(true)
	_visual.scale = _visual_scale
	_on_reset()


## Lớp con ghi đè: cách cháy rụi. Mặc định co hình rồi ẩn, tắt va chạm
func _on_burned_out() -> void:
	_set_present(false, true)


## Lớp con ghi đè: trả thêm trạng thái riêng khi reset (vị trí rơi của cầu...)
func _on_reset() -> void:
	pass


func _on_ignited() -> void:
	is_burning = true
	caught_fire.emit()
	if spread_radius > 0.0:
		_spread_timer = get_tree().create_timer(spread_delay, false)
		var timer := _spread_timer
		timer.timeout.connect(func() -> void:
			# Bị reset giữa chừng thì hẹn lan cũ bỏ qua
			if timer == _spread_timer and is_burning:
				spread_fire(global_position, spread_radius))


func _on_extinguished() -> void:
	if not is_burning:
		return
	is_burning = false
	is_burned = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	_on_burned_out()
	burned_out.emit()


## Châm mọi vật dễ cháy khác có mép trong radius quanh center (dùng cho lửa lan và vụ nổ)
func spread_fire(center: Vector3, radius: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Flammable
		if other == null or other == self or other.is_burning or other.is_burned:
			continue
		if other.global_position.distance_to(center) - other.body_radius <= radius:
			other.ignite(self)


## Hiện / ẩn cả hình, va chạm và khả năng bắt lửa. animate: co hình trước khi ẩn
func _set_present(present: bool, animate: bool = false) -> void:
	burnable.set_enabled(present)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not present)
	if present or not animate:
		visible = present
		return
	_tween = create_tween()
	_tween.tween_property(_visual, ^"scale", Vector3(_visual_scale.x, 0.05, _visual_scale.z), vanish_time).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)
