class_name TutorialCatalog
extends Resource
## Danh mục tất cả bài hướng dẫn trong game: tra cứu dữ liệu theo id cho Popup và Sổ Hướng Dẫn.

@export var tutorials: Array[TutorialData] = []


func get_tutorial(id: StringName) -> TutorialData:
	for tut in tutorials:
		if tut and tut.id == id:
			return tut
	return null
