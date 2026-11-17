class_name AoeRectIndicator
extends Node3D
## Khung chữ nhật chỉ thị vùng sát thương trên mặt đất (bẫy có mặt vuông như búa nện).
## Viền cố định đúng kích thước vùng, lõi nở dần từ tâm ra trong thời gian cảnh báo để người chơi canh nhịp.
## Khác vòng tròn: các vùng vuông xếp sát nhau thì khung khít nhau, không chồng lên nhau.
## Hiệu năng: top_level, chỉ chạy _physics_process khi đang hiện.

## Độ dày viền (m)
@export var border_width: float = 0.12

var _size: Vector2 = Vector2.ONE
var _duration: float = 1.0
var _timer: float = 0.0

@onready var _fill: MeshInstance3D = $Fill
@onready var _edges: Array[MeshInstance3D] = [$EdgeN, $EdgeS, $EdgeE, $EdgeW]


func _ready() -> void:
	top_level = true
	visible = false
	set_physics_process(false)


## Hiện khung kích thước size (rộng X, sâu Z) tại target_pos, lõi đầy sau duration giây
func show_indicator(target_pos: Vector3, size: Vector2, duration: float) -> void:
	_size = Vector2(maxf(size.x, 0.01), maxf(size.y, 0.01))
	_duration = maxf(duration, 0.01)
	_timer = 0.0
	# Giữ sát mặt đất để tránh z-fighting
	global_position = target_pos + Vector3.UP * 0.02
	var w := minf(border_width, minf(_size.x, _size.y) * 0.5)
	_place_edge(_edges[0], Vector3(0, 0, -(_size.y - w) * 0.5), Vector3(_size.x, 1, w))
	_place_edge(_edges[1], Vector3(0, 0, (_size.y - w) * 0.5), Vector3(_size.x, 1, w))
	_place_edge(_edges[2], Vector3((_size.x - w) * 0.5, 0, 0), Vector3(w, 1, _size.y))
	_place_edge(_edges[3], Vector3(-(_size.x - w) * 0.5, 0, 0), Vector3(w, 1, _size.y))
	_fill.scale = Vector3(0.001, 1, 0.001)
	visible = true
	set_physics_process(true)


func hide_indicator() -> void:
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_timer += delta
	var t := clampf(_timer / _duration, 0.0, 1.0)
	_fill.scale = Vector3(maxf(_size.x * t, 0.001), 1, maxf(_size.y * t, 0.001))
	# Đầy rồi thì giữ nguyên tới khi búa nện tắt nó
	if t >= 1.0:
		set_physics_process(false)


func _place_edge(edge: MeshInstance3D, offset: Vector3, scale_xz: Vector3) -> void:
	edge.position = offset
	edge.scale = scale_xz
