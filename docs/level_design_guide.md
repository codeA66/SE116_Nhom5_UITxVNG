# Hướng dẫn thiết kế map (Level Design Guide)

Tài liệu chung cho cả nhóm khi xây map. Chỉ ghi những gì nhóm đã chốt; mục nào chưa chốt ghi rõ "chưa chốt".

## 1. Đã chốt

- **Môi trường là vũ khí**: action-adventure, giải đố bằng môi trường, platforming nhẹ.
- **Không có wall jump.**
- **Đường tắt được phép nhưng hạn chế**: chỉ dùng để rút ngắn đường quay lại, không để bỏ qua câu đố.
- **Cấu trúc**:
  - mỗi khu (zone) là một scene riêng;
  - các phòng trong cùng một khu nối liền mạch, không có màn hình chờ;
  - các khu (và hang, phòng phụ) nối với nhau bằng **cổng dịch chuyển (Portal)** có chuyển cảnh.
- **Checkpoint**: đi qua là kích hoạt. Chết thì hồi sinh ở checkpoint; chưa có checkpoint thì về khu bắt đầu.
- **Quái đứng sẵn trong phòng**, không tự nhiên xuất hiện; trận bắt đầu khi người chơi bước vào.

## 2. Kiểu map: khóa – chìa (giống Death's Door)

Người chơi gặp chỗ bị chặn (**khóa**), lấy **chìa** ở nơi khác rồi dùng chìa để mở đường.

- **Chìa** có thể là kỹ năng, cơ quan, hoặc vật phẩm nhặt được.
- Ví dụ: biển chặn đường vì thuyền không có gió. Người chơi lấy kỹ năng gió, rồi thổi vào buồm để thuyền chạy.

## 3. Đường chính và đường phụ (có quay lại)

### Đường chính (để đánh xong game): không bắt đi qua lại nhiều
1. **Khóa và chìa nằm gần nhau**: cùng một khu, cách nhau tối đa 1–2 phòng.
2. **Map đi theo vòng.** Lấy chìa xong, đường phía trước tự dẫn về sát chỗ khóa.
3. **Cho thấy khóa trước khi lấy chìa**, để người chơi tự nhận ra cách giải ("à ra thế").

```
Không nên:  Khóa → X → Y → Chìa → (quay lại Y → X) → Khóa
Nên:        Khóa → X → Chìa → Lối ra mới (mở bằng chìa) → về sát Khóa
```

### Đường phụ: được quay lại khu cũ
- Khu cũ được phép có **bí mật, phần thưởng, phòng thử thách** chỉ mở được bằng kỹ năng nhặt ở khu sau (ví dụ vách ở Map Gió cần kỹ năng khu Lửa).
- Đây là nội dung cho người chơi sau khi đủ kỹ năng, trước khi vào Đền Trung Tâm đánh Final Boss.
- Để quay lại không mệt: mỗi khu có **đường tắt hoặc cổng** nối về Đền Trung Tâm.
- Chỗ khóa đường phụ phải **nhìn thấy được từ lần đầu đi qua**, để người chơi nhớ và muốn quay lại.

## 4. Câu đố: nhìn là hiểu, làm mới khó

- Vào phòng là thấy **mục tiêu** và **cơ chế** ngay; không giấu cách giải.
- Độ khó nằm ở **thực hiện**: canh nhịp gió, nối dash / nhảy / kỹ năng liên tục, sai một nhịp là hỏng.
- Vật tương tác phải **nổi bật nhất phòng**; không dùng đồ trang trí trông giống vật tương tác.
- Một kỹ năng nên dùng được cho nhiều loại khóa. Khóa không cần kỹ năng thì dùng cơ quan (công tắc, đòn bẩy, chìa khóa).

## 5. Chưa chốt

- Bố cục cụ thể từng khu sau Map Gió.
- Nội dung đường phụ ở từng khu (bí mật gì, mở bằng kỹ năng nào).
- Thiết kế Final Boss và Đền Trung Tâm.
