# Wind sailboat

Model tự dựng trong Blender, 6 mesh, khoảng 828 tam giác; không dùng asset bên ngoài.
GLB dùng Y-up, mũi +Z, đơn vị mét. Boong nằm tại y=0.4 để khớp cao độ thuyền cũ.

Scene gameplay: `res://objects/traversal/boat/boat.tscn`. Các instance trong map tự nhận model mới.
Gán `route` (Path3D), `data` (BoatData), và `water` nếu cần nhấp nhô theo sóng.

- Collider thân: convex theo đường bao thân, mặt trên phẳng; không dùng trimesh cho vật đỡ di chuyển.
- Collider cột: cylinder riêng. Vải buồm, dây và thanh ngang không chặn người chơi.
- Deck: Area3D theo đường bao boong để nhận hành khách.
- Animation: shader cuộn/mở buồm và nâng thanh ngang dưới; vải gợn theo TIME.
  BoatVisual điều khiển deployment/gust bằng Tween, không có vòng lặp script mỗi frame.
- Model và shader dùng chung. Ba ShaderMaterial được tạo một lần cho mỗi thuyền để không đồng bộ nhầm trạng thái buồm giữa các instance.

Chỉnh thời gian mở/cụp và phản ứng khi thổi sai hướng trong `resources/boat/boat_default.tres`.
Chỉnh độ gợn, tốc độ gợn và tỷ lệ buồm cụp trên BoatVisual. Nạp lại scene sau khi đổi các thông số này.
Giữ `sail_top` / `sail_bottom` theo model, chỉ đổi khi thay hình học.

Test: chạy `res://tests/levels/boat_integration/test_boat_integration.tscn`, dùng thư mục user data riêng để tránh ảnh hưởng save cá nhân.
Test kiểm tra collider bằng raycast, player đáp/chạy cùng thuyền, nhận gió và cập bến, cùng các chuyển tiếp animation.
