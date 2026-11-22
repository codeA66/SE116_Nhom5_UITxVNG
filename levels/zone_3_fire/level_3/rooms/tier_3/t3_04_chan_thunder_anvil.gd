class_name ChanThunderAnvil
extends Node3D
## Điều phối mạch điện, cửa và hồi sinh của phòng Chấn.

signal activated
signal seal_released(seal_id: StringName)

const SEAL_ID: StringName = &"chan"
const SEAL_FLAG: StringName = &"level_3.t3_seal_chan"

@export var data: ChanPuzzleData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/chan_puzzle_data.tres")
@export var seal_flag: StringName = SEAL_FLAG

var _player: Player
var _tutorial_open: bool = false
var _forge_solved: bool = false
var _complete: bool = false
var _pending_arena: bool = false
var _wave_damage: DamageInfo

@onready var _presence: Area3D = $Presence
@onready var _arena: Area3D = $ArenaTrigger
@onready var _tutorial_hammer: ChanHammer = $Hammers/TutorialHammer
@onready var _forge_hammer: ChanHammer = $Hammers/ForgeHammer
@onready var _tutorial: ChanCircuit = $TutorialCircuit
@onready var _forge: ChanCircuit = $ForgeCircuit
@onready var _entry_gate: StaticBody3D = $EntryGate
@onready var _tutorial_gate: StaticBody3D = $TutorialGate
@onready var _forge_gate: StaticBody3D = $ForgeGate
@onready var _respawn: Marker3D = $Respawn
@onready var _encounter: ChanEncounter = $Encounter
@onready var _seal: InteractableComponent = $Seal/Interactable
@onready var _seal_stone: MeshInstance3D = $Seal/Stone
@onready var _ready_glow: Node3D = $Seal/ReadyGlow


func _ready() -> void:
	_wave_damage = DamageInfo.new(data.wave_damage, DamageInfo.Type.PHYSICAL, Vector3.ZERO, self)
	_wave_damage.staggers = false
	_presence.body_entered.connect(_on_entered)
	_presence.body_exited.connect(_on_exited)
	_arena.body_entered.connect(_on_arena_entered)
	_tutorial_hammer.struck.connect(_on_struck.bind(_tutorial))
	_forge_hammer.struck.connect(_on_struck.bind(_forge))
	_tutorial_hammer.wave_hit.connect(_on_wave_hit)
	_forge_hammer.wave_hit.connect(_on_wave_hit)
	_tutorial.powered.connect(_unlock_tutorial)
	_forge.powered.connect(_unlock_forge)
	_encounter.phase_changed.connect(_on_phase_changed)
	_seal.interacted.connect(_finish)
	GameState.progress_replaced.connect(_restore_progress, CONNECT_DEFERRED)
	_restore_progress()


func is_active() -> bool:
	return _complete


func _on_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_player = player
	if not _complete:
		player.register_local_respawn(_respawn_local)
		_start_hammers()


func _on_exited(body: Node3D) -> void:
	if body != _player:
		return
	_stop_hammers()
	_tutorial.return_carried_block(body)
	_forge.return_carried_block(body)
	if _player.health.is_dead():
		return
	_player.unregister_local_respawn(_respawn_local)
	_player = null


func _on_arena_entered(body: Node3D) -> void:
	if not body is Player or _complete or _pending_arena:
		return
	if _encounter.phase != ChanEncounter.Phase.INACTIVE:
		return
	_pending_arena = true
	_start_encounter.call_deferred(body)


func _start_encounter(player: Player) -> void:
	if _pending_arena and is_instance_valid(player) and not player.health.is_dead():
		_encounter.start(player)
	_pending_arena = false


func _on_struck(circuit: ChanCircuit) -> void:
	circuit.pulse(data.power_time)


func _on_wave_hit(player: Player) -> void:
	player.receive_environment_hit(_wave_damage)


func _unlock_tutorial() -> void:
	if _tutorial_open:
		return
	_tutorial_open = true
	_tutorial.lock()
	_refresh_layout()


func _unlock_forge() -> void:
	if _forge_solved:
		return
	_forge_solved = true
	_forge.lock()
	_refresh_layout()


func _on_phase_changed(phase: ChanEncounter.Phase) -> void:
	_refresh_layout()
	if phase == ChanEncounter.Phase.FULL_ROOM:
		_stop_hammers()
		_start_hammers()
	elif phase == ChanEncounter.Phase.CLEARED:
		_stop_hammers()


func _start_hammers() -> void:
	if not is_instance_valid(_player) or _player.health.is_dead():
		return
	match _encounter.phase:
		ChanEncounter.Phase.INACTIVE, ChanEncounter.Phase.ARENA:
			_tutorial_hammer.start(_player, data)
			_forge_hammer.start(_player, data)
		ChanEncounter.Phase.FULL_ROOM:
			_tutorial_hammer.start(_player, data, data.combat_cycle_time, data.combat_warning_time)
			_forge_hammer.start(_player, data, data.combat_cycle_time, data.combat_warning_time, data.combat_cycle_time * 0.5)


func _stop_hammers() -> void:
	_tutorial_hammer.stop()
	_forge_hammer.stop()
	_tutorial.stop()
	_forge.stop()


func _respawn_local(player: Player) -> void:
	if player != _player or not player.health.is_dead():
		return
	_reset_attempt()
	player.revive_locally(_respawn.global_position, Vector3.RIGHT)
	_start_hammers()


func _finish(body: Node3D) -> void:
	if _complete or _encounter.phase != ChanEncounter.Phase.CLEARED or not body is Player:
		return
	_complete = true
	GameState.set_flag(seal_flag)
	_refresh_layout()
	if is_instance_valid(_player):
		_player.unregister_local_respawn(_respawn_local)
	activated.emit()
	seal_released.emit(SEAL_ID)


func _restore_progress() -> void:
	_complete = GameState.has_flag(seal_flag)
	_reset_attempt()
	if is_instance_valid(_player):
		if _complete:
			_player.unregister_local_respawn(_respawn_local)
		else:
			_player.register_local_respawn(_respawn_local)
			_player.teleport(_respawn.global_position, Vector3.RIGHT)
			_start_hammers()


func _reset_attempt() -> void:
	_stop_hammers()
	_tutorial_open = false
	_forge_solved = false
	_pending_arena = false
	_tutorial.reset()
	_forge.reset()
	_encounter.reset(_complete)
	_refresh_layout()


func _refresh_layout() -> void:
	var phase: ChanEncounter.Phase = _encounter.phase
	var joined: bool = phase == ChanEncounter.Phase.FULL_ROOM or phase == ChanEncounter.Phase.CLEARED
	_set_gate(_entry_gate, _complete or not joined)
	_set_gate(_tutorial_gate, joined or _tutorial_open)
	_set_gate(_forge_gate, joined or (phase == ChanEncounter.Phase.INACTIVE and _forge_solved))
	var can_adjust: bool = not _complete and phase == ChanEncounter.Phase.INACTIVE
	_tutorial.set_interaction_enabled(can_adjust and not _tutorial_open)
	_forge.set_interaction_enabled(can_adjust and _tutorial_open and not _forge_solved)
	_seal.enabled = not _complete and phase == ChanEncounter.Phase.CLEARED
	_ready_glow.visible = _seal.enabled
	_seal_stone.visible = not _complete


func _set_gate(gate: StaticBody3D, open: bool) -> void:
	gate.visible = not open
	gate.set_deferred(&"collision_layer", 0 if open else 1)
