class_name WispFlame
extends Node3D
## Ma trơi (câu đố phòng 09 tier 2 map Lửa): cục lửa bay vòng theo quỹ đạo elip quanh vị trí gốc, nhấp nhô.
## Chỉ mũi tên của cung đang ghép GIÓ mới dập được (trúng hurtbox, không có AttackData = đòn từ tên, người bắn là Player).
## Chém, phun lửa, tên thường: chỉ báo resisted, không tắt. Dập xong thì tắt hình / va chạm và phát extinguished.
## Hiệu năng: chỉ _process lúc còn cháy (di chuyển theo quỹ đạo); tắt rồi thì dừng hẳn.

signal extinguished(wisp: WispFlame)
## Bị trúng đòn không dập được (gợi ý người chơi đổi sang cung gió)
signal resisted

@export_group("Quỹ đạo")
## Bán trục elip theo X / Z (m)
@export var radius: Vector2 = Vector2(4.0, 2.5)
## Độ cao bay so với gốc (m) và biên độ nhấp nhô: ngang tầm tên bay (~1 m) để bắn thẳng trúng được
@export var height: float = 1.1
@export var bob_amount: float = 0.25
## Vòng / giây (âm = bay ngược chiều)
@export var speed: float = 0.12
## Góc xuất phát trên quỹ đạo (0..1 vòng)
@export_range(0.0, 1.0) var phase: float = 0.0
## Nhịp nhấp nhô (lần / giây)
@export var bob_speed: float = 0.6

var is_lit: bool = true

var _t: float = 0.0

@onready var _flame: Node3D = $Flame
@onready var _hurtbox: HurtboxComponent = $Flame/HurtboxComponent
@onready var _light: OmniLight3D = $Flame/Light


func _ready() -> void:
	_t = phase / absf(speed) if not is_zero_approx(speed) else 0.0
	_hurtbox.hurt.connect(_on_hurt)
	_place()


func _process(delta: float) -> void:
	_t += delta
	_place()


## Vị trí cục lửa hiện tại (thế giới)
func get_flame_position() -> Vector3:
	return _flame.global_position


## Dập lửa (đúng đòn, hoặc gọi thẳng)
func extinguish() -> void:
	if not is_lit:
		return
	is_lit = false
	set_process(false)
	_hurtbox.set_deferred(&"monitorable", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(_flame, ^"scale", Vector3.ONE * 0.05, 0.35)
	tween.tween_property(_light, ^"light_energy", 0.0, 0.35)
	tween.chain().tween_callback(_flame.hide)
	extinguished.emit(self)


## Đòn này có dập được không: tên (không AttackData) do Player bắn, và cung đang ghép Gió
static func is_wind_arrow(info: DamageInfo) -> bool:
	if info.attack != null or not info.source is Player:
		return false
	var element := GameState.get_fused_element(WeaponData.Slot.BOW)
	return element != null and element.id == &"wind"


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	if is_wind_arrow(info):
		extinguish()
	else:
		resisted.emit()


func _place() -> void:
	var angle := TAU * speed * _t
	_flame.position = Vector3(cos(angle) * radius.x, height + sin(_t * bob_speed * TAU) * bob_amount, sin(angle) * radius.y)
