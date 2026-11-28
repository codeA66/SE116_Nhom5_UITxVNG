class_name CharmRevealOnClear
extends Node
## Hiện bùa ẩn (CharmPickup có starts_hidden) khi MỌI nguồn đã dọn xong: phòng có nhiều lồng / trận đánh,
## hạ hết quái của tất cả thì bùa mới hiện. Nạp lại khu khi các nguồn đã lưu cờ dọn xong: bùa hiện ngay.
## Nguồn: SpawnerCage, Encounter hoặc node bất kỳ có signal cleared và hàm is_active() (true = đã dọn).
## Hiệu năng: chỉ nghe signal cleared, không có _process.

@export var sources: Array[Node] = []
@export var pickup: CharmPickup


func _ready() -> void:
	if not _valid():
		return
	for src: Node in sources:
		if not src.is_connected(&"cleared", _check_all):
			src.connect(&"cleared", _check_all)
	_check_all()


## Nguồn rỗng / null / thiếu signal thì bỏ qua cả cụm: không bao giờ coi "không có nguồn" là đã dọn
func _valid() -> bool:
	if pickup == null or sources.is_empty():
		return false
	for src: Node in sources:
		if src == null or not src.has_signal(&"cleared") or not src.has_method(&"is_active"):
			push_warning("CharmRevealOnClear: nguồn thiếu signal cleared / hàm is_active(): %s" % src)
			return false
	return true


func _check_all() -> void:
	# Bùa đã có (pickup tự xoá) thì thôi
	if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
		return
	for src: Node in sources:
		if not is_instance_valid(src) or not bool(src.call(&"is_active")):
			return
	pickup.reveal()
