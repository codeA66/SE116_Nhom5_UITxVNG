class_name CharmEffect
extends Resource
## Một tác dụng của bùa lên player khi đeo. Bùa cụ thể = lớp con, ghi đè apply / remove.
## Luật sát thương luôn 1: tác dụng chỉ đổi công dụng (tầm, lực đẩy, năng lượng, i-frame...), không tăng sát thương.


func apply(_player: Node) -> void:
	pass


func remove(_player: Node) -> void:
	pass
