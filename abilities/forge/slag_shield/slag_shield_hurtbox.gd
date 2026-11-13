class_name SlagShieldHurtbox
extends GuardedHurtboxComponent
## Hurtbox thay thế của player trong lúc giữ Khiên xỉ (hurtbox gốc tạm tắt monitorable nên đòn đánh trúng cái này).
## Đòn trong cung khiên bị chặn (guard); đòn còn lại chuyển nguyên cho hurtbox gốc, nên máu, i-frames, Hurt state
## của player vẫn chạy như thường. Đạn dội được hỏi reflect_projectile() trước khi gây đòn.

## Hurtbox gốc của player nhận đòn không bị chặn
var forward_to: HurtboxComponent
## Người dội đạn (đạn dội lại tính là của người này)
var reflect_source: Node3D
var reflects_projectiles: bool = true


func receive_hit(info: DamageInfo) -> bool:
	if forward_to == null or not forward_to.is_alive():
		return false
	for guard in guards:
		if guard.try_block(info):
			blocked.emit(info, guard)
			return false
	return forward_to.receive_hit(info)


func is_alive() -> bool:
	return forward_to != null and forward_to.is_alive()


## Đạn hỏi trước khi gây đòn: trả về người dội nếu đòn nằm trong cung khiên và khiên đang dội đạn, ngược lại null.
## Dội được thì tính là đã chặn (phát blocked)
func reflect_projectile(info: DamageInfo) -> Node3D:
	if not reflects_projectiles:
		return null
	for guard in guards:
		if guard.try_block(info):
			blocked.emit(info, guard)
			return reflect_source
	return null
