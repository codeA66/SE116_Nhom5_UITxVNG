class_name CameraViewData
extends Resource
## Góc nhìn camera của player (khoảng cách, góc cúi, FOV). Khu cần nhìn rộng hơn (khu trung tâm) dùng .tres riêng;
## khu không gán thì giữ góc mặc định trong player.tscn.

## Khoảng cách từ camera tới điểm bám (m)
@export_range(5.0, 200.0, 0.5) var distance: float = 32.0
## Góc cúi xuống so với mặt ngang (độ): nhỏ = nhìn xa hơn, thấy chân trời
@export_range(5.0, 89.0, 0.5) var pitch_degrees: float = 50.0
@export_range(10.0, 120.0, 0.5) var fov: float = 30.0
## Xoay ngang quanh điểm bám (độ). 0 = nhìn từ phía nam như mặc định; 45 = nhìn chéo từ đông nam
## (kiểu isometric). Input di chuyển tính theo hướng camera nên tự khớp góc xoay
@export_range(-180.0, 180.0, 0.5) var yaw_degrees: float = 0.0


## Transform của camera so với CameraRig (camera nhìn về -Z, lùi về +Z, rồi xoay ngang theo yaw)
func get_local_transform() -> Transform3D:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var basis := yaw * Basis(Vector3.RIGHT, -pitch)
	return Transform3D(basis, yaw * (Vector3(0.0, sin(pitch), cos(pitch)) * distance))
