# Art Style Guide — SE116 Nhóm 5

Tài liệu mô tả phong cách hình ảnh và yêu cầu kỹ thuật cho model 3D của game, dùng để gửi cho họa sĩ hoặc AI tạo model.

- Mục **có thông số** = đã có trong project, làm theo đúng.
- Mục **`[CẦN NHÓM CHỐT]`** = nhóm chưa quyết, phải điền trước khi gửi cho AI.

---

## 1. Tổng quan game

| Mục | Nội dung |
|---|---|
| Thể loại | 3D hành động + giải đố |
| Góc nhìn | Camera **cao, chéo từ trên xuống**, cố định góc (không xoay) |
| Cơ chế chính | Nguyên tố tác động môi trường; khu đầu tiên là **Gió** |
| Các khu | Gió → Lửa → Băng → Mộc → Đền Trung Tâm (boss cuối) |
| Nhân vật chính | **Con cáo đứng 2 chân** (đã chốt). Model hiện tại trong project vẫn là hiệp sĩ KayKit tạm thời |
| Chất liệu văn hóa | **Thần thoại Đông Á** (đã chốt). Nhân vật cáo dựa trên hình tượng hồ ly / kitsune; số liệu nghiên cứu ở mục 7 |

## 2. Phong cách hình ảnh

### Phong cách mục tiêu (đã chốt: không theo KayKit)
- **Tối giản, thanh thoát, có chút bí ẩn.** Tham chiếu tinh thần: *Death's Door* (nền gần đơn sắc, một màu nhấn, khối lớn, bóng đổ đậm).
- **Low-poly, mặt phẳng lớn, cạnh sắc, shading phẳng**, ít chi tiết nhỏ.
- **Không** chibi, **không** đầu to, **không** kiểu đồ chơi / game mobile.
- **Môi trường tông tối, ít bão hòa** (xám đen); mỗi khu chỉ có **một màu nhấn** theo nguyên tố, dành cho vật quan trọng (nhân vật, tượng, checkpoint, cổng, quái).
- **Nhân vật nhỏ trên màn hình:** camera xa, nhân vật chỉ chiếm khoảng **7% chiều cao màn hình**, nên hình khối phải **dễ đọc từ xa** (silhouette rõ, màu tương phản với nền). Chi tiết nhỏ (hoa văn, khắc chữ) **không thấy được**.

### Asset tạm trong project
Nhân vật, animation và vũ khí hiện tại là gói **KayKit** (phong cách chibi). Đây **chỉ là đồ tạm để làm prototype**, **không phải** phong cách cuối và **không dùng làm mẫu** khi làm model mới.

## 3. Bảng màu đang dùng

| Vai trò | Màu | Hex |
|---|---|---|
| Sàn / môi trường chính | Xám đen | `#1F1F21` |
| Platform / bậc cao | Xám tối | `#3D3D42` |
| Vệt gió ngang | Trắng ánh xanh | `#D9F2FF` |
| Cột gió nâng | Xanh nhạt | `#8CD9FF` |
| Checkpoint đang kích hoạt | Vàng cam phát sáng | `#FFD980` |
| Thanh máu | Xanh lá | `#8CD161` |

### Màu chủ đạo theo khu nguyên tố
| Khu | Màu chủ đạo | Trạng thái |
|---|---|---|
| Gió | **Trắng** | Đã chốt |
| Lửa | **Đỏ** | Đã chốt |
| Băng | **Xanh dương đậm** | Đã chốt |
| Mộc | Chưa cần (làm sau) | Để sau |

Mã hex chính xác cho từng khu `[CẦN NHÓM CHỐT]` (màu ở bảng trên là màu đang dùng trong code).

## 4. Yêu cầu kỹ thuật (bắt buộc)

