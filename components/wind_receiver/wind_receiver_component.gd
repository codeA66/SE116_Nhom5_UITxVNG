class_name WindReceiverComponent
extends Area3D
## Gắn vào thứ chịu tác động của gió (player, quái, vật thể).
## Cộng lực của mọi WindZone đang chồng lên và di chuyển body theo đó.

## Pháp tuyến có thành phần Y nhỏ hơn mức này được coi là tường (không phải sàn/dốc)
const WALL_NORMAL_MAX_Y := 0.7

## Hệ số chịu gió: quái nặng đặt < 1, vật nhẹ đặt > 1
@export var wind_multiplier: float = 1.0
## Gia tốc kéo vận tốc đứng về tốc độ gió dọc; phải lớn hơn trọng lực để cột gió nâng được
@export var vertical_response: float = 80.0

var enabled: bool = true


func _ready() -> void:
	monitorable = false


func get_wind() -> Vector3:
	if not enabled:
		return Vector3.ZERO
	var total := Vector3.ZERO
	for area in get_overlapping_areas():
		var zone := area as WindZone
		if zone:
			total += zone.get_wind_at(global_position)
	return total * wind_multiplier


## Thay cho body.move_and_slide().
## Gió ngang là vận tốc trôi cộng tạm thời (không tích lũy, người chơi vẫn chống lại được);
## gió dọc kéo vận tốc đứng về tốc độ gió (nâng lên, lơ lửng khi lực giảm dần).
func move_with_wind(body: CharacterBody3D, delta: float) -> void:
	var wind := get_wind()
	if wind.is_zero_approx():
		body.move_and_slide()
		return
	if not is_zero_approx(wind.y):
		body.velocity.y = move_toward(body.velocity.y, wind.y, vertical_response * delta)
	var own_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z)
	body.velocity += Vector3(wind.x, 0.0, wind.z)
	body.move_and_slide()
	# Trả lại vận tốc riêng (bỏ phần trôi theo gió), nhưng bỏ phần đâm vào tường như move_and_slide thường làm
	for i in body.get_slide_collision_count():
		var normal := body.get_slide_collision(i).get_normal()
		if absf(normal.y) < WALL_NORMAL_MAX_Y:
			var into_wall := own_velocity.dot(normal)
			if into_wall < 0.0:
				own_velocity -= normal * into_wall
	body.velocity.x = own_velocity.x
	body.velocity.z = own_velocity.z
