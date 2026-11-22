extends ChanCircuit
## Xung có thể mang 0 hoặc 1; nhánh ngắt giữ trạng thái tắt.

const K1_TO_K2: PackedInt32Array = [3, 1, 2]
const K2_TO_K3: PackedInt32Array = [3, 1, 2]
const INVERTED_PINS: PackedInt32Array = [2, 3]
const SELECTOR_COUNT: int = 3
const PORT_COUNT: int = 3
const ANY_PORT: int = 0

@export var source_track: Node3D
@export var crossed_tracks: Array[Node3D] = []
@export var tracks_before_gate: Array[Node3D] = []
@export var tracks_after_gate: Array[Node3D] = []
@export var receiver_track: Node3D
@export var receiver_zero_track: Node3D
@export var zero_taps: Array[Node3D] = []
@export var receiver_value: Label3D
@export var inverter_labels: Array[Label3D] = []

@onready var _track_groups: Array[Array] = [crossed_tracks, tracks_before_gate, tracks_after_gate, zero_taps]


func _ready() -> void:
	super()
	_show_circuit_labels.call_deferred()


func _trace_pulse() -> bool:
	_hide_tracks()
	source_track.show()
	if sockets.size() != SELECTOR_COUNT * PORT_COUNT:
		return false

	var first_port: int = _trace_selector(0, ANY_PORT)
	if first_port == ANY_PORT:
		return false
	crossed_tracks[first_port - 1].show()
	var second_port: int = _trace_selector(1, K1_TO_K2[first_port - 1])
	if second_port == ANY_PORT:
		return false
	tracks_before_gate[second_port - 1].show()
	tracks_after_gate[second_port - 1].show()

	var powered: bool = not INVERTED_PINS.has(second_port)
	var third_port: int = _trace_selector(2, K2_TO_K3[second_port - 1])
	if third_port == ANY_PORT:
		return false
	receiver_track.visible = powered
	receiver_zero_track.visible = not powered
	if not powered:
		zero_taps[third_port - 1].show()
	receiver_value.text = "1" if powered else "0"
	receiver_value.show()
	return powered


func _trace_selector(index: int, incoming_port: int) -> int:
	var first_socket: int = index * PORT_COUNT
	var selected_port: int = ANY_PORT
	var count: int = 0
	for port: int in range(1, PORT_COUNT + 1):
		if sockets[first_socket + port - 1].has_block():
			selected_port = port
			count += 1
	var connected: bool = count == 1 and (incoming_port == ANY_PORT or selected_port == incoming_port)
	if connected:
		sockets[first_socket + selected_port - 1].show_trace(true, false)
		return selected_port
	for port: int in range(1, PORT_COUNT + 1):
		var socket: ChanSocket = sockets[first_socket + port - 1]
		if (count > 1 and socket.has_block()) or incoming_port == port or (incoming_port == ANY_PORT and count == 0):
			socket.show_trace(false, true)
	return ANY_PORT


func _hide_tracks() -> void:
	_clear_socket_traces()
	source_track.hide()
	receiver_track.hide()
	receiver_zero_track.hide()
	receiver_value.hide()
	for group: Array in _track_groups:
		for track: Node3D in group:
			track.hide()


func _show_circuit_labels() -> void:
	# Cảnh walkthrough ẩn nhãn dựng phòng khi khởi tạo.
	for label: Label3D in inverter_labels:
		label.modulate.a = 1.0
	receiver_value.modulate.a = 1.0
