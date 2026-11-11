class_name ForgeSkillData
extends SkillData
## Kỹ năng thử nghiệm của tier 2 map Lửa (Lò Rèn Lòng Núi). Khác SkillData thường ở chỗ state FSM không nằm sẵn
## trong player.tscn: ForgeSkillInstaller tạo state từ state_script và gắn vào StateMachine của player lúc player
## xuất hiện trong khu. Nhờ vậy thêm kỹ năng không phải sửa player.gd / player.tscn.

## Script của state (lớp con ForgePlayerState); node state được đặt tên theo `state`
@export var state_script: Script
