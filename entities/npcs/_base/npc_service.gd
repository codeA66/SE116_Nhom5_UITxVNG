class_name NpcService
extends Node
## Một việc NPC làm sau lời chào: nâng cấp kỹ năng, bán bùa, thu tiền qua cổng...
## Gắn làm con của Npc. Loại NPC mới = service mới kế thừa lớp này, không sửa Npc hay state.
## Lớp con ghi đè _on_open(), làm xong gọi finish() (bấm thoát thì finish(true)). Lớp gốc không làm gì (đóng ngay).

## cancelled = người chơi bấm thoát: NPC không nói lời tạm biệt, kết thúc luôn
signal closed(cancelled: bool)

## Giữ hộp thoại mở khi chuyển sang service (service hỏi tiếp bằng npc.ask(), ví dụ "Trả 100 Ngọc để qua?").
## Tắt khi service mở màn riêng (màn nâng cấp, cửa hàng).
@export var keep_dialogue_open: bool = false

var npc: Npc
var player: Player

var _active: bool = false


## Có mở được lúc này không (ví dụ gác cổng đã nhận tiền thì thôi). Không mở được thì NPC chỉ nói chuyện.
func is_available() -> bool:
	return true


func open(owner_npc: Npc, target: Player) -> void:
	npc = owner_npc
	player = target
	_active = true
	_on_open()


## Lớp con gọi khi làm xong (cancelled = false) hoặc người chơi bấm thoát (cancelled = true)
func finish(cancelled: bool = false) -> void:
	if not _active:
		return
	_active = false
	_on_close()
	closed.emit(cancelled)


func is_active() -> bool:
	return _active


## Lớp con ghi đè: mở màn / hỏi / thu tiền...
func _on_open() -> void:
	finish()


## Lớp con ghi đè: dọn màn riêng khi đóng
func _on_close() -> void:
	pass
