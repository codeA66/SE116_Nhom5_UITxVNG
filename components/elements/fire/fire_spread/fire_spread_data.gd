class_name FireSpreadData
extends Resource
## Thông số luồng lửa phụt ra khi gió thổi trúng mục tiêu đang cháy. Chỉnh trong .tres, không sửa code.

## Chiều dài luồng lửa theo hướng gió, tính từ tâm mục tiêu (m)
@export_range(0.1, 30.0, 0.1, "or_greater") var length: float = 4.0
## Bề ngang luồng lửa (m)
@export_range(0.1, 20.0, 0.1, "or_greater") var width: float = 2.0
@export_range(0.1, 5.0, 0.1) var height: float = 1.8
## Luồng lửa bật trong bao lâu (s); ngắn vì chỉ cần chạm để bắt lửa
@export_range(0.02, 2.0, 0.01) var active_time: float = 0.25
## Một mục tiêu phụt lửa lại sớm nhất sau khoảng này (s): chống lan qua lại vô hạn trong cùng cú gió
@export_range(0.0, 5.0, 0.05) var spread_cooldown: float = 0.5
## Mục tiêu vừa bắt lửa mà còn đang trôi vì cú gió đó thì phụt lửa tiếp (một cú gió đốt cả hàng)
@export var chain_while_pushed: bool = true
## Cú gió phải mạnh ít nhất chừng này mới làm lửa phụt theo hướng (cú thổi E = 12).
## Lực kéo nhỏ mỗi khung của hố hút Cung Gió (~0.6) không tính: hố có luật riêng (lốc lửa)
@export_range(0.0, 100.0, 0.1) var min_impulse: float = 3.0
## Lan nối tiếp chỉ khi cú gió mạnh gần nhất xảy ra trong khoảng này (s): đang trôi vì thứ khác (hố hút)
## thì không phụt theo hướng một cú gió cũ
@export_range(0.0, 5.0, 0.05) var chain_window: float = 0.6
