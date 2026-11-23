class_name CharmEffect
extends Resource
## Một tác dụng của bùa lên player khi đeo. Bùa cụ thể = lớp con, ghi đè apply / remove.
## Mỗi tác dụng tự gỡ signal, timer và modifier để thay bùa không làm sót buff trên player.


func apply(_player: Node) -> void:
	pass


func remove(_player: Node) -> void:
	pass
