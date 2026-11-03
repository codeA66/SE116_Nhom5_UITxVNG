class_name DropEntry
extends Resource
## Một mục trong bảng rơi: loại tiền + số CỐ ĐỊNH (không ngẫu nhiên, để tính được tiền qua cổng / mua đồ).

@export var currency: CurrencyData
@export_range(0, 9999, 1, "or_greater") var amount: int = 1
