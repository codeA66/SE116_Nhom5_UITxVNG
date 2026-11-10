extends HurtboxComponent
## Chỉ đạn của chính con Bọ Đất sau khi bị phản mới xuyên mai.


func receive_hit(info: DamageInfo) -> bool:
	var projectile := info.source as StoneSeed
	return projectile != null and projectile.is_reflected() and super(info)
