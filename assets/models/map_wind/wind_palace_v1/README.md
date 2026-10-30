# Bộ model cung điện map Gió phiên bản 1

## Tiến độ ngày 25 tháng 10 năm 2026

Hiện có **45 mẫu Art R2**, đã sửa toàn bộ GLB tại đúng đường dẫn cũ bằng Blender MCP, kiểm tra bằng Godot 4.7.2 GL Compatibility trên NVIDIA MX230. Nguồn Blender đã lưu ngoài project. Đợt sửa toàn bộ model đã hoàn tất; đánh giá thẩm mỹ cuối cùng vẫn dành cho người dùng. Các mục bên dưới là lịch sử; thông tin bàn giao mới nhất nằm ngay sau đoạn này.

### Bàn giao Art R2 — toàn bộ 45 model

- **28.482 tam giác** trên toàn bộ kit. Audit không có lỗi; 45/45 model giữ nguyên bounds, tên và transform của node so với bản sao trước R2. Sai khác bounds đo từ GLB: **0 m**. Giữ nguyên tên file, đường dẫn và gốc đáy giữa; không thêm model mới trong đợt R2.
- Cầu thang `stair_straight_3m.glb`: mặt bước trên cùng cao **2 m**, chiều chạy **4 m**, giữ nguyên. Tường `wall_straight_4m.glb`: thân cao **4 m**, dày **0,69 m**; tổng chiều cao có phào **4,08 m đã tồn tại từ trước**, không phải kích thước mới.
- Dáng cột thuôn, chân/đầu cột nhiều cấp, lan can con tiện, vòm liền khối và hốc vòm tường; sàn đá mảng lớn, khung giá sách, bàn ghế, bình rỗng, lồng đèn và vải/cánh gió đã chỉnh. Màu theo palette đã chốt; cyan phát sáng dành cho tương tác.
- Đã xem ảnh màu và trắng đen từ Godot: `output/wind_palace/qa/art_corner_comparison.png`, `art_corner_after_grayscale.png`, `palace_exploration_overview.png`, `palace_exploration_overview_grayscale.png`. Contact sheet hiện tại: `palace_catalog_contact_sheet.png` và bản `_grayscale.png`.
- **97/97 kiểm tra hành vi PASS**: 22 phần chuyển động, 20 tích hợp, 19 tuyến cầu thang/camera Player, 36 tuyến khám phá. Audit gốc tọa độ trong Godot: **45/45 PASS**. Các phép kiểm này thuộc scene QA của kit, không thay thế nghiệm thu toàn bộ map đang được Claude xây.
- Nguồn: `C:/Code/UITxVNG/Foxy_Art_Source/wind_palace_v1/wind_palace_kit_v1.blend`. Bản sao trước R2: `C:/Code/UITxVNG/Foxy_Art_Source/wind_palace_v1/before_art_r2/`.
- Báo cáo đối chiếu từng GLB và SHA-256: `output/wind_palace/qa/art_r2_glb_compatibility.json`. Danh sách bàn giao chi tiết: `DONE.txt` (chỉ tạo sau khi toàn bộ kiểm tra cuối đạt).
- Builder có thể reimport và chạy lại để nạp model mới. Nếu builder cache PackedScene, cần nạp lại cache hoặc khởi động lại phiên builder. Không đổi bố cục, kích thước hay code map của Claude trong đợt này.

### Lịch sử trước Art R2

- Audit trước R2: đủ 45 GLB, tổng **5.398 tam giác** ở thời điểm đó (audit hiện tại đã được cập nhật cho R2). Cả **45 origin** đã kiểm tra đáy giữa trong Godot sau import. Các lỗi origin ghi trong lịch sử lượt 8 đã được xử lý ở lượt 9.
- Duyệt toàn bộ bộ hình: `output/wind_palace/qa/palace_catalog_contact_sheet.png` và bản `_grayscale.png`.
- Kiểm tra phần chuyển động: **22 PASS** ở `output/wind_palace/qa/motion_report.json`; tích hợp bệ nâng và tuyến cầu thang xem các mục lịch sử bên dưới.
- Duyệt đồ gỗ/cờ và đèn ở camera Player: `output/wind_palace/qa/palace_wood_after_lamplit.png`, bản `_grayscale.png`; so sánh trước/sau `palace_wood_lighting_comparison.png`.
- Tuyến nhiều tầng dùng camera Player: `output/wind_palace/qa/palace_route_player_camera_waypoint_4.png`; báo cáo `route_player_camera_report.json` và bản grayscale cùng tên ảnh.
- Sau chuẩn hóa origin, chạy lại **61 kiểm tra hành vi PASS**: 22 phần chuyển động, 20 tích hợp bệ nâng/cửa, 19 tuyến cầu thang. Đã chụp lại gallery, phòng gỗ và ảnh grayscale; chưa thay model vào map chính.
- Cụm khám phá lắp thử mới: `tests/wind_palace_kit/palace_exploration_demo.tscn` (F6). Có nhánh thư viện, nhánh rương trên tầng 2m và vòng quay về qua cầu thang thứ hai; **36 kiểm tra PASS**. Ảnh tổng quan thật từ Godot: `output/wind_palace/qa/palace_exploration_overview.png` và bản `_grayscale.png`.

- Model GLB: thư mục hiện tại.
- File Blender gốc bên ngoài project: `C:/Code/UITxVNG/Foxy_Art_Source/wind_palace_v1/wind_palace_kit_v1.blend`.
- Danh mục và thống kê: `manifest.json`.
- Script tạo hình và sửa pivot: `output/wind_palace/build_wind_palace.py`, `finalize_kit.py`.
- Scene kiểm tra: `res://tests/kits/wind_palace_kit/wind_palace_gallery.tscn`. F6 rồi phím trái/phải để đổi trang.
- Xem phòng ghép thử bằng tham số `-- --room`; tự chụp và thoát bằng `-- --room --capture`.
- Ảnh Godot, ảnh trắng đen, log, audit: `output/wind_palace/qa/`.

