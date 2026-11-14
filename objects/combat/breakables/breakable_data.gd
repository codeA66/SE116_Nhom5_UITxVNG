class_name BreakableData
extends Resource
## Thông số một loại vật phá được (thùng gỗ, bình gốm, tinh thể...). Thêm loại mới = thêm .tres + scene hình, không sửa code.
## Năng lượng: nhát chém cận chiến trúng hurtbox nào cũng tự nạp (Attack._on_hit), nên vật này không tự cộng năng lượng.

## Số nhát chịu được trước khi vỡ (mỗi nhát chém trúng = 1 lần nạp năng lượng)
@export_range(1, 20) var max_hits: int = 3
## Vỡ xong bao lâu thì mọc lại (s); 0 = vỡ luôn không mọc lại
@export_range(0.0, 120.0, 0.1) var respawn_time: float = 5.0

@export_group("Trúng đòn")
@export_range(0.0, 0.5, 0.01) var shake_offset: float = 0.08
@export_range(0.02, 1.0, 0.01) var shake_time: float = 0.18
@export_range(0.02, 1.0, 0.01) var flash_time: float = 0.1
@export_range(0.0, 1.0, 0.01) var hit_trauma: float = 0.04
@export_range(0.0, 0.3, 0.01) var hit_squash: float = 0.13
@export_range(0.0, 0.4, 0.01, "suffix:m") var damage_part_offset: float = 0.15
@export_range(0.0, 45.0, 0.5, "degrees") var damage_part_tilt: float = 18.0
@export_range(1, 12) var hit_chip_count: int = 6

@export_group("Vỡ")
@export_range(0.1, 4.0, 0.05) var debris_time: float = 0.9
## Quãng văng ngang và độ cao vọt lên của mảnh (m)
@export_range(0.0, 8.0, 0.1) var debris_reach: float = 1.4
@export_range(0.0, 4.0, 0.1) var debris_lift: float = 0.9
@export_range(0.0, 1.0, 0.01) var break_trauma: float = 0.12
@export_range(0.0, 0.5, 0.01, "suffix:m") var debris_bounce: float = 0.09
@export_range(0.0, 90.0, 1.0, "degrees") var debris_landing_turn: float = 32.0

@export_group("Mọc lại")
@export_range(0.05, 2.0, 0.05) var respawn_grow_time: float = 0.35
@export_range(0.0, 2.0, 0.05, "suffix:m") var rebuild_lift: float = 0.55
@export_range(0.0, 0.2, 0.005, "suffix:s") var rebuild_stagger: float = 0.035
@export_range(0.02, 0.3, 0.01, "suffix:s") var rebuild_flash_time: float = 0.10
