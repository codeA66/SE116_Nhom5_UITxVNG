class_name PasswordUnlock
extends UnlockCondition
## Cần đã nhập đúng mật khẩu (bản đưa người test chơi thử). Chỉ lưu mã băm SHA-256 nên đọc file game không ra chữ gốc.
## Nhớ theo máy (user://access.cfg), không theo save: nhập một lần, save mới không phải nhập lại.
## Mỗi cổng / mỗi mật khẩu một access_id riêng, nên thêm cổng cần mật khẩu khác chỉ là thêm resource.

const SECTION := "unlocked"

## File lưu những mật khẩu đã nhập đúng trên máy này. Test đổi sang file riêng
static var store_path: String = "user://access.cfg"

## Tên mục lưu trong file (khác nhau giữa các cổng dùng mật khẩu khác nhau)
@export var access_id: StringName = &"tester_access"
## SHA-256 (hex thường) của mật khẩu đã bỏ khoảng trắng hai đầu
@export var password_sha256: String = ""
@export var hint: String = "Cần mật khẩu"


func _init() -> void:
	# Mật khẩu chỉ hỏi lúc bước vào cổng, cổng vẫn mở / chiếu lễ thức khi thắng khu trước
	check_on_entry = true


func is_met() -> bool:
	var config := ConfigFile.new()
	if config.load(store_path) != OK:
		return false
	return config.get_value(SECTION, String(access_id), "") == password_sha256 and not password_sha256.is_empty()


func get_hint() -> String:
	return hint


## Đúng thì ghi nhớ trên máy rồi trả true. Không phân biệt khoảng trắng thừa hai đầu, có phân biệt hoa thường
func try_password(text: String) -> bool:
	var entered := text.strip_edges()
	if entered.is_empty() or password_sha256.is_empty() or entered.sha256_text() != password_sha256:
		return false
	var config := ConfigFile.new()
	config.load(store_path)
	# Lưu chính mã băm: đổi mật khẩu thì máy đã nhập mật khẩu cũ phải nhập lại
	config.set_value(SECTION, String(access_id), password_sha256)
	var error := config.save(store_path)
	if error != OK:
		push_error("PasswordUnlock: không ghi được %s (lỗi %d)" % [store_path, error])
	return true


## Đặt mật khẩu mới (chỉ lưu mã băm); dùng cho công cụ dev và test, game không gọi
func set_password(text: String) -> void:
	password_sha256 = text.strip_edges().sha256_text()