| Mục | Yêu cầu |
|---|---|
| Engine | Godot 4.7 |
| Định dạng | **`.glb`** (glTF 2.0 binary), hoặc `.gltf` + `.bin` |
| Đơn vị | **1 đơn vị = 1 mét** |
| Trục | **Y hướng lên** |
| Hướng nhìn của nhân vật | Mặt nhân vật hướng về **+Z** (code xoay model theo quy ước này) |
| Gốc tọa độ (pivot) | **Giữa hai chân, sát mặt đất** (y = 0 tại lòng bàn chân) |
| Chiều cao nhân vật người | Khoảng **1.8 m** (khớp vùng va chạm hiện tại) |
| Bóng đổ | Model nhỏ / trang trí nên dùng ít đa giác để tắt bóng đổ được |
| Vật liệu | **1 vật liệu cho mỗi model**, ưu tiên **một texture chung** cho nhiều model. Phần cần phát sáng hoặc đổi màu theo trạng thái được phép thêm 1 vật liệu riêng |
| Số đa giác | Xem bảng "Giới hạn số tam giác" ngay bên dưới |

### Giới hạn số tam giác
Mốc hiệu năng tham khảo (chỉ dùng số liệu, không dùng phong cách): asset tạm trong project có nhân vật **5.800–7.562** tam giác, kiếm **~300**, khiên **~284**, đều chạy tốt.

| Loại model | Giới hạn tam giác | Ví dụ |
|---|---|---|
| Nhân vật chính (cáo) | **≤ 8.000** (nên 3.000–5.000) | Tính cả đuôi |
| Quái thường | **≤ 5.000** | Nhiều con xuất hiện cùng lúc nên nhẹ hơn nhân vật chính |
| Boss | **≤ 15.000** | Xuất hiện một mình, to trên màn hình |
| Vũ khí, vật nhỏ cầm tay | **≤ 500** | Kiếm, vật phẩm |
| Vật tương tác cỡ vừa | **≤ 2.000** | Tượng kỹ năng, checkpoint, cổng, chong chóng, cổng song sắt |
| Khối môi trường lớn | **≤ 5.000** mỗi khối | Mảng nền, vách đá, công trình; dùng lại nhiều lần thay vì làm khối khổng lồ |

Camera xa (nhân vật chỉ ~7% màn hình) nên vượt giới hạn **không làm hình đẹp hơn rõ rệt**, chỉ làm game nặng hơn.

### Con cáo (đã chốt)
- **Đứng 2 chân, tỉ lệ tự nhiên, thanh thoát**: đầu nhỏ, thân gọn, **chân cáo** (gập kiểu thú), đuôi lớn. **Không chibi, không giống KayKit.**
- **Khung xương và animation riêng** cho cáo (không dùng rig KayKit, vì animation KayKit làm cho tỉ lệ chibi, dùng lại sẽ mang "chất KayKit").
- Thiết kế chi tiết và câu lệnh gửi AI: xem **mục 6.1**.

### Animation cần làm cho nhân vật
Tối thiểu: **idle, run, jump, fall, dash, attack, pickup, hit, death**.
- Khung xương cần một **xương ở tay phải để gắn vũ khí** (code hiện gắn kiếm vào một xương tay).
- Trong lúc chưa có cáo, prototype vẫn chạy bằng nhân vật và animation KayKit tạm; khi thay, code chỉ cần đổi tên animation và xương gắn kiếm, không phải viết lại logic.

## 5. Danh sách model cần làm

### Đã có model tạm (khối cơ bản, cần thay)
| Vật | Mô tả chức năng | Kích thước hiện tại |
|---|---|---|
| **Tượng mở kỹ năng** | Người chơi bấm E để nhận kỹ năng; quả cầu trên đỉnh **sáng lên** sau khi dùng | Bệ 1.4 × 1.4 m, cao tổng khoảng 2.5 m |
| **Checkpoint** | Đi ngang qua là lưu; **pha lê lơ lửng xoay** giữa một **vòng đá phẳng sát đất**, sáng khi kích hoạt. **Không được chắn đường đi** | Vòng đá đường kính khoảng 2.2 m; pha lê cao 0.6 m, lơ lửng ở độ cao 1.6 m |
| **Cổng dịch chuyển** | Đi xuyên qua để sang khu khác; dạng **vòng đứng** | Vòng đường kính khoảng 2.6 m, tâm cao 1.3 m |
| **Bẫy gai** | Mặt đất có gai, đứng lên bị đau | 2 × 2 m, gai cao khoảng 0.45 m |
| **Hình nộm tập** | Bao tập đánh | Cao 1.8 m |
| **Kiếm** | Đang dùng tạm `sword_1handed` của KayKit; cần thay bằng kiếm hợp phong cách mới | — |

