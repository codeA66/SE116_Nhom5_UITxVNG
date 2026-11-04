class_name ShiftingGardenSeal
extends Node
## Ba điểm đặt sẵn tránh vùng đất; Timer chỉ chạy khi thử thách bắt đầu.
@export var seal: GardenSwitch
@export var anchors: Array[Marker3D] = []
@export var color: Color = Color("58d5ff")
@export_range(1, 20, 1) var interval: int = 3
var _timer: Timer
var _label: Label3D
var _remaining: int
var _index: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var material: StandardMaterial3D = seal.glow.material_override.duplicate() as StandardMaterial3D
	material.albedo_color = color; material.emission_enabled = true; material.emission = color*0.3
	seal.glow.material_override = material
	_label = Label3D.new(); _label.name = "TeleportCountdown"; _label.font_size = 56; _label.pixel_size = 0.012
	_label.outline_size = 8; _label.modulate = color; _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	seal.add_child(_label); _label.position.y = 2; _label.hide()
	_timer = Timer.new(); _timer.wait_time = 1; _timer.timeout.connect(_tick); add_child(_timer)
	seal.activated.connect(stop)

func begin() -> void:
	if anchors.size()<2 or seal.is_active(): return
	_remaining = maxi(interval,1); _label.text = str(_remaining); _label.show(); _timer.start()

func stop() -> void:
	_timer.stop(); _label.text = "✓" if seal.is_active() else ""; _label.visible = seal.is_active()

func _tick() -> void:
	_remaining -= 1
	if _remaining<=0:
		# Chọn trong n-1 điểm còn lại, không thử random lặp lại vô hạn.
		_index = (_index+_rng.randi_range(1,anchors.size()-1))%anchors.size()
		seal.global_position = anchors[_index].global_position
		seal.reset_physics_interpolation()
		seal.scale = Vector3.ONE*0.75
		seal.create_tween().tween_property(seal,"scale",Vector3.ONE,0.18).set_trans(Tween.TRANS_BACK)
		_remaining = maxi(interval,1)
	_label.text = str(_remaining)
