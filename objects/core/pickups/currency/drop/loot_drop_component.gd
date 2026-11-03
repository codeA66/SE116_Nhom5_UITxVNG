class_name LootDropComponent
extends Node
## Quái chết thì rơi đồ theo drop_table tại chỗ gục. Nghe health.died (không quét mỗi frame).
## Tìm PickupCollector (gắn trên người chơi) một lần lúc chết; không có người nhặt trong khu thì không rơi gì.

@export var health: HealthComponent
## Thân quái: lấy vị trí chỗ gục
@export var body: Node3D
@export var drop_table: DropTable


func _ready() -> void:
	if health == null or body == null:
		push_error("%s cần health và body" % get_path())
		return
	health.died.connect(_on_died)


func _on_died() -> void:
	if drop_table == null:
		return
	var collector := get_tree().get_first_node_in_group(PickupCollector.GROUP) as PickupCollector
	if collector == null:
		return
	for entry: DropEntry in drop_table.entries:
		if entry and entry.currency and entry.amount > 0:
			collector.spawn(body.global_position, entry.currency, entry.amount)
