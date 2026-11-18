class_name StatBonusEffect
extends CharmEffect
## Tác dụng bùa cộng thêm vào một chỉ số của player (máu tối đa...). Bùa kiểu này chỉ cần .tres, không viết code.
## Tên chỉ số do nơi đọc đặt: max_health (Player). Luật sát thương luôn 1: không dùng cho sát thương.

@export var stat: StringName
## Số cộng thêm (2 = thêm 2 ô máu); âm là trừ
@export_range(-20.0, 20.0, 1.0) var bonus: float = 0.0


func apply(player: Node) -> void:
	var stats := _stats_of(player)
	if stats and not stat.is_empty():
		stats.set_bonus(stat, _source_id(), bonus)


func remove(player: Node) -> void:
	var stats := _stats_of(player)
	if stats and not stat.is_empty():
		stats.remove_bonus(stat, _source_id())


## Mỗi tác dụng là một nguồn riêng: tháo bùa nào gỡ đúng phần bùa đó
func _source_id() -> StringName:
	return StringName("effect_%d" % get_instance_id())


func _stats_of(player: Node) -> StatModifiers:
	var p := player as Player
	return p.stats if p else null
