class_name StatMultiplierEffect
extends CharmEffect
## Tác dụng bùa nhân một chỉ số của player (tốc độ chém, quãng dash...). Bùa kiểu này chỉ cần .tres, không viết code.
## Tên chỉ số do nơi đọc đặt: melee_attack_speed (Attack). Luật sát thương luôn 1: không dùng cho sát thương.

@export var stat: StringName
## > 1 là tăng (1.25 = nhanh hơn 25%), < 1 là giảm
@export_range(0.1, 5.0, 0.05) var multiplier: float = 1.0


func apply(player: Node) -> void:
	var stats := _stats_of(player)
	if stats and not stat.is_empty():
		stats.set_multiplier(stat, _source_id(), multiplier)


func remove(player: Node) -> void:
	var stats := _stats_of(player)
	if stats and not stat.is_empty():
		stats.remove_multiplier(stat, _source_id())


## Mỗi tác dụng là một nguồn riêng: hai bùa cùng chỉ số thì nhân dồn, tháo bùa nào gỡ đúng phần bùa đó
func _source_id() -> StringName:
	return StringName("effect_%d" % get_instance_id())


func _stats_of(player: Node) -> StatModifiers:
	var p := player as Player
	return p.stats if p else null
