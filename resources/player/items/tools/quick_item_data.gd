class_name QuickItemData
extends ItemData
## Vật phẩm dùng bằng phím use_item (T): chọn trong trang Vật phẩm của túi đồ (GameState.select_item), rồi
## giữ T để nhắm (vòng tầm + dấu dưới con trỏ), thả T để dùng ở chỗ dấu. aim_range = 0: bấm T là dùng ngay.
## QuickItemUser (gắn vào player lúc chạy) lo phím và nhắm; lớp con chỉ ghi đè use().
## Thêm vật phẩm dùng phím mới = lớp con + file .tres trong danh mục, không sửa player.

## Lớp va chạm "world" (layer 1) để dò mặt sàn
const WORLD_MASK := 1

## Thời gian chờ giữa hai lần dùng (s)
@export_range(0.0, 10.0, 0.05) var cooldown: float = 0.5
@export_group("Aim")
## Tầm xa nhất tính từ player (m, mặt phẳng ngang). Con trỏ xa hơn thì dấu nằm ở mép tầm theo hướng con trỏ.
## 0 = không nhắm
@export_range(0.0, 30.0, 0.1) var aim_range: float = 0.0
## Gần nhất tính từ player (m): con trỏ sát / trùng nhân vật thì đẩy ra chừng này (không đặt chồng lên người)
@export_range(0.0, 5.0, 0.05) var min_range: float = 0.8
## Không có chuột (chạy headless) hoặc không nhắm: dùng ở trước mặt cách chừng này (m)
@export_range(0.0, 10.0, 0.05) var default_distance: float = 1.3
## Dò mặt sàn từ trên điểm nhắm xuống chừng này (m)
@export_range(0.5, 20.0, 0.1) var floor_probe: float = 6.0
## Scene vòng tầm + dấu (AimIndicator); trống = nhắm không có hình
@export var aim_indicator: PackedScene


## Dùng vật phẩm ở target (mặt sàn, đã giới hạn trong tầm). state: trạng thái riêng của player này cho vật phẩm này
## (QuickItemUser giữ, ví dụ khối đã đặt). true = đã dùng (tính hồi chiêu)
func use(_player: Player, _state: Dictionary, _target: Vector3) -> bool:
	return false


## Đưa điểm con trỏ raw về chỗ dùng hợp lệ: trong [min_range, aim_range] quanh player theo mặt phẳng ngang,
## rồi hạ xuống mặt sàn dò được (không thấy sàn thì giữ độ cao chân player). exclude: RID bỏ qua khi dò sàn
func resolve_target(player: Player, raw: Vector3, exclude: Array[RID] = []) -> Vector3:
	var origin := player.global_position
	var offset := Vector3(raw.x - origin.x, 0.0, raw.z - origin.z)
	var distance := offset.length()
	var direction := offset / distance if distance > 0.001 else _facing(player)
	var limit := aim_range if aim_range > 0.0 else default_distance
	distance = clampf(distance, minf(min_range, limit), limit)
	var at := origin + direction * distance
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * floor_probe, WORLD_MASK)
	query.exclude = exclude
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else at


## Vật thể bỏ qua khi dò mặt sàn (ngoài player), ví dụ khối TNT đã đặt
func get_probe_exclude(_state: Dictionary) -> Array[RID]:
	return []


## Điểm mặc định khi không nhắm được bằng chuột: trước mặt default_distance
func default_target(player: Player) -> Vector3:
	return player.global_position + _facing(player) * default_distance


func _facing(player: Player) -> Vector3:
	var facing := player.get_facing_direction()
	facing.y = 0.0
	return facing.normalized() if facing.length_squared() > 0.0001 else Vector3.FORWARD
