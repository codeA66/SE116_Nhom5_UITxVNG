class_name DamageArea
extends Area3D
## Vùng gây sát thương liên tục (bẫy gai, sau này lửa, độc...).
## Mỗi mục tiêu chỉ bị trúng lại sau hit_interval: quái không có bất tử nên nếu không giới hạn sẽ trúng mỗi frame.
## Phe bị ảnh hưởng do collision_mask quyết định (layer hurtbox của player / enemy).
## Hiệu năng: theo dõi mục tiêu bằng signal vào/ra, chỉ chạy _physics_process khi có mục tiêu bên trong.

@export var damage: int = 1
@export var damage_type: DamageInfo.Type = DamageInfo.Type.PHYSICAL
@export var knockback: float = 6.0
@export var hit_interval: float = 0.5

## Mục tiêu đang ở trong vùng -> thời gian còn lại trước khi được trúng tiếp (<= 0 = trúng được ngay)
var _targets: Dictionary[HurtboxComponent, float] = {}


func _ready() -> void:
	monitorable = false
	monitoring = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	for hurtbox: HurtboxComponent in _targets.keys():
		if not is_instance_valid(hurtbox):
			_targets.erase(hurtbox)
			continue
		_targets[hurtbox] -= delta
		if _targets[hurtbox] <= 0.0:
			_targets[hurtbox] = hit_interval
			_hit(hurtbox)
	set_physics_process(not _targets.is_empty())


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	_targets[hurtbox] = 0.0
	set_physics_process(true)


func _on_area_exited(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox:
		_targets.erase(hurtbox)


func _hit(hurtbox: HurtboxComponent) -> void:
	var direction := hurtbox.global_position - global_position
	direction.y = 0.0
	hurtbox.receive_hit(DamageInfo.new(damage, damage_type, direction.normalized() * knockback, self))
