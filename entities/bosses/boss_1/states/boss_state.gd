class_name BossState
extends State
## Lớp cơ sở cho các state của Boss 1. Cung cấp tham chiếu an toàn tới Boss1.

var boss: Boss1


func _ready() -> void:
	boss = owner as Boss1
