class_name ShaderWarmupData
extends Resource
## Thông số biên dịch sẵn shader lúc vào khu. Chỉnh trong file .tres, không cần sửa code.

## Số frame vẽ bản sao trước camera. Particle cần 1–2 frame mới phát hạt nên không để dưới 2
@export_range(1, 30) var frames: int = 3
## Khoảng cách từ camera tới chỗ đặt bản sao (m); phải nằm trong khung nhìn của camera
@export var distance_from_camera: float = 6.0
## Scene chỉ được tạo lúc chạy (đạn, mô hình vũ khí...) nên khu không có sẵn: quét hình của chúng mà không đưa vào cây
@export var extra_scenes: Array[PackedScene] = []
## Chạy headless (test tự động) không có GPU nên không có gì để biên dịch
@export var skip_when_headless: bool = true
