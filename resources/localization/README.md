# Bản dịch

Giữ câu tiếng Việt trong scene hoặc resource. Khi hiển thị dữ liệu từ resource trong một Label tự dịch, gán câu gốc vào `text`. Với chữ ghép, chữ viết hoa bằng code, hoặc vẽ trực tiếp, gọi `tr(câu_gốc)` trước khi định dạng. Dùng `tr_n()` cho số ít và số nhiều. Giữ nguyên placeholder và thay phím hiện tại sau khi dịch template.

UI đang mở dựng lại chữ ghép khi nhận `NOTIFICATION_TRANSLATION_CHANGED`. `Settings` lưu locale. `vi` là mặc định và fallback.

Để thêm ngôn ngữ, tạo một catalogue gettext, đăng ký file trong Project Settings > Localization và thêm tên ngôn ngữ vào `SettingsData.languages`. Không nhân bản resource gameplay.

Chạy `python tests/ui/check_localization.py` để rà literal trong các file nguồn dạng text. Kiểm tra thêm chữ ghép ở runtime và scene nhị phân.
