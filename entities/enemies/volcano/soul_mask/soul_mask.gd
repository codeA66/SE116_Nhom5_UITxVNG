class_name SoulMask
extends FlyingEnemy
## Đầu Lửa: đầu lâu bay lượn vòng quanh player, há miệng tụ lực rồi bắn một tia thẳng.
## Script chỉ là API mỏng cho các state (Orbit, Charge, Beam, Recover): hàm, miệng, hướng ngắm, tia.

signal charge_started
signal beam_fired(from: Vector3, to: Vector3)

@export_group("Behaviour States")
@export var beam_state: StringName = &"Beam"
@export var recover_state: StringName = &"Recover"
@export_group("Model")
## Node hàm dưới trong model (xoay quanh trục X dương để há)
@export var jaw_path: NodePath
@export var muzzle_path: NodePath

var soul_data: SoulMaskData
## Hướng tia đã khoá ở cuối lúc tụ lực; state Beam đọc
var locked_direction: Vector3 = Vector3.FORWARD

var _jaw: Node3D
var _jaw_tween: Tween

@onready var beam: SoulBeam = $SoulBeam
@onready var _muzzle: Marker3D = get_node(muzzle_path) as Marker3D


func _ready() -> void:
	soul_data = data as SoulMaskData
	assert(soul_data != null and soul_data.beam != null and soul_data.hover != null and soul_data.attack != null,
		"%s: cần SoulMaskData có beam / hover / attack" % name)
	super()
	hover.stats = soul_data.hover
	_jaw = get_node_or_null(jaw_path) as Node3D
	var exclude: Array[RID] = [get_rid()]
	beam.setup(soul_data.beam, soul_data.attack, exclude)
	beam.fired.connect(func(from: Vector3, to: Vector3) -> void: beam_fired.emit(from, to))
	died.connect(_on_soul_died)


# ---------- Ngắm ----------

func muzzle_position() -> Vector3:
	return _muzzle.global_position


## Hướng 3D từ miệng tới ngực mục tiêu; không có mục tiêu thì nhìn thẳng
func aim_direction() -> Vector3:
	if not has_target():
		return get_facing_direction()
	var point := target.global_position + Vector3.UP * soul_data.beam.target_height
	return (point - muzzle_position()).normalized()


# ---------- Hàm ----------

## Há hàm tới góc jaw_open_degrees * amount trong duration giây (0 = tức thì)
func set_jaw(amount: float, duration: float) -> void:
	if _jaw == null:
		return
	if _jaw_tween:
		_jaw_tween.kill()
	var angle := deg_to_rad(soul_data.beam.jaw_open_degrees) * amount
	if duration <= 0.0:
		_jaw.rotation.x = angle
		return
	_jaw_tween = create_tween()
	_jaw_tween.tween_property(_jaw, ^"rotation:x", angle, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func jaw_angle() -> float:
	return _jaw.rotation.x if _jaw else 0.0


# ---------- Tia ----------

func begin_charge() -> void:
	set_jaw(1.0, soul_data.beam.charge_time)
	charge_started.emit()


func update_warning(direction: Vector3) -> void:
	beam.show_warning(muzzle_position(), direction)


## Chớp trắng vạch cảnh báo lúc khoá hướng (SoulCharge gọi theo nhịp lock_flashes)
func flash_warning(on: bool) -> void:
	beam.set_warning_flash(on)


func fire_beam(direction: Vector3) -> void:
	beam.fire(muzzle_position(), direction)
	if soul_data.beam.fire_trauma > 0.0:
		ScreenShake.add_trauma(soul_data.beam.fire_trauma)


func stop_beam() -> void:
	beam.stop()


func _on_soul_died(_enemy: Enemy) -> void:
	stop_beam()
	set_jaw(0.0, 0.2)
