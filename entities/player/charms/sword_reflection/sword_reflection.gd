extends Node
## Dùng vùng kiếm thật để phản đạn khớp từng nhát, kể cả khi nhát bị ngắt.

const RECEIVER_LAYER: int = 8
const REFLECT_METHOD: StringName = &"try_reflect_by_sword"

var _player: Player
var _hitbox: HitboxComponent
var _push_speed: float
var _original_receiver_mask: bool


func _ready() -> void:
	_hitbox = _player.hitbox
	_original_receiver_mask = _hitbox.get_collision_mask_value(RECEIVER_LAYER)
	_hitbox.set_collision_mask_value(RECEIVER_LAYER, true)
	_hitbox.area_entered.connect(_on_area_entered)


func _exit_tree() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.area_entered.disconnect(_on_area_entered)
		_hitbox.set_collision_mask_value(RECEIVER_LAYER, _original_receiver_mask)


func configure(player: Player, push_speed: float) -> void:
	_player = player
	_push_speed = push_speed


func release() -> void:
	# Bỏ kết nối ngay trước khi CharmHolder áp lại bùa trong cùng khung hình.
	get_parent().remove_child(self)
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	if not _hitbox.is_active() or _player.health.is_dead():
		return
	var weapon: WeaponData = _player.get_weapon()
	if weapon == null or weapon.slot != WeaponData.Slot.SWORD:
		return
	var projectile: Node = area.get_parent() if area is WindReceiverComponent else area
	if projectile != null and projectile.has_method(REFLECT_METHOD):
		projectile.call(REFLECT_METHOD, _player.get_facing_direction() * _push_speed, _player)
