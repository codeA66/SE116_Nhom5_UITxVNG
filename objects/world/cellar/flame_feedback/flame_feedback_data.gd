class_name FlameFeedbackData
extends Resource
## Thông số phản hồi của một ngọn lửa (đuốc cầm tay, đuốc tường...): bùng lên khi châm, chập chờn khi cháy,
## lập loè khi sắp tắt, khói khi tắt. Mỗi mức quan trọng là một file .tres trong resources/feedback/flame/.

@export_group("Châm lửa")
## Ngọn lửa vọt lên bằng này lần rồi nảy về 1 (TRANS_BACK)
@export var ignite_pop_scale: Vector3 = Vector3(1.4, 1.8, 1.4)
@export_range(0.05, 1.5, 0.01) var ignite_pop_time: float = 0.28
## Ánh sáng vọt lên bằng này lần năng lượng gốc rồi dịu về (ease-out)
@export_range(1.0, 5.0, 0.05) var flash_multiplier: float = 1.8
@export_range(0.05, 3.0, 0.01) var flash_settle_time: float = 0.45
@export_range(0, 64) var spark_amount: int = 14
## Rung màn hình qua ScreenShake (0 = không rung)
@export_range(0.0, 1.0, 0.01) var ignite_trauma: float = 0.15

@export_group("Đang cháy")
## Biên độ chập chờn của ánh sáng (tỉ lệ năng lượng)
@export_range(0.0, 1.0, 0.01) var flicker_amount: float = 0.12
@export_range(0.0, 40.0, 0.1) var flicker_speed: float = 9.0
## Cỡ ngọn lửa / ánh sáng thấp nhất khi gần hết giờ (lửa nhỏ dần cho người chơi thấy)
@export_range(0.05, 1.0, 0.01) var burn_min_intensity: float = 0.55

@export_group("Sắp tắt")
@export_range(0.0, 1.0, 0.01) var sputter_flicker_amount: float = 0.45
@export_range(0.0, 60.0, 0.1) var sputter_flicker_speed: float = 18.0

@export_group("Tắt")
@export_range(0, 64) var smoke_amount: int = 10

@export_group("Hạt lửa")
## Nhân kích thước + tốc độ bay của hạt: đuốc cầm tay ~0.8, đuốc tường ~1.3, lửa trại ~2.2
@export_range(0.2, 6.0, 0.05) var particle_size: float = 1.0
## Bán kính nơi hạt sinh ra (m): rộng cho lửa trại, hẹp cho đuốc
@export_range(0.01, 1.5, 0.01) var emission_radius: float = 0.06
## Nhân cỡ từng hạt (độc lập với chiều cao): hạt to chồng nhau thì cháy trắng, nhỏ quá thì rời rạc
@export_range(0.1, 4.0, 0.05) var blob_scale: float = 1.0
## Số hạt đồng thời (0 = tắt lớp đó). Giữ nhỏ vì đuốc có thể nhiều cái cùng lúc
@export_range(0, 80) var flame_amount: int = 24
@export_range(0, 24) var plume_amount: int = 6
@export_range(0, 24) var ember_amount: int = 5
## Khói bắt đầu cách tâm lửa bao nhiêu m về phía trên
@export_range(0.0, 2.0, 0.01) var plume_height: float = 0.3

@export_group("Ánh sáng sống")
## Đèn lệch ngẫu nhiên tối đa bấy nhiêu m quanh vị trí gốc (ánh sáng nhảy theo ngọn lửa)
@export_range(0.0, 0.5, 0.005) var light_wobble: float = 0.06
@export_range(0.0, 20.0, 0.1) var light_wobble_speed: float = 5.0
## Màu đèn ngả đỏ khi ngọn lửa xẹp xuống (0 = màu cố định)
@export_range(0.0, 1.0, 0.01) var color_flicker: float = 0.35
## Ngả đỏ thêm theo mức cạn của đuốc
@export_range(0.0, 1.0, 0.01) var dying_red_shift: float = 0.5
## Đèn phụ đỏ cam sát ngọn: vùng sáng gần, 0 = không dùng
@export_range(0.0, 8.0, 0.05) var fill_light_energy: float = 0.8
@export_range(0.5, 12.0, 0.1) var fill_light_range: float = 2.2
## Mesh ngọn lửa trong model chỉ còn là lõi sáng: nhân cỡ này để hạt lửa mới là phần nhìn chính (1 = nguyên cỡ cũ)
@export_range(0.1, 1.5, 0.05) var core_scale: float = 0.6
## Mô phỏng sẵn bấy nhiêu giây khi hạt bắt đầu phát, để lửa bùng đầy ngay thay vì thưa dần lên (0 = từ trống, dùng cho đuốc)
@export_range(0.0, 2.0, 0.05) var preprocess: float = 0.0
