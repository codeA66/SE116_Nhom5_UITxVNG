class_name GridFlame
extends Node3D
## Một ngọn lửa vuông phủ vừa một ô sàn (thử thách cuối): fire() → ô sáng cảnh báo (Warning) warning_time giây
## → lửa bùng lên hết ô (Flame + DamageArea) burst_time giây → tắt. Đang cháy / cảnh báo thì fire() bỏ qua.
## Hiệu năng: không có _process; chuỗi pha là Timer, hình là tween ngắn.

signal erupted
signal finished

enum Phase { IDLE, WARNING, BURST }

## Cạnh ô (m): lửa và vùng sát thương nhỏ hơn chút để đứng trên vạch giữa hai ô không bị dính oan
@export var cell_size: float = 4.0
@export var margin: float = 0.25
@export var flame_height: float = 3.2
@export_range(0.01, 1.0, 0.01) var rise_time: float = 0.1

var phase: Phase = Phase.IDLE
var burst_time: float = 0.6

var _tween: Tween

@onready var _warning: MeshInstance3D = $Warning
@onready var _flame: Node3D = $Flame
@onready var _damage_shape: CollisionShape3D = $DamageArea/CollisionShape3D
@onready var _timer: Timer = $PhaseTimer


func _ready() -> void:
	var side: float = cell_size - margin * 2.0
	_warning.scale = Vector3(side, 1.0, side)
	_flame.scale = Vector3(side, 0.01, side)
	var box: BoxShape3D = (_damage_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size = Vector3(side, flame_height, side)
	_damage_shape.shape = box
	_damage_shape.position.y = flame_height * 0.5
	_damage_shape.disabled = true
	_warning.hide()
	_flame.hide()
	_timer.one_shot = true
	_timer.timeout.connect(_advance)


func is_idle() -> bool:
	return phase == Phase.IDLE


func fire(warning_time: float, burst: float) -> bool:
	if phase != Phase.IDLE:
		return false
	burst_time = burst
	phase = Phase.WARNING
	_warning.show()
	if _tween:
		_tween.kill()
	# Ô sáng dần lên tới lúc phun
	_warning.transparency = 0.85
	_tween = create_tween()
	_tween.tween_property(_warning, ^"transparency", 0.15, warning_time)
	_timer.start(warning_time)
	return true


## Dập ngay (thử thách bị huỷ): tắt cảnh báo, lửa và vùng sát thương
func cancel() -> void:
	_timer.stop()
	if _tween:
		_tween.kill()
	phase = Phase.IDLE
	_warning.hide()
	_flame.hide()
	_damage_shape.set_deferred(&"disabled", true)


func _advance() -> void:
	match phase:
		Phase.WARNING:
			phase = Phase.BURST
			_warning.hide()
			_flame.show()
			if _tween:
				_tween.kill()
			var side: float = cell_size - margin * 2.0
			_tween = create_tween()
			_tween.tween_property(_flame, ^"scale", Vector3(side, flame_height, side), rise_time)
			_damage_shape.set_deferred(&"disabled", false)
			erupted.emit()
			_timer.start(burst_time)
		Phase.BURST:
			phase = Phase.IDLE
			_damage_shape.set_deferred(&"disabled", true)
			if _tween:
				_tween.kill()
			var side: float = cell_size - margin * 2.0
			_tween = create_tween()
			_tween.tween_property(_flame, ^"scale", Vector3(side, 0.01, side), rise_time * 1.5)
			_tween.tween_callback(_flame.hide)
			finished.emit()
