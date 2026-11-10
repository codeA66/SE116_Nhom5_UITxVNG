extends PlayerState
## Nhặt vũ khí: đứng yên, chạy anim PickUp, gắn vũ khí vào tay ở giữa animation.

## Mốc (giây) gắn vũ khí vào tay, khớp lúc tay nhặt lên
@export var equip_time: float = 0.6
@export var duration: float = 1.1

var _elapsed: float = 0.0
var _equipped: bool = false
var _picked_weapon: WeaponData = null


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_equipped = false
	_picked_weapon = player.pending_weapon
	player.play_action(Player.ANIM_PICK_UP)


func exit() -> void:
	# Bị ngắt giữa chừng vẫn phải nhận vũ khí
	if not _equipped and player.pending_weapon:
		player.equip_weapon(player.pending_weapon)
	_trigger_weapon_tutorial()


func _trigger_weapon_tutorial() -> void:
	if _picked_weapon == null:
		return
	var weapon := _picked_weapon
	_picked_weapon = null
	if weapon is BowData or weapon.slot == WeaponData.Slot.BOW:
		GameState.unlock_tutorial(&"bow")
	elif weapon.slot == WeaponData.Slot.SWORD:
		GameState.unlock_tutorial(&"sword")


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_gravity(delta)
	player.move_toward_direction(Vector3.ZERO, delta)

	if not _equipped and _elapsed >= equip_time:
		player.equip_weapon(player.pending_weapon)
		_equipped = true
	if _elapsed >= duration:
		state_machine.transition_to(IDLE)
