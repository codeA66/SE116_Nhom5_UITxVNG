extends Node3D
## Kết nối một lần, không quét group trong vòng lặp vật lý.
@export var leader: MonkeyChieftain
@export var members: Array[MonkeyGrunt] = []

func _ready() -> void:
	assert(leader != null)
	leader.engaged.connect(_rally)

func _rally(player: Node3D) -> void:
	for member: MonkeyGrunt in members:
		if is_instance_valid(member): member.receive_rally(player)
