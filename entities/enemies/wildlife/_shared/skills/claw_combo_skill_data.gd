class_name ClawComboSkillData
extends EnemySkillData
## Mỗi cửa sổ là một cú cào riêng trong cùng clip; đồng hồ được state chia theo buff.
@export var hit_windows: Array[Vector2] = []
@export var slash_radius: float = 2.6
@export var slash_arc_degrees: float = 145.0
@export var slash_height: float = 1.05
@export var hit_height: float = 2.15
