class_name RoomGateTrial
extends Area3D
@export var gates: Array[GardenLiftGate] = []
@export var lock_seconds: float = 3.0
@export var challenge: Node
@export var start_guide: GardenTotemGuide
var _busy: bool = false
var _pending_actor: Player
func _ready() -> void:
	body_entered.connect(_entered)
	set_process(false); set_physics_process(false)
func _entered(body: Node3D) -> void:
	if not body is Player or _busy: return
	if challenge != null and challenge.call("is_cleared"): return
	_busy = true
	# Không tiêu hết 3 giây trong màn tải/biên dịch shader lúc vừa mở scene.
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is ZoneRoot: ancestor = ancestor.get_parent()
	if ancestor is ZoneRoot and not (ancestor as ZoneRoot).is_combat_ready():
		await (ancestor as ZoneRoot).combat_ready
		if not is_instance_valid(body) or not overlaps_body(body): _busy = false; return
	for gate: GardenLiftGate in gates: gate.set_locked(self,true)
	_pending_actor = body as Player
	if start_guide != null and not start_guide.has_been_read:
		if not start_guide.read_completed.is_connected(_start_challenge):
			start_guide.read_completed.connect(_start_challenge,CONNECT_ONE_SHOT)
		return
	_start_challenge()

func _start_challenge() -> void:
	if not is_instance_valid(_pending_actor) or _pending_actor.health.is_dead(): return
	if challenge != null:
		if not challenge.is_connected("cleared",_open): challenge.connect("cleared",_open,CONNECT_ONE_SHOT)
		challenge.call("begin",_pending_actor)
	else: get_tree().create_timer(maxf(lock_seconds,0.1),false).timeout.connect(_open)
func _open() -> void:
	for gate: GardenLiftGate in gates:
		if is_instance_valid(gate): gate.set_locked(self,false)
	_busy = false
