class_name ForgeHammer
extends Node3D
## Búa máy lò rèn nện xuống theo nhịp: cảnh báo (vòng đỏ dưới chỗ nện) → búa rơi nhanh, gây sát thương + hất văng
## (player và quái) → nằm im một chút → nhấc lên → nghỉ. Đặt nhiều búa lệch pha bằng start_delay để thành hành lang canh nhịp.
## Hiệu năng: một Timer đổi pha, búa di chuyển bằng Tween; vùng sát thương chỉ bật đúng lúc nện (shape disabled ngoài lúc đó).

signal warned
signal slammed
signal raised

enum Phase { REST, WARNING, SLAM, HOLD, RISE }

@export_group("Nhịp")
## Trễ trước lượt đầu (giây): lệch pha giữa các búa
@export_range(0.0, 10.0, 0.05) var start_delay: float = 0.0
@export_range(0.1, 5.0, 0.05) var warning_time: float = 0.8
## Thời gian búa rơi từ trên xuống sàn
@export_range(0.02, 1.0, 0.01) var slam_time: float = 0.08
## Vùng sát thương bật bao lâu kể từ lúc chạm sàn
@export_range(0.02, 1.0, 0.01) var impact_time: float = 0.15
## Búa nằm im trên sàn (đã hết sát thương) trước khi nhấc lên
@export_range(0.0, 3.0, 0.05) var hold_time: float = 0.4
@export_range(0.05, 3.0, 0.05) var rise_time: float = 0.5
@export_range(0.0, 10.0, 0.05) var rest_time: float = 0.3
@export_group("Hình dạng")
## Mặt búa (rộng x cao x sâu, m)
@export var head_size: Vector3 = Vector3(1.8, 0.9, 1.8)
## Độ cao đáy búa khi nhấc lên (m, so với sàn)
@export_range(0.5, 12.0, 0.1) var raise_height: float = 3.2
@export_group("Đòn nện")
@export var damage: int = 1
@export var knockback: float = 10.0
@export_range(0.0, 1.0) var shake_trauma: float = 0.25
## Rung đủ mức khi camera nhìn trong bán kính này (m); xa dần yếu dần, ngoài shake_max_radius thì không rung
@export_range(0.0, 100.0, 0.5) var shake_full_radius: float = 8.0
@export_range(0.0, 200.0, 0.5) var shake_max_radius: float = 20.0

var phase: Phase = Phase.REST

var _tween: Tween

@onready var _timer: Timer = $PhaseTimer
@onready var _indicator: AoeCircleIndicator = $Indicator
@onready var _head: Node3D = $Head
@onready var _head_mesh: MeshInstance3D = $Head/Mesh
@onready var _damage_area: DamageArea = $DamageArea
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D


func _ready() -> void:
	_apply_shape()
	_damage_area.damage = damage
	_damage_area.knockback = knockback
	_damage_shape.disabled = true
	_head.position.y = raise_height
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	if start_delay > 0.0:
		_timer.start(start_delay)
	else:
		_enter(Phase.WARNING)


## Độ cao đáy búa hiện tại (m, so với sàn)
func get_head_height() -> float:
	return _head.position.y


func is_damaging() -> bool:
	return not _damage_shape.disabled


func _advance() -> void:
	match phase:
		Phase.REST:
			_enter(Phase.WARNING)
		Phase.WARNING:
			_enter(Phase.SLAM)
		Phase.SLAM:
			_enter(Phase.HOLD)
		Phase.HOLD:
			_enter(Phase.RISE)
		Phase.RISE:
			_enter(Phase.REST)


func _enter(next: Phase) -> void:
	phase = next
	match next:
		Phase.WARNING:
			_indicator.show_indicator(global_position, _footprint_radius(), warning_time)
			warned.emit()
			_timer.start(warning_time)
		Phase.SLAM:
			_move_head(0.0, slam_time, Tween.EASE_IN)
			_timer.start(slam_time)
		Phase.HOLD:
			_indicator.hide_indicator()
			# set_deferred: đổi shape trong callback vật lý phải hoãn tới cuối frame
			_damage_shape.set_deferred(&"disabled", false)
			ScreenShake.add_trauma_at(shake_trauma, global_position, shake_full_radius, shake_max_radius)
			slammed.emit()
			get_tree().create_timer(impact_time, false, true).timeout.connect(_end_impact)
			_timer.start(maxf(hold_time, impact_time))
		Phase.RISE:
			_move_head(raise_height, rise_time, Tween.EASE_OUT)
			_timer.start(rise_time)
		Phase.REST:
			raised.emit()
			_timer.start(maxf(rest_time, 0.01))


func _end_impact() -> void:
	_damage_shape.set_deferred(&"disabled", true)


func _move_head(height: float, time: float, ease_type: Tween.EaseType) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	_tween.tween_property(_head, ^"position:y", height, time)


func _footprint_radius() -> float:
	return Vector2(head_size.x, head_size.z).length() * 0.5


## Mặt búa + vùng sát thương theo head_size. Mesh con của Head dời lên nửa chiều cao nên Head.y là đáy búa
func _apply_shape() -> void:
	var box: BoxMesh = (_head_mesh.mesh as BoxMesh).duplicate() as BoxMesh
	box.size = head_size
	_head_mesh.mesh = box
	_head_mesh.position.y = head_size.y * 0.5
	var shape: BoxShape3D = (_damage_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	# Vùng sát thương rộng hơn mặt búa một chút và cao bằng người: ai đứng dưới búa lúc nện đều trúng
	shape.size = Vector3(head_size.x + 0.2, 1.6, head_size.z + 0.2)
	_damage_shape.shape = shape
	_damage_shape.position.y = 0.8
