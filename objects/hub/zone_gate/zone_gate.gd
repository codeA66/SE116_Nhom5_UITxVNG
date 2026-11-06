class_name ZoneGate
extends Node3D
## Cổng sang một khu ở khu trung tâm. Mở khi khu đã có scene và mọi điều kiện thỏa (chìa, phá khu trước...).
## Chưa mở: cổng dịch chuyển tắt, vách chặn bật, bảng chữ ghi lý do. Nghe GameState đổi tiến trình để tự mở,
## không kiểm tra mỗi frame.

## Phát khi cổng chuyển từ khóa sang mở (hiệu ứng / âm thanh mở cổng nối vào đây)
signal opened

@export var zone: ZoneData
@export var conditions: Array[UnlockCondition] = []
## Chữ khi khu đích chưa có scene
@export var not_ready_hint: String = "Chưa mở"

var _open: bool = false

@onready var _portal: Portal = $Portal
@onready var _blocker: CollisionShape3D = $Blocker/CollisionShape3D
@onready var _label: Label3D = $Label
@onready var _watcher: ProgressWatcher = $ProgressWatcher


func _ready() -> void:
	if zone == null:
		push_error("%s: chưa gán ZoneData" % get_path())
		return
	_watcher.changed.connect(_refresh)
	_portal.target_zone = zone.scene_path
	_portal.target_portal_id = zone.arrival_id
	_apply(_compute_open(), true)


func is_open() -> bool:
	return _open


func _refresh() -> void:
	if zone:
		_apply(_compute_open(), false)


func _compute_open() -> bool:
	return zone.has_scene() and UnlockCondition.all_met(conditions)


func _apply(open: bool, initial: bool) -> void:
	var was_open := _open
	_open = open
	_portal.set_active(open)
	_blocker.set_deferred(&"disabled", open)
	var hint := ""
	if not open:
		hint = not_ready_hint if not zone.has_scene() else UnlockCondition.first_hint(conditions)
	_label.text = zone.display_name if hint.is_empty() else "%s\n%s" % [zone.display_name, hint]
	_label.modulate = zone.color
	if open and not was_open and not initial:
		opened.emit()
