extends Node
## Luật export (docs/export_release_rules.md): script chạy trong game không được gọi hàm / class chỉ có trong editor.
## Bản release không có các hàm này nên script không biên dịch được, kéo theo mọi lớp con (lỗi 13/11/2026: pickup.gd).
## Quét mọi file .gd được đưa vào bản export, chạy được cả headless. Thêm luật mới = thêm một hàm _rule_* rồi gọi trong
## _check_source(), không sửa phần quét.
##
## ===== USE CASE =====
## UC1  Code hiện tại của project không vi phạm (CI báo đỏ ngay ở PR nếu ai đó thêm lời gọi sai).
## UC2  Gọi _get_configuration_warnings() mà script và các lớp cha không tự khai báo hàm này -> báo lỗi.
## UC3  Script tự khai báo (hoặc lớp cha khai báo) _get_configuration_warnings() rồi gọi -> hợp lệ.
## UC4  Dùng class Editor* (EditorInterface, EditorPlugin...) trong script game -> báo lỗi.
## UC5  Script chỉ dành cho editor (extends Editor*, ví dụ *_import.gd) và thư mục không export (addons/, tests/, output/,
##      thư mục có .gdignore) -> bỏ qua. Chữ nằm trong comment hay chuỗi -> bỏ qua.
##
## ===== TEST CASE =====
## TC1 (UC2)  Mẫu gọi hàm không khai báo -> 1 lỗi.
## TC2 (UC3)  Mẫu tự khai báo rồi gọi -> 0 lỗi; mẫu lớp con gọi hàm lớp cha đã khai báo -> 0 lỗi.
## TC3 (UC4)  Mẫu dùng EditorInterface -> 1 lỗi; Engine.is_editor_hint() -> 0 lỗi.
## TC4 (UC5)  Mẫu extends EditorScenePostImport -> 0 lỗi; tên hàm chỉ nằm trong comment / chuỗi -> 0 lỗi.
## TC5 (UC1)  Quét toàn project: 0 lỗi, và quét được trên 100 script (không lặng lẽ quét 0 file).

## Thư mục không vào bản export (khớp exclude_filter trong export_presets.cfg) hoặc chỉ dùng trong editor
const SKIP_DIRS: PackedStringArray = ["res://addons", "res://tests", "res://output", "res://.godot"]
const WARNINGS_FUNC := "_get_configuration_warnings"
## Số script tối thiểu phải quét được; ít hơn nghĩa là đường quét hỏng chứ không phải project sạch
const MIN_SCRIPTS: int = 100

var _fails: int = 0
var _editor_class := RegEx.create_from_string("\\bEditor[A-Z]\\w*")
var _warnings_call := RegEx.create_from_string("\\b" + WARNINGS_FUNC + "\\s*\\(")
var _warnings_decl := RegEx.create_from_string("^\\s*(static\\s+)?func\\s+" + WARNINGS_FUNC + "\\s*\\(")
var _extends := RegEx.create_from_string("^\\s*extends\\s+(\"[^\"]+\"|\\w+)")
var _class_name := RegEx.create_from_string("^\\s*class_name\\s+(\\w+)")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tc1_undeclared_call()
	_tc2_declared_call()
	_tc3_editor_class()
	_tc4_skipped()
	_tc5_project()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _tc1_undeclared_call() -> void:
	var src := "extends Node\nfunc _ready() -> void:\n\tvar w := _get_configuration_warnings()\n"
	var errors := _check_source("res://sample_a.gd", src, {"res://sample_a.gd": src}, {})
	_check(errors.size() == 1, "TC1: gọi %s() khi không khai báo -> %d lỗi (cần 1)" % [WARNINGS_FUNC, errors.size()])


func _tc2_declared_call() -> void:
	var own := "extends Node\nfunc _ready() -> void:\n\tupdate(_get_configuration_warnings())\n" \
		+ "func _get_configuration_warnings() -> PackedStringArray:\n\treturn []\n"
	var errors := _check_source("res://own.gd", own, {"res://own.gd": own}, {})
	_check(errors.is_empty(), "TC2: tự khai báo rồi gọi -> %d lỗi (cần 0)" % errors.size())
	var parent := "class_name SampleParent\nextends Node3D\nfunc _get_configuration_warnings() -> PackedStringArray:\n" \
		+ "\treturn []\n"
	var child := "extends SampleParent\nfunc _ready() -> void:\n\tprint(_get_configuration_warnings())\n"
	var sources := {"res://parent.gd": parent, "res://child.gd": child}
	errors = _check_source("res://child.gd", child, sources, {&"SampleParent": "res://parent.gd"})
	_check(errors.is_empty(), "TC2: lớp cha đã khai báo -> lớp con gọi được (%d lỗi, cần 0)" % errors.size())


