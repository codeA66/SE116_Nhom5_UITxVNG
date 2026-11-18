class_name FireToadSkills
extends Resource
## Thông số 3 skill của Ếch Hoả Vương ở một mức (bình thường / cuồng loạn). Cuồng loạn = một file .tres khác,
## không sửa code: nâng cấp skill chỉ là đổi số.

@export_group("Nghỉ giữa các skill")
## Đứng nhìn player bao lâu trước skill kế (s)
@export_range(0.1, 10.0, 0.05) var idle_time: float = 1.4

@export_group("Skill 1: Mưa Hoả Cầu")
## Số quả mỗi đợt
@export_range(1, 30) var rain_count: int = 5
## Số đợt liên tiếp
@export_range(1, 5) var rain_waves: int = 1
## Nghỉ giữa hai đợt (s)
@export_range(0.1, 5.0, 0.05) var rain_wave_gap: float = 0.9
## Gồng phun lên trời (s) trước khi vòng báo hiện
@export_range(0.0, 3.0, 0.05) var rain_windup: float = 0.6
## Vòng báo hiện bao lâu thì cầu lửa chạm đất (s)
@export_range(0.2, 5.0, 0.05) var rain_warn_time: float = 1.0
## Bán kính nổ của mỗi quả (m)
@export_range(0.3, 6.0, 0.05) var rain_radius: float = 1.5
## Các quả ngoài quả nhắm thẳng player rải trong bán kính này quanh player (m)
@export_range(0.0, 15.0, 0.1) var rain_spread: float = 4.5
## Thu đòn sau đợt cuối (s)
@export_range(0.0, 3.0, 0.05) var rain_recover: float = 0.8

@export_group("Skill 2: Rút ra ngoài sân")
## Số nhện canh hiện ở các góc ngoài sân, bắn tơ vào player (tối đa bằng số bệ canh)
@export_range(0, 8) var sentinel_count: int = 2
## Nhện thứ hai trở đi hiện lệch nhau chừng này giây để không phun tơ cùng lúc
@export_range(0.0, 5.0, 0.05) var sentinel_stagger: float = 0.8
## Thời gian đứng ngoài sân (s) rồi nhảy về
@export_range(1.0, 30.0, 0.5) var retreat_duration: float = 8.0
## Bắn một loạt cầu lửa mỗi chừng này giây
@export_range(0.2, 10.0, 0.05) var retreat_shot_interval: float = 2.0
## Số quả mỗi loạt, xoè thành hình quạt (1 = bắn thẳng)
@export_range(1, 9) var retreat_shot_count: int = 3
## Góc xoè của cả quạt (độ)
@export_range(0.0, 120.0, 1.0) var retreat_shot_spread: float = 24.0
## Nhắm đón đầu: 0 = bắn vào chỗ player đang đứng, 1 = bắn vào chỗ player sẽ tới nếu giữ hướng chạy
@export_range(0.0, 1.5, 0.05) var retreat_shot_lead: float = 1.0
## Đổi sang bệ khác mỗi chừng này giây
@export_range(0.5, 20.0, 0.1) var retreat_hop_interval: float = 3.0

@export_group("Skill 3: Dậm Dung Nham")
## Số lần dậm tạo dung nham liên tiếp
@export_range(1, 8) var slam_count: int = 2
## Sau lần dậm cuối nhảy về giữa sân, không tạo dung nham (rời khỏi vũng vừa tạo)
@export var slam_return_center: bool = true
## Bán kính vũng dung nham (m)
@export_range(0.5, 10.0, 0.1) var lava_radius: float = 3.0
## Vũng dung nham tồn tại (s)
@export_range(0.2, 20.0, 0.1) var lava_lifetime: float = 4.0
## Vòng báo chỗ đáp hiện trước khi đáp (s)
@export_range(0.2, 3.0, 0.05) var slam_air_time: float = 0.9
