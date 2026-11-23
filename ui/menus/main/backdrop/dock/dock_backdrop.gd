class_name DockBackdrop
extends Control
## Nền menu chính "bến gió": tranh nền đã xoá vải + lớp khăn, hai lớp cờ bay bằng shader (cloth_wave) + ba lớp hạt
## (đốm lửa đèn lồng, bụi sáng phía lâu đài, hạt cỏ lau bay theo cơn gió).
## Hạt đặt theo toạ độ điểm ảnh của tranh gốc: node Ambient được co giãn giống cách tranh phủ kín màn
## (KEEP_ASPECT_COVERED), nên đổi độ phân giải hạt vẫn nằm đúng chỗ. Chỉ tính lại khi đổi cỡ, không chạy mỗi frame.

## Cỡ tranh gốc (px): mọi toạ độ của lớp vải và hạt tính theo ảnh này
@export var art_size: Vector2 = Vector2(1672, 941)
## Chu kỳ cơn gió (s): phải bằng gust_interval của các lớp vải để hạt cỏ bay đúng lúc vải bị thổi
@export_range(1.0, 12.0, 0.1) var gust_interval: float = 5.2
## Hạt cỏ bắn ra ở thời điểm này của chu kỳ (0..1), ngay khi vải bắt đầu bị thổi
@export_range(0.0, 1.0, 0.01) var gust_start: float = 0.06

@onready var _ambient: Node2D = $Ambient
@onready var _fluff: CPUParticles2D = $Ambient/Fluff
@onready var _gust_timer: Timer = $GustTimer


func _ready() -> void:
	resized.connect(_fit_ambient)
	_fit_ambient()
	_gust_timer.wait_time = gust_interval
	_gust_timer.timeout.connect(_on_gust)
	# Canh pha với TIME của shader (tính từ lúc game chạy) để hạt cỏ và vải cùng một cơn gió
	var now := Time.get_ticks_msec() / 1000.0
	var wait := fposmod(gust_start * gust_interval - now, gust_interval)
	get_tree().create_timer(maxf(wait, 0.01)).timeout.connect(_start_gusts)


func _start_gusts() -> void:
	if not is_inside_tree():
		return
	_on_gust()
	_gust_timer.start()


func _on_gust() -> void:
	_fluff.restart()


func _fit_ambient() -> void:
	var scale_factor := maxf(size.x / art_size.x, size.y / art_size.y)
	_ambient.scale = Vector2.ONE * scale_factor
	_ambient.position = (size - art_size * scale_factor) * 0.5
