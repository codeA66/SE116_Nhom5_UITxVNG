class_name CurrencyData
extends Resource
## Định nghĩa một loại tiền (Soul Jade, ...). Thêm loại tiền mới = thêm file .tres, không sửa code.
## Số tiền người chơi đang có nằm ở PlayerProgress.currencies theo id; đọc / cộng / trừ qua GameState.

## Khoá lưu trong tiến trình và file save; đặt một lần, đổi sau sẽ mất tiền trong save cũ
@export var id: StringName
## Tên hiện cho người chơi (tiếng Anh)
@export var display_name: String = ""
## Icon trên HUD / cửa hàng (để trống nếu chưa có)
@export var icon: Texture2D
## Màu chủ đạo (HUD, viên rơi)
@export var color: Color = Color.WHITE
## Scene viên rơi của loại tiền này (root dùng script CurrencyPickup); để trống thì nhặt cộng thẳng, không có viên bay
@export var pickup_scene: PackedScene
## Hiệu ứng ở chỗ rơi (một lần mỗi lần rơi) và ở người nhặt (mỗi lần nhặt, có giới hạn tần suất); root dùng PickupVfx. Để trống = không có
@export var drop_vfx_scene: PackedScene
@export var collect_vfx_scene: PackedScene
