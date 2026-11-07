class_name DialogueLine
extends Resource
## Một câu thoại. Người nói để trống = tên của NPC đang nói chuyện.

## Tên hiện trên hộp thoại; để trống = dùng tên NPC (dùng khi muốn chen lời người khác, ví dụ cáo đáp lại)
@export var speaker: String = ""
@export_multiline var text: String = ""
