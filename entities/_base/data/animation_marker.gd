class_name AnimationMarker
extends Resource
## Một marker gắn vào clip animation (ví dụ lúc lưỡi kiếm bắt đầu vung qua).
## Dùng cho clip nhập từ GLB không sửa trực tiếp được: marker được thêm vào clip lúc nạp.

## Tên clip trong AnimationLibrary (không kèm tên thư viện), ví dụ "Attack_Horizontal"
@export var clip: StringName
@export var marker: StringName
## Thời điểm trong clip (giây, ở tốc độ gốc 1.0)
@export var time: float = 0.0
