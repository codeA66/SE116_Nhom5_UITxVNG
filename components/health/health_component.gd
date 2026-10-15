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
