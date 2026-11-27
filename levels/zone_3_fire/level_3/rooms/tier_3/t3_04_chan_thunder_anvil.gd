class_name ChanThunderAnvil
extends Node3D
## Điều phối mạch điện, cửa và hồi sinh của phòng Chấn.

signal activated
signal seal_released(seal_id: StringName)

const SEAL_ID: StringName = &"chan"
const SEAL_FLAG: StringName = &"level_3.t3_seal_chan"

@export var data: ChanPuzzleData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/chan_puzzle_data.tres")
@export var seal_flag: StringName = SEAL_FLAG
@export_group("Cửa")
@export_range(0.5, 10.0, 0.1, "or_greater") var gate_lift_height: float = 2.8
@export_range(0.05, 3.0, 0.05, "or_greater") var gate_open_time: float = 0.65

var _player: Player
var _tutorial_powered: bool = false
var _tutorial_open: bool = false
var _forge_powered: bool = false
var _forge_solved: bool = false
var _complete: bool = false
var _pending_arena: bool = false
var _wave_damage: DamageInfo
var _gate_closed_y: float = 1.65
var _gate_tweens: Dictionary[StaticBody3D, Tween] = {}

@onready var _presence: Area3D = $Presence
@onready var _arena: Area3D = $ArenaTrigger
@onready var _tutorial_hammer: ChanHammer = $Hammers/TutorialHammer
@onready var _forge_hammer: ChanHammer = $Hammers/ForgeHammer
@onready var _tutorial: ChanCircuit = $TutorialCircuit
@onready var _forge: ChanCircuit = $ForgeCircuit
@onready var _tutorial_receiver: ChanGateReceiver = $Receivers/TutorialReceiver
@onready var _forge_receiver: ChanGateReceiver = $Receivers/ForgeReceiver
@onready var _entry_gate: StaticBody3D = $EntryGate
@onready var _tutorial_gate: StaticBody3D = $TutorialGate
@onready var _forge_gate: StaticBody3D = $ForgeGate
@onready var _encounter: ChanEncounter = $Encounter
@onready var _seal: InteractableComponent = $Seal/Interactable
@onready var _seal_stone: MeshInstance3D = $Seal/Stone
@onready var _gem: SealGem = $Seal/ChanGem
@onready var _ready_glow: Node3D = $Seal/ReadyGlow


func _ready() -> void:
	_gate_closed_y = _tutorial_gate.position.y
	_wave_damage = DamageInfo.new(data.wave_damage, DamageInfo.Type.PHYSICAL, Vector3.ZERO, self)
	_wave_damage.staggers = false
	_presence.body_entered.connect(_on_entered)
	_presence.body_exited.connect(_on_exited)
	_arena.body_entered.connect(_on_arena_entered)
	_tutorial_hammer.struck.connect(_on_struck.bind(_tutorial))
	_forge_hammer.struck.connect(_on_struck.bind(_forge))
	_tutorial_hammer.wave_hit.connect(_on_wave_hit)
	_forge_hammer.wave_hit.connect(_on_wave_hit)
	_tutorial.powered.connect(_on_tutorial_powered)
	_tutorial.unpowered.connect(_on_tutorial_unpowered)
	_forge.powered.connect(_on_forge_powered)
	_forge.unpowered.connect(_on_forge_unpowered)
	_tutorial_receiver.activated.connect(_open_tutorial_gate)
	_forge_receiver.activated.connect(_open_forge_gate)
	_encounter.phase_changed.connect(_on_phase_changed)
	_seal.interacted.connect(_finish)
	var placed_flag: StringName = StringName(String(seal_flag) + "_placed")
	_gem.configure_reward(seal_flag, placed_flag)
	var zone: ZoneRoot = get_parent() as ZoneRoot
	if zone:
		zone.player_spawned.connect(_gem.set_carrier)
		_gem.set_carrier(zone.get_node_or_null(^"Player") as Player)
	GameState.progress_replaced.connect(_restore_progress, CONNECT_DEFERRED)
	_restore_progress()


func is_active() -> bool:
	return _complete


func _on_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_player = player
	_gem.set_carrier(player)
	if not _complete:
		_start_hammers(true)


func _on_exited(body: Node3D) -> void:
	if body != _player:
		return
	_stop_hammers()
	_tutorial.return_carried_block(body)
	_forge.return_carried_block(body)
	if _player.health.is_dead():
		return
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


func _on_tutorial_powered() -> void:
	if _tutorial_powered:
		return
	_tutorial_powered = true
	_tutorial_receiver.set_powered(true)
	_refresh_layout()


func _on_tutorial_unpowered() -> void:
	if not _tutorial_powered:
		return
	_tutorial_powered = false
	_tutorial_receiver.set_powered(false)
	_refresh_layout()