## Phạm vi 36 model đã có

Kiến trúc: sàn 2m, sàn 4m, sàn viền, sàn vỡ, tường thẳng, tường thấp, góc tường, cửa vòm, cửa sổ vòm, cột vuông, cột tám cạnh, lan can 2m/4m, cầu thang thẳng, chiếu nghỉ, ban công, nhịp cầu, cửa đôi, cổng đường tắt.

Trang trí và đèn: cờ, giá sách, bàn đọc, ghế băng, bình cao/thấp, đá vụn, thảm, đèn treo tường, đèn đứng.

Phần hình tương tác: rương, trụ nạp gió, cần gạt, ổ đá, đá gió, bệ chìa, cầu xoay.

## Màu và import

- Tường #5A6270; chi tiết đá #8A8F96; sàn #B8B2A6.
- Gỗ #4A3A2E; vải #7FA7A8 không emission.
- Đèn #F2B45A; chi tiết tương tác #3FE0D0 có emission.
- Không dùng cam làm màu đồ vật hoặc đỏ làm trang trí.
- Màu nền nằm trong vertex colors, không dùng texture. Vật liệu chung: `palace_vertex_color.tres`.
- `palace_import.gd` gán vật liệu chung sau import. Cần giữ `import_script/path` trong các GLB import settings trỏ tới script này. Bản import đầu cho thấy Godot chưa bật vertex color theo material Blender; post-import đã sửa và được kiểm tra lại bằng ảnh renderer thật.
- Phần vải/cánh quạt mỏng tắt cast shadow để tránh tự tạo sọc bóng.

## Kiểm tra đã làm

- 36 GLB có COLOR_0, không có camera, texture hoặc default Cube lẫn vào; audit không có mục lỗi.
- Xuất lại với use_active_scene để scene mặc định Blender không lọt vào GLB.
- Gom hình học tĩnh dùng chung vật liệu; giữ các phần chuyển động tách riêng.
- Sửa pivot cánh cửa, nắp rương, cần gạt, cầu xoay và rotor; sửa cổng bị lệch transform.
- Sửa mặt nắp phào tường đồng phẳng gây z-fighting.
- Chạy 4 trang gallery trong Godot, không có lỗi vật liệu ở lượt sau khi sửa.
- Ghép một phòng kiểm tra với Player/Foxy thật, camera nhìn chéo, đèn ấm; screenshot và ảnh trắng đen đã được xem. Sàn và tường phân biệt rõ trong bối cảnh này. Phân biệt cáo vẫn dựa đáng kể vào màu cam; cần kiểm tra thêm trong ánh sáng và cảnh chiến đấu của map thật.
- Import editor toàn project có báo lỗi `_exit_tree` trong `objects/checkpoint/checkpoint.gd` khi đóng editor; không sửa gameplay trong lượt dựng model này. Runtime scene gallery/phòng kiểm tra không có lỗi đó.

## Các phần cần tiếp tục trong lượt lịch tiếp theo

1. Đánh giá và tinh chỉnh chất lượng tạo hình từ ảnh Godot; bộ hiện tại còn đơn giản, không tuyên bố đã đạt art cuối theo Death's Door.
2. Bổ sung module tường có lỗ cửa sổ thật, cửa vòm gắn tường, góc/đoạn lan can, cầu thang đổi hướng, cấu trúc tầng dưới tối và bệ nâng gió. Các marker/gameplay của đồ hiện có cần được đối chiếu trước khi thay model vào object thật.
3. Bổ sung cụm kiến trúc có đường vòng/nhánh khám phá, cơ quan gió đọc được từ camera, rồi kiểm tra vật thể ở nhiều cao độ và ánh sáng khác nhau.
4. Thêm collider hình đơn giản và nối các phần hình tương tác vào scene gameplay tương ứng. GLB hiện là hình ảnh; không coi chúng là vật chơi đã có FSM/collider.
5. Kiểm tra animation thực tế của bản lề/rotor/gate và vị trí người đứng trên cầu/bệ sau khi gắn gameplay. Hiện đã chuẩn bị pivot, chưa có nghiệm thu hành vi chuyển động.
6. Kiểm tra grayscale và độ nổi của player/quái/vật tương tác trong map thật, không chỉ phòng kiểm tra.

Không tạo lại 36 mẫu đã có hoặc chạy lại builder từ đầu khi chưa có lý do. Khi chỉnh model, mở file Blender hiện có và sửa phần cần thiết; xuất có chọn riêng model và active scene, giữ file `.blend` ngoài project. Không ghi đè model ngoài thư mục kit này.

## Lượt tiếp tục thứ hai ngày 25 tháng 10 năm 2026

Tổng hiện tại: **44 model**. Đã mở rộng đúng scene/file Blender đang có; không tạo lại 36 mẫu đầu.

Tám mẫu mới: `wall_window_open_6m`, `wall_door_open_6m`, `balustrade_corner_2m`, `stair_turn_landing`, `upper_gallery_l_6m`, `lower_arch_foundation_6m`, `wind_lift_palace_visual`, `wind_vent_wall`.

