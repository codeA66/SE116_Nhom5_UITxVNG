class_name DevCheat
extends RefCounted
## Một cheat của bảng dev (F1, chỉ có trong bản debug). Mỗi cheat là một file trong dev/cheats/, DevConsole tự tìm
## và tạo, bảng dev tự dựng nút theo kind. Thêm cheat mới = thêm file kế thừa lớp này, không sửa file nào khác.

enum Kind {
	TOGGLE,  ## Bật / tắt: apply() khi bật, remove() khi tắt
	ACTION,  ## Nút bấm một lần: run()
	SLIDER,  ## Thanh kéo: set_value()
	CHOICE,  ## Danh sách chọn rồi bấm: get_choices() + choose()
}

## Chữ hiện trên bảng
var title: String = ""
## Nhóm trên bảng (Player, Combat, Tiến trình, Di chuyển...)
var group: String = ""
var kind: Kind = Kind.ACTION
## Thứ tự trong nhóm, nhỏ đứng trước
var order: int = 0
## Dùng cheat này thì chặn ghi save tới hết phiên chơi
var blocks_saving: bool = true

## Thanh kéo
var min_value: float = 0.0
var max_value: float = 1.0
var step: float = 0.1
var default_value: float = 0.0

var enabled: bool = false
var value: float = 0.0


func apply(_console: DevConsole) -> void:
	pass


func remove(_console: DevConsole) -> void:
	pass


func run(_console: DevConsole) -> void:
	pass


func set_value(_console: DevConsole, new_value: float) -> void:
	value = new_value


func get_choices(_console: DevConsole) -> PackedStringArray:
	return PackedStringArray()


func choose(_console: DevConsole, _index: int) -> void:
	pass


## Khu mới vừa sẵn sàng (player mới được tạo): cheat đang bật áp lại cho player mới
func on_zone_ready(_console: DevConsole) -> void:
	pass
