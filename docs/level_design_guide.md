# Hướng dẫn thiết kế map (Level Design Guide)

Tài liệu chung cho cả nhóm khi xây map. Chỉ ghi những gì nhóm đã chốt; mục nào chưa chốt ghi rõ "chưa chốt".

## 1. Đã chốt

- **Môi trường là vũ khí**: action-adventure, giải đố bằng môi trường, platforming nhẹ.
- **Không có wall jump.**
- **Không có đường tắt.**
- **Một kỹ năng gió duy nhất**: đẩy lùi; gió làm lửa cháy to và lan rộng hơn.
- **Cấu trúc lai**:
  - mỗi khu (zone) là một scene riêng;
  - các phòng trong cùng một khu nối liền mạch, không có màn hình chờ;
  - **không dùng cổng dịch chuyển (portal)**; cách nối giữa các khu **chưa chốt** (tạm thời các khu chưa nối với nhau).
- **Checkpoint**: đi qua là kích hoạt. Chết thì hồi sinh ở checkpoint; chưa có checkpoint thì về khu bắt đầu.

## 2. Kiểu map: khóa – chìa (giống Death's Door)

Người chơi gặp chỗ bị chặn (**khóa**), lấy **chìa** ở nơi khác rồi dùng chìa để mở đường.

- **Chìa** có thể là kỹ năng, cơ quan, hoặc vật phẩm nhặt được.
- Ví dụ: biển chặn đường vì thuyền không có gió. Người chơi lấy kỹ năng gió, rồi thổi vào buồm để thuyền chạy.

## 3. Nguyên tắc: không bắt người chơi đi qua lại nhiều

1. **Khóa và chìa nằm gần nhau**: cùng một khu, cách nhau tối đa 1–2 phòng.
2. **Map đi theo vòng.** Lấy chìa xong, đường phía trước tự dẫn về sát chỗ khóa, không đi lại phòng đã qua.
3. **Lối ra chỉ mở bằng chìa vừa lấy** (ví dụ cửa mở bằng gió). Cửa này mở bằng kỹ năng nên không phải đường tắt.
4. **Cho thấy khóa trước khi lấy chìa**, để người chơi tự nhận ra cách giải ("à ra thế").
5. **Không có nhiệm vụ đi tìm đồ xuyên khu.** Mỗi khu tự giải hết các khóa của nó.

```
Không nên:  Khóa → X → Y → Chìa → (quay lại Y → X) → Khóa
Nên:        Khóa → X → Chìa → Lối ra mới (mở bằng chìa) → về sát Khóa
```

## 4. Một chìa mở nhiều khóa

Vì chỉ có một kỹ năng gió, gió phải dùng được cho nhiều loại khóa. Khóa không cần kỹ năng thì dùng cơ quan (công tắc, đòn bẩy, chìa khóa).

## 5. Object hiện có

| Object | Trạng thái |
|---|---|
| Luồng gió ngang (WindZone) | Đã có code |
| Cột gió đẩy lên (WindZone updraft) | Đã có code |
| Vực (KillZone) | Đã có code |
| Bẫy gai (SpikeTrap) | Đã có code |
| Checkpoint | Đã có code |
| Cổng dịch chuyển (Portal) | Có code nhưng **tạm không dùng** (giữ trong objects/portal/) |
| Tượng nhận kỹ năng (AbilityStatue) | Đã có code |
| Kỹ năng thổi gió | **Chưa có code** |
| Thuyền chạy bằng gió | **Chưa có code** |
| Chong chóng mở cổng | **Chưa có code** |
| Công tắc / đòn bẩy / chìa khóa | **Chưa có code** |
| Lửa cháy lan theo gió | **Chưa có code** |

## 6. Chưa chốt

- Bố cục cụ thể từng phòng của khu Gió.
- Màu chủ đạo khu Gió: trắng hay xanh pastel.
- Thiết kế boss khu Gió.
