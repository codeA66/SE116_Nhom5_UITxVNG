class_name DetailEntry
extends RefCounted
## Nội dung bảng chi tiết bên phải màn Tab. Mỗi loại ô tự dựng một DetailEntry; bảng chỉ hiển thị,
## không biết đó là nguyên tố, vũ khí hay vật phẩm. Thêm loại ô mới không cần sửa bảng.

var title: String = ""
## Dòng nhỏ dưới tên (cấp, loại vật phẩm...)
var subtitle: String = ""
var accent: Color = Color.WHITE
## Hình: kỹ năng có hình cáo dựng từ model (ưu tiên), không thì ảnh / biểu tượng
var art_ability: AbilityData
var art_texture: Texture2D
## Từng đoạn: tiêu đề nhỏ + nội dung; warning = tô màu cảnh báo (thiếu vật phẩm...)
var sections: Array[Dictionary] = []
## Câu truyện nhỏ cuối bảng
var lore: String = ""
## Dòng hướng dẫn thao tác ở đáy bảng
var hint: String = ""


func add_section(heading: String, text: String, warning: bool = false) -> DetailEntry:
	if not text.is_empty():
		sections.append({"heading": heading, "text": text, "warning": warning})
	return self
