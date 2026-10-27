class_name FusionEffect
extends Resource
## Một hiệu ứng buff mà nguyên tố ghép thêm vào đòn thường của vũ khí. Player gọi các hàm dưới đây
## đúng lúc; hiệu ứng nào chỉ cần một vài thời điểm thì chỉ ghi đè hàm đó.
## Thêm buff mới (Lửa cháy, Nước làm chậm...) = thêm script kế thừa + file .tres, không sửa code cũ.


## Hitbox của một nhát cận chiến vừa bật. combo_index đếm từ 0; direction là hướng ngang của nhát
func on_melee_active(_user: Player, _attack: AttackData, _combo_index: int, _combo_size: int, _direction: Vector3, _active_time: float) -> void:
	pass


## Đạn của vũ khí (mũi tên) vừa trúng thứ gì đó tại position
func on_projectile_impact(_user: Player, _position: Vector3, _direction: Vector3) -> void:
	pass
