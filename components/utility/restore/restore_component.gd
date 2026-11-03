class_name RestoreComponent
extends Node
## Hồi phục toàn bộ cho thực thể (checkpoint, sau này suối hồi máu...): đầy máu + đầy năng lượng.
## Nguồn hồi không cần biết bên trong thực thể: tìm component bằng find_on() rồi gọi restore_all().
## Thêm thứ cần hồi (bình máu, đạn...) thì nghe signal restored, không sửa nguồn hồi hay file này.

## Vừa hồi phục xong (thứ khác cần nạp lại nghe signal này)
signal restored

## Để trống nếu thực thể không có máu / năng lượng
@export var health: HealthComponent
@export var energy: EnergyComponent


## Component con trực tiếp của node (nguồn hồi gọi một lần khi có người bước vào, không quét mỗi frame); null nếu không có
static func find_on(node: Node) -> RestoreComponent:
	if node == null:
		return null
	for child in node.get_children():
		if child is RestoreComponent:
			return child
	return null


func restore_all() -> void:
	if health:
		health.heal_full()
	if energy:
		energy.set_current(energy.get_max())
	restored.emit()