- Tường mới có phần mở thật trong hình học ở cửa sổ/cửa vòm; không dùng mặt đá kín phía sau khung.
- Bệ nâng mới có node `Platform`, marker `LowerStop` ở 0.45m và `UpperStop` ở 4.45m. Chưa thay model trong scene gameplay WindLift.
- Module mới từ 120 đến 336 tam giác; không có texture/camera/light trong GLB. Audit 44 GLB không có mục lỗi.
- Đã import và chạy gallery 5 trang trong Godot; sửa gallery để số trang tính theo manifest thay vì cố định 4 trang. Log không có lỗi material/script.
- Có bối cảnh ghép nhiều tầng để duyệt phần hình bằng `-- --exploration`. Chụp bằng `-- --exploration --capture`. Ảnh: `output/wind_palace/qa/godot_exploration.png` và `godot_exploration_grayscale.png`.
- Đã xem ảnh màu và trắng đen từ Godot Compatibility/MX230. Sàn/tường/tầng dưới tách về độ sáng; cáo vẫn cần kiểm tra trong bối cảnh combat và ánh sáng cuối. Đây là scene duyệt hình, không phải map chơi được.
- Tầng dưới đang làm tối bằng material override trong scene kiểm tra; chưa có sương chiều sâu và chưa nghiệm thu fog trên Compatibility.
- File `.blend` cùng đường dẫn gốc ngoài project đã lưu đủ 44 mẫu. Script bổ sung: `output/wind_palace/extend_kit_batch2.py` (không chạy lại khi mẫu đã tồn tại).

Việc tiếp theo ưu tiên: hoàn thiện liên kết cao độ/lối đi của cụm cầu thang và gallery, thêm collider đơn giản và thử đi qua các cửa mở bằng nhân vật; thử chuyển động bệ nâng với model mới trong scene test riêng, không thay scene gameplay chính khi chưa kiểm tra kích thước/marker. Sau đó mới nghiệm thu đường vòng khám phá, fog và art cuối.

## Lượt tiếp tục thứ ba ngày 25 tháng 10 năm 2026

Đã chuyển từ kiểm tra hình tĩnh sang kiểm tra tích hợp vật lý trong scene riêng; tổng vẫn là 44 model.

- Sửa trong Blender model `wind_charger_visual`: đổi các node đèn thành `Charge_Lens_0/1/2` để khớp code WindCharger thật; trạng thái mặc định dùng màu tối không emission. Chỉ khi nạp, gameplay mới phủ material xanh ngọc sáng. File GLB và file Blender ngoài project đã lưu lại.
- Thêm các scene riêng `tests/wind_palace_kit/palace_wind_lift.tscn`, `palace_wind_charger.tscn`. Chúng tái sử dụng script/FSM hiện có, thay phần hình mới, điều chỉnh collider theo kích thước model. Không sửa scene gameplay gốc.
- Deck collider là hình lồi tám cạnh khớp hình bệ, không phải đĩa tròn rộng hơn góc vát. Collider bốn cột, điểm dừng, cửa chặn, phần dưới bệ và vị trí receiver của trụ đã chỉnh theo model.
- Có scene wrapper tường/collider `palace_wall_door.tscn`, `palace_wall_window.tscn`: box ở trụ/bệ và các khối lồi nhỏ theo vòm, để trống lỗ cửa.
- Resource gió riêng cho cung điện trong thư mục test đã đổi lá cam thành xám xanh, giữ cam dành cho cáo. Resource/VFX của khu cũ không đổi.
- Test `palace_integration_test.tscn` đã chạy headless ở lượt đầu và chạy renderer OpenGL Compatibility/MX230 sau lần sửa cuối. **20 kiểm tra PASS**: đáp bệ; chân ở cao độ 0.56m; góc vát không có sàn vô hình; marker; nạp bằng WindReceiver thật; FSM nâng tới 4.45m; player được chở lên và xuống không trượt; model bám collider; đèn thật sự sáng/tắt; đi xuyên cửa mở; trụ cửa chặn; lỗ cửa sổ trống, bệ cửa vẫn đặc.
- Đã xem ảnh màu ở cả Lowered/Raised và ảnh trắng đen ở Raised. Bệ, player và đèn trụ tách được trong scene kiểm tra. Ảnh `output/wind_palace/qa/palace_lift_lowered.png`, `palace_lift_raised.png`, `palace_lift_raised_grayscale.png`. Log `output/wind_palace/integration_visual.log`, báo cáo `output/wind_palace/qa/integration_report.json`.
- Script tái tạo wrapper: `output/wind_palace/create_integration_scenes.py`. Không chạy builder model gốc để tránh mất các chỉnh sửa đã thực hiện trực tiếp trong Blender.

Việc tiếp theo: collider/cao độ cầu thang đổi hướng và gallery thành một lối đi liên tục, kiểm tra người chơi thực sự lên được tầng trên và đến rương; kiểm tra trạng thái góc khuất/camera trong bối cảnh khám phá. Bệ nâng và cửa chỉ đã nghiệm thu trong scene test riêng, chưa thay thế trong map chính. Art cuối và fog chưa nghiệm thu.

## Lượt tiếp tục thứ tư ngày 25 tháng 10 năm 2026

Tổng hiện tại **45 model**. Có một tuyến lên tầng trên và quay lại đã được chạy bằng Player thật trong scene riêng.

