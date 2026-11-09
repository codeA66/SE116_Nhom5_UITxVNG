class_name WindBlastVisual
extends Node3D
## Lớp gốc cho hình ảnh cú Thổi Gió đặt dưới gốc Player (không dưới Model: foxy_player.gd ghi đè material mọi mesh
## dưới Model). Chỉ nghe signal của WindBlastArea, không chứa logic đẩy. Đổi kiểu hình (phễu, luồng gió, ...) =
## thêm lớp kế thừa mới; test và scene chỉ cần biết các hàm ở đây.

signal charge_finished
signal blast_finished

## Tránh chia cho 0 khi các thời gian bị chỉnh về 0
const MIN_TIME := 0.001

@export var area: WindBlastArea


## Đang gồng ở tay (trước khi vùng đẩy bật)
func is_charging() -> bool:
	return false


## Đang trong một lượt hình (luồng gió hoặc đuôi tan)
func is_playing() -> bool:
	return false


## Tổng thời gian hình còn hiện kể từ lúc vùng đẩy bật (s)
func get_blast_time() -> float:
	return 0.0
