class_name GardenTimedSpikes
extends Area3D
@export var cycle_duration: float = 3.2
@export var active_duration: float = 1.0
@export var warning_duration: float = 0.55
@export var phase_offset: float = 0.0
@export var spikes: Node3D
@export var warning: MeshInstance3D
var _clock: float = 0.0
var _phase: int = -1
var _bodies: Array[Player] = []

func _ready() -> void:
	body_entered.connect(_entered); body_exited.connect(_exited); set_enabled(false)

func set_enabled(value: bool) -> void:
	set_physics_process(value)
	if not value: _phase = 0; spikes.scale.y = 0.06; warning.visible = false

func _physics_process(delta: float) -> void:
	_clock += delta
	var phase_time: float = fposmod(_clock+phase_offset,maxf(cycle_duration,0.1))
	var phase: int = 2 if phase_time<active_duration else 1 if phase_time>cycle_duration-warning_duration else 0
	if phase == _phase: return
	_phase = phase; spikes.scale.y = 1.0 if phase==2 else 0.06
	warning.visible = phase>0
	(warning.material_override as StandardMaterial3D).albedo_color = Color(1,0.15,0.04,0.6) if phase==2 else Color(1,0.65,0.08,0.5)
	if phase == 2:
		for player: Player in _bodies: _damage(player)

func _entered(body: Node3D) -> void:
	if not body is Player: return
	_bodies.append(body as Player)
	if _phase==2: _damage(body as Player)

func _exited(body: Node3D) -> void:
	if body is Player: _bodies.erase(body)

func _damage(player: Player) -> void:
	if not is_instance_valid(player) or not player.is_on_floor(): return
	(player.get_node("HurtboxComponent") as HurtboxComponent).receive_hit(DamageInfo.new(1,DamageInfo.Type.PHYSICAL,Vector3.ZERO,self))
