# Foxy - SE116 Nhóm 5 (UITxVNG)

[![CI](https://github.com/codeA66/SE116_Nhom5_UITxVNG/actions/workflows/ci.yml/badge.svg)](https://github.com/codeA66/SE116_Nhom5_UITxVNG/actions/workflows/ci.yml)

Game **3D hành động + giải đố**, camera nhìn chéo từ trên xuống, làm bằng **Godot 4.7.2 (GDScript)**.

Chú cáo Foxy phiêu lưu trên đảo Foxy: vượt 4 khu vực theo 4 nguyên tố (**Gió, Lửa, Băng, Sét**) rồi đánh Final Boss
ở **Đền Trung Tâm**. Mỗi khu vực cho một kỹ năng nguyên tố; kỹ năng dùng để mở đường, giải đố và đánh boss, ghép được
vào vũ khí (kiếm, cung) và nâng cấp được.

- GDD: <https://docs.google.com/document/d/1qCVMmGQN1oJioUDbPiM-4gmw_NNKXITcRHQCiNvJGJo>

## Tình trạng

| Phần | Trạng thái |
|---|---|
| Đền Trung Tâm (hub) | Có trong game (`levels/temple_center/hub`) |
| Khu Gió | Có trong game (`levels/zone_1_wind`) |
| Khu Lửa | Có trong game (`levels/zone_3_fire`) |
| Khu Băng, khu Sét | Chưa làm |

## Bắt đầu

1. Cài **Godot 4.7.2 stable** (bản thường, không phải .NET). Project dùng renderer **GL Compatibility**.
2. Clone repo:
   ```bash
   git clone https://github.com/codeA66/SE116_Nhom5_UITxVNG.git
   ```
3. Bật hook của repo (chặn commit lỡ sửa file luật được bảo vệ), chạy một lần sau khi clone:
   ```bash
   git config core.hooksPath .githooks
   ```
4. Mở Godot, **Import** file `project.godot`. Lần đầu Godot import toàn bộ tài nguyên, mất vài phút.
5. Bấm **F5** để chạy game (scene đầu là `levels/boot/boot.tscn`).

## Điều khiển

Chỉ hỗ trợ bàn phím + chuột.

| Phím | Hành động |
|---|---|
| W A S D | Di chuyển (8 hướng, theo góc camera) |
| Chuột trái / J | Đánh |
| Chuột phải (giữ) | Kéo cung, thả để bắn |
| Shift | Lăn né (dash) |
| E | Kỹ năng Gió |
| Q | Kỹ năng Lửa |
| R | Bùa đặc biệt |
| F | Tương tác / nhặt |
| Tab | Túi đồ, kỹ năng, bùa (Z / C đổi trang) |
| H | Trợ giúp |
| Esc | Tạm dừng |

Phím dành cho dev: F1 mở menu dev, F9 xoá save. Mọi phím chỉnh trong **Project Settings > Input Map**.

## Cấu trúc thư mục

Tổ chức **theo tính năng** (scene và script cùng tên nằm cùng thư mục), mỗi thư mục tối đa 6 mục con.

```
abilities/    kỹ năng (dash, gió, lửa, nâng cấp...) và ghép nguyên tố vào vũ khí
assets/       model, shader, VFX, âm thanh, UI (chia theo map: map_wind, map_fire...)
autoload/     GameState, SaveManager, SceneManager, ScreenShake, HitStop...
components/   component dùng chung: máu, hitbox / hurtbox, state machine, object pool, cháy, gió...
entities/     player (FSM dạng node), quái, boss, NPC
levels/       boot, hub (Đền Trung Tâm), khu Gió, khu Lửa
objects/      vật tương tác: cổng, vật nhặt, câu đố, bẫy...
resources/    dữ liệu cân bằng (.tres): chỉ số, đòn đánh, bùa, vật phẩm
ui/           HUD, menu, chuyển cảnh
tests/        scene test tự động và sân thử
dev/          công cụ dev (menu cheat, script CI)
docs/         tài liệu thiết kế (Godot bỏ qua)
```

## Quy trình làm việc

- **Nhánh:** mỗi tính năng một nhánh `feature/<tên>` tách từ `main`, xong thì mở Pull Request vào `main`.
- **Commit:** dùng tiền tố `feat`, `fix`, `tweak`, `style`, `chore`, `revert` kèm phạm vi, ví dụ
  `feat(fire): ...`, `fix(bow): ...`.
- **Quy tắc code:** xem [AGENTS.md](AGENTS.md) / [CLAUDE.md](CLAUDE.md): static typing, FSM dạng node cho nhân vật,
  component + Resource để mở rộng mà không sửa code cũ, thông số chỉnh được để `@export`, comment tiếng Việt.
- **File luật được bảo vệ** (chỉ chủ repo sửa): `CLAUDE.md`, `AGENTS.md`, `docs/map_building_rules.md`,
  `docs/export_release_rules.md`, `.claude/settings.json`, `.github/CODEOWNERS`, `.githooks/pre-commit`.
- **Xây / sửa map:** đọc [docs/map_building_rules.md](docs/map_building_rules.md) trước.
- **Bản export release:** đọc [docs/export_release_rules.md](docs/export_release_rules.md) trước khi viết
  script `@tool` hay sửa cấu hình export.

## Test

Test là các scene trong `tests/`: mở scene rồi bấm **F6**, hoặc chạy headless. Test in `PASS` / `FAIL` từng mục rồi
tự thoát. Một số sân thử cần tham số `--verify` để tự chạy, ví dụ:

```bash
godot --headless --path . res://tests/wind/wind/tornado/tornado_sandbox.tscn -- --verify
```

Chạy cả bộ test mà CI dùng (danh sách trong [dev/ci/ci_suite.txt](dev/ci/ci_suite.txt)):

```bash
GODOT=/đường/dẫn/tới/godot bash dev/ci/run_tests.sh
```

### Quy ước test

Mục tiêu: test luôn được chạy và luôn đúng với code hiện tại, không để test hỏng nằm đó.
CI **không bắt buộc** viết test cho mọi thay đổi; nó chỉ chạy các test đang có để chắc code mới không làm hỏng phần cũ.

1. **Khi nào nên viết test:** phần logic dễ hỏng ngầm mà chơi thử khó thấy:
   - luật chơi và con số (sát thương, hồi chiêu, năng lượng, điều kiện kích hoạt);
   - lưu / nạp save, tiến trình (nhặt đồ, nâng cấp, mở khoá, cờ đã qua phòng);
   - chuyển state của player / quái / boss;
   - câu đố, cổng, cơ chế map (mở đúng điều kiện, không kẹt).

   **Không cần test:** VFX, shader, âm thanh, ánh sáng, UI thuần hình ảnh, chỉnh thông số nhỏ, dựng map / đặt model
   (map có quy trình riêng trong [docs/map_building_rules.md](docs/map_building_rules.md)): chơi thử hoặc chụp ảnh là đủ.
2. **Cách viết:** scene test trong `tests/<nhóm>/<tên>/`: tự dựng tình huống, bấm phím / gọi hàm thật, mỗi mục in
   `PASS ...` hoặc `FAIL ...`, xong thì `get_tree().quit(1 nếu có FAIL, ngược lại 0)`. Thêm một dòng vào
   [dev/ci/full_suite.txt](dev/ci/full_suite.txt); test nhanh (dưới ~3 phút) và quan trọng thì thêm cả vào
   [dev/ci/ci_suite.txt](dev/ci/ci_suite.txt).
3. **Đổi hành vi của thứ đã có test thì sửa test trong cùng PR** (quy tắc bắt buộc duy nhất). Ví dụ bỏ sát thương của
   một chiêu thì sửa luôn test đang mong chiêu đó gây sát thương.
4. **Chạy test trước khi mở PR** (lệnh ở trên). Lỗi bắt tại máy rẻ hơn chờ CI báo.
5. **CI đỏ thì sửa trước khi merge.** Ai làm hỏng thì người đó sửa trong PR của mình.
6. **Test hỏng sẵn:** sửa test (game đổi thiết kế), sửa game (test đúng, game sai) hoặc xoá test (tính năng đã bỏ).
   Không để test FAIL mãi: quen nhìn đỏ thì không ai để ý đỏ nữa.

## CI

GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) chạy trên mỗi Pull Request vào `main` và mỗi lần
push lên `main`:

1. **Kiểm tra + test:** import project bằng Godot 4.7.2 headless, báo đỏ nếu có lỗi script / resource không load được,
   rồi chạy bộ test trong `dev/ci/ci_suite.txt`. Test hỏng thì log được lưu ở mục Artifacts của lần chạy.
2. **Build Windows** (chỉ khi push lên `main`): export bản release `Foxy.exe`, tải về ở tab **Actions** > lần chạy >
   mục **Artifacts** (giữ 14 ngày).

Thêm test vào CI: thêm một dòng vào `dev/ci/ci_suite.txt` (chỉ test tự thoát và đang PASS).

**Test hằng đêm** ([.github/workflows/nightly.yml](.github/workflows/nightly.yml)): 2 giờ sáng mỗi ngày chạy **toàn bộ**
test trong `dev/ci/full_suite.txt` trên `main`, chia nhóm chạy song song. Có test hỏng thì GitHub gửi email báo, log
từng nhóm nằm ở mục Artifacts. Chạy tay: tab **Actions** > **Nightly tests** > **Run workflow**.

## Tài liệu

- [Hướng dẫn thiết kế level](docs/level_design_guide.md), [luật xây map](docs/map_building_rules.md),
  [bố cục level 1](docs/level_1_layout.md)
- [Hướng dẫn nhân vật](docs/character_guide.md), [Foxy player](docs/foxy_player.md),
  [phong cách hình ảnh](docs/art_style_guide.md)
- Quái: [docs/enemies](docs/enemies), boss: [docs/bosses](docs/bosses)
- [Hội thoại NPC Map Gió](docs/npcs/wind_conversation.md)
- Khu Lửa: [docs/zone_3_fire](docs/zone_3_fire), Map Gió: [docs/map_wind](docs/map_wind)
