class_name AnimationMarkerSet
extends Resource
## Bộ marker cho một model. Thêm/chỉnh marker bằng cách sửa file .tres, không sửa code.

@export var markers: Array[AnimationMarker] = []


## Gắn marker vào các clip có trong thư viện; clip không có thì báo để biết dữ liệu đã lệch model
func apply_to(library: AnimationLibrary) -> void:
	for entry in markers:
		if entry == null:
			continue
		if not library.has_animation(entry.clip):
			push_warning("AnimationMarkerSet: không có clip '%s' cho marker '%s'" % [entry.clip, entry.marker])
			continue
		var animation := library.get_animation(entry.clip)
		if animation.has_marker(entry.marker):
			animation.remove_marker(entry.marker)
		animation.add_marker(entry.marker, clampf(entry.time, 0.0, animation.length))
