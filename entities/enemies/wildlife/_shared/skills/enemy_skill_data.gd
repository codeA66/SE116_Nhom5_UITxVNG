class_name EnemySkillData
extends AttackData
## Đòn riêng vẫn dùng AttackData để đi qua hitbox/hurtbox hiện có.
@export var skill_id: StringName
@export var state: StringName = &"SkillAttack"
@export var cooldown: float = 3.0
@export var minimum_range: float = 0.0
@export var maximum_range: float = 2.0
@export var windup_end: float = 0.4
@export var track_during_windup: bool = false
@export var melee_enabled: bool = true
@export var effect_scene: PackedScene
@export var effect_on_start: bool = false
@export var effect_after_animation: bool = false
@export var effect_at_target: bool = false
@export var effect_forward_offset: float = 0.8
## Đòn ném hồi riêng, không khóa hoặc chờ cooldown của đòn đánh gần.
@export var use_attack_cooldown: bool = true
@export var cooldown_affected_by_buff: bool = true
