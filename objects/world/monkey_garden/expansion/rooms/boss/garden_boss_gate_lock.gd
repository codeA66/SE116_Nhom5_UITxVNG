class_name GardenBossGateLock
extends Node
## Ghép checkpoint, trận boss và cổng bằng signal; không đổi FSM chiến đấu của quái.
@export var encounter: GardenKingEncounter
@export var gate: GardenOfferingGate
@export var checkpoint: Checkpoint

func _ready() -> void:
	encounter.approached.connect(_approached)
	encounter.cleared.connect(gate.unlock_after_battle)
	set_process(false); set_physics_process(false)

func _approached(_player: Player) -> void:
	# Lối vào rộng hơn trụ: người đi sát mép vẫn có điểm hồi sinh bên trong trước khi cửa đóng.
	if not checkpoint.is_active():
		GameState.set_checkpoint(get_tree().current_scene.scene_file_path,checkpoint.checkpoint_id)
	gate.lock_for_battle()