- Sửa model cầu thang có sẵn trong Blender: kéo dài chiếu nghỉ để đóng khe hở 0.2m giữa flight dưới và landing. Không dựng lại 44 mẫu.
- Thêm biến thể `upper_gallery_l_entry_6m`, có lối vào rộng 2m khớp flight trên của cầu thang. Giữ nguyên mẫu gallery kín cũ. Hạ lan can phía camera ở biến thể mới xuống 0.728m tính từ mặt deck, giúp nhìn thấy cáo rõ hơn khi đứng gần rương; collider cập nhật cùng kích thước.
- GLB mới và cầu thang sửa đã xuất; file Blender gốc ngoài project đã lưu đủ 45 mẫu. Script tạo biến thể: `output/wind_palace/connect_stair_gallery.py` (không chạy lại nếu mẫu đã tồn tại; chiều cao rail đã được chỉnh trực tiếp trong Blender sau đó).
- Wrapper có collider: `palace_stair_turn.tscn`, `palace_gallery_entry.tscn`, `palace_chest_collision.tscn` trong thư mục test. Script dựng wrapper: `output/wind_palace/create_route_scenes.py`.
- Lần chạy đầu với box collider từng bậc cho thấy Player bị chặn ngay bậc đầu. Đã dùng mặt dốc lồi liên tục cho hai flight, giữ hình bậc thang. Đây là collider dốc, không trùng từng mặt bậc; vị trí chân ở từng frame trên bậc chưa nghiệm thu như foot IK. Các mặt chiếu nghỉ và gallery đúng cao độ 1m/2m.
- `palace_route_demo.tscn` chạy F6 để đi thử thủ công. `-- --verify --capture` điều khiển chính Player qua Input Map; không tắt physics player, không dịch chuyển hoặc bấm nhảy để vượt tuyến.
- **19 kiểm tra PASS** trong lần cuối bằng renderer Godot Compatibility/MX230: đi lên cả hai flight, vào gallery, đến sát rương ở tầng 2m, đi ngược xuống đất; bốn waypoint mỗi chiều đạt vị trí và cao độ. Log `output/wind_palace/route_visual.log`, báo cáo `output/wind_palace/qa/route_report.json`.
- Đã xem ảnh màu và grayscale cuối: `palace_route_end.png`, `palace_route_end_grayscale.png` ở thư mục QA. Sau sửa rail nhìn thấy thân/cam cáo và chốt rương tốt hơn. Lượt render đầu có gallery trắng vì import chưa hoàn tất; đã chờ editor import xong, xác nhận material vertex=true và chụp lại, không dùng ảnh trắng làm nghiệm thu.

Việc tiếp theo: ghép tuyến này với cơ quan gió thành cụm khám phá có nhánh phụ/đường quay về, kiểm tra lan can/cạnh hở và khả năng đọc hướng đi từ camera thực tế; thêm và kiểm chứng sương tầng dưới trên Compatibility. Chưa có cơ chế mở/nhận đồ trong rương và chưa thay các scene vào map chính. Art cuối vẫn cần đối chiếu thêm với Death's Door.

## Lượt tiếp tục thứ năm ngày 25 tháng 10 năm 2026

Tổng vẫn **45 model**; lượt này tập trung kiểm chứng phần đọc cao độ và sương tầng dưới trong Godot, không tạo lại model.

- Đã kết nối Blender và xác nhận scene/file gốc vẫn đúng, không ghi đè nguồn model trong lượt này.
- Thử native Environment fog bằng các property đọc trực tiếp từ Godot 4.7.2. Có hiệu ứng trên Compatibility nhưng thiết lập thử làm tối/mờ cả sàn chơi và cáo, nên không chọn làm mặc định. Ảnh thử bị loại: `output/wind_palace/qa/palace_native_fog_rejected.png`.
- Thêm **sương giả theo chiều cao** chỉ gán cho kết cấu/sàn tầng dưới, không phải volumetric fog: shader `palace_lower_fog.gdshader`, material `palace_lower_fog.tres` và `palace_lower_floor_fog.tres`. Giữ material vertex color ở pass nền, phủ haze không chịu đèn ở next pass. Vùng trên -0.8m rõ; càng xuống tới -5m càng hòa vào màu nền, maximum_haze 0.75. Không có texture hoặc mesh phủ toàn màn, không gán cho đồ tương tác.
- Thử shader đầu tiên thay toàn bộ shading khiến phần dưới bị tối sai; đã bỏ cách đó và chuyển overlay pass giữ nguyên ánh sáng vật liệu gốc.
- Chạy A/B cùng camera và scene bằng renderer OpenGL Compatibility/MX230. `fog_review_report.json` ghi 3 điểm ở chân kết cấu dưới chuyển từ `272f3f`/`262e3e` sang `242c38`, gần màu nền `252c36` hơn; 2 điểm trên sàn chơi giữ nguyên `b8b19e`/`a49e8d` trước/sau. Các điểm này chứng minh tác động cục bộ trong cảnh thử, không đại diện mọi góc camera/máy.
- Đã xem ảnh màu và grayscale: `palace_fog_off.png`, `palace_fog_on.png`, `palace_fog_on_grayscale.png` trong QA. Sàn đi được vẫn tách sáng với tường; tầng dưới giảm tương phản mà không phủ mờ cáo.
- Duyệt A/B bằng `-- --fog-review --capture`; native fog bị loại chỉ thử lại khi có lý do bằng thêm `--native-fog`. Xem cảnh với hiệu ứng đã chọn bằng `-- --exploration --lower-fog`. Scene vẫn là duyệt phần hình, không coi bố cục đó là tuyến chơi đã nghiệm thu.

Việc tiếp theo: ghép tuyến Player đã đi được (scene route) với cơ quan gió thành cụm khám phá có nhánh phụ/đường quay về. Giữ sương height-fade đã kiểm tra như một công cụ trình bày tầng dưới; không lặp lại thử nghiệm native fog nếu chưa có yêu cầu mới. Cơ chế mở/nhận đồ trong rương, bố cục map chính và art cuối vẫn chưa nghiệm thu.

## Lượt tiếp tục thứ sáu ngày 25 tháng 10 năm 2026

Tổng vẫn **45 model**. Lượt này sửa hình học phần chuyển động và kiểm tra lại các file đã import, không thêm cơ chế gameplay.