### Khu Gió: vật môi trường (lấy từ nghiên cứu các game dùng gió)
Danh sách tổng hợp từ các khu gió trong *Zelda: The Wind Waker* (Đền Gió), *Zelda: Breath of the Wild* (Thần thú Vah Medoh, lá Korok) và *Zelda: Tears of the Kingdom* (Đền Gió). Cột "Có trong code" cho biết vật đã có cơ chế chưa.

| Vật | Chức năng (theo game tham khảo) | Trạng thái cần thể hiện | Nguồn tham khảo | Có trong code |
|---|---|---|---|---|
| **Luồng gió / vòi khí** | Đẩy nhân vật và vật nhẹ theo một hướng | Có gió / tắt gió (gió ngắt quãng) | Wind Waker | ✓ (`WindZone`, hiện chỉ là hiệu ứng hạt) |
| **Quạt sàn / cột gió nâng** | Đứng vào thì bay lên tầng trên | Đang thổi | Wind Waker, Vah Medoh, TotK | ✓ (`WindZone` xoay lên, có vòng sáng) |
| **Chong chóng / cối xay gió** | Thổi gió vào thì quay, mở đường | Đứng yên / đang quay | Wind Waker, Vah Medoh | Chưa |
| **Tua-bin "ổ khóa"** | Nhiều tua-bin phải được quay thì cửa chính mới mở | Chưa kích hoạt / đã kích hoạt | TotK (5 tua-bin khóa cửa) | Chưa |
| **Cổng / cửa song sắt** | Mở khi chong chóng hoặc tua-bin hoạt động | Đóng / mở | Wind Waker, Vah Medoh, TotK | Chưa |
| **Công tắc quạt** | Thổi gió vào thì kích hoạt | Tắt / bật | Wind Waker | Chưa |
| **Platform chạy trên ray** | Trượt đi khi được tác động | Đứng yên / đang trượt | Vah Medoh | Chưa |
| **Bè / thuyền có buồm** | Thổi vào buồm thì bè chạy | Buồm xẹp / buồm căng | BotW (lá Korok) | Chưa |
| **Vật nhẹ / vật nặng** | Vật nhẹ bị gió đẩy, vật nặng đứng yên | — (khác biệt phải nhìn ra được bằng hình dáng) | Wind Waker (giày sắt), BotW (quái lớn không bị đẩy) | ✓ (hệ số chịu gió) |
| **Quái bay** | Bị gió thổi rơi khỏi không trung | Bay / rơi | Wind Waker | Chưa |
| **Vực / mép vách** | Gió thổi quái hoặc người chơi rơi xuống | — | TotK (thổi quái nhẹ rơi khỏi vách) | ✓ (`KillZone`) |

Cột "Chưa" nghĩa là **chưa có code**. Danh sách này là tham khảo cho phần model; vật nào thực sự đưa vào game vẫn do nhóm quyết khi thiết kế màn.

## 6. Mẫu yêu cầu gửi AI tạo model

Điền các chỗ `[...]` rồi gửi:

```
Create a low-poly 3D model for a top-down action-adventure game (camera high and far,
character takes ~7% of screen height, so shapes must read clearly from distance).

Style: minimalist and elegant low-poly, flat shading, clean hard edges, simple large
shapes, limited color palette. Mood reference: Death's Door. NOT toy-like, NOT chibi,
NOT a mobile-game look. Environment is dark grey (#1F1F21); the object must contrast
against it.

Object: [TÊN VẬT]
Gameplay function: [CHỨC NĂNG]
Size: [KÍCH THƯỚC THEO MÉT]
States to show: [VÍ DỤ: inactive dim / active glowing [MÀU]]
Theme: East Asian mythology (fox spirit / kitsune, shrines, temples), [KHU NGUYÊN TỐ]

Technical: export .glb (glTF 2.0), 1 unit = 1 meter, Y-up, front faces +Z,
pivot at bottom center (y = 0 on the ground), low triangle count,
as few materials as possible. Separate any part that must glow or rotate
into its own mesh/node.
```

