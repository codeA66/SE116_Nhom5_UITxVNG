class_name ItemData
extends Resource
## Một vật phẩm hiện trong trang Vật phẩm của màn Tab: vật liệu nâng cấp kỹ năng, chìa khóa, đồ sưu tầm.
## Thêm vật phẩm mới = thêm file .tres và đưa vào ItemCatalog, không sửa code.

enum Category { UPGRADE, KEY, COLLECTIBLE, TOOL }

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.UPGRADE
## Để trống thì màn Tab vẽ hình thoi kèm chữ cái đầu
@export var icon: Texture2D
@export_multiline var description: String = ""
## Một câu truyện nhỏ (in nghiêng, mờ hơn) dưới phần mô tả
@export_multiline var lore: String = ""
## Vật phẩm "có hay không" theo cờ thế giới (chìa khóa nhặt rồi = cờ đã bật). Trống = đếm theo số lượng trong túi
@export var owned_flag: StringName


## Số đang có trong tiến trình: theo cờ (0 / 1) hoặc theo số lượng đã cộng
func count_in(progress: PlayerProgress) -> int:
	if not owned_flag.is_empty():
		return 1 if progress.flags.has(owned_flag) else 0
	return progress.items.get(id, 0)