- Duyệt cửa đang mở phát hiện các đai/tay nắm của cánh trái nằm chung mesh cánh phải. Đã chuyển đúng phần sang `DoorLeft` trong Blender. Hai cánh mở quanh bản lề bên, phụ kiện không thò ngang khỏi cánh.
- Duyệt rương đang mở phát hiện thân là khối đặc và đai kim loại chắn lòng rương. Đã dựng lại riêng thân rương thành đáy và bốn vách; lòng tối có đáy ở 0.15m. Đai trên nắp đi cùng node `Lid`, không cắt ngang khoang rương. Giữ chốt xanh ngọc và tên phần chuyển động.
- Hai GLB sửa và file `.blend` ngoài project đã lưu. Blender hiện có 45 mẫu, không mặt n-gon, không smooth shading, không scale chưa apply; file nguồn không có thay đổi chưa lưu. Không chạy lại `refine_interactive_geometry.py`: script này đã hoàn thành và có thao tác thêm đai nắp.
- Scene `tests/wind_palace_kit/palace_motion_review.tscn` chạy thật trên Godot Compatibility/MX230, **22 kiểm tra PASS**. Bao gồm bản lề cửa, biên phụ kiện; bản lề/nắp rương và raycast vào đáy khoang thật; cần gạt; cầu xoay 90 độ; toàn bộ song cổng nâng cùng nhau, trụ đứng yên; rotor xoay trong mặt phẳng cánh đúng tâm. Collider trimesh raycast chỉ tạo tạm trong QA để đo hình học khoang, không gắn vào GLB hoặc wrapper chơi.
- Đã xem ảnh màu `palace_motion_active.png`, `palace_chest_open.png` và bản trắng đen. Khoang rương mở rõ, không còn đai chạy xuyên lòng. Gỗ có độ sáng thấp đúng vai trò màu nâu tối; trên nền trống tối trong gallery, thân gỗ có tương phản yếu. Vì vậy không coi toàn bộ silhouette đã đạt trong mọi cảnh; cần duyệt đồ gỗ trên sàn sáng và dưới vũng đèn của phòng thực tế.
- Chụp lại cả năm trang gallery đủ 45 mẫu, ghép ảnh `palace_catalog_contact_sheet.png` cùng bản trắng đen. Sàn sáng hơn tường, phần sáng tương tác nổi rõ trong bối cảnh thử. Gallery nhỏ chỉ là bảng tổng quan; không dùng kích thước ảnh ghép để kết luận khả năng đọc mọi vật nhỏ ở camera gameplay.
- Audit xuất mới bằng `output/wind_palace/audit_exports.py`: 45 GLB, 5.440 tam giác; vertex color hoặc emission đúng phần, tối đa hai material/file, không texture/camera/light/default Cube, triangle list, unit scale và post-import dùng chung đúng. Tất cả số tam giác khớp manifest. Log renderer `output/wind_palace/motion_visual.log`, `catalog_latest.log`; báo cáo `qa/motion_report.json`, `qa/glb_audit_latest.json`.

Lượt tiếp theo ưu tiên duyệt tạo hình/độ sáng đồ gỗ trong phòng và khả năng đọc chủ đề Gió ở camera thật. Giữ phần gameplay đã kiểm tra làm mẫu tích hợp; không tự mở rộng sang inventory/loot hay thay map chính chỉ để hoàn thiện bộ model. Bố cục khám phá cuối và art theo Death's Door vẫn cần hoàn thiện, chưa báo đạt.

## Lượt tiếp tục thứ bảy ngày 25 tháng 10 năm 2026

Tổng vẫn **45 model**, không dựng lại bộ đã hoàn thành. Đã tinh chỉnh hai mẫu trong Blender và sửa một lỗi ánh sáng thấy được khi ghép đèn vào phòng.

- Giá sách giữ thân gỗ #4A3A2E, thêm phần đỉnh có hình tam giác rộng và đế đá để tách hình khối. Kích thước mới 2.48 × 0.76 × 3.5m theo Blender, pivot vẫn ở đáy giữa. Đây là thay đổi tạo hình, không nâng emission hoặc đổi màu gỗ sang cam.
- Cờ thêm ba dải gió bằng vertex color đá #8A8F96, không phát sáng. Dải gió ghép vào mesh `Cloth` nên đi cùng phần vải khi biến đổi; không thêm material, texture hoặc cơ chế tương tác cho cờ.
- Hai GLB đã xuất và file `.blend` ngoài project đã lưu. Kiểm tra hai mẫu trong Blender không có mặt chưa triangulate, smooth shading hoặc scale khác 1; file nguồn không còn thay đổi chưa lưu. Script `output/wind_palace/refine_palace_identity.py` có chặn chạy trùng, không dùng builder ban đầu để tạo lại chúng.
- Scene QA mới `tests/wind_palace_kit/palace_wood_review.tscn` dùng FOV 30 độ và transform camera lấy từ camera của Player, không thu nhỏ đồ gỗ để làm ảnh đẹp hơn. Độ cao capsule 1.8m chiếm **6.92% chiều cao ảnh** ở điểm đứng thử; đây là phép chiếu capsule, không phải đo chính xác mọi pixel của model cáo/animation.
- Chạy hai mức sáng trong cùng phòng: ambient/sun 0.9/0.8 và 0.32/0.2; các đèn vàng giữ energy 2.0, range 5.5m. Đây là preset QA cục bộ, không thay environment hoặc ánh sáng map chính. Đã xem ảnh màu và grayscale trong Godot Compatibility/MX230. Bàn, ghế và rương đọc được nhờ silhouette tối trên sàn sáng; thân gỗ trên nền tường tối vẫn không nên dùng làm điểm dẫn đường nếu thiếu đèn. Chốt rương và cáo cam còn nổi trong ảnh màu; chưa nghiệm thu combat/che khuất.
- Lượt đầu lộ các mảng bóng đa giác rất lớn từ chính chụp/mesh đèn đứng, làm đứt vũng sáng dẫn đường. Đã cập nhật post-import để cả hai model `standing_lantern` và `wall_lantern` tắt cast shadow của phần hình nhỏ. Giữ shadow của đèn để bàn/rương và kiến trúc vẫn có bóng. Trước/sau được chụp lại thật; mảng bóng do chụp đèn biến mất, vũng vàng liên tục hơn.
- Thêm wrapper phần hình/ánh sáng `tests/wind_palace_kit/palace_standing_lantern.tscn`, dùng trực tiếp trong phòng kiểm tra. GLB vẫn không chứa light/camera; OmniLight thuộc scene Godot, màu #F2B45A. Wrapper này chưa có collider và không thay model trong scene gameplay chính.
- Sau thay post-import, lượt import đầu vẫn dùng cache cũ của hai đèn; không lấy ảnh đó làm kết quả cuối. Đã tạo lại riêng cache `.scn` dẫn xuất của hai đèn rồi import, chờ hoàn tất và chụp lại. Runtime cuối `output/wind_palace/wood_after.log` không có script/shader error. Editor import vẫn có lỗi checkpoint khi đóng đã ghi từ trước, ngoài phạm vi bộ model.
- Báo cáo góc camera và mẫu pixel bề mặt: `qa/wood_review_before.json`, `wood_review_after.json`. Một điểm được chiếu qua mặt bàn nên trường là `visible_surface_samples`, không gọi tất cả là màu sàn. Ảnh cuối: `palace_wood_after_day.png`, `palace_wood_after_lamplit.png`, các bản `_grayscale.png` và `palace_wood_lighting_comparison.png`.
- Audit 45 GLB sau sửa: **5.518 tam giác**, không có mục lỗi; số material/vertex color, texture/camera/light, scale, post-import và số tam giác trong manifest đều đạt các phép kiểm kỹ thuật. Bảng catalog ở lượt trước là ảnh lịch sử trước hai thay đổi tạo hình này; ưu tiên ảnh phòng mới khi duyệt giá sách/cờ.

Việc tiếp theo: duyệt bộ hình ở góc camera Player trên cụm nhiều tầng đã có, nhất là khả năng thấy điểm đến/nhánh phụ và mức che khuất của rail/tường. Chỉ sửa module hoặc bố trí scene thử cần thiết; không tự mở thêm hệ thống gameplay. Chưa coi bộ art hoặc bố cục map chính đã được duyệt theo Death's Door.

## Lượt tiếp tục thứ tám ngày 25 tháng 10 năm 2026

Tổng vẫn **45 model**. Đã dùng camera Player để duyệt tuyến lên tầng trên, sửa phần vòm tầng dưới trong Blender và kiểm tra thêm hướng mặt của bộ model.

- `palace_route_demo.tscn -- --verify --capture --player-camera-review` dùng chính camera/FOV/lookahead của Player. Thêm kiến trúc hậu cảnh, cờ và đèn trong chế độ QA này; chế độ route mặc định vẫn dùng bố cục/camera thử trước. Không thay camera hay map chính.
- Tuyến đi lên tới rương và quay xuống chạy lại bằng Input Map, đạt **19 kiểm tra PASS** trên Godot Compatibility/MX230 sau lần sửa model cuối. Chụp điểm bắt đầu và bốn waypoint; đã xem ảnh màu và grayscale. Đây vẫn là tuyến thử, chưa phải một map khám phá có nhánh phụ hoàn chỉnh.
- Đo che khuất bằng hai ảnh render cùng pose: phủ material magenta không chịu đèn lên mesh của Player, chụp với môi trường và khi ẩn riêng mesh môi trường, đếm pixel magenta. Material này chỉ dùng tạm trong QA, không phải màu game hoặc asset xuất. Camera, animation và physics Player chỉ tạm dừng khi đứng yên chụp cặp ảnh, khôi phục trước khi tiếp tục đi; không dùng tạm dừng để vượt tuyến.
- Kết quả năm pose: **100%, 100%, 100%, 86.4%, 76.5%** số pixel model Player (có cả phần trang bị) còn thấy được. Hai pose cuối bị rail che một phần thấp; đã xem ảnh và vẫn thấy đầu/thân. Không dùng tỷ lệ này làm chứng nhận cho mọi chuyển động, góc nhìn hoặc combat. Lần đo đầu có lệch 1–3 pixel khi pose chưa ổn định; đã dừng pose và chờ render, đo lại ra tỷ lệ ổn định. Báo cáo `qa/route_player_camera_report.json`, log `route_player_camera.log`.
- Ảnh đầu có sọc đồng phẳng trên mặt ledge tầng dưới vì đỉnh ledge trùng mặt sàn. Đã hạ vị trí kết cấu trong scene thử từ -5m xuống -5.26m, giữ phần sàn chơi ở 0m. Đây là chỉnh mối ghép của scene thử, không đổi cao độ waypoint/collider của đường đi.
- Ảnh cận `inspect_foundation.gd` cho thấy các vệt tối/giao khối cũng có khi tắt sương. Không thay shader sương để che lỗi hình học. Kiểm tra Blender phát hiện 48 khối kín có hướng mặt đảo trong 7 mẫu: các vòm, corbel ban công và đỉnh giá sách. Đã đảo lại riêng các khối kín đó, giữ vertex colors, số tam giác và các phần chuyển động; cập nhật helper dựng vòm/corbel/đỉnh cho lần mở rộng sau. Không chạy lại builder cả bộ.
- Sửa hướng mặt chưa loại hết vệt giao khối ở kết cấu tầng dưới. Đã thay riêng mesh `lower_arch_foundation_6m` bằng mặt vòm liên tục có lỗ thật, bỏ các khối vòm chồng nhau; giữ kích thước **6 × 1.3 × 5m**, palette và root. Mẫu này giảm **192 xuống 72 tam giác**. Đã xuất lại GLB, import xong rồi xem ảnh cận màu/trắng đen với và không có haze. Vệt giao khối của mẫu cũ không còn trong ảnh mới. So sánh `qa/palace_foundation_comparison.png`; nguồn sửa `refine_foundation_arch.py`, có chặn chạy trùng.
- File Blender ngoài project đã lưu. Audit nguồn cuối: **401 khối kín** không còn volume âm, 9 phần hở không kiểm bằng volume (vải/mặt phẳng); không lỗi topology tam giác, flat shading hoặc scale trong các phép kiểm này. Báo cáo `qa/blender_health_audit_latest.json`; lịch sử sửa 48 khối ở `closed_normal_repair_report.json`. Audit GLB cuối: 45 file, **5.398 tam giác**, không lỗi các phép kiểm xuất. Runtime cuối không có script/shader error; lỗi checkpoint khi đóng editor vẫn là lỗi cũ ngoài phạm vi bộ hình.

