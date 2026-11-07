class_name NewGameData
extends Resource
## Thứ người chơi có sẵn khi bắt đầu game (kể cả save cũ thiếu chúng).
## Thêm/bớt kỹ năng khởi đầu trong file .tres, không sửa code.

@export var starting_abilities: Array[AbilityData] = []
## Số ô khắc bùa lúc bắt đầu game
@export_range(0, 12) var charm_notches: int = 3
