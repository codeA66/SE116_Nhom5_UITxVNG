class_name FireWindData
extends Resource
## Thông số lửa theo vết gió. Chỉnh trong .tres, không sửa code.

## Vết lửa còn bật thêm bao lâu sau khi cú gió tắt (s); 0 = tắt cùng gió
@export_range(0.0, 2.0, 0.01) var extra_time: float = 0.1

@export_group("Flare")
## Bùng lửa phụt ra sau lưng mỗi vật đang cháy bị gió thổi trúng (đốt thứ dễ cháy trong vùng phụt). Để trống = tắt
@export var flare_scene: PackedScene
## Chiều dài vùng phụt theo hướng gió (m), tính từ sau lưng vật cháy
@export_range(0.1, 10.0, 0.05, "or_greater") var flare_length: float = 1.8
## Bề rộng và chiều cao vùng phụt (m)
@export_range(0.1, 10.0, 0.05, "or_greater") var flare_width: float = 1.4
@export_range(0.1, 10.0, 0.05, "or_greater") var flare_height: float = 1.6
## Khoảng lùi từ tâm vật cháy tới đầu vùng phụt (m), để lửa phụt ra sau lưng chứ không trùm lên vật
@export_range(0.0, 3.0, 0.05, "or_greater") var flare_offset: float = 0.3
## Thời gian vùng phụt còn đốt (s)
@export_range(0.05, 3.0, 0.01, "or_greater") var flare_time: float = 0.3
## Số vật tối đa được bùng trong một cú thổi
@export_range(1, 16) var flare_max: int = 3