func _tc3_editor_class() -> void:
	var bad := "extends Node\nfunc _ready() -> void:\n\tvar s := EditorInterface.get_selection()\n"
	var errors := _check_source("res://bad.gd", bad, {}, {})
	_check(errors.size() == 1, "TC3: dùng EditorInterface trong script game -> %d lỗi (cần 1)" % errors.size())
	var ok := "extends Node\nfunc _ready() -> void:\n\tif Engine.is_editor_hint():\n\t\treturn\n"
	errors = _check_source("res://ok.gd", ok, {}, {})
	_check(errors.is_empty(), "TC3: Engine.is_editor_hint() hợp lệ (%d lỗi, cần 0)" % errors.size())


func _tc4_skipped() -> void:
	var importer := "@tool\nextends EditorScenePostImport\nfunc _post_import(scene: Node) -> Object:\n\treturn scene\n"
	var errors := _check_source("res://x_import.gd", importer, {}, {})
	_check(errors.is_empty(), "TC4: script extends EditorScenePostImport bị bỏ qua (%d lỗi, cần 0)" % errors.size())
	var text_only := "extends Node\n## Gọi _get_configuration_warnings() làm hỏng bản release, xem EditorInterface\n" \
		+ "func _ready() -> void:\n\tprint(\"_get_configuration_warnings() EditorPlugin\") # EditorInterface\n"
	errors = _check_source("res://doc.gd", text_only, {"res://doc.gd": text_only}, {})
	_check(errors.is_empty(), "TC4: chỉ nhắc trong comment / chuỗi -> %d lỗi (cần 0)" % errors.size())


func _tc5_project() -> void:
	var paths: PackedStringArray = []
	_collect("res://", paths)
	var sources := {}
	var classes := {}
	for path: String in paths:
		var src := FileAccess.get_file_as_string(path)
		sources[path] = src
		for line: String in src.split("\n"):
			var m := _class_name.search(line)
			if m:
				classes[StringName(m.get_string(1))] = path
				break
	var errors: PackedStringArray = []
	for path: String in paths:
		errors.append_array(_check_source(path, sources[path], sources, classes))
	for line: String in errors:
		print("   ", line)
	_check(paths.size() >= MIN_SCRIPTS, "TC5: quét %d script (cần >= %d)" % [paths.size(), MIN_SCRIPTS])
	_check(errors.is_empty(), "TC5: toàn project không gọi hàm chỉ có trong editor (%d chỗ sai)" % errors.size())


## Trả danh sách lỗi "đường dẫn:dòng: lý do" của một script. Script chỉ dành cho editor thì bỏ qua cả file.
func _check_source(path: String, src: String, sources: Dictionary, classes: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var parent := _parent_of(src)
	if parent.begins_with("Editor"):
		return errors
	var lines := src.split("\n")
	for i in lines.size():
		var code := _strip_text(lines[i])
		_rule_editor_class(path, i, code, errors)
		_rule_warnings_call(path, i, code, src, sources, classes, errors)
	return errors


## Class Editor* chỉ tồn tại trong editor
func _rule_editor_class(path: String, line: int, code: String, errors: PackedStringArray) -> void:
	var m := _editor_class.search(code)
	if m:
		errors.append("%s:%d: dùng %s (chỉ có trong editor)" % [path, line + 1, m.get_string()])


## _get_configuration_warnings() chỉ gọi được khi script hoặc lớp cha tự khai báo
func _rule_warnings_call(path: String, line: int, code: String, src: String, sources: Dictionary, classes: Dictionary,
		errors: PackedStringArray) -> void:
	if not _warnings_call.search(code) or _warnings_decl.search(code):
		return
	if _declares_warnings(src, sources, classes, 0):
		return
	errors.append("%s:%d: gọi %s() nhưng script / lớp cha không tự khai báo (bản release không có hàm này)"
		% [path, line + 1, WARNINGS_FUNC])


func _declares_warnings(src: String, sources: Dictionary, classes: Dictionary, depth: int) -> bool:
	for line: String in src.split("\n"):
		if _warnings_decl.search(line):
			return true
	var parent := _parent_of(src)
	if depth > 16 or parent.is_empty():
		return false
	var parent_path: String = parent.trim_prefix("\"").trim_suffix("\"") if parent.begins_with("\"") \
		else String(classes.get(StringName(parent), ""))
	if parent_path.is_empty() or not sources.has(parent_path):
		return false
	return _declares_warnings(sources[parent_path], sources, classes, depth + 1)


func _parent_of(src: String) -> String:
	for line: String in src.split("\n"):
		var m := _extends.search(line)
		if m:
			return m.get_string(1)
	return ""


## Bỏ chuỗi và comment để chữ trong đó không bị tính là lời gọi thật
func _strip_text(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote.is_empty():
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
			else:
				out += c
		elif c == "\\":
			i += 1
		elif c == quote:
			quote = ""
		i += 1
	return out


func _collect(dir_path: String, out: PackedStringArray) -> void:
	for skip: String in SKIP_DIRS:
		if dir_path.trim_suffix("/") == skip:
			return
	if FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
