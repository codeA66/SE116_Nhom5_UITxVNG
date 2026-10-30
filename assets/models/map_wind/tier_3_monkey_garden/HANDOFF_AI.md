> CẬP NHẬT: người dùng không duyệt chất lượng mỹ thuật của cả 39 model. Đang thiết kế lại toàn bộ; các GLB/ảnh QA hiện tại là blockout v1, không phải art đã duyệt.

# Bàn giao AI – Monkey Garden

## Đọc trước

README.md: tên/công dụng/số liệu 39 model; manifest.json: đường dẫn, description_vi, collection, source, kích thước GLB, pivot mesh rời; hai spec docs/map_wind/tier_3_monkey_garden_kit.md và docs/art_style_guide.md.

## Trạng thái

- Blender 5.2.0 LTS, MCP addon 1.8 protocol 13 hoạt động. Người dùng mở lại garden_live_workbench.blend sau crash và yêu cầu tiếp tục trực tiếp trong Blender.
- Crash xảy ra khi bpy.data.libraries.write({scene}) với scene mới tạo. Stack: BKE_view_layer_copy_data -> scene_copy_data -> PartialWriteContext. KHÔNG lặp cách ghi scene này. save_as_mainfile đã dùng thành công.
- Model gốc trong Garden_<asset> đang ẩn tránh chồng tại origin. Garden_Live_Preview là linked copies.
- bpy.app.driver_namespace["garden"] đã khôi phục. Nếu restart: exec build_garden.py vào namespace riêng, rồi LOAD LẠI assets và PAL từ manifest; helper mặc định khởi tạo danh sách rỗng/màu ban đầu.
- Helper ở C:/Code/UITxVNG/output/tier_3_monkey_garden. Không chạy lại toàn bộ stage_one/structures/plants: sẽ tạo trùng collection.
- Repo chỉ tạo kit mới và tests/monkey_garden_kit. Spec docs/map_wind/tier_3_monkey_garden_kit.md đã untracked từ trước.

## Việc tiếp theo

1. Bố trí toàn cảnh live trong Blender, save checkpoint bằng save_as_mainfile.
2. Xác nhận normal chốt rương: sửa trước crash có thể đã lưu GLB nhưng chưa lưu workbench, kiểm tra trước khi đảo lần nữa.
3. Chỉnh kích thước lệch, mặt top floor_stone về y=0. Kiểm tra Face Orientation, hinge, transforms.
4. Scale shot với GLB cáo/khỉ hiện có, chỉ đọc nguồn; xem màu+xám cùng slash ivory.
5. Render lại contact sheets vì vừa chỉnh layout camera, đo cả đá/đất.
6. Xác nhận import game chính, tránh sửa import kit khác.
7. Cập nhật README/manifest và việc còn thiếu.

## Giới hạn

Không sửa kit khác, project.godot, gameplay/builder/level, không addon, không commit. Không Blender nền. Không libraries.write(scene). Không gán số đo chưa có hoặc gọi concept là render Godot.


## Mốc mới nhất: V2 + hoa văn

Cả 39 nguồn trong Garden_<name> là V2. BlockoutV1_* và preview cũ chỉ để phục hồi, không xuất. Helpers mới v2_*.py ngoài project. v2_ornaments.py đã chạy một lần: KHÔNG chạy lại vì sẽ thêm trùng hoa văn. Chỉnh trực tiếp source collection. Đã solidify vải đa số props; fruit_peels đã giảm còn 3 cánh để không vượt 40 tris. Hai leaf kit vines còn sheet hai mặt đồng phẳng, cần xem tiếp. Mặt cầu đã chia hoa văn tại nếp gãy y=0, cần render lại xác nhận. Thư viện .blend object và workbench đã lưu; save_as_mainfile an toàn, tránh libraries.write(scene) từng crash. Godot test có --group=corner/ground/walls/structures/plants/monkey_props/interactive/scale/motion/composition. Scale dùng bake_mesh_from_current_skeleton_pose để đo posed AABB, không lấy bind-pose AABB sai. Cập nhật render và README sau mọi sửa.


## Cập nhật sau QA hoa văn

Đã render lại cầu sau khi chia decal ở nếp gãy và xem màu+xám. Đã chạy corner/composition trong GAME CHÍNH, ảnh và shared-material audit thành công; có texture RID leak khi thoát, ghi README. Luminance mới 0.271117 / 0.197825. READ README bản mới thay vì các đoạn trạng thái lịch sử ở trên. Blender hiện hiển thị Garden_Current_Art_Preview toàn cảnh, sources Garden_<name>. V2 vẫn chờ người dùng duyệt, không gọi art approved.
