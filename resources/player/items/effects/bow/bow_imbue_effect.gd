class_name BowImbueEffect
extends CharmEffect
## Bùa đăng ký nguồn hiệu ứng riêng, không sửa nguyên tố đã ghép trong tiến trình.

@export_group("Hiệu ứng tên cung")
@export_file("*.tres") var infusion_path: String = ""

var _infusion: FusionData
var _loaded_path: String = ""


func apply(player: Node) -> void:
	var user: Player = player as Player
	if user:
		user.register_bow_imbue(_source_id(), get_infusion())


func remove(player: Node) -> void:
	var user: Player = player as Player
	if user:
		user.unregister_bow_imbue(_source_id())


func get_infusion() -> FusionData:
	# Catalog nạp trước Player; trì hoãn dữ liệu tránh khởi tạo FusionEffect khi static registry chưa sẵn sàng.
	if _loaded_path != infusion_path:
		_loaded_path = infusion_path
		_infusion = load(infusion_path) as FusionData if not infusion_path.is_empty() else null
	return _infusion


func _source_id() -> StringName:
	return StringName("bow_imbue_%d" % get_instance_id())
