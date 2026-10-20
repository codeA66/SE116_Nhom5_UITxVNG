@tool
class_name BoulderResetPlate
extends Area3D
## Phiến đá khôi phục: người chơi bước lên thì các đá trượt gán ở ô Boulders (chưa vào ổ) về lại chỗ ban đầu.
## Câu đố trượt có thể đẩy đá vào góc không ra được; phiến này cho người chơi làm lại mà không phải chết.

signal reset_done

@export var boulders: Array[WindBoulder] = []:
	set(value):
		boulders = value
		update_configuration_warnings()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _get_configuration_warnings() -> PackedStringArray:
	if boulders.is_empty():
		return ["Chưa gán đá ở ô Boulders: phiến này không làm gì."]
	return []


func _on_body_entered(_body: Node3D) -> void:
	var any := false
	for boulder in boulders:
		if boulder and boulder.reset_to_start():
			any = true
	if any:
		reset_done.emit()
