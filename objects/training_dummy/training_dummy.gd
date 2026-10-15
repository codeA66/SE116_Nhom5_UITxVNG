class_name TrainingDummy
extends CharacterBody3D
## Hình nộm tập đánh: nhận đòn, nháy sáng, bị đẩy lùi, hết máu thì hồi lại sau một lúc.

@export var knockback_friction: float = 25.0
@export var flash_material: Material
@export var flash_time: float = 0.1
@export var revive_delay: float = 1.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _health_label: Label3D = $HealthLabel


func _ready() -> void:
	_hurtbox.hurt.connect(_on_hurt)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_on_health_changed(_health.current_health, _health.max_health)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, knockback_friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _on_hurt(_damage: int, knockback: Vector3) -> void:
	velocity += knockback
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
