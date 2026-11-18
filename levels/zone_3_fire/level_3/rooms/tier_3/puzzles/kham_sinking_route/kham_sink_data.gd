class_name KhamSinkData
extends Resource
## Chia đường thành ô độc lập, chỉ những ô player chạm mới sập.

@export var tile_size: Vector2 = Vector2(1.8, 1.8)
@export_range(1, 256, 1) var max_tiles_per_body: int = 128
@export var trigger_on_exit: bool = false
@export var crumble: CrumblingFloorData
