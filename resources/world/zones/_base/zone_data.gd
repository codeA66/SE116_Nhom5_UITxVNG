class_name ZoneData
extends AreaData
## Một khu lớn của đảo (Gió, Lửa, Băng, Sét). Cổng ở khu trung tâm, dấu nguyên tố trên cửa đền
## và điều kiện "đã phá khu" đều đọc từ đây: thêm khu mới = thêm .tres, không sửa code.
## Tên, dòng phụ (chữ giới thiệu khu vực) kế thừa từ AreaData.

## Màu nguyên tố của khu (cổng, dấu trên cửa đền)
@export var color: Color = Color.WHITE
## Scene của khu; để trống = khu chưa làm, cổng luôn đóng
@export_file("*.tscn") var scene_path: String = ""
## Tên điểm xuất hiện trong khu đích khi đi qua cổng
@export var arrival_id: StringName = &"start"
## Cờ trong GameState bật khi phá đảo khu này
@export var cleared_flag: StringName


func has_scene() -> bool:
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path)


func is_cleared() -> bool:
	return not cleared_flag.is_empty() and GameState.has_flag(cleared_flag)


## Như is_cleared nhưng đọc một tiến trình bất kỳ (ô hồ sơ trên menu chưa nạp vào GameState)
func is_cleared_in(progress: PlayerProgress) -> bool:
	return progress != null and not cleared_flag.is_empty() and progress.flags.has(cleared_flag)
