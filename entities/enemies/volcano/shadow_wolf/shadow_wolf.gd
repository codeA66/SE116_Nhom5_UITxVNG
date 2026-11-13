class_name ShadowWolf
extends Enemy
## Sói Bóng Đêm. Rình vòng quanh player và tan vào bóng tối (WolfStalk), gồng người rồi vồ từ xa (WolfPounce),
## cắn liên hoàn khi áp sát (WolfBite). Đi theo bầy: WolfPack cho mỗi lúc một con vồ.
## Sợ lửa: nhận thêm sát thương lửa, trúng lửa thì hiện rõ và bỏ chạy (WolfFlee); player cầm đuốc cháy
## hoặc đang bốc cháy thì không dám vồ / cắn. Script này là API mỏng cho các state.

signal pounce_started
signal pounce_landed(hit: bool)
signal feared

@export var pack: WolfPack

@export_group("Behaviour States")
@export var pounce_state: StringName = &"WolfPounce"
@export var flee_state: StringName = &"WolfFlee"

var wolf_data: ShadowWolfData
## Độ mờ hiện tại (0 = rõ, 1 = biến mất)
var fade: float = 0.0

var _pounce_cooldown_left: float = 0.0
var _fade_materials: Array[ShaderMaterial] = []
var _fade_tween: Tween

@onready var skeleton: Skeleton3D = $Model/Visual/ShadowWolfModel/ShadowWolfModel/Rig/Skeleton3D


func _ready() -> void:
	wolf_data = data as ShadowWolfData
	assert(wolf_data != null, "%s: EnemyData phải là ShadowWolfData" % name)
	assert(wolf_data.pounce_attack != null, "%s: ShadowWolfData thiếu pounce_attack" % name)
	super()
	hurtbox.resistances[DamageInfo.Type.FIRE] = wolf_data.fire_damage_multiplier
	_bind_fade_materials()
	died.connect(_on_wolf_died)


func _pre_state_update(delta: float) -> void:
	super(delta)
	_pounce_cooldown_left = maxf(_pounce_cooldown_left - delta, 0.0)


# ---------- Vồ / bầy ----------

## Đủ điều kiện vồ: hết hồi chiêu, mục tiêu không cầm lửa, và giành được lượt của bầy
func try_start_pounce() -> bool:
	if _pounce_cooldown_left > 0.0 or is_target_lit():
		return false
	return pack == null or pack.try_claim(self)


func end_pounce() -> void:
	_pounce_cooldown_left = wolf_data.pounce_cooldown
	if pack:
		pack.release(self)


func pounce_ready() -> bool:
	return _pounce_cooldown_left <= 0.0


# ---------- Sợ lửa / ánh sáng ----------

## Mục tiêu đang cầm đuốc cháy hoặc đang bốc cháy
func is_target_lit() -> bool:
	if not has_target():
		return false
	var torch := HandTorch.find_on(target)
	if torch and torch.is_lit:
		return true
	var burn := target.get_node_or_null(^"BurnableComponent") as BurnableComponent
	return burn != null and burn.is_burning()


# ---------- Tan vào bóng tối ----------

## Mờ dần tới amount (0 = rõ, 1 = mất) trong time giây; 0 giây = đổi ngay
func fade_to(amount: float, time: float = -1.0) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if time < 0.0:
		time = wolf_data.fade_time
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	if is_equal_approx(amount, fade):
		return
	if time <= 0.0:
		_apply_fade(amount)
		return
	_fade_tween = create_tween()
	_fade_tween.tween_method(_apply_fade, fade, amount, time)


# ---------- Nội bộ ----------

func _on_hurt(info: DamageInfo, damage_taken: int) -> void:
	super(info, damage_taken)
	# Trúng lửa (phun lửa, cầu lửa, TNT...): hiện rõ và bỏ chạy, thay cho khựng thường
	if info.type == DamageInfo.Type.FIRE and not is_dead():
		fade_to(0.0, 0.0)
		feared.emit()
		state_machine.transition_to(flee_state)


## Mỗi con một bản vật liệu thân để mờ riêng (mắt / răng dùng vật liệu sáng chung, luôn hiện)
func _bind_fade_materials() -> void:
	for node: Node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i: int in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(i) as ShaderMaterial
			if mat:
				var own := mat.duplicate() as ShaderMaterial
				mesh.set_surface_override_material(i, own)
				_fade_materials.append(own)


func _apply_fade(amount: float) -> void:
	fade = amount
	for mat: ShaderMaterial in _fade_materials:
		mat.set_shader_parameter(&"fade", amount)


func _on_wolf_died(_enemy: Enemy) -> void:
	fade_to(0.0, 0.0)
	if pack:
		pack.release(self)
