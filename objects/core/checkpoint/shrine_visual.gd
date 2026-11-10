@tool
class_name ShrineVisual
extends Node3D
## Lớp cơ sở hình ảnh miếu checkpoint (Gió, Lửa...): Checkpoint chỉ gọi set_active, không biết bên trong.
## Thêm kiểu miếu mới = kế thừa lớp này + scene checkpoint mới, không sửa checkpoint.gd.


## Bật / tắt trạng thái sáng. legacy_material, spin_degrees giữ cho miếu Gió; kiểu khác có thể bỏ qua
func set_active(_enabled: bool, _legacy_material: Material = null, _spin_degrees: float = 12.0, _immediate: bool = false) -> void:
	pass
