extends "res://components/feedback/conversation/conversation_particles.gd"
## Vệt bụi bạc lướt ngang sát đất, tan ở hai mép thay vì biến mất đột ngột.

@export var width: float = 4.0
@export var wind_speed: float = 0.32
@export var streak_length: float = 0.55


func particle_transform(index: int, time: float) -> Transform3D:
	var seed_value := float(index)
	var phase := fposmod(seed_value * 0.173 + time * wind_speed, 1.0)
	var point := Vector3((phase - 0.5) * width, 0.12 + fposmod(seed_value * 0.37, 0.6), sin(seed_value * 2.4) * 0.9)
	var fade := sin(phase * PI)
	return Transform3D(Basis.IDENTITY.scaled(Vector3(streak_length, 0.025, 0.025) * fade), point)
