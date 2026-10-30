class_name GuardedHurtboxComponent
extends HurtboxComponent
## Hurtbox có bộ lọc chặn đòn. Đòn bị guard nào đó chặn thì không trừ máu, không đổi bất tử, không phát `hurt`;
## chỉ phát `blocked`. Là lớp con nên mọi nơi dùng HurtboxComponent (Enemy, tên, bẫy) vẫn dùng được.

signal blocked(info: DamageInfo, guard: HitGuard)

## Duyệt theo thứ tự, guard đầu tiên chặn được thì dừng
@export var guards: Array[HitGuard] = []


func receive_hit(info: DamageInfo) -> bool:
	if not is_alive():
		return false
	for guard in guards:
		if guard.try_block(info):
			blocked.emit(info, guard)
			return false
	return super(info)
