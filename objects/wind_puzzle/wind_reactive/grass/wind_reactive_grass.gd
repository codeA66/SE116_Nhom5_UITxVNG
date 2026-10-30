class_name WindReactiveGrass
extends WindReactiveFoliage
## Cọng cỏ bứt ra có dạng sợi mảnh.

func _make_piece_mesh() -> PrimitiveMesh:
	var stem := CylinderMesh.new()
	stem.top_radius = 0.01
	stem.bottom_radius = 0.02
	stem.height = 0.17
	return stem
