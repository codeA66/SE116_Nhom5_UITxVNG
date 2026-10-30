class_name EnergyData
extends Resource
## Thông số thanh năng lượng kiểu Death's Door: đánh thường trúng thì nạp, cung / kỹ năng / chiêu ghép thì tiêu.
## Giá tiêu nằm ở dữ liệu của thứ tiêu (WeaponData, AbilityData, FusionData), không nằm ở đây.

## Số ô tối đa
@export_range(1, 20) var max_energy: int = 4
## Số ô nạp mỗi nhát đánh thường trúng (một nhát trúng nhiều mục tiêu vẫn chỉ nạp một lần)
@export_range(0, 20) var gain_per_hit: int = 1
