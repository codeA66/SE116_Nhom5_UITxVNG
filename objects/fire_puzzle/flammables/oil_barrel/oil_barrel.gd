class_name OilBarrel
extends Flammable
## Thùng dầu: bắt lửa thì cháy ngắn (ngòi) rồi NỔ: gây đòn lửa quanh mình (player, quái, tường nứt...) qua
## ExplosionComponent, và châm mọi vật dễ cháy trong bán kính nổ. Nổ xong thì mất.

@onready var explosion: ExplosionComponent = $ExplosionComponent


func _on_burned_out() -> void:
	explosion.explode(self)
	spread_fire(explosion.global_position, explosion.radius)
	_set_present(false)
