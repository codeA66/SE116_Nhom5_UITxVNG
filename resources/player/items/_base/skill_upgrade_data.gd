class_name SkillUpgradeData
extends Resource
## Một bậc nâng cấp kỹ năng (cấp n -> n+1), do NPC thực hiện khi đủ vật phẩm.
## Kỹ năng giữ danh sách bậc theo thứ tự trong AbilityData.upgrades. Thêm bậc = thêm phần tử, không sửa code.

## Tên hiển thị của cấp mới (ví dụ "Thổi gió II"); trống = tên gốc + số La Mã
@export var display_name: String = ""
## Cấp mới thay đổi gì (hiện trên màn Tab)
@export_multiline var description: String = ""
@export var requirements: Array[ItemCost] = []
## Thuộc tính của dữ liệu kỹ năng được đổi ở cấp mới: tên thuộc tính -> giá trị (ví dụ "reach": 7.0)
@export var overrides: Dictionary[StringName, Variant] = {}


func is_affordable(progress: PlayerProgress) -> bool:
	for cost: ItemCost in requirements:
		if cost.item == null or cost.item.count_in(progress) < cost.count:
			return false
	return true
