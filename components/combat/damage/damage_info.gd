class_name DamageInfo
extends RefCounted
## Một lần gây sát thương. Mọi nguồn (kiếm, bẫy, quái, kỹ năng) đều tạo gói này,
## nên Hurtbox không cần biết sát thương đến từ đâu.

## Loại sát thương. Thêm nguyên tố mới (gió, lửa...) chỉ cần thêm một giá trị ở đây
enum Type { PHYSICAL }

var amount: int
var type: Type
var knockback: Vector3
var source: Node
## Hướng đòn (ngang, đã chuẩn hóa), tách khỏi knockback: đòn không đẩy vẫn có hướng cho hiệu ứng văng
var direction: Vector3
## Đòn gây ra cú đánh (null nếu nguồn không phải AttackData: bẫy, sóng...). Hiệu ứng trúng đọc kiểu chém từ đây
var attack: AttackData
## Bỏ qua bất tử của mục tiêu (bẫy môi trường: dash hay vừa bị đánh cũng không đi xuyên được)
var ignores_invincibility: bool = false


func _init(p_amount: int = 1, p_type: Type = Type.PHYSICAL, p_knockback: Vector3 = Vector3.ZERO, p_source: Node = null) -> void:
	amount = p_amount
	type = p_type
	knockback = p_knockback
	source = p_source
	direction = Vector3(p_knockback.x, 0.0, p_knockback.z).normalized()
