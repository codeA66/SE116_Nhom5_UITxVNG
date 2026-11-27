extends ChanCircuit
## Xung có thể mang 0 hoặc 1; nhánh ngắt giữ trạng thái tắt.

const K1_TO_K2: PackedInt32Array = [3, 1, 2]
const K2_TO_K3: PackedInt32Array = [3, 1, 2]
const INVERTED_PINS: PackedInt32Array = [2, 3]
const SELECTOR_COUNT: int = 3
const PORT_COUNT: int = 3

@export var source_track: Node3D
@export var crossed_tracks: Array[Node3D] = []
@export var tracks_before_gate: Array[Node3D] = []
@export var tracks_after_gate: Array[Node3D] = []
@export var receiver_track: Node3D
@export var inverter_plates: Array[MeshInstance3D] = []
@export var inverter_active_material: Material

@onready var _track_groups: Array[Array] = [crossed_tracks, tracks_before_gate, tracks_after_gate]


func _trace_pulse() -> bool:
	_hide_tracks()
	source_track.show()
	if sockets.size() != SELECTOR_COUNT * PORT_COUNT:
		return false

	var powered: bool = false
	for first: int in PORT_COUNT:
		if not _trace_port(0, first):
			continue
		crossed_tracks[first].show()
		var second: int = K1_TO_K2[first] - 1
		if not _trace_port(1, second):
			continue
		tracks_before_gate[second].show()
		var inverter: int = INVERTED_PINS.find(second + 1)
		if inverter >= 0:
			if inverter < inverter_plates.size():
				inverter_plates[inverter].material_override = inverter_active_material
			continue
		if second < tracks_after_gate.size() and tracks_after_gate[second] != null:
			tracks_after_gate[second].show()
		var third: int = K2_TO_K3[second] - 1
		if not _trace_port(2, third):
			continue
		powered = true
	receiver_track.visible = powered
	return powered


func _trace_port(selector: int, port: int) -> bool:
	var socket: ChanSocket = sockets[selector * PORT_COUNT + port]
	var connected: bool = socket.has_block()
	socket.show_trace(connected, not connected)
	return connected


func _hide_tracks() -> void:
	_clear_socket_traces()
	source_track.hide()
	receiver_track.hide()
	for plate: MeshInstance3D in inverter_plates:
		plate.material_override = null
	for group: Array in _track_groups:
		for track: Node3D in group:
			if track != null:
				track.hide()