Dòng cuối quan trọng: phần **cần sáng** (quả cầu, pha lê) hoặc **cần xoay** phải là **mesh riêng**, để code đổi vật liệu hoặc xoay được mà không ảnh hưởng phần còn lại.

### 6.1. Con cáo: câu lệnh hoàn chỉnh
Nguyên tắc (học từ con quạ *Death's Door*): chỉ 3 nét nhận diện (tai, mõm, đuôi); 3 màu phẳng tương phản với nền xám; không chi tiết thừa; dễ thương nhưng có chút bí ẩn; điểm nhấn để dành cho vũ khí và nguyên tố. Mã màu dưới đây là đề xuất, nhóm có thể đổi.

```
Create a minimalist low-poly 3D character: an anthropomorphic FOX SPIRIT that stands
and walks on TWO legs, for a top-down action-adventure game (camera is high and far,
the character takes only ~7% of screen height, so it must read clearly from distance).

Design goals (minimalism and elegance first):
- Instantly readable silhouette with only 3 key features: tall triangular ears,
  a long slender snout, and a large flowing tail (about 1/3 of the silhouette).
- Slender, natural animal proportions: small head, lean body, digitigrade fox legs.
  NOT chibi, NOT big-headed, NOT cartoony or toy-like.
- Calm, graceful and slightly mysterious mood, inspired by East Asian fox spirit
  folklore (huli jing / kitsune). No clothes, no accessories, no armor.
- Exactly 3 flat colors, no painted textures, flat shading with clean hard edges:
  orange-red body (#E0602A), cream white chest and tail tip (#F2E6D0),
  dark brown lower legs and ear tips (#3A2A24). Eyes: small, simple, dark.
- Mood reference: the minimalist crow from Death's Door. Do NOT copy any existing
  character, and do NOT use a toy-like / mobile-game look.

Technical requirements:
- Neutral T-pose, arms straight out to the sides.
- Y-up, 1 unit = 1 meter, height about 1.6–1.8 m including ears, character FACES +Z,
  pivot at the center between the feet on the ground (y = 0).
- Under 8,000 triangles (aim for 3,000–5,000), 1 material using a small color
  palette texture.
- Separate meshes: Body, Head, Tail, Eyes.
- Export as .glb (glTF 2.0).
```

Với **AI tạo ảnh** (vẽ concept trước): bỏ phần *Technical requirements*, thêm *"front, side and back view, character turnaround sheet"*. Nhiều công cụ AI tạo model **chưa tạo khung xương**; khung xương và animation thường phải làm tiếp trong Blender.

## 7. Nghiên cứu chất liệu văn hóa (đã chốt: thần thoại Đông Á)

Số liệu dưới đây lấy từ báo cáo công khai (tra cứu tháng 10/2026). Phần lớn là **game lớn (AAA)**; dữ liệu về game indie theo văn hóa còn ít.

| Văn hóa | Bằng chứng thị trường | Ghi chú |
|---|---|---|
| **Thần thoại Trung Quốc** | *Black Myth: Wukong* (dựa trên Tây Du Ký): 10 triệu bản trong 3 ngày, ~20 triệu bản sau 1 tháng; game bán chạy nhất Steam 2024. Ước tính ~25% doanh số (9/2024), sau này có báo cáo hơn một nửa, đến từ ngoài Trung Quốc | Bằng chứng mạnh nhất. Con số "30 triệu bản" năm 2026 **bị nhà phát triển phủ nhận**, không nên trích |
| **Văn hóa Nhật Bản** | *Ghost of Tsushima*: hơn 13 triệu bản sau ~4 năm; hơn 1 triệu bản tại Nhật dù làm bởi studio phương Tây. Cáo là chi tiết được yêu thích: người chơi đã vuốt cáo hơn 75 triệu lần (số liệu nhà phát triển, 2 năm sau ra mắt) | Hình tượng **cáo (kitsune)** gắn chặt với văn hóa Nhật |
| **Thần thoại phương Đông kết hợp phong cách riêng** | *Nine Sols* (Đài Loan, thần thoại Đông Á + cyberpunk, gọi là "Taopunk"): vượt mục tiêu gây quỹ trong 24 giờ, được báo chí đánh giá cao | **Không tìm được số liệu doanh số** |
| **Văn hóa Việt Nam** | *The Scourge / Tai Ương* (kinh dị, Sài Gòn thập niên 90): nhà phát triển công bố hơn 37.000 bản, người chơi từ hơn 40 nước. *Curse of the Lineage*: nhà phát triển cho biết 70% wishlist từ nước ngoài | **Chưa có game nào thật sự viral**; số liệu chủ yếu do chính nhà phát triển công bố |
| **Game có nhân vật cáo** | *Tunic* (cáo nhỏ, góc nhìn isometric): ước tính ~317.000 bản trên Steam (bên thứ ba, độ tin cậy trung bình), có mặt trên Xbox Game Pass | Thành công tốt với game indie, nhưng **trùng nhân vật cáo**: cần khác biệt rõ về hình ảnh |

### Nhận định (dựa trên số liệu trên)
- **Thần thoại Đông Á** (Trung Quốc, Nhật) có bằng chứng thương mại lớn nhất hiện tại.
- **Con cáo** có sẵn vị trí trong thần thoại Đông Á: hồ ly (Trung Quốc, Việt Nam), kitsune (Nhật), kumiho (Hàn Quốc). Chọn hướng này thì nhân vật và văn hóa khớp nhau tự nhiên.
- **Văn hóa Việt Nam** là **điểm khác biệt** (ít game khai thác) nhưng **chưa có bằng chứng viral**: rủi ro cao hơn, đổi lại dễ nổi bật và hợp với đối tác VNG.
- Hướng có thể cân nhắc: **thần thoại Đông Á, lồng chất liệu Việt** (hồ ly trong truyện dân gian Việt, kiến trúc đình chùa, Ngũ hành). Có nền tảng thị trường mà vẫn có bản sắc riêng.

Đây là nhận định từ số liệu game lớn; **không có số liệu chứng minh** điều tương tự đúng với một game đồ án. Nhóm quyết định.

### Nguồn
- Black Myth: Wukong 10 triệu bản trong 3 ngày: https://www.rpgsite.net/news/16209-black-myth-wukong-sells-10-million-units-in-three-days
- Black Myth: Wukong, các mốc doanh số và tỉ lệ ngoài Trung Quốc: https://wnhub.io/news/investment/item-46973
- Black Myth: Wukong, tranh cãi con số 30 triệu: https://tweaktown.com/news/112271/black-myth-wukong-mirrors-gta-v-success-with-30-million-copies-sold-in-less-than-2-years/index.html
- Ghost of Tsushima 13 triệu bản: https://wnhub.io/news/finance/item-45579
- Ghost of Tsushima 1 triệu bản tại Nhật: https://www.pushsquare.com/news/2023/05/ghost-of-tsushima-topped-an-impressive-1-million-sales-in-japan
- Nine Sols: https://www.gematsu.com/2024/03/nine-sols-for-pc-launches-may-29
- The Scourge / Tai Ương: https://www.gamespress.com/The-Scourge-Tai-Uong-Brings-Vietnamese-Psychological-Horror-From-1990s
- Curse of the Lineage: https://www.buv.edu.vn/buv-students-bring-vietnamese-folklore-to-the-world-through-global-gaming-platform/
- Tunic, ước tính doanh số Steam: https://raijin.gg/app/553420/TUNIC
