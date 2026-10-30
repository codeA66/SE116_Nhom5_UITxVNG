extends SkyFerryState
## Đã tới bến mới: đậu lại, nhấp nhô. Chưa có chuyến về.


func enter(_previous: StringName) -> void:
	ferry.speed = 0.0
	ferry.notify_arrived()


func physics_update(delta: float) -> void:
	ferry.hover(delta)
