class_name HealthComponent
extends Node
## Quản lý máu. Không phụ thuộc chủ sở hữu, ai cần phản ứng thì nghe signal.

signal health_changed(current: int, max_value: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 5

var current_health: int


func _ready() -> void:
	current_health = max_health


func is_dead() -> bool:
	return current_health <= 0


func take_damage(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if is_dead():
		died.emit()


func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


## Đổi máu tối đa (bùa thêm máu...). heal_added: ô mới thêm được đổ đầy luôn. Bớt ô thì máu hiện tại bị kẹp xuống.
## Không phát damaged/died: đổi sức chứa không phải bị đánh. Tối thiểu 1 ô để không chết vì tháo bùa
func set_max_health(value: int, heal_added: bool = false) -> void:
	var old_max := max_health
	max_health = maxi(value, 1)
	if heal_added and max_health > old_max:
		current_health += max_health - old_max
	current_health = clampi(current_health, 0, max_health)
	health_changed.emit(current_health, max_health)


## Đặt máu trực tiếp (khôi phục máu khi chuyển khu); không phát damaged/died
func set_current_health(value: int) -> void:
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)
