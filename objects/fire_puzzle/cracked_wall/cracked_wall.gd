class_name CrackedWall
extends StaticBody3D
## Tường đá nứt chắn lối (map Lửa): chém, bắn, phun lửa không vỡ; chỉ vỡ khi bị NỔ (Slime Dung Nham tự nổ, TNT, thùng dầu).
## Nhận nổ qua hàm on_explosion_hit(source) mà ExplosionComponent / TNT gọi trên chủ hurtbox trước khi gây đòn;
## hurtbox để invulnerable nên đòn thường bị bỏ qua. Vỡ thì nhớ vĩnh viễn (persistent_id).
## Hiệu năng: không có _process.

signal broken

## Cờ lưu đã vỡ
@export var persistent_id: StringName
## Thời gian mảnh vỡ sụp xuống (giây)
@export_range(0.05, 3.0, 0.05) var crumble_time: float = 0.5
@export_range(0.0, 1.0) var shake_trauma: float = 0.3

var is_broken: bool = false

@onready var _intact: Node3D = $Intact
@onready var _rubble: Node3D = $Rubble
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent


func _ready() -> void:
	_hurtbox.invulnerable = true
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_break(true)
		return
	_rubble.visible = false


## ExplosionComponent / TNT gọi khi tường nằm trong vùng nổ
func on_explosion_hit(_source: Node) -> void:
	if is_broken:
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	ScreenShake.add_trauma(shake_trauma)
	_break(false)
	broken.emit()


func _break(instant: bool) -> void:
	is_broken = true
	_hurtbox.set_deferred(&"monitorable", false)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", true)
	_rubble.visible = true
	if instant:
		_intact.visible = false
		return
	var tween := create_tween()
	tween.tween_property(_intact, ^"scale", Vector3(1.0, 0.05, 1.0), crumble_time).set_ease(Tween.EASE_IN)
	tween.tween_callback(_intact.hide)
