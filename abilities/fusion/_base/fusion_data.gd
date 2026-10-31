class_name FusionData
extends Resource
## Một tổ hợp vũ khí + nguyên tố: ghép vào thì đòn thường của vũ khí được buff bằng các FusionEffect.
## Không có nút / chiêu riêng. Thêm tổ hợp mới = thêm file .tres, không sửa code.

@export var weapon_slot: WeaponData.Slot = WeaponData.Slot.SWORD
@export var element: ElementData
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effects: Array[FusionEffect] = []
