class_name FxUtil
extends RefCounted
## Hàm dựng Curve / Gradient cho particle trong code (gọi một lần ở _ready, không gọi mỗi frame).


static func make_curve(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	for p in points:
		curve.add_point(p)
	return curve


## stops: [[offset, alpha], ...]; RGB trắng, màu thật nằm ở uniform tint của shader
static func make_alpha_gradient(stops: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Array in stops:
		offsets.append(stop[0])
		colors.append(Color(1.0, 1.0, 1.0, stop[1]))
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient
