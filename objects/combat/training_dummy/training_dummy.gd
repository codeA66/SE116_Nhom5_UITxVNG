class_name TrainingDummy
extends CharacterBody3D
## Hình nộm tập đánh: nhận đòn, nháy sáng. Mặc định đứng yên (không bị chém bay, không bị gió thổi) để làm
## trạm nạp năng lượng ổn định: chém trúng là player +1 ô. Bật knockback_enabled / wind_enabled khi cần thử đòn đẩy.
## Hết máu thì hồi lại tại chỗ; rơi vào vùng chết thì biến mất rồi xuất hiện lại ở vị trí ban đầu.

## Bị đòn đánh đẩy lùi
@export var knockback_enabled: bool = false
## Bị gió (vùng gió, cú thổi) đẩy đi
@export var wind_enabled: bool = false
@export var knockback_friction: float = 25.0
@export var flash_material: Material
@export var flash_time: float = 0.1
@export var revive_delay: float = 1.0

var _spawn_position: Vector3

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _wind_receiver: WindReceiverComponent = $WindReceiverComponent
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _health_label: Label3D = $HealthLabel


func _ready() -> void:
	_spawn_position = global_position
	_hurtbox.hurt.connect(_on_hurt)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_on_health_changed(_health.current_health, _health.max_health)
	_wind_receiver.enabled = wind_enabled
	# Không bị đẩy kiểu nào thì đứng yên tại chỗ: khỏi chạy vật lý mỗi frame
	set_physics_process(knockback_enabled or wind_enabled)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, knockback_friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_wind_receiver.move_with_wind(self, delta)


## Gọi từ KillZone
func on_kill_zone_entered() -> void:
	_set_present(false)
	await get_tree().create_timer(revive_delay).timeout
	global_position = _spawn_position
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_health.heal_full()
	_set_present(true)


## Gọi từ vùng chết người (gai...): chết ngay rồi hồi lại như khi hết máu
func on_lethal_zone_entered(red_flash: bool = false) -> void:
	if _health.is_dead():
		return
	if red_flash:
		_flash()
	_health.take_damage(_health.current_health)


func _set_present(present: bool) -> void:
	visible = present
	set_physics_process(present and (knockback_enabled or wind_enabled))
	_hurtbox.set_deferred(&"monitorable", present)


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	if knockback_enabled:
		velocity += info.knockback
	_flash()


func _flash() -> void:
	_mesh.material_overlay = flash_material
	await get_tree().create_timer(flash_time).timeout
	_mesh.material_overlay = null


func _on_health_changed(current: int, max_value: int) -> void:
	_health_label.text = "%d / %d" % [current, max_value]


func _on_died() -> void:
	await get_tree().create_timer(revive_delay).timeout
	_health.heal_full()
