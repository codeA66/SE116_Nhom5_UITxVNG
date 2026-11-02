class_name BurnData
extends Resource
## Thông số trạng thái cháy của một loại quái / vật. Quái nào cần khác (quái Map Lửa miễn nhiễm...) thì tạo .tres riêng.

## Miễn nhiễm: ignite() không có tác dụng
@export var immune: bool = false
## Cháy kéo dài bao lâu kể từ lần bị đốt gần nhất (s); 0 = không cháy
@export_range(0.0, 60.0, 0.05, "or_greater") var duration: float = 2.0
## Khoảng giữa hai lần mất máu (s); tick đầu tiên rơi sau đúng khoảng này kể từ lúc bắt lửa
@export_range(0.05, 10.0, 0.05, "or_greater") var tick_interval: float = 1.5
## Máu mất mỗi tick (luật game: 1)
@export var tick_damage: int = 1
## Tick xuyên bất tử sau trúng đòn: không thì quái / boss có i-frames sẽ "nuốt" tick
@export var ignores_invincibility: bool = true
