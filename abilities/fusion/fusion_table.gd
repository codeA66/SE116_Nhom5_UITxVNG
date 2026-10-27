class_name FusionTable
extends Resource
## Bảng mọi nguyên tố và tổ hợp ghép. GameState và tủ đồ tra ở đây.

@export var elements: Array[ElementData] = []
@export var fusions: Array[FusionData] = []


func get_element(id: StringName) -> ElementData:
	for element in elements:
		if element.id == id:
			return element
	return null


## Nguyên tố có kỹ năng gốc là ability_id; null nếu kỹ năng đó không phải nguyên tố
func get_element_by_ability(ability_id: StringName) -> ElementData:
	for element in elements:
		if element.ability and element.ability.id == ability_id:
			return element
	return null


func get_fusion(slot: WeaponData.Slot, element_id: StringName) -> FusionData:
	for fusion in fusions:
		if fusion.weapon_slot == slot and fusion.element and fusion.element.id == element_id:
			return fusion
	return null
