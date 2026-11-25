class_name FireRainData
extends SkillData
## Thông số Mưa Hỏa Tiễn (Phun lửa cấp 2, kiểu chiêu R của Rumble): giữ phím tại điểm đầu, rê chuột chọn hướng,
## thả phím thì cầu lửa rơi lần lượt dọc một đường thẳng rồi để lại dải đất cháy. Chỉnh trong file .tres, không sửa code.

const ID := &"fire_rain"

## Đòn của mỗi cầu lửa (luật game: 1 sát thương, lửa không đẩy). Mỗi mục tiêu chỉ trúng 1 lần cả chiêu
@export var attack: AttackData

@export_group("Aim")
## Điểm đầu đường lửa (chỗ chuột lúc bấm) cách cáo tối đa bấy nhiêu mét
@export_range(1.0, 40.0, 0.5) var max_cast_range: float = 12.0
## Chuột còn gần điểm đầu hơn mức này thì chưa đủ để chọn hướng: đường chạy thẳng từ cáo qua điểm đầu
@export_range(0.05, 5.0, 0.05) var min_drag: float = 0.6
## Tốc độ đi lúc đang ngắm so với tốc độ chạy thường
@export_range(0.0, 1.0, 0.05) var aim_move_scale: float = 0.5

@export_group("Line")
## Đường lửa dài / rộng bấy nhiêu mét, tính từ điểm đầu
@export_range(0.5, 60.0, 0.1) var line_length: float = 10.0
@export_range(0.1, 12.0, 0.05) var line_width: float = 2.5
## Chiều cao vùng trúng / vùng đốt tính từ mặt sàn (m)
@export_range(0.5, 8.0, 0.1) var hit_height: float = 2.5

@export_group("Impacts")
## Số cầu lửa rơi dọc đường; mỗi quả phủ một đoạn bằng nhau của đường
@export_range(1, 40) var impact_count: int = 6
## Thời gian cầu lửa đầu tiên rơi tới đất kể từ lúc thả phím (s)
@export_range(0.0, 3.0, 0.01) var first_impact_delay: float = 0.35
## Từ quả đầu tới quả cuối chạm đất (s)
@export_range(0.0, 5.0, 0.01) var impact_spread_time: float = 0.6
## Cầu lửa rơi từ độ cao này (m) xuống điểm chạm: chỉ ảnh hưởng hình
@export_range(1.0, 40.0, 0.5) var drop_height: float = 10.0
## Dò sàn cho điểm chạm: từ trên đường bấy nhiêu mét xuống tới dưới đường bấy nhiêu mét. Không có sàn thì bỏ quả đó
@export_range(0.0, 20.0, 0.1) var floor_probe_up: float = 3.0
@export_range(0.0, 40.0, 0.1) var floor_probe_down: float = 6.0
@export_flags_3d_physics var floor_mask: int = 1
## Rung màn hình mỗi quả chạm đất
@export_range(0.0, 1.0, 0.01) var impact_shake: float = 0.22

@export_group("Burn")
## Dải đất cháy còn lại sau quả cuối (s); 0 = không có dải cháy
@export_range(0.0, 30.0, 0.1) var burn_lifetime: float = 4.0
## Thứ đứng trong dải được đốt lại mỗi bấy nhiêu giây (nên nhỏ hơn thời gian cháy của BurnData)
@export_range(0.1, 5.0, 0.05) var burn_refresh: float = 0.5
## Hình tàn (vết cháy xém mờ dần) sau khi dải tắt (s)
@export_range(0.0, 5.0, 0.05) var linger: float = 1.2

@export_group("Timing")
## Động tác thả sau khi nhả phím (s); hết thì về Idle / Run
@export_range(0.05, 2.0, 0.01) var cast_duration: float = 0.45
## Hồi chiêu tính từ lúc thả phím (s)
@export_range(0.0, 120.0, 0.1) var cooldown: float = 15.0

@export_group("Animation")
## Model cáo chưa có anim gọi mưa riêng, tạm dùng anim tung chiêu
@export var animation: StringName = &"Attack_Melee"
@export var anim_speed: float = 1.3


## Hồi chiêu bắt đầu đúng lúc thả phím (start_skill gọi lúc thả), không cộng thời gian ngắm
func get_lockout() -> float:
	return cooldown


## Mốc (s, tính từ lúc thả) quả thứ index chạm đất
func get_impact_time(index: int) -> float:
	if impact_count <= 1:
		return first_impact_delay
	return first_impact_delay + impact_spread_time * float(index) / float(impact_count - 1)