**Việc phải làm tiếp về origin:** kiểm tra đáy trong hệ tọa độ root phát hiện 8 mẫu chưa đặt đúng đáy y=0 theo art guide. Giá trị dưới đây là Blender Z, tương ứng Godot Y: `floor_2m`/`floor_4m` -0.08m; `balcony_4m` -0.9m; `banner_hanging` +0.18m; `urn_small` +0.05m; `rubble_cluster` +0.0237m; `wall_lantern` +0.19m; `wind_boulder_visual` +0.045m. Những origin này không nằm trong phép kiểm GLB trước đó; không coi báo cáo xuất PASS là đã đạt quy cách pivot. Lượt kế tiếp ưu tiên chuẩn hóa 8 origin và cập nhật vị trí instance trong các scene thử để giữ nguyên mặt đi được/vị trí lắp; sau đó kiểm tra lại physics và ảnh. Giữ pivot riêng của phần xoay và không dựng lại các mẫu đã có.

Bố cục map chính, art cuối theo Death's Door và độ đọc trong combat vẫn chưa nghiệm thu.

## Lượt tiếp tục thứ chín ngày 25 tháng 10 năm 2026

Đã hoàn tất việc chuẩn hóa origin trong Blender và kiểm chứng lại trong Godot. Tổng vẫn **45 model / 5.398 tam giác**.

- Kiểm tra cả ba trục phát hiện ngoài 8 mẫu lệch đáy đã ghi còn 14 mẫu có tâm ngang lệch. Đã chỉnh **22 root** để tâm bounds ở X/Z=0 và đáy Y=0 trong Godot, theo rest pose. Không dựng lại hình học. Root của 23 mẫu còn lại đã đúng và giữ nguyên.
- Di chuyển origin bằng cách giữ world transform của các nhánh con: toàn bộ vertex trong catalog Blender có độ lệch thế giới lớn nhất **0m** trong phép đo trước/sau; pivot bản lề, nắp, vải và các phần chuyển động giữ vị trí trong bộ hình. File `.blend` ngoài project đã lưu. Sai số đáy giữa lớn nhất của nguồn sau chỉnh khoảng **0.00000204m** do số thực; báo cáo `qa/blender_health_audit_latest.json`.
- Xuất lại riêng 22 GLB đã chỉnh. Mỗi mẫu này có node `AssemblyAnchor` giữ điểm lắp trước đây; post-import chuẩn hóa tên node để bỏ hậu tố tự sinh của Blender. Dữ liệu bù tọa độ nằm trong `legacy_placement_offset_godot` của từng entry manifest.
- Các phòng QA cũ được bù vị trí instance để giữ mặt sàn, chỗ đặt vật và đường đi. Helper `tests/wind_palace_kit/palace_preview_placement.gd` chỉ dùng cho những bố cục QA đã có. Năm wrapper cầu thang/gallery/rương/tường cửa/tường cửa sổ bù riêng vị trí node `Model`; collider, root gameplay và waypoint giữ nguyên. Các script tạo wrapper cũng đã đọc offset từ manifest để không làm lệch khi tái tạo scene.
- Chạy `output/wind_palace/inspect_origins.gd` trên GLB Godot đã import: **45/45** có đáy Y=0, tâm X/Z=0 và scale root=1 trong dung sai 0.001m; cả 22 node `AssemblyAnchor` đúng vị trí tương đối. Báo cáo `qa/godot_origin_audit.json`, log `origin_audit.log` không có mục thất bại. Đây là kiểm tra từ bounds renderer Godot, bổ sung cho số đo nguồn Blender.
- Chạy lại với renderer Compatibility/MX230: **22/22** kiểm tra chuyển động; **20/20** tích hợp vật lý bệ nâng/cửa; **19/19** tuyến đi thật lên rương và quay về bằng Input Map/camera Player. Runtime các lượt cuối không có script/shader error. Lỗi checkpoint khi đóng editor import vẫn là lỗi cũ đã ghi, chưa sửa trong phạm vi bộ model.
- Chụp và xem lại ảnh màu/trắng đen của phòng gỗ, tuyến nhiều tầng và bảng 5 trang đủ 45 mẫu. Sàn/tường vẫn tách độ sáng, vũng vàng dẫn đường còn liên tục, cờ không phát sáng và chốt tương tác vẫn nổi. Ảnh mới dùng cùng ánh sáng và bố cục đã bù. So sánh pixel trước/sau được lưu ở `qa/origin_preview_comparison.json`; có sai khác nhỏ, không coi ảnh là giống hệt từng pixel.
- Các ảnh và báo cáo chính trong phần đầu README đã được cập nhật bằng bản render sau chuẩn hóa origin. Audit GLB và audit nguồn (401 khối kín, 9 phần hở không đo volume) không có mục lỗi trong các phép kiểm đã nêu. Các phép này không thay thế đánh giá art và bố cục.

**Cách lắp từ phiên bản origin mới:** kéo GLB vào scene thì điểm đặt là đáy giữa của toàn model. Ví dụ `floor_4m` có tổng chiều cao 0.32m; đặt root ở Y=-0.32m để mặt đi trên cùng ở Y=0. Với ban công, đáy giữa nằm ở chân corbel, nên mặt deck nằm cao hơn root. Bounds từng mẫu đã chỉnh nằm trong manifest; không dùng các tọa độ root cũ để suy ra mặt đi. Khi cần khớp điểm lắp cũ, dùng node `AssemblyAnchor` hoặc xem helper của các scene QA. Bộ mới không cần helper nếu lắp trực tiếp bằng origin đáy giữa.

