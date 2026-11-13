class_name LavaTide
extends Node3D
## Dung nham dâng / rút theo chu kỳ (phòng Thủy triều tier 2 map Lửa): rút (thấp, dưới sàn) → báo trước (rung, mặt
## dung nham sủi lên) → dâng (ngập sàn) → giữ → rút. Chạm dung nham khi đang dâng là chết thật (KillZone lethal):
## dung nham sâu, Giày dung nham cũng không cứu. Đứng trên bục cao hơn high_y thì an toàn.
## Hiệu năng: một Timer đổi pha, mặt dung nham + vùng chết di chuyển bằng Tween; không có _process.

signal warned
signal rising
signal risen
signal falling
signal fallen

enum Phase { LOW, WARNING, RISING, HIGH, FALLING }

@export_group("Nhịp")
## Trễ trước chu kỳ đầu (giây)
@export_range(0.0, 30.0, 0.05) var start_delay: float = 0.0
@export_range(0.1, 60.0, 0.05) var low_time: float = 6.0
@export_range(0.1, 10.0, 0.05) var warning_time: float = 1.5
@export_range(0.1, 10.0, 0.05) var rise_time: float = 1.5
@export_range(0.1, 60.0, 0.05) var high_time: float = 6.0
@export_range(0.1, 10.0, 0.05) var fall_time: float = 1.5
@export_group("Mực dung nham")
## Độ cao mặt dung nham (so với gốc node) lúc rút / lúc dâng
@export var low_y: float = -1.0
@export var high_y: float = 1.6
## Lúc báo trước mặt dung nham sủi lên bấy nhiêu (m)
@export var warning_bump: float = 0.3
## Mặt dung nham rộng x sâu (m)
@export var size: Vector2 = Vector2(28, 24)
@export_range(0.0, 1.0) var warning_trauma: float = 0.15
## Rung đủ mức khi camera nhìn trong bán kính này (m); xa dần yếu dần, ngoài shake_max_radius thì không rung
@export_range(0.0, 100.0, 0.5) var shake_full_radius: float = 8.0
@export_range(0.0, 200.0, 0.5) var shake_max_radius: float = 20.0

var phase: Phase = Phase.LOW

var _tween: Tween

@onready var _timer: Timer = $PhaseTimer
@onready var _surface: Node3D = $Surface
@onready var _surface_mesh: MeshInstance3D = $Surface/Mesh
@onready var _kill: KillZone = $Surface/KillZone


func _ready() -> void:
	var plane := (_surface_mesh.mesh as PlaneMesh).duplicate() as PlaneMesh
	plane.size = size
	_surface_mesh.mesh = plane
	# Vùng chết là lớp dày 4 m ngay dưới mặt dung nham, đi theo mặt
	_kill.size = Vector3(size.x, 4.0, size.y)
	_kill.position.y = -2.0 - 0.15
	_surface.position.y = low_y
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	_timer.start(maxf(start_delay + low_time, 0.01))


## Độ cao mặt dung nham hiện tại (so với gốc node)
func get_level() -> float:
	return _surface.position.y


func _advance() -> void:
	match phase:
		Phase.LOW:
			_enter(Phase.WARNING)
		Phase.WARNING:
			_enter(Phase.RISING)
		Phase.RISING:
			_enter(Phase.HIGH)
		Phase.HIGH:
			_enter(Phase.FALLING)
		Phase.FALLING:
			_enter(Phase.LOW)


func _enter(next: Phase) -> void:
	phase = next
	match next:
		Phase.WARNING:
			_move(low_y + warning_bump, warning_time * 0.5)
			ScreenShake.add_trauma_at(warning_trauma, global_position, shake_full_radius, shake_max_radius)
			warned.emit()
			_timer.start(warning_time)
		Phase.RISING:
			_move(high_y, rise_time)
			rising.emit()
			_timer.start(rise_time)
		Phase.HIGH:
			risen.emit()
			_timer.start(high_time)
		Phase.FALLING:
			_move(low_y, fall_time)
			falling.emit()
			_timer.start(fall_time)
		Phase.LOW:
			fallen.emit()
			_timer.start(low_time)


func _move(level: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_surface, ^"position:y", level, time)
