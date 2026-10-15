@tool
class_name Portal
extends Node3D
## Cổng dịch chuyển: player bước vào là sang khu khác.
## Cổng hai chiều = đặt một Portal ở mỗi khu, trỏ về nhau qua target_portal_id.
## Mỗi cổng có điểm đến riêng (Arrival) đặt trước mặt cổng, để player tới nơi không đứng ngay
## trong cổng rồi bị dịch chuyển ngược lại.
## @tool chỉ để hiện cảnh báo cấu hình trong editor.

## Tên cổng này, duy nhất trong khu; cổng ở khu kia trỏ tới tên này để player xuất hiện tại đây
@export var portal_id: StringName:
	set(value):
		portal_id = value
		update_configuration_warnings()
## Khu đích
@export_file("*.tscn") var target_zone: String:
	set(value):
		target_zone = value
		update_configuration_warnings()
## Tên cổng ở khu đích, player xuất hiện trước cổng đó
@export var target_portal_id: StringName:
	set(value):
		target_portal_id = value
		update_configuration_warnings()

@onready var _trigger: Area3D = $Trigger
@onready var _arrival: SpawnPoint = $Arrival


func _ready() -> void:
	# Phải gán trước khi ZoneRoot tìm điểm xuất hiện; cổng là con của khu nên _ready chạy trước
	_arrival.spawn_id = portal_id
	if Engine.is_editor_hint():
		return
	_trigger.body_entered.connect(_on_body_entered)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if portal_id.is_empty():
		warnings.append("Chưa đặt Portal Id (tên cổng này).")
	if target_zone.is_empty():
		warnings.append("Chưa chọn Target Zone (scene khu đích).")
	if target_portal_id.is_empty():
		warnings.append("Chưa đặt Target Portal Id (tên cổng ở khu đích).")
	return warnings


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not SceneManager.is_busy():
		SceneManager.change_zone(target_zone, target_portal_id)
