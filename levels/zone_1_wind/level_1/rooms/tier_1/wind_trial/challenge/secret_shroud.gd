class_name SecretShroud
extends MeshInstance3D
## Lớp che phòng bí mật (tham khảo cách Hollow Knight che phòng ẩn): mái / khối che phủ kín phòng, đứng ngoài
## chỉ thấy như công trình bình thường. Material phải có transparency để mờ dần.
## Player bước vào reveal_area thì tan dần; ra khỏi thì phủ lại để phòng giữ vẻ bí mật khi nhìn từ ngoài.
## Hiệu năng: không có _process; chỉ nghe vào/ra của Area3D và chạy một tween ngắn. Tan hẳn thì ẩn mesh.

signal revealed
signal covered

@export var reveal_area: Area3D
@export_range(0.05, 3.0, 0.05) var fade_in_time: float = 0.9
@export_range(0.05, 3.0, 0.05) var fade_out_time: float = 0.6

var _material: StandardMaterial3D
var _tween: Tween
var _inside: int = 0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Material riêng: mỗi phòng bí mật tự mờ, không ảnh hưởng nhau
	_material = (material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	material_override = _material
	if reveal_area:
		reveal_area.body_entered.connect(_on_body_entered)
		reveal_area.body_exited.connect(_on_body_exited)


## Đúng khi màn che đang tan (player ở trong phòng)
func is_revealed() -> bool:
	return _inside > 0


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	_inside += 1
	if _inside == 1:
		_fade_to(0.0, fade_in_time)
		revealed.emit()


func _on_body_exited(body: Node3D) -> void:
	if not body is Player:
		return
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		_fade_to(1.0, fade_out_time)
		covered.emit()


func _fade_to(alpha: float, time: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	show()
	_tween = create_tween()
	_tween.tween_property(_material, ^"albedo_color:a", alpha, time)
	if alpha <= 0.0:
		_tween.tween_callback(hide)
