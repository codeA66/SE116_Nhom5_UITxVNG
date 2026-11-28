class_name CharmHolder
extends Node
## Áp tác dụng của các bùa đang đeo lên player. Nghe GameState (đeo / tháo bùa, nạp save), không chạy mỗi frame.
## Mỗi lần thay đổi: gỡ hết tác dụng cũ rồi áp lại bùa đang đeo, để không bao giờ áp trùng hay sót.
## Thêm bùa mới = thêm CharmData .tres (và CharmEffect mới nếu cần), không sửa file này.
## Không gỡ tác dụng khi rời cây: node này là con cố định của Player nên rời cây = player bị huỷ (đổi khu). Gỡ lúc đó
## làm máu tối đa tụt về mức gốc, máu bị kẹp rồi ghi đè máu đã giữ trong GameState (lỗi 28/11/2026: đeo Bùa Tâm Cáo
## đổi khu mất 2 máu). Đeo / tháo bùa trong lúc chơi vẫn gỡ rồi áp lại qua refresh().

@export var player: Player

var _applied: Array[CharmEffect] = []


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	GameState.charms_changed.connect(refresh)
	GameState.progress_replaced.connect(refresh)
	# Lần áp đầu do Player gọi trong _ready (trước khi khôi phục máu cũ): con _ready trước cha nên ở đây chưa có stats


## Gỡ hết rồi áp lại bùa đang đeo, gom trong một đợt để người nghe chỉ thấy kết quả cuối
func refresh() -> void:
	# stats là @onready của Player: chưa gán thì Player chưa sẵn sàng, Player sẽ tự gọi lại trong _ready
	if player == null or player.stats == null:
		return
	player.stats.begin_batch()
	_clear()
	for id: StringName in GameState.progress.equipped_charms:
		var charm := GameState.ITEMS.get_charm(id)
		if charm == null:
			continue
		for effect: CharmEffect in charm.effects:
			if effect:
				effect.apply(player)
				_applied.append(effect)
	player.stats.end_batch()


func _clear() -> void:
	if player == null:
		_applied.clear()
		return
	for effect: CharmEffect in _applied:
		effect.remove(player)
	_applied.clear()
