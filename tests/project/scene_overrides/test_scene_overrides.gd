extends Node
## Luật export: ghi đè thuộc tính lên node con của scene nhúng (instance) chỉ được giữ khi export nếu instance đó có
## dòng [editable path="..."] trong .tscn. Editor đọc thẳng .tscn nên vẫn chạy đúng, bản release thì mất ghi đè
## (lỗi 28/11/2026: người chèo đò phòng 10 không tặng bùa, boss tier 2 lệch chỗ, màn chắn đền hiện ra).
## Quét mọi .tscn được export, chạy được headless. Công cụ sửa tự động: python dev/tools/scene_overrides.py --fix
##
## ===== USE CASE =====
## UC1  Scene hiện tại không còn ghi đè nào thiếu [editable] (CI báo đỏ ngay ở PR nếu ai đó thêm).
## UC2  Ghi đè node con của instance mà thiếu [editable] của instance đó -> báo lỗi.
## UC3  Có [editable] đúng instance -> hợp lệ; node có type hoặc instance riêng (node mới) -> không phải ghi đè.
## UC4  Ghi đè xuyên qua instance lồng trong scene con (.tscn) -> cần [editable] cả instance ngoài lẫn instance lồng.
##
## ===== TEST CASE =====
## TC1 (UC2)  Mẫu ghi đè "Npc/Story" thiếu [editable path="Npc"] -> 1 lỗi.
## TC2 (UC3)  Cùng mẫu có [editable path="Npc"] -> 0 lỗi; node mới type="Node" dưới instance -> 0 lỗi.
## TC3 (UC4)  Mẫu ghi đè xuyên instance lồng (scene con .tscn có instance) -> báo thiếu instance lồng.
## TC4 (UC1)  Quét toàn project: 0 lỗi, quét trên 100 scene và thấy trên 100 chỗ ghi đè (đường quét không hỏng).

const SKIP_DIRS: PackedStringArray = ["res://addons", "res://tests", "res://output", "res://.godot", "res://docs"]
const MIN_SCENES: int = 100
const MIN_OVERRIDES: int = 100

var _fails: int = 0
var _node_re := RegEx.create_from_string("(?m)^\\[node ([^\\]]*)\\]")
var _ext_re := RegEx.create_from_string("(?m)^\\[ext_resource ([^\\]]*)\\]")
var _editable_re := RegEx.create_from_string("(?m)^\\[editable path=\"([^\"]+)\"\\]")
var _attr_re := RegEx.create_from_string("\\b(\\w+)=\"([^\"]*)\"")
var _instance_re := RegEx.create_from_string("instance=ExtResource\\(\"([^\"]+)\"\\)")
## Đếm số chỗ ghi đè đã thấy (TC4 dùng để chắc đường quét hoạt động)
var _override_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tc1_missing()
	_tc2_valid()
	_tc3_nested()
	_tc4_project()
	print("RESULT fails=%d" % _fails)
	get_tree().quit()


func _tc1_missing() -> void:
	var text := _sample(false)
	var errors := _check_text("res://sample.tscn", text, {})
	_check(errors.size() == 1, "TC1: ghi đè Npc/Story thiếu [editable] -> %d lỗi (cần 1)" % errors.size())


func _tc2_valid() -> void:
	var errors := _check_text("res://sample.tscn", _sample(true), {})
	_check(errors.is_empty(), "TC2: có [editable path=\"Npc\"] -> %d lỗi (cần 0)" % errors.size())
	var added := "[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://npc.tscn\" id=\"1\"]\n\n" \
		+ "[node name=\"Root\" type=\"Node3D\"]\n\n[node name=\"Npc\" parent=\".\" instance=ExtResource(\"1\")]\n\n" \
		+ "[node name=\"Gift\" type=\"Node\" parent=\"Npc\"]\nenabled = false\n"
	errors = _check_text("res://added.tscn", added, {})
	_check(errors.is_empty(), "TC2: node mới type=\"Node\" dưới instance -> %d lỗi (cần 0)" % errors.size())


func _tc3_nested() -> void:
	# Outer nhúng Room (room.tscn); trong room.tscn có instance Keeper; outer ghi đè Room/Keeper/Story
	var inner := "[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://keeper.tscn\" id=\"1\"]\n\n" \
		+ "[node name=\"Room\" type=\"Node3D\"]\n\n[node name=\"Keeper\" parent=\".\" instance=ExtResource(\"1\")]\n"
	var outer := "[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://room.tscn\" id=\"1\"]\n\n" \
		+ "[node name=\"Level\" type=\"Node3D\"]\n\n[node name=\"Room\" parent=\".\" instance=ExtResource(\"1\")]\n\n" \
		+ "[node name=\"Story\" parent=\"Room/Keeper\"]\nenabled = false\n\n[editable path=\"Room\"]\n"
	var errors := _check_text("res://outer.tscn", outer, {"res://room.tscn": inner})
	_check(errors.size() == 1 and String(errors[0]).contains("Room/Keeper"), "TC3: thiếu [editable] instance lồng Room/Keeper -> %s" % [errors])


