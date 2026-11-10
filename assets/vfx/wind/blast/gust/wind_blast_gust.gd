class_name WindBlastGust
extends WindBlastVisual
## Đọc mốc đòn thật và phát tín hiệu riêng cho các lớp vẽ; giữ đường gọi của scene cũ.
signal visual_charge(data: WindBlastData)
signal visual_burst(data: WindBlastData, span: float)
signal visual_dissolve(data: WindBlastData, span: float)
signal visual_reset

@export_group("Tail")
@export var linger_time: float = 0.35

var _cast_data: WindBlastData
var _charging_fx: bool = false
var _playing_fx: bool = false
var _dissolving_fx: bool = false
var _cast_age: float = 0.0
var _gust_span: float = 0.0

## Không khởi tạo lưới phễu cũ; các lớp con đã sẵn sàng khi nối vùng gió.
func _ready() -> void:
	top_level = true
	hide()
	set_process(false)
	if area == null:
		push_error("WindBlastGust cần WindBlastArea")
		return
	area.charge_started.connect(_start_charge)
	area.blast_started.connect(_start_gust)
	area.blast_stopped.connect(_stop_charge_if_interrupted)

## Chỉ bám tay trước khi bung, để phần gió đã phóng không quay theo nhân vật.
func _process(delta: float) -> void:
	if _charging_fx:
		_snap_to_area()
		return
	_cast_age += delta
	if not _dissolving_fx and _cast_age >= _gust_span:
		_dissolving_fx = true
		visual_dissolve.emit(_cast_data,maxf(linger_time,MIN_TIME))
	if _cast_age >= get_blast_time():
		_reset_visual()
		_notify_blast_finished()

## Test và các scene cũ vẫn đọc cùng trạng thái gồng.
func is_charging() -> bool:
	return _charging_fx

## Luồng chính và đuôi đều thuộc cùng một lượt vẽ hữu hạn.
func is_playing() -> bool:
	return _playing_fx

## Đo cả đuôi hiển thị để test biết lúc nào mọi lớp đã tắt.
func get_blast_time() -> float:
	return _gust_span+maxf(linger_time,MIN_TIME)

## Đồng bộ gồng với animation thông qua mốc phát từ state.
func _start_charge(data: WindBlastData) -> void:
	_reset_visual()
	_snap_to_area()
	_charging_fx = true
	show()
	set_process(true)
	visual_charge.emit(data)

## Chốt hướng và vị trí ở khung hitbox bật; đuôi tiếp tục sau khi hitbox tắt.
func _start_gust(data: WindBlastData) -> void:
	var had_charge: bool = _charging_fx
	_reset_visual()
	_snap_to_area()
	_cast_data = data
	_gust_span = maxf(data.duration-data.active_start,MIN_TIME)
	_cast_age = 0.0
	_playing_fx = true
	show()
	set_process(true)
	if had_charge:
		_notify_charge_finished()
	visual_burst.emit(data,_gust_span)

## Vùng đẩy cũng phát stop giữa lượt, chỉ hủy hình khi chưa bung.
func _stop_charge_if_interrupted() -> void:
	if _charging_fx:
		_reset_visual()

## Tắt cả lớp hình và tiếng trước khi dùng lại cùng instance.
func _reset_visual() -> void:
	_charging_fx = false
	_playing_fx = false
	_dissolving_fx = false
	hide()
	set_process(false)
	visual_reset.emit()

## Chỉ dùng trục ngang của vùng đẩy để hướng hình khớp lực.
func _snap_to_area() -> void:
	var forward: Vector3 = area.global_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(-forward.normalized()),area.global_position)