Việc tiếp theo ưu tiên trình bày/lắp thử một cụm khám phá có nhánh phụ và đường quay về bằng những module đã có, kiểm tra camera và khả năng đọc điểm đến. Các kiểm tra origin đã xong; không chạy lại builder hoặc đổi origin tiếp khi chưa có lỗi mới. Giữ phạm vi trong scene thử và bộ model, chưa thay map chính hoặc thêm hệ thống inventory/loot.

## Lượt tiếp tục thứ mười ngày 25 tháng 10 năm 2026

Đã ghép được một cụm khám phá chơi thử từ các module hiện có. Bộ nguồn vẫn **45 GLB / 5.398 tam giác**; không tạo thêm hoặc dựng lại model.

- Đã kết nối Blender, xác nhận đúng file nguồn ngoài project và không có thay đổi chưa lưu. Đọc tâm phần kính của `wall_lantern` trong hệ Godot là `(0, 0.34, 0.15009535)` để đặt OmniLight đúng chụp. Thêm wrapper ánh sáng `palace_wall_lantern.tscn`, dùng màu #F2B45A, energy 1.4/range 4.8m trong preset thử; light vẫn ở scene Godot, không nhúng vào GLB.
- Scene `tests/wind_palace_kit/palace_exploration_demo.tscn` gồm hành lang tầng dưới, góc thư viện bên trái, cầu thang lên gallery tầng 2m, nhánh hẹp dẫn tới rương, cầu thang thứ hai quay 180 độ để xuống lối bên phải và vòng về cửa vào. Nhánh rương tách khỏi tuyến vòng, không chặn đường xuống bằng rương. Vòng này đi được sẵn theo cả hai hướng; chưa có cơ chế mở khóa đường tắt hoặc thiết kế puzzle gió hoàn chỉnh.
- Cụm mới dùng GLB với origin đáy giữa mới: sàn đặt đáy thấp hơn mặt đi 0.32m; tường/rail/đồ gỗ có box collider đơn giản. Cầu thang, gallery, rương và cửa sổ tái sử dụng wrapper đã kiểm tra. Kết cấu thấp dùng lại material haze theo chiều cao; sàn chơi không gán haze. Khối dưới sàn đặt tránh trùng mặt trên ledge với sàn.
- Dùng Player và camera/FSM thật, trụ nạp gió từ scene đã có; không sửa code Player hoặc scene map chính. Chỉ tái sử dụng driver kiểm tra và phép đo che khuất của route demo. KillZone không lethal có sẵn được đặt dưới cụm để hỗ trợ chơi thủ công; lượt verify dừng nếu chân thấp hơn -0.25m, không dùng hồi về của KillZone để hoàn tất tuyến.
- `-- --verify --capture` đã chạy trên Godot Compatibility/MX230: **36/36 PASS**. Player đi vào nhánh thư viện rồi quay ra; lên tầng 2m; tới rương; quay ra nhánh; xuống cầu thang thứ hai; theo lối tầng dưới trở về điểm xuất phát. Không bấm nhảy, dịch chuyển hoặc tắt physics khi đi. Tất cả 16 waypoint đạt vị trí/cao độ; chân thấp nhất ghi được khoảng **0.000339m**, không có lượt rơi vào KillZone. Ray ở khoảng trống sân trong không chạm sàn vô hình.
- Đo che khuất bằng cặp ảnh render tạm như lượt trước: ở điểm rương và chân cầu thang thứ hai, 100% pixel mesh Player/trang bị còn thấy trong hai pose đã đo. Các pose được dừng tạm riêng lúc chụp mask, sau đó khôi phục; không suy ra mọi chuyển động đều không bị che. Báo cáo `qa/exploration_report.json`, log `exploration_visual.log`.
- Đã xem ảnh màu và grayscale của tổng quan, góc Player ở ngã rẽ/rương và góc thư viện. Mặt đi sáng hơn tường, các khoảng trống tối rõ, chốt rương xanh ngọc phát sáng khác cờ trang trí. Vũng vàng chỉ dẫn lối và nhánh thưởng; ánh sáng thư viện dịu hơn. Cáo vẫn đọc được bằng silhouette và màu cam trong cảnh này; chưa kiểm tra combat/quái hoặc mọi mép nhảy.
- Ảnh tổng quan là camera trình bày riêng; các ảnh ở waypoint dùng camera Player FOV 30 độ. Sau khi tuyến PASS chỉ chỉnh khung camera tổng quan và chụp lại, không đổi geometry/collider/tuyến. Runtime verify và capture cuối không có script/shader error. Lỗi checkpoint khi đóng editor import là lỗi cũ ngoài bộ model.

Mở scene và F6 để tự đi thử. `-- --capture` chỉ chụp tổng quan/điểm vào rồi thoát; `-- --verify --capture` chạy cả hai nhánh và vòng trở về. Ảnh: `palace_exploration_overview.png`, `palace_exploration_loot_fork.png`, `palace_exploration_loot_nook.png`, `palace_exploration_archive_nook.png` và các bản `_grayscale.png` trong thư mục QA. Rương hiện là model/collider để tới gần, chưa có nhận đồ; các props thư viện không tự thành vật tương tác.

Bộ V1 đã có bộ hình, chuẩn origin, mẫu collider/chuyển động và cụm khám phá để duyệt trực tiếp. Công việc tiếp theo chỉ nên sửa những vấn đề cụ thể thấy được khi duyệt art/camera/cạnh hở hoặc có yêu cầu mới; không tạo thêm model, hệ thống gameplay hoặc lặp lại các bài test chỉ để lấp lượt lịch. Chưa coi đây là map chính hoặc art cuối đã được người dùng duyệt.
