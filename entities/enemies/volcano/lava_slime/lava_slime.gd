class_name LavaSlime
extends Enemy
## Slime Dung Nham: nảy tới gần player (SlimeHop), vào tầm thì đứng lại châm ngòi, phình to và nháy (SlimeFuse),
## hết ngòi thì nổ (ExplosionComponent) và chết. Kiểu Creeper: player chạy ra ngoài fuse_cancel_range thì
## ngòi xẹp dần; ngòi không reset về 0 ngay nên quay lại sát slime thì nổ sớm hơn.
## Bị giết trước khi nổ thì không nổ (tan thành vũng). Kháng lửa, sợ gió (bị thổi văng làm ngắt châm ngòi).
## Script này là API mỏng cho các state: tiến độ ngòi, phình, nổ.

signal fuse_started
signal fuse_cancelled
signal exploded(center: Vector3, hit_count: int)

const ANIM_SWELL := &"Swell"
const ANIM_DEFLATE := &"Deflate"

var slime_data: LavaSlimeData
## Tiến độ ngòi 0..1 (1 = nổ)
var fuse: float = 0.0
var has_exploded: bool = false

var _fusing: bool = false

@onready var explosion: ExplosionComponent = $ExplosionComponent
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _fuse_sound: AudioStreamPlayer3D = $FuseSound


func _ready() -> void:
	slime_data = data as LavaSlimeData
	assert(slime_data != null, "%s: EnemyData phải là LavaSlimeData" % name)
	super()
	hurtbox.resistances[DamageInfo.Type.FIRE] = slime_data.fire_damage_multiplier
	var burnable := get_node_or_null(^"BurnableComponent") as BurnableComponent
	if burnable and slime_data.fire_immune:
		burnable.set_enabled(false)
	explosion.attack = slime_data.attack
	explosion.radius = slime_data.explosion_radius
	explosion.ignite_targets = slime_data.explosion_ignites
	explosion.exploded.connect(func(center: Vector3, hits: int) -> void: exploded.emit(center, hits))


func _pre_state_update(delta: float) -> void:
	super(delta)
	# Không châm thì ngòi tụt dần (kiểu Creeper)
	if not _fusing and fuse > 0.0:
		fuse = maxf(fuse - delta / slime_data.fuse_decay_time, 0.0)


func is_fusing() -> bool:
	return _fusing


## Độ dài clip (s); 0 nếu model chưa có clip đó
func get_animation_length(anim_name: StringName) -> float:
	return _anim_player.get_animation(anim_name).length if _anim_player.has_animation(anim_name) else 0.0


## Bắt đầu / tiếp tục châm ngòi từ tiến độ hiện tại: clip Swell chạy khớp fuse_time và nhảy tới đúng tiến độ
func begin_fuse() -> void:
	_fusing = true
	set_telegraph(true)
	if _anim_player.has_animation(ANIM_SWELL):
		var length := _anim_player.get_animation(ANIM_SWELL).length
		_anim_player.play(ANIM_SWELL, 0.05, length / slime_data.fuse_time)
		_anim_player.seek(fuse * length, true)
	if _fuse_sound.stream:
		_fuse_sound.play()
	fuse_started.emit()


## Cộng tiến độ ngòi; trả về true khi đầy (phải nổ)
func advance_fuse(delta: float) -> bool:
	fuse = minf(fuse + delta / slime_data.fuse_time, 1.0)
	return fuse >= 1.0


## Dừng châm (player chạy xa, bị thổi / đánh văng): xì hơi xẹp lại, ngòi tụt dần ở _pre_state_update
func end_fuse() -> void:
	if not _fusing:
		return
	_fusing = false
	set_telegraph(false)
	_fuse_sound.stop()
	if not is_dead() and _anim_player.has_animation(ANIM_DEFLATE):
		play_action(ANIM_DEFLATE)
	fuse_cancelled.emit()


## Nổ ngay: gây đòn quanh mình, ẩn hình rồi chết (Dead lo phần dọn xác)
func explode() -> void:
	if has_exploded or is_dead():
		return
	has_exploded = true
	_fusing = false
	set_telegraph(false)
	_fuse_sound.stop()
	explosion.explode(self)
	model.visible = false
	_die_now()
