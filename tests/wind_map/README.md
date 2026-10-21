# Map phế tích Gió theo concept

Mở `wind_ruins_concept_map_built.tscn` và nhấn **F6**. Đây là scene map mới đã ráp model; scene khởi động và các level cũ của project không được thay đổi.

- **Tab**: đổi giữa góc toàn cảnh và điều khiển cáo bằng camera game.
- **WASD**, **Space**: đi và nhảy bằng controller hiện có.
- **E** khi đứng trên hoặc sát thuyền: đi giữa hai bến hồ.
- **R**: đưa cáo về cổng vào.

Bố cục: cổng tầng thấp ở góc trái trước; Giếng Gió ở giữa; cầu chính bị gãy qua vực; thư điện trên tầng cao phía sau; hồ có kè và hai bến phía phải; đàn Gió với vòng đá mất cung ở phía xa. Có tuyến vòng đi từ cổng lên giếng, qua thư điện và cầu trên đến đàn Gió; bậc thang xuống bến và thuyền nối phía còn lại. Vùng gió nâng ở giếng dùng component gió hiện có.

`wind_ruins_concept_map.tscn` là scene dựng từ script; bản `_built.tscn` lưu sẵn hình học để xem và chỉnh bố cục trong editor. Nguồn model, scene gameplay cũ và cấu hình main scene không được ghi lại.

Map này là môi trường khám phá dựa theo bố cục concept, dùng bộ model stylized đã tạo. Kẻ địch, boss và chuỗi câu đố của level chính chưa được ghép vào map mới.

Bản hiện tại đã ráp đủ 39 mã model và có đường đi thử. Đây là bản bố cục 3D; hình dáng vách, mật độ kiến trúc, màu và ánh sáng còn đơn giản hơn ảnh concept, chưa phải bản tái hiện y hệt ảnh.

Kiểm tra ngày 20/10/2026: mở lại scene đã lưu bằng Godot 4.7.2, cáo đi được từ cổng lên giếng, lên thư điện, qua cầu trên và đứng trên thuyền chuyển động. Gallery nạp được 39 model / 92 biến thể. Đối chiếu SHA-256 của 91 scene/cấu hình cũ: không có file thay đổi so với trước khi dựng scene mới. Log và ảnh kiểm tra lúc đó đã được dọn khỏi project (vẫn còn trong lịch sử git); chạy lại thì ảnh ghi vào `user://wind_map_verification/` và `user://wind_gallery_verification/`. Khi đóng bài kiểm tra đồ họa có cảnh báo giải phóng RID của Godot; chưa xác định nguyên nhân, không coi đây là kiểm tra hiệu năng hay bộ nhớ đã hoàn tất.

Lưu bản dựng bằng `verify_map.tscn -- --bake` phải chạy với backend đồ họa; backend headless không lưu buffer MultiMesh của nền. Bài kiểm tra chủ động chặn thao tác bake headless để tránh lưu scene mất nền.
