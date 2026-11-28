class_name PlanarMirrorConfig
extends Resource
## Cấu hình phản chiếu phẳng thời gian thực (SubViewport + Camera3D) cho gương.
## GHI CHÚ TỐI ƯU: Có thể bổ sung chế độ phản chiếu giả lập (stylized/fake reflection)
## bằng cubemap/environment hoặc shader tĩnh trong tương lai nếu cần giảm chi phí render.

@export_group("Hiệu năng")
## Tỉ lệ độ phân giải của SubViewport phản chiếu so với cạnh nhỏ của viewport chính.
@export_range(0.05, 1.0, 0.05) var resolution_scale: float = 0.5
## Giới hạn cạnh lớn nhất (pixel) cho SubViewport phản chiếu (0 = không giới hạn).
@export_range(0, 2048, 32) var max_resolution: int = 256
## Cập nhật phản chiếu mỗi N khung hình (1 = mỗi frame; >1 để giảm tải GPU).
@export_range(1, 10, 1) var update_every_n_frames: int = 1
## Tắt shadow atlas trong ảnh phản chiếu để tiết kiệm hiệu năng.
@export var disable_shadows_in_reflection: bool = true

@export_group("Hình học & Layer")
## Bật phản chiếu cả 2 mặt của đĩa gương (phù hợp gương xoay câu đố).
@export var double_sided: bool = true
## Góc nhìn (FOV) của camera phản chiếu đặt tại tâm mặt gương.
@export_range(20.0, 110.0, 1.0) var reflection_fov: float = 55.0
## Độ nhô của camera ảo trước mặt gương (lớn hơn nửa độ dày mặt gương 0.08 m để không nhìn xuyên ra sau).
@export_range(0.01, 0.5, 0.01) var surface_offset: float = 0.1
## Làm phẳng bớt góc chúi xuống của tia phản xạ (0 = chuẩn vật lý theo camera top-down; 0.65 = thấy rõ Foxy và tường).
@export_range(0.0, 1.0, 0.05) var pitch_flatten: float = 0.65
## Chỉ bật nếu muốn kẹp thêm near plane theo bán kính (thường tắt khi camera đặt ngay trên mặt gương).
@export var use_near_plane_clip: bool = false
## Bán kính mặt gương dùng để map UV đĩa tròn.
@export_range(0.05, 20.0, 0.05) var mirror_radius: float = 0.86
## Khoảng lùi an toàn trước mặt gương để tránh cắt lẹm góc đĩa gương.
@export_range(0.0, 2.0, 0.01) var near_plane_margin: float = 0.15
## Visual layer riêng của mặt gương, bị loại khỏi cull_mask của camera phản chiếu.
@export_range(1, 20, 1) var mirror_visual_layer: int = 20
## Trục pháp tuyến mặt gương trong local space của MeshInstance3D (CylinderMesh là Y).
@export var mirror_local_axis: Vector3 = Vector3(0.0, 1.0, 0.0)
## Đảo trục dọc ảnh phản chiếu vì gốc Y của ViewportTexture trong gl_compatibility ngược với UV mặt đĩa.
@export var flip_y: bool = true

@export_group("Gương đồng cổ")
## Cường độ ảnh phản chiếu trên bề mặt gương đồng.
@export_range(0.0, 1.0, 0.01) var reflection_strength: float = 0.82
## Tông màu đồng cổ nhuộm lên ảnh phản chiếu.
@export var tint_color: Color = Color(0.86, 0.72, 0.46, 1.0)
## Màu nền kim loại đồng khi ánh sáng chiếu trực tiếp.
@export var base_color: Color = Color(0.42, 0.31, 0.18, 1.0)
## Màu vành hông mảnh của đĩa gương.
@export var edge_color: Color = Color(0.5, 0.25, 0.085, 1.0)
## Độ dốc hiệu ứng Fresnel ở góc nhìn nghiêng.
@export_range(0.5, 8.0, 0.1) var fresnel_power: float = 2.6
## Độ tăng phản chiếu ở rìa góc nhìn nghiêng.
@export_range(0.0, 1.0, 0.01) var fresnel_boost: float = 0.28
## Độ kim loại của mặt đồng.
@export_range(0.0, 1.0, 0.01) var metallic: float = 0.85
## Độ nhám bề mặt đồng.
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.22
