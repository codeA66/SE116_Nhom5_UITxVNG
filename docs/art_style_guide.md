# Art Style Guide — SE116 Nhóm 5

Quy cách chung cho **mọi asset 3D** của game (nhân vật, quái, môi trường, đồ vật). Người hoặc AI làm model đọc file này trước khi dựng.

## 1. Phong cách

- **Low-poly, mặt phẳng lớn, cạnh sắc, shading phẳng, ít chi tiết nhỏ.**
- Camera cao, nhìn chéo từ trên xuống và ở xa: nhân vật chỉ chiếm khoảng 7% chiều cao màn hình. Hình khối phải đọc được từ xa nhờ silhouette rõ và màu tương phản với nền. Chi tiết nhỏ (hoa văn, chữ khắc) không thấy được thì không làm.
- Màu phẳng, ít màu trên một model. Không chibi, không kiểu đồ chơi / game mobile.

## 2. Kích thước nhân vật

- Vùng va chạm của nhân vật (player và quái thường) là capsule **cao 1.8 m, bán kính 0.35 m**. Model nhân vật cao khoảng 1.8 m để khớp vùng này.
- Mọi asset dựng theo tỉ lệ thật so với nhân vật: lối đi, cửa, bậc thang, lan can phải vừa với capsule trên.

## 3. Yêu cầu kỹ thuật

| Mục | Yêu cầu |
|---|---|
| Engine | Godot 4.7, renderer **GL Compatibility** (nhẹ, nên model càng phải gọn) |
| Định dạng | **`.glb`** (glTF 2.0 binary) |
| Đơn vị | 1 đơn vị = 1 mét |
| Trục | Y hướng lên; mặt trước của model hướng **+Z** trong Godot (= -Y trong Blender) |
| Gốc tọa độ (pivot) | Ở **đáy giữa**, y = 0 tại mặt đất. Phần cần xoay / chuyển động riêng thì pivot đặt tại trục xoay của phần đó |
| Màu | Tô bằng **vertex color**, không dùng texture. Dùng chung material của project để nhiều model gộp được khi vẽ |
| Vật liệu | **1 material cho mỗi model**. Phần cần phát sáng hoặc đổi màu theo trạng thái được thêm 1 material riêng |
| Phần tách riêng | Phần cần **phát sáng, xoay hoặc chuyển động** phải là mesh / node riêng, đặt tên rõ ràng |
| Transform | **Apply scale và rotation** trước khi xuất (scale = 1, rotation = 0) |

### Giới hạn số tam giác

| Loại | Giới hạn |
|---|---|
| Nhân vật chính | ≤ 8.000 (nên 3.000–5.000) |
| Quái thường | ≤ 5.000 |
| Boss | ≤ 15.000 |
| Vật nhỏ (cầm tay, vật phẩm) | ≤ 500 |
| Vật tương tác cỡ vừa | ≤ 2.000 |
| Khối môi trường lớn | ≤ 5.000 mỗi khối |
| Vật lặp lại nhiều lần (cỏ, đá vụn, lá) | càng ít càng tốt, khoảng vài chục tới vài trăm |

Camera xa nên vượt giới hạn không làm hình đẹp hơn rõ rệt, chỉ làm game nặng hơn.

### Để game không lag

- Không dùng subdivision / làm mịn. Không n-gon.
- Xóa mặt không bao giờ nhìn thấy (mặt đáy chạm đất, mặt bị khối khác che).
- Làm theo **module dùng lại được** (khối, cột, đoạn cầu...) thay vì một khối khổng lồ duy nhất.
- Vật nhỏ, vật lặp nhiều: tắt bóng đổ trong Godot, ít tam giác để có thể vẽ hàng loạt (MultiMesh).
- Collider dùng hình cơ bản (box, capsule, cylinder) đặt trong Godot, không dùng mesh chi tiết làm collider.
- Không nhúng texture, camera, đèn vào file `.glb`.

## 4. Lưu file

- File **`.glb`** đặt **trong project Godot**, trong thư mục `assets/models/` theo nhóm asset.
- File **`.blend`** (file gốc để sửa) để **ngoài project Godot**, không đặt trong thư mục project.
- Khi xuất từ Blender: chỉ chọn object của model rồi xuất với tùy chọn chỉ xuất phần đang chọn và apply modifier.

## 5. Checklist trước khi giao

- [ ] Đúng phong cách mục 1, nhìn rõ ở góc camera game (chéo từ trên xuống, từ xa)
- [ ] Đúng tỉ lệ với nhân vật (mục 2)
- [ ] Số tam giác trong giới hạn, số material đúng quy định
- [ ] Đúng trục, pivot, scale đã apply
- [ ] Phần sáng / xoay đã tách riêng
- [ ] `.glb` trong project, `.blend` ở ngoài project
- [ ] Kèm ảnh chụp ở góc camera game và ghi rõ những chỗ chưa chắc
