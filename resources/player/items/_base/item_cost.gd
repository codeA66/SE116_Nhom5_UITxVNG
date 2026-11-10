class_name ItemCost
extends Resource
## Một dòng yêu cầu: cần bao nhiêu cái của vật phẩm nào (nâng cấp kỹ năng, mua bán sau này).

@export var item: ItemData
@export_range(1, 99) var count: int = 1