func _tc4_project() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	_override_count = 0
	var errors: PackedStringArray = []
	for path in files:
		errors.append_array(_check_text(path, FileAccess.get_file_as_string(path), {}))
	for e in errors:
		print("  LỖI " + e)
	_check(files.size() >= MIN_SCENES, "TC4: quét %d scene (cần >= %d)" % [files.size(), MIN_SCENES])
	_check(_override_count >= MIN_OVERRIDES, "TC4: thấy %d chỗ ghi đè (cần >= %d)" % [_override_count, MIN_OVERRIDES])
	_check(errors.is_empty(), "TC4: toàn project không còn ghi đè thiếu [editable] (%d lỗi; sửa: python dev/tools/scene_overrides.py --fix)" % errors.size())


## Trả về danh sách lỗi của một file .tscn. overrides_text: nội dung thay cho file con (dùng trong test mẫu)
func _check_text(path: String, text: String, sub_texts: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var parsed := _parse(text)
	var nodes: Array = parsed.nodes
	var editable: Dictionary = parsed.editable
	var instances := {}
	for n: Dictionary in nodes:
		if not String(n.instance).is_empty():
			instances[n.path] = n.instance
	for n: Dictionary in nodes:
		if n.parent == null or not String(n.type).is_empty() or not String(n.instance).is_empty():
			continue
		var parts: PackedStringArray = [] if n.parent == "." else String(n.parent).split("/")
		var owner := ""
		for i in range(parts.size(), 0, -1):
			var cand := "/".join(parts.slice(0, i))
			if instances.has(cand):
				owner = cand
				break
		if owner.is_empty():
			continue
		_override_count += 1
		var chain: PackedStringArray = [owner]
		var parent_rest := String(n.parent).substr(owner.length() + 1) if String(n.parent).length() > owner.length() else ""
		if not parent_rest.is_empty():
			chain.append_array(_nested(instances[owner], parent_rest, owner, sub_texts, 0))
		for c in chain:
			if not editable.has(c):
				errors.append("%s: ghi đè %s nhưng thiếu [editable path=\"%s\"]" % [path, n.path, c])
	return errors


## Instance lồng trong scene con nằm trên đường rest (đường dẫn tính từ gốc file đang xét)
func _nested(scene_path: String, rest: String, prefix: String, sub_texts: Dictionary, depth: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if depth > 8 or not scene_path.ends_with(".tscn"):
		return out
	var text: String = sub_texts.get(scene_path, "")
	if text.is_empty():
		if not FileAccess.file_exists(scene_path):
			return out
		text = FileAccess.get_file_as_string(scene_path)
	var sub_nodes: Array = _parse(text).nodes
	var parts := rest.split("/")
	for i in range(1, parts.size() + 1):
		var sub := "/".join(parts.slice(0, i))
		for n: Dictionary in sub_nodes:
			if n.path == sub and not String(n.instance).is_empty():
				var full := prefix + "/" + sub
				out.append(full)
				if i < parts.size():
					out.append_array(_nested(n.instance, "/".join(parts.slice(i)), full, sub_texts, depth + 1))
	return out


func _parse(text: String) -> Dictionary:
	var ext := {}
	for m in _ext_re.search_all(text):
		var a := _attrs(m.get_string(1))
		ext[a.get("id", "")] = a.get("path", "")
	var nodes: Array = []
	for m in _node_re.search_all(text):
		var raw := m.get_string(1)
		var a := _attrs(raw)
		var parent: Variant = a.get("parent", null)
		var name: String = a.get("name", "")
		var npath := "." if parent == null else (name if parent == "." else String(parent) + "/" + name)
		var inst := _instance_re.search(raw)
		nodes.append({
			"path": npath, "parent": parent, "type": a.get("type", ""),
			"instance": ext.get(inst.get_string(1), "") if inst else "",
		})
	var editable := {}
	for m in _editable_re.search_all(text):
		editable[m.get_string(1)] = true
	return {"nodes": nodes, "editable": editable}


func _attrs(raw: String) -> Dictionary:
	var out := {}
	for m in _attr_re.search_all(raw):
		out[m.get_string(1)] = m.get_string(2)
	return out


func _collect(dir_path: String, out: PackedStringArray) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS or FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))


func _sample(with_editable: bool) -> String:
	var text := "[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://npc.tscn\" id=\"1\"]\n\n" \
		+ "[node name=\"Room\" type=\"Node3D\"]\n\n[node name=\"Npc\" parent=\".\" instance=ExtResource(\"1\")]\n\n" \
		+ "[node name=\"Story\" parent=\"Npc\" index=\"8\"]\nenabled = false\n"
	if with_editable:
		text += "\n[editable path=\"Npc\"]\n"
	return text


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1
