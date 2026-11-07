class_name TollData
extends Resource
## Chữ và tên hoạt ảnh của cổng thu tiền (dùng chung cho mọi kẻ gác cổng cùng kiểu).
## Giá, loại tiền, cờ lưu là của từng cổng: đặt trên TollService của từng con.
## Trong chữ dùng được {price} (giá), {currency} (tên tiền), {have} (đang có).

@export_multiline var question: String = "(Chữ tạm) Muốn qua thì trả {price} {currency}. Ngươi đang có {have}."
@export var pay_option: String = "Trả {price}"
@export var decline_option: String = "Thôi"
## Nói sau khi nhận tiền, trước khi bước sang bên
@export var thanks_lines: Array[DialogueLine] = []
## Nói khi bấm Trả mà không đủ tiền
@export var refuse_lines: Array[DialogueLine] = []
## Nói khi chọn Thôi
@export var decline_lines: Array[DialogueLine] = []

@export_group("Hoạt ảnh")
@export var accept_animation: StringName = &"Accept"
@export var refuse_animation: StringName = &"Refuse"
@export var step_aside_animation: StringName = &"StepAside"
@export var idle_aside_animation: StringName = &"IdleAside"
