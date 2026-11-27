extends ZoneRoot
## Hồi máu lúc vào đấu trường mà không thay đổi luật chuyển khu dùng chung.


func _ready() -> void:
	player_spawned.connect(_on_player_arrived)
	super._ready()


func _on_player_arrived(player: Player) -> void:
	# Dùng luồng hồi máu chung để HUD và máu lưu trong GameState cùng cập nhật.
	player.health.heal_full()