func _open_tutorial_gate() -> void:
	if _tutorial_open:
		return
	_tutorial_open = true
	_tutorial.lock()
	_tutorial_receiver.set_opened(true)
	_refresh_layout(true)


func _on_forge_powered() -> void:
	if _forge_powered:
		return
	_forge_powered = true
	_forge_receiver.set_powered(true)
	_refresh_layout()


func _on_forge_unpowered() -> void:
	if not _forge_powered:
		return
	_forge_powered = false
	_forge_receiver.set_powered(false)
	_refresh_layout()


func _open_forge_gate() -> void:
	if _forge_solved:
		return
	_forge_solved = true
	_forge.lock()
	_forge_receiver.set_opened(true)
	_refresh_layout(true)


func _on_phase_changed(phase: ChanEncounter.Phase) -> void:
	_refresh_layout()
	if phase == ChanEncounter.Phase.FULL_ROOM:
		_stop_hammers()
		_start_hammers()
	elif phase == ChanEncounter.Phase.CLEARED:
		_stop_hammers()


func _start_hammers(warn_on_entry: bool = false) -> void:
	if not is_instance_valid(_player) or _player.health.is_dead():
		return
	match _encounter.phase:
		ChanEncounter.Phase.INACTIVE, ChanEncounter.Phase.ARENA:
			_tutorial_hammer.start(_player, data, data.cycle_time, data.warning_time, 0.0, warn_on_entry)
			_forge_hammer.start(_player, data, data.cycle_time, data.warning_time, 0.0, warn_on_entry)
		ChanEncounter.Phase.FULL_ROOM:
			_tutorial_hammer.start(_player, data, data.combat_cycle_time, data.combat_warning_time)
			_forge_hammer.start(_player, data, data.combat_cycle_time, data.combat_warning_time, data.combat_cycle_time * 0.5)


func _stop_hammers() -> void:
	_tutorial_hammer.stop()
	_forge_hammer.stop()
	_tutorial.stop()
	_forge.stop()


func _finish(body: Node3D) -> void:
	if _complete or _encounter.phase != ChanEncounter.Phase.CLEARED or not body is Player:
		return
	_complete = true
	GameState.set_flag(seal_flag)
	_refresh_layout()
	activated.emit()
	seal_released.emit(SEAL_ID)


func _restore_progress() -> void:
	_complete = GameState.has_flag(seal_flag)
	if not _complete:
		_gem.hide()
	_reset_attempt()
	if is_instance_valid(_player) and not _complete:
		_start_hammers()


func _reset_attempt() -> void:
	_stop_hammers()
	_tutorial_powered = false
	_tutorial_open = false
	_forge_powered = false
	_forge_solved = false
	_pending_arena = false
	_tutorial.reset()
	_forge.reset()
	_tutorial_receiver.reset(_complete)
	_forge_receiver.reset(_complete)
	_encounter.reset(_complete)
	_refresh_layout()


func _refresh_layout(animate_gates: bool = false) -> void:
	var phase: ChanEncounter.Phase = _encounter.phase
	var joined: bool = phase == ChanEncounter.Phase.FULL_ROOM or phase == ChanEncounter.Phase.CLEARED
	_set_gate(_entry_gate, _complete or not joined, false)
	_set_gate(_tutorial_gate, joined or _tutorial_open, animate_gates)
	_set_gate(_forge_gate, joined or (phase == ChanEncounter.Phase.INACTIVE and _forge_solved), animate_gates)
	var can_adjust: bool = not _complete and phase == ChanEncounter.Phase.INACTIVE
	_tutorial.set_interaction_enabled(can_adjust and not _tutorial_open)
	_forge.set_interaction_enabled(can_adjust and _tutorial_open and not _forge_solved)
	_tutorial_receiver.set_interaction_enabled(can_adjust)
	_forge_receiver.set_interaction_enabled(can_adjust and _tutorial_open)
	_seal.enabled = not _complete and phase == ChanEncounter.Phase.CLEARED
	_ready_glow.visible = _seal.enabled
	_seal_stone.visible = not _complete


func _set_gate(gate: StaticBody3D, open: bool, animate: bool = false) -> void:
	if gate == _entry_gate:
		gate.visible = not open
		gate.set_deferred(&"collision_layer", 0 if open else 1)
		return
	var active_tween: Tween = _gate_tweens.get(gate) as Tween
	if active_tween:
		active_tween.kill()
		_gate_tweens.erase(gate)
	var target_y: float = _gate_closed_y + gate_lift_height if open else _gate_closed_y
	gate.set_deferred(&"collision_layer", 0 if open else 1)
	if animate and open and not is_equal_approx(gate.position.y, target_y):
		gate.visible = true
		var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(gate, ^"position:y", target_y, gate_open_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func() -> void:
			_gate_tweens.erase(gate)
			gate.visible = false
		)
		_gate_tweens[gate] = tween
		return
	gate.position.y = target_y
	gate.visible = not open
