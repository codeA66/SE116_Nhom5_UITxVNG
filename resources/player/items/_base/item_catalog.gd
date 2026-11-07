class_name ItemCatalog
extends Resource
## Danh mục mọi vật phẩm và bùa của game: màn Tab, NPC nâng cấp và save tra theo id ở đây.

@export var items: Array[ItemData] = []
@export var charms: Array[CharmData] = []


func get_item(id: StringName) -> ItemData:
	for item in items:
		if item and item.id == id:
			return item
	return null


func get_charm(id: StringName) -> CharmData:
	for charm in charms:
		if charm and charm.id == id:
			return charm
	return null
