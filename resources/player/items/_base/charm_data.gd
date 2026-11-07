class_name CharmData
extends Resource
## Một bùa đeo được: tốn notch_cost ô khắc. Chỉ đổi bùa được khi đứng trong khu đổi bùa (CharmStation).
## Thêm bùa mới = thêm file .tres vào ItemCatalog.charms, không sửa code.

@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(1, 6) var notch_cost: int = 1
@export_multiline var description: String = ""
@export_multiline var lore: String = ""
@export var effects: Array[CharmEffect] = []
