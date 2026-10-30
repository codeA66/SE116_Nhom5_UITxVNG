class_name IgniterArea
extends Area3D
## Vùng gây cháy: bật lên thì mọi BurnableComponent đi vào vùng bắt lửa (mỗi lần bật, mỗi mục tiêu một lần).
## Hai cách dùng:
## - follow_hitbox: bám theo một HitboxComponent (lửa phun Q, sau này kiếm lửa): bật/tắt và dùng chung shape với nó,
##   nên đổi tầm / độ rộng ở dữ liệu kỹ năng là vùng cháy đổi theo.
## - Tự đứng (luồng lửa lan, bẫy lửa...): tự thêm CollisionShape3D con rồi gọi activate() / deactivate().
## Chỉ quét layer "burnable" (lọc ở engine), không đụng hurtbox. Không đốt BurnableComponent của chính thực thể chứa nó.

## Phát mỗi lần một mục tiêu bắt lửa từ vùng này (VFX / âm thanh nghe)
signal ignited_target(burnable: BurnableComponent)

## Layer "burnable" trong Project Settings (layer 10)
const BURNABLE_LAYER := 10

## Hitbox để bám theo; để trống nếu vùng tự đứng
@export var follow_hitbox: HitboxComponent

var _active: bool = false
var _already_lit: Array[BurnableComponent] = []
var _follow_shape: CollisionShape3D
var _own_shape: CollisionShape3D


## Chỉ quét layer burnable; nếu bám hitbox thì tạo shape dùng chung và nghe signal bật/tắt của nó
func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(BURNABLE_LAYER, true)
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)
	if follow_hitbox == null:
		return
	_follow_shape = follow_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	_own_shape = CollisionShape3D.new()
	# Dùng chung resource: set_reach / set_cross_section của hitbox đổi luôn kích thước vùng cháy
	_own_shape.shape = _follow_shape.shape
	add_child(_own_shape)
	follow_hitbox.activated.connect(_on_hitbox_activated)
	follow_hitbox.deactivated.connect(deactivate)


## Đúng khi vùng đang bật
func is_active() -> bool:
	return _active


## Bật vùng: xoá danh sách đã đốt để lần phun mới đốt lại được; monitoring bật trễ 1 khung (không đổi trong callback vật lý)
func activate() -> void:
	_already_lit.clear()
	_active = true
	set_deferred(&"monitoring", true)


## Tắt vùng; gọi nhiều lần không sao
func deactivate() -> void:
	_active = false
	set_deferred(&"monitoring", false)


## Hitbox vừa bật: chép vị trí của hitbox và shape (shape đã được state kéo dài theo tầm) rồi bật vùng
func _on_hitbox_activated(_attack: AttackData) -> void:
	global_transform = follow_hitbox.global_transform
	_own_shape.transform = _follow_shape.transform
	activate()


## Mục tiêu dễ cháy đi vào vùng: đốt một lần mỗi lần bật, bỏ qua của chính mình
func _on_area_entered(area: Area3D) -> void:
	var burnable := area as BurnableComponent
	if not _active or burnable == null or burnable in _already_lit or _is_own(burnable):
		return
	_already_lit.append(burnable)
	burnable.ignite(owner)
	ignited_target.emit(burnable)


## Đúng khi mục tiêu thuộc cùng thực thể với vùng này (player tự phun không tự cháy)
func _is_own(burnable: BurnableComponent) -> bool:
	return owner != null and owner.is_ancestor_of(burnable)
