## Thay đổi gì

<!-- Ngắn gọn: thêm / sửa tính năng gì, vì sao. Có ảnh hoặc video thì kéo thả vào đây. -->

## Loại thay đổi

- [ ] Tính năng mới (`feat`)
- [ ] Sửa lỗi (`fix`)
- [ ] Chỉnh thông số / cảm giác chơi (`tweak`)
- [ ] Hình ảnh / VFX / âm thanh (`style`)
- [ ] Map / level
- [ ] Dọn dẹp, cấu hình, tài liệu (`chore`)

## Kiểm tra trước khi merge

- [ ] Đã chạy bộ test tại máy: `GODOT=<đường dẫn godot> bash dev/ci/run_tests.sh` và không có test hỏng
- [ ] Tính năng mới có scene test trong `tests/` và đã thêm vào `dev/ci/ci_suite.txt` (hoặc ghi lý do không cần)
- [ ] Đổi hành vi của tính năng cũ thì đã sửa test của nó trong PR này
- [ ] Đã chơi thử trong editor phần vừa sửa
- [ ] Không đụng file luật được bảo vệ (`CLAUDE.md`, `AGENTS.md`, `docs/map_building_rules.md`,
      `docs/export_release_rules.md`, `.claude/settings.json`, `.github/CODEOWNERS`, `.githooks/pre-commit`)
- [ ] Sửa map: đã làm theo `docs/map_building_rules.md`
- [ ] Viết script `@tool` / sửa cấu hình export: đã đọc `docs/export_release_rules.md`

## Cần người review chú ý

<!-- Chỗ nào chưa chắc, chưa test được, thông số nên chỉnh thêm... Không có thì ghi "Không". -->
