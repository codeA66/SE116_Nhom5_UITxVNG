class_name HitGuard
extends Node
## Lớp cơ sở của bộ lọc chặn đòn gắn vào GuardedHurtboxComponent.
## Kiểu chặn mới (giáp sau lưng, khiên nguyên tố...) = thêm lớp con ghi đè try_block(), không sửa hurtbox.

## Tắt thì không chặn gì (quái hạ khiên lúc tụ lực / hồi chiêu)
@export var enabled: bool = true


## true = đòn bị chặn hoàn toàn (không trừ máu, không tính bất tử)
func try_block(_info: DamageInfo) -> bool:
	return false
