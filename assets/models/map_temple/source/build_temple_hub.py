"""Dựng Đền Tứ Linh (hub trung tâm) bám sát concept 2D đã chốt 2026-11-26.

Concept: sân tròn lớn khắc vòng rune nổi trên biển mây; 4 khu nguyên tố theo góc, chạy theo chiều kim đồng hồ đúng
thứ tự mở khoá Gió (tây bắc) -> Lửa (đông bắc) -> Băng (đông nam) -> Sét (tây nam); quả cầu thiên văn vàng ở tâm;
mạch năng lượng nhiều màu từ mỗi khu chạy vào tâm; cầu thang vào từ phía nam; xung quanh là vách núi, thác nước,
đảo nổi nhỏ có đền và cột sáng.
Mỗi khu là một cung điện (người dùng 2026-11-26: thay đất đá bằng cung điện):
- Gió: cung cẩm thạch trắng mái đồng xanh ngọc, tháp giữa chóp củ hành, hành lang cột tròn, cờ bay, dải gió xoáy.
- Lửa: thành đá đen viền vàng có răng cưa, tháp góc mái chóp vàng, đền bậc giữa đỉnh có lò lửa, hào dung nham.
- Băng: điện tròn mái vòm pha lê có sườn bạc, tháp nhọn pha lê, dãy vòm gothic phía trước.
- Sét: tháp kim đá tím sẫm, cột thu lôi đồng, vòng sáng nổi, tia sét giữa các đỉnh.
Khu chưa mở (AWAKE = False): đá xám, mạch tắt, màn tối chặn cổng. Bản xem trước để cả 4 khu thức như concept.

Toạ độ Blender: Z lên, +Y = bắc (xa camera), -Y = nam (cầu thang vào, phía camera). Đơn vị mét.
Đèn điểm trong collection PreviewLights chỉ để xem trước trong Blender, KHÔNG xuất sang game (renderer Compatibility
bật đèn lần đầu bị giật): trong game ánh sáng nguyên tố làm bằng vật liệu tự phát sáng + glow.
Texture Poly Haven (CC0) nằm trong source/textures/.

Chạy trong Blender đang mở (MCP) hoặc: blender -b -P build_temple_hub.py
"""

import math
import os
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

TEX_DIR: str = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")

# ---- Thông số bố cục -------------------------------------------------------------------------------------------
PLATFORM_RADIUS: float = 28.0
PLATFORM_THICKNESS: float = 1.6
UNDERSIDE_DEPTH: float = 22.0
SECTOR_RADIUS: float = 17.0
SECTOR_PAVING_RADIUS: float = 8.0
DAIS_RADIUS: float = 6.0
RAIL_HEIGHT: float = 1.1
RAIL_POST_SPACING: float = 2.4
GATE_HALF_WIDTH: float = 3.2
STAIR_HALF_WIDTH: float = 3.5
STAIR_DROP: float = 3.0
STAIR_RUN: float = 8.0
ISLAND_DISTANCE: float = 78.0

SECTORS: dict[str, float] = {"wind": 135.0, "fire": 45.0, "ice": -45.0, "thunder": 225.0}
SOUTH_ANGLE: float = 270.0
AWAKE: dict[str, bool] = {"wind": True, "fire": True, "ice": True, "thunder": True}

# Độ cao mặt trên các lớp trên sàn: tách nhau >= 3 cm để không bị vệt loang
Z_SEAM: float = 0.03
Z_RING: float = 0.07
Z_RUNE: float = 0.11
Z_CARVE: float = 0.10
Z_PAVING: float = 0.15
Z_GROUND_FX: float = 0.19
Z_CONDUIT: float = 0.24

ELEMENT_COLOR: dict[str, tuple[float, float, float]] = {
	"wind": (0.25, 0.95, 0.88),
	"fire": (1.00, 0.42, 0.06),
	"ice": (0.55, 0.82, 1.00),
	"thunder": (0.62, 0.30, 1.00),
}

random.seed(11)


# ---- Vật liệu ---------------------------------------------------------------------------------------------------
def _principled(mat: bpy.types.Material) -> bpy.types.Node:
	return next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")


def material(name: str, color: tuple[float, float, float], roughness: float = 0.85, metallic: float = 0.0,
		emission: tuple[float, float, float] | None = None, emission_strength: float = 0.0,
		alpha: float = 1.0) -> bpy.types.Material:
	mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	mat.use_nodes = True
	mat.diffuse_color = (*color, alpha)
	shader = _principled(mat)
	shader.inputs["Base Color"].default_value = (*color, 1.0)
	shader.inputs["Roughness"].default_value = roughness
	shader.inputs["Metallic"].default_value = metallic
	if emission is not None:
		key = "Emission Color" if "Emission Color" in shader.inputs else "Emission"
		shader.inputs[key].default_value = (*emission, 1.0)
		shader.inputs["Emission Strength"].default_value = emission_strength
	if alpha < 1.0:
		shader.inputs["Alpha"].default_value = alpha
		try:
			mat.surface_render_method = "BLENDED"
		except (AttributeError, TypeError):
			mat.blend_method = "BLEND"
	return mat


def tinted_image(prefix: str, tint: tuple[float, float, float]) -> bpy.types.Image:
	"""Ảnh Diffuse đã nhân màu, lưu trong textures/tinted/ (tạo một lần, lần sau dùng lại file đã có)."""
	key = "_".join(f"{c:.2f}" for c in tint).replace(".", "")
	folder = os.path.join(TEX_DIR, "tinted")
	path = os.path.join(folder, f"{prefix}_{key}_Diffuse.jpg")
	if not os.path.exists(path):
		import numpy
		os.makedirs(folder, exist_ok=True)
		source = bpy.data.images.load(os.path.join(TEX_DIR, f"{prefix}_Diffuse.jpg"), check_existing=True)
		width, height = source.size
		pixels = numpy.empty(width * height * 4, dtype=numpy.float32)
		source.pixels.foreach_get(pixels)
		pixels = pixels.reshape(-1, 4)
		pixels[:, :3] = numpy.clip(pixels[:, :3] * numpy.array(tint, dtype=numpy.float32), 0.0, 1.0)
		out = bpy.data.images.new(f"{prefix}_{key}_Diffuse", width, height)
		out.pixels.foreach_set(pixels.ravel())
		out.filepath_raw = path
		out.file_format = "JPEG"
		out.save()
		bpy.data.images.remove(out)
	return bpy.data.images.load(path, check_existing=True)


def tex_material(name: str, prefix: str, tint: tuple[float, float, float] | None = None) -> bpy.types.Material:
	"""Vật liệu PBR từ texture Poly Haven (Diffuse / Rough / nor_gl), ảnh nối thẳng vào shader để glTF xuất được.
	tint: nhân màu (ví dụ nhuộm đá cung Sét sang tím). glTF không xuất nút nhân màu nên màu nhuộm được nướng sẵn vào
	một ảnh Diffuse mới (textures/tinted/), không dùng nút Mix."""
	mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	mat.use_nodes = True
	nodes = mat.node_tree.nodes
	links = mat.node_tree.links
	shader = _principled(mat)
	for node in [n for n in nodes if n.type in ("TEX_IMAGE", "NORMAL_MAP", "MIX")]:
		nodes.remove(node)

	def image(suffix: str, non_color: bool) -> bpy.types.Node:
		path = os.path.join(TEX_DIR, f"{prefix}_{suffix}.jpg")
		node = nodes.new("ShaderNodeTexImage")
		node.image = bpy.data.images.load(path, check_existing=True)
		if non_color:
			node.image.colorspace_settings.name = "Non-Color"
		return node

	diffuse = image("Diffuse", False)
	if tint is not None:
		diffuse.image = tinted_image(prefix, tint)
	links.new(diffuse.outputs["Color"], shader.inputs["Base Color"])
	links.new(image("Rough", True).outputs["Color"], shader.inputs["Roughness"])
	normal_map = nodes.new("ShaderNodeNormalMap")
	normal_map.inputs["Strength"].default_value = 0.9
	links.new(image("nor_gl", True).outputs["Color"], normal_map.inputs["Color"])
	links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
	mat.diffuse_color = (0.3, 0.3, 0.3, 1.0)
	return mat


def build_materials() -> dict[str, bpy.types.Material]:
	mats = {
		"floor": tex_material("TH_Floor", "stone_tiles_02"),
		"paving": tex_material("TH_Paving", "stone_tiles"),
		"block": tex_material("TH_Block", "stone_wall_05"),
		"rock": tex_material("TH_Rock", "aerial_rocks_02"),
		"far_rock": tex_material("TH_FarRock", "aerial_rocks_02", tint=(0.55, 0.65, 0.85)),
		"wind_wall": tex_material("TH_WindWall", "white_sandstone_bricks_03", tint=(1.15, 1.15, 1.12)),
		"fire_wall": tex_material("TH_FireWall", "stone_block_wall", tint=(0.95, 0.78, 0.72)),
		"thunder_wall": tex_material("TH_ThunderWall", "stone_tile_wall", tint=(0.36, 0.28, 0.52)),
		"trim": material("TH_Trim", (0.07, 0.075, 0.085), roughness=0.7),
		"moss": material("TH_Moss", (0.06, 0.12, 0.045)),
		"gold": material("TH_Gold", (0.95, 0.66, 0.24), roughness=0.3, metallic=1.0),
		"gold_dark": material("TH_GoldDark", (0.45, 0.30, 0.10), roughness=0.4, metallic=1.0),
		"core": material("TH_Core", (0.85, 0.95, 1.0), emission=(0.75, 0.9, 1.0), emission_strength=6.0),
		"core_halo": material("TH_CoreHalo", (0.6, 0.85, 1.0), emission=(0.6, 0.85, 1.0), emission_strength=2.0,
			alpha=0.25),
		"off": material("TH_Off", (0.06, 0.06, 0.07), roughness=0.6),
		"veil": material("TH_Veil", (0.03, 0.015, 0.05), emission=(0.10, 0.03, 0.18), emission_strength=0.6,
			alpha=0.85),
		"cloud": material("TH_Cloud", (0.46, 0.52, 0.62), roughness=1.0),
		"rune": material("TH_Rune", (0.45, 0.80, 0.90), emission=(0.45, 0.85, 1.0), emission_strength=2.5),
		"rim_rune": material("TH_RimRune", (0.35, 0.6, 1.0), emission=(0.35, 0.6, 1.0), emission_strength=4.0),
		"waterfall": material("TH_Waterfall", (0.80, 0.90, 0.97), emission=(0.65, 0.82, 0.95), emission_strength=0.5,
			alpha=0.45),
		"mist": material("TH_Mist", (0.85, 0.9, 0.95), roughness=1.0, alpha=0.35),
		"fire_cloth": material("TH_FireCloth", (0.55, 0.06, 0.04), roughness=0.8, emission=(0.6, 0.1, 0.02),
			emission_strength=0.3),
		"beam": material("TH_Beam", (0.2, 0.5, 1.0), emission=(0.2, 0.5, 1.0), emission_strength=3.0, alpha=0.35),
		"basalt": material("TH_Basalt", (0.035, 0.03, 0.03), roughness=0.75),
		"lava": material("TH_Lava", (1.0, 0.35, 0.04), emission=(1.0, 0.32, 0.03), emission_strength=7.0),
		"flame": material("TH_Flame", (1.0, 0.55, 0.1), emission=(1.0, 0.5, 0.08), emission_strength=9.0, alpha=0.9),
		"flame_core": material("TH_FlameCore", (1.0, 0.9, 0.5), emission=(1.0, 0.85, 0.45), emission_strength=12.0),
		"ice": material("TH_Ice", (0.70, 0.86, 0.97), roughness=0.12, emission=(0.45, 0.72, 1.0),
			emission_strength=0.35, alpha=0.8),
		"crystal": material("TH_Crystal", (0.75, 0.92, 1.0), roughness=0.05, emission=(0.55, 0.85, 1.0),
			emission_strength=1.2, alpha=0.75),
		"frost": material("TH_Frost", (0.78, 0.88, 0.95), roughness=0.5),
		"storm_stone": material("TH_StormStone", (0.07, 0.055, 0.10), roughness=0.6),
		"bolt": material("TH_Bolt", (0.9, 0.8, 1.0), emission=(0.85, 0.7, 1.0), emission_strength=14.0),
		"leaf": material("TH_Leaf", (0.95, 0.55, 0.12), emission=(0.9, 0.5, 0.1), emission_strength=0.6),
		"marble": material("TH_Marble", (0.80, 0.80, 0.78), roughness=0.35),
		"patina": material("TH_Patina", (0.16, 0.50, 0.46), roughness=0.45, metallic=0.6),
		"wind_cloth": material("TH_WindCloth", (0.85, 0.95, 0.93), roughness=0.8, emission=(0.25, 0.9, 0.85),
			emission_strength=0.5),
		"basalt_tex": material("TH_FireStone", (0.05, 0.042, 0.04), roughness=0.55),
		"silver": material("TH_Silver", (0.78, 0.84, 0.90), roughness=0.25, metallic=0.85),
		"copper": material("TH_Copper", (0.75, 0.40, 0.20), roughness=0.35, metallic=1.0),
	}
	for element, color in ELEMENT_COLOR.items():
		mats[f"{element}_lit"] = material(f"TH_{element}_Lit", color, emission=color, emission_strength=6.0)
		mats[f"{element}_soft"] = material(f"TH_{element}_Soft", color, emission=color, emission_strength=2.2,
			alpha=0.55)
	return mats


def lit(mats: dict, element: str) -> bpy.types.Material:
	return mats[f"{element}_lit"] if AWAKE[element] else mats["off"]


def soft(mats: dict, element: str) -> bpy.types.Material:
	return mats[f"{element}_soft"] if AWAKE[element] else mats["off"]


# ---- Hình học ---------------------------------------------------------------------------------------------------
def polar(angle_deg: float, radius: float, z: float = 0.0) -> Vector:
	a = math.radians(angle_deg)
	return Vector((math.cos(a) * radius, math.sin(a) * radius, z))


def add_box(bm: bmesh.types.BMesh, center: Vector, size: tuple[float, float, float], rot_z: float = 0.0) -> list:
	verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
	bmesh.ops.scale(bm, vec=Vector(size), verts=verts)
	bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=Matrix.Rotation(rot_z, 3, "Z"))
	bmesh.ops.translate(bm, vec=center, verts=verts)
	return verts


def add_segment_flat(bm: bmesh.types.BMesh, a: Vector, b: Vector, width: float, height: float) -> None:
	"""Thanh nằm ngang trên sàn nối a -> b (đường khắc nổi)."""
	d = b - a
	d.z = 0.0
	mid = (a + b) * 0.5
	add_box(bm, Vector((mid.x, mid.y, height * 0.5)), (d.length, width, height), math.atan2(d.y, d.x))


def add_segment(bm: bmesh.types.BMesh, a: Vector, b: Vector, width: float, depth: float) -> None:
	"""Thanh hộp nối hai điểm 3D (dùng cho vòm, tia sét, mạch)."""
	d = b - a
	length = d.length
	if length < 1e-4:
		return
	verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
	bmesh.ops.scale(bm, vec=Vector((width, depth, length)), verts=verts)
	rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
	bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=rot)
	bmesh.ops.translate(bm, vec=(a + b) * 0.5, verts=verts)


def add_cyl(bm: bmesh.types.BMesh, center: Vector, r_bottom: float, r_top: float, height: float,
		segments: int = 32) -> list:
	"""center = tâm đáy."""
	verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r_bottom,
		radius2=r_top, depth=height)["verts"]
	bmesh.ops.translate(bm, vec=center + Vector((0, 0, height * 0.5)), verts=verts)
	return verts


def add_tapered_box(bm: bmesh.types.BMesh, base: Vector, w_bottom: float, w_top: float, height: float,
		rot_z: float = 0.0) -> list:
	verts = add_box(bm, Vector((0, 0, height * 0.5)), (w_bottom, w_bottom, height))
	for v in verts:
		if v.co.z > height * 0.5 - 0.001:
			v.co.x *= w_top / w_bottom
			v.co.y *= w_top / w_bottom
	bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=Matrix.Rotation(rot_z, 3, "Z"))
	bmesh.ops.translate(bm, vec=base, verts=verts)
	return verts


def add_annulus(bm: bmesh.types.BMesh, r_in: float, r_out: float, z_top: float, thickness: float,
		segments: int = 128, center: Vector | None = None) -> None:
	c = center or Vector()
	for i in range(segments):
		a0 = 360.0 * i / segments
		a1 = 360.0 * (i + 1) / segments
		pts = [polar(a0, r_in), polar(a0, r_out), polar(a1, r_out), polar(a1, r_in)]
		bottom = [bm.verts.new((c.x + p.x, c.y + p.y, z_top - thickness)) for p in pts]
		top = [bm.verts.new((c.x + p.x, c.y + p.y, z_top)) for p in pts]
		bm.faces.new(top)
		bm.faces.new(list(reversed(bottom)))
		for k in range(4):
			bm.faces.new([bottom[k], bottom[(k + 1) % 4], top[(k + 1) % 4], top[k]])


def add_torus(bm: bmesh.types.BMesh, center: Vector, major: float, minor: float, rotation: Matrix,
		segments: int = 64, ring_segments: int = 10) -> None:
	rings = []
	for i in range(segments):
		theta = 2 * math.pi * i / segments
		ring = []
		for j in range(ring_segments):
			phi = 2 * math.pi * j / ring_segments
			local = Vector(((major + minor * math.cos(phi)) * math.cos(theta),
				(major + minor * math.cos(phi)) * math.sin(theta), minor * math.sin(phi)))
			ring.append(bm.verts.new(center + rotation @ local))
		rings.append(ring)
	for i in range(segments):
		for j in range(ring_segments):
			a = rings[i][j]
			b = rings[(i + 1) % segments][j]
			c = rings[(i + 1) % segments][(j + 1) % ring_segments]
			d = rings[i][(j + 1) % ring_segments]
			bm.faces.new([a, b, c, d])


def add_prism(bm: bmesh.types.BMesh, base: Vector, radius: float, height: float, tip: float = 0.0,
		sides: int = 6, tilt: Vector | None = None) -> list:
	"""Lăng trụ n cạnh (bazan lục giác, tinh thể); tip > 0 thì có chóp nhọn."""
	verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
		radius2=radius * 0.92, depth=height)["verts"]
	bmesh.ops.translate(bm, vec=Vector((0, 0, height * 0.5)), verts=verts)
	if tip > 0.0:
		tip_verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=sides, radius1=radius * 0.92,
			radius2=0.0, depth=tip)["verts"]
		bmesh.ops.translate(bm, vec=Vector((0, 0, height + tip * 0.5)), verts=tip_verts)
		verts = verts + tip_verts
	if tilt is not None:
		bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=(Matrix.Rotation(tilt.x, 3, "X")
			@ Matrix.Rotation(tilt.y, 3, "Y")))
	bmesh.ops.translate(bm, vec=base, verts=verts)
	return verts


def box_uv(bm: bmesh.types.BMesh, size: float) -> None:
	"""Trải UV kiểu chiếu hộp theo toạ độ thế giới: texture lặp đúng cỡ thật (size mét mỗi ô)."""
	bm.normal_update()
	uv_layer = bm.loops.layers.uv.verify()
	for face in bm.faces:
		n = face.normal
		ax = max(range(3), key=lambda i: abs(n[i]))
		for loop in face.loops:
			co = loop.vert.co
			if ax == 2:
				uv = (co.x, co.y)
			elif ax == 0:
				uv = (co.y, co.z)
			else:
				uv = (co.x, co.z)
			loop[uv_layer].uv = (uv[0] / size, uv[1] / size)


TEX_SIZE: dict[str, float] = {"TH_Floor": 2.0, "TH_Paving": 3.17, "TH_Block": 2.055, "TH_Rock": 25.0,
	"TH_FarRock": 40.0, "TH_WindWall": 2.0, "TH_FireWall": 2.1, "TH_ThunderWall": 2.0}


def obj_from_bm(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material, coll: bpy.types.Collection,
		smooth: bool = False, bevel: float = 0.0) -> bpy.types.Object:
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	box_uv(bm, TEX_SIZE.get(mat.name, 2.0))
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.materials.append(mat)
	if smooth:
		for poly in mesh.polygons:
			poly.use_smooth = True
	obj = bpy.data.objects.new(name, mesh)
	coll.objects.link(obj)
	if bevel > 0.0:
		# Bo cạnh đá / kiến trúc: hết kiểu hộp cạnh sắc như nhựa
		mod = obj.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel
		mod.segments = 2
		mod.limit_method = "ANGLE"
		mod.angle_limit = math.radians(35.0)
		mod.harden_normals = True
	return obj


def collection(name: str) -> bpy.types.Collection:
	coll = bpy.data.collections.get(name) or bpy.data.collections.new(name)
	if coll.name not in bpy.context.scene.collection.children:
		bpy.context.scene.collection.children.link(coll)
	return coll


def _angle_in(angle: float, lo: float, hi: float) -> bool:
	return (angle - lo) % 360.0 <= (hi - lo) % 360.0


def preview_light(name: str, location: Vector, color: tuple[float, float, float], power: float,
		radius: float = 1.5) -> None:
	"""Đèn chỉ để xem trước trong Blender (không xuất sang game)."""
	coll = collection("PreviewLights")
	data = bpy.data.lights.new(name, type="POINT")
	data.energy = power
	data.color = color
	data.shadow_soft_size = radius
	obj = bpy.data.objects.new(name, data)
	obj.location = location
	coll.objects.link(obj)


# ---- Sân tròn --------------------------------------------------------------------------------------------------
def rail_gaps() -> list[tuple[float, float]]:
	gaps = []
	for angle in list(SECTORS.values()) + [SOUTH_ANGLE]:
		half = GATE_HALF_WIDTH if angle != SOUTH_ANGLE else STAIR_HALF_WIDTH
		half_deg = math.degrees(half / PLATFORM_RADIUS)
		gaps.append((angle - half_deg, angle + half_deg))
	return gaps


def build_platform(mats: dict) -> None:
	coll = collection("Platform")
	bm = bmesh.new()
	add_cyl(bm, Vector((0, 0, -PLATFORM_THICKNESS)), PLATFORM_RADIUS, PLATFORM_RADIUS, PLATFORM_THICKNESS, 160)
	obj_from_bm("Platform_Floor", bm, mats["floor"], coll)

	# Vành viền đá to quanh mép (bậc tròn như concept), rãnh lát, vành rune
	bm = bmesh.new()
	add_annulus(bm, PLATFORM_RADIUS - 2.2, PLATFORM_RADIUS - 0.05, Z_RING, Z_RING, 160)
	add_annulus(bm, PLATFORM_RADIUS + 0.0, PLATFORM_RADIUS + 0.35, 0.0, PLATFORM_THICKNESS + 0.4, 160)
	obj_from_bm("Platform_Rim", bm, mats["paving"], coll)

	bm = bmesh.new()
	for r_in, r_out in ((DAIS_RADIUS + 0.6, DAIS_RADIUS + 1.1), (13.6, 14.2), (20.2, 20.8)):
		add_annulus(bm, r_in, r_out, Z_RING, Z_RING)
	for k in range(36):
		a = k * 10.0 + 5.0
		for r0, r1 in ((DAIS_RADIUS + 1.3, 13.4), (14.4, 20.0), (21.0, PLATFORM_RADIUS - 2.4)):
			p0, p1 = polar(a, r0), polar(a, r1)
			mid = (p0 + p1) * 0.5
			add_box(bm, Vector((mid.x, mid.y, Z_SEAM * 0.5)), ((p1 - p0).length, 0.09, Z_SEAM), math.radians(a))
	for r in (10.2, 17.2, 23.2):
		add_annulus(bm, r - 0.05, r + 0.05, Z_SEAM, Z_SEAM)
	obj_from_bm("Platform_Seams", bm, mats["trim"], coll)

	# Rune phát sáng: vòng giữa trên sàn + vòng quanh mặt hông sân (concept có rune sáng quanh mép)
	bm = bmesh.new()
	for k in range(140):
		a = k * (360.0 / 140)
		p = polar(a, 20.5)
		add_box(bm, Vector((p.x, p.y, Z_RUNE - 0.02)), (0.14, 0.45 if k % 3 else 0.85, 0.04), math.radians(a))
	obj_from_bm("Platform_Runes", bm, mats["rune"], coll)

	# Hoa văn nổi: ngôi sao 8 cánh + hàng ô thoi quanh bệ tâm, vòng vảy giữa vòng 14 và vòng 20
	bm = bmesh.new()
	star_in, star_out = DAIS_RADIUS + 1.4, 12.8
	for k in range(16):
		a0 = k * 22.5
		tip = polar(a0, star_out if k % 2 == 0 else star_out - 2.6, Z_CARVE * 0.5)
		for side in (-11.25, 11.25):
			base = polar(a0 + side, star_in, Z_CARVE * 0.5)
			add_segment_flat(bm, base, tip, 0.22, Z_CARVE)
	for k in range(32):
		p = polar(k * 11.25 + 5.625, 10.4)
		add_box(bm, Vector((p.x, p.y, Z_CARVE * 0.5)), (0.55, 0.55, Z_CARVE), math.radians(k * 11.25 + 50.6))
	for k in range(60):
		a = k * 6.0
		p = polar(a, 17.0)
		add_box(bm, Vector((p.x, p.y, Z_CARVE * 0.5)), (1.4, 0.18, Z_CARVE), math.radians(a + 60.0))
		add_box(bm, Vector((p.x, p.y, Z_CARVE * 0.5)), (1.4, 0.18, Z_CARVE), math.radians(a - 60.0))
	obj_from_bm("Platform_Carving", bm, mats["trim"], coll)
	bm = bmesh.new()
	for k in range(180):
		a = k * 2.0
		p = polar(a, PLATFORM_RADIUS + 0.38)
		add_box(bm, Vector((p.x, p.y, -0.75)), (0.08, 0.5 if k % 4 else 0.9, 0.22 if k % 2 else 0.4),
			math.radians(a))
	obj_from_bm("Platform_RimRunes", bm, mats["rim_rune"], coll)

	# Đáy đá treo: nón ngược lởm chởm + mỏm đá nhọn rủ xuống
	bm = bmesh.new()
	verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=56, radius1=PLATFORM_RADIUS + 0.2,
		radius2=3.0, depth=UNDERSIDE_DEPTH)["verts"]
	bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=Matrix.Rotation(math.pi, 3, "X"))
	bmesh.ops.translate(bm, vec=Vector((0, 0, -PLATFORM_THICKNESS - UNDERSIDE_DEPTH * 0.5 + 0.05)), verts=verts)
	bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 3.0],
		cuts=3, use_grid_fill=False)
	for v in bm.verts:
		if v.co.z < -PLATFORM_THICKNESS - 0.4:
			jitter = 1.0 + random.uniform(-0.2, 0.12)
			v.co.x *= jitter
			v.co.y *= jitter
			v.co.z += random.uniform(-1.4, 1.0)
	for _k in range(16):
		p = polar(random.uniform(0, 360), random.uniform(6, 20), -PLATFORM_THICKNESS - random.uniform(4, 12))
		spike = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=7, radius1=random.uniform(1.5, 3.5),
			radius2=0.0, depth=random.uniform(6, 14))["verts"]
		bmesh.ops.rotate(bm, verts=spike, cent=Vector(), matrix=Matrix.Rotation(math.pi, 3, "X"))
		bmesh.ops.translate(bm, vec=p, verts=spike)
	obj_from_bm("Platform_Underside", bm, mats["rock"], coll)

	# Lan can mép sân
	gaps = rail_gaps()
	bm_posts = bmesh.new()
	radius = PLATFORM_RADIUS - 0.45
	count = int(2 * math.pi * radius / RAIL_POST_SPACING)
	usable = [360.0 * i / count for i in range(count)]
	usable = [a for a in usable if not any(_angle_in(a, lo, hi) for lo, hi in gaps)]
	for lo, hi in gaps:
		usable += [lo % 360.0, hi % 360.0]
	usable = sorted(usable)
	for a in usable:
		p = polar(a, radius)
		add_box(bm_posts, Vector((p.x, p.y, Z_RING + RAIL_HEIGHT * 0.5)), (0.45, 0.45, RAIL_HEIGHT), math.radians(a))
		add_box(bm_posts, Vector((p.x, p.y, Z_RING + RAIL_HEIGHT + 0.09)), (0.6, 0.6, 0.18), math.radians(a))
	for i, a0 in enumerate(usable):
		a1 = usable[(i + 1) % len(usable)]
		span = (a1 - a0) % 360.0
		mid = (a0 + span * 0.5) % 360.0
		if any(_angle_in(mid, lo, hi) for lo, hi in gaps) or span > 30.0:
			continue
		p0, p1 = polar(a0, radius), polar(a1, radius)
		center = (p0 + p1) * 0.5
		rot = math.atan2((p1 - p0).y, (p1 - p0).x)
		add_box(bm_posts, Vector((center.x, center.y, Z_RING + RAIL_HEIGHT - 0.12)), ((p1 - p0).length, 0.3, 0.22),
			rot)
		add_box(bm_posts, Vector((center.x, center.y, Z_RING + 0.2)), ((p1 - p0).length, 0.36, 0.4), rot)
	obj_from_bm("Platform_Balustrade", bm_posts, mats["block"], coll, bevel=0.04)


def build_south_stairs(mats: dict) -> None:
	coll = collection("Stairs")
	bm = bmesh.new()
	steps = 12
	rise = STAIR_DROP / steps
	run = STAIR_RUN / steps
	y_top = -PLATFORM_RADIUS + 0.4
	for i in range(steps):
		y = y_top - run * (i + 0.5)
		z_top = -rise * i
		add_box(bm, Vector((0, y, z_top - 2.0)), (STAIR_HALF_WIDTH * 2, run, 4.0))
	landing_y = y_top - STAIR_RUN - 3.0
	add_box(bm, Vector((0, landing_y, -STAIR_DROP - 1.5)), (STAIR_HALF_WIDTH * 2 + 2.0, 6.0, 3.0))
	obj_from_bm("Stairs_Steps", bm, mats["paving"], coll)

	bm = bmesh.new()
	for side in (-1, 1):
		x = side * (STAIR_HALF_WIDTH + 0.25)
		for i in range(0, steps + 1, 2):
			add_box(bm, Vector((x, y_top - run * i, -rise * i + RAIL_HEIGHT * 0.5)), (0.5, 0.5, RAIL_HEIGHT))
		add_segment(bm, Vector((x, y_top, RAIL_HEIGHT - 0.1)), Vector((x, y_top - STAIR_RUN, -STAIR_DROP + RAIL_HEIGHT
			- 0.1)), 0.3, 0.24)
		add_box(bm, Vector((x + side * 1.0, landing_y, -STAIR_DROP + RAIL_HEIGHT * 0.5)), (0.42, 5.6, RAIL_HEIGHT))
	add_box(bm, Vector((0, landing_y - 3.0, -STAIR_DROP + RAIL_HEIGHT * 0.5)), (STAIR_HALF_WIDTH * 2 + 2.4, 0.42,
		RAIL_HEIGHT))
	obj_from_bm("Stairs_Rails", bm, mats["block"], coll, bevel=0.04)
	bm = bmesh.new()
	verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12, radius1=6.0, radius2=0.5,
		depth=14.0)["verts"]
	bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=Matrix.Rotation(math.pi, 3, "X"))
	bmesh.ops.translate(bm, vec=Vector((0, landing_y + 1.0, -STAIR_DROP - 9.5)), verts=verts)
	obj_from_bm("Stairs_Rock", bm, mats["rock"], coll)


# ---- Tâm: bệ + quả cầu thiên văn -------------------------------------------------------------------------------
def build_center(mats: dict) -> None:
	coll = collection("Center")
	bm = bmesh.new()
	add_cyl(bm, Vector((0, 0, 0)), DAIS_RADIUS, DAIS_RADIUS - 0.15, 0.5, 72)
	add_cyl(bm, Vector((0, 0, 0.5)), DAIS_RADIUS - 1.3, DAIS_RADIUS - 1.45, 0.5, 72)
	add_cyl(bm, Vector((0, 0, 1.0)), DAIS_RADIUS - 2.6, DAIS_RADIUS - 2.7, 0.4, 72)
	obj_from_bm("Center_Dais", bm, mats["paving"], coll)
	bm = bmesh.new()
	add_annulus(bm, DAIS_RADIUS - 1.2, DAIS_RADIUS - 0.4, 0.55, 0.05, 96)
	obj_from_bm("Center_DaisGlow", bm, mats["rune"], coll)

	core_z = 8.4
	bm = bmesh.new()
	add_cyl(bm, Vector((0, 0, 1.4)), 1.1, 0.7, 3.2, 24)
	add_cyl(bm, Vector((0, 0, 1.4)), 1.4, 1.4, 0.3, 24)
	add_cyl(bm, Vector((0, 0, 4.4)), 1.0, 1.25, 0.35, 24)
	add_cyl(bm, Vector((0, 0, 4.75)), 0.45, 0.32, 2.4, 16)
	obj_from_bm("Center_Pedestal", bm, mats["gold_dark"], coll, smooth=True)

	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=1.4)
	bmesh.ops.translate(bm, vec=Vector((0, 0, core_z)), verts=bm.verts)
	obj_from_bm("Center_Core", bm, mats["core"], coll, smooth=True)
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=2.3)
	bmesh.ops.translate(bm, vec=Vector((0, 0, core_z)), verts=bm.verts)
	obj_from_bm("Center_CoreHalo", bm, mats["core_halo"], coll, smooth=True)

	# Các vòng thiên văn: khung ngoài dày (kinh tuyến + chân trời) và các vòng trong nghiêng khác nhau
	c = Vector((0, 0, core_z))
	frame = bmesh.new()
	add_torus(frame, c, 6.2, 0.32, Matrix.Rotation(math.pi / 2, 3, "X"), 96, 12)
	add_torus(frame, c, 6.2, 0.32, Matrix.Rotation(math.pi / 2, 3, "X") @ Matrix.Rotation(math.pi / 2, 3, "Y"), 96, 12)
	add_torus(frame, c, 6.2, 0.28, Matrix.Identity(3), 96, 12)
	obj_from_bm("Center_Frame", frame, mats["gold"], coll, smooth=True)
	inner = bmesh.new()
	for k, (major, rx, ry) in enumerate(((4.8, 35, 10), (4.2, -25, 50), (3.6, 70, -20), (3.0, 10, 80))):
		add_torus(inner, c, major, 0.17, Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(ry),
			3, "Y"), 80, 8)
	obj_from_bm("Center_Rings", inner, mats["gold"], coll, smooth=True)
	# Ngọc nguyên tố trên vòng chân trời, hướng về khu của mình
	for element, angle in SECTORS.items():
		bm = bmesh.new()
		bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.45)
		bmesh.ops.translate(bm, vec=polar(angle, 6.2, core_z), verts=bm.verts)
		obj_from_bm(f"Center_Gem_{element}", bm, lit(mats, element), coll, smooth=True)
	preview_light("L_Core", Vector((0, 0, core_z)), (0.75, 0.9, 1.0), 3500, 1.0)


def build_conduits(mats: dict) -> None:
	"""Mạch năng lượng: hai dải uốn từ mỗi khu vào bệ tâm, khu đã mở sáng màu nguyên tố."""
	coll = collection("Conduits")
	for element, angle in SECTORS.items():
		bm = bmesh.new()
		for offset, bend in ((-9.0, 1.0), (9.0, -1.0)):
			start_r, end_r = SECTOR_RADIUS - 3.2, DAIS_RADIUS + 0.1
			prev = None
			for i in range(31):
				t = i / 30
				r = start_r + (end_r - start_r) * t
				a = angle + offset * (1 - t) + bend * math.sin(t * math.pi) * 10.0
				p = polar(a, r, Z_CONDUIT * 0.5)
				if prev is not None:
					d = p - prev
					mid = (p + prev) * 0.5
					add_box(bm, mid, (d.length + 0.05, 0.75, Z_CONDUIT), math.atan2(d.y, d.x))
				prev = p
		obj_from_bm(f"Conduit_{element}", bm, lit(mats, element), coll)


# ---- Cổng khu + đảo xa -----------------------------------------------------------------------------------------
def build_gate(element: str, mats: dict, coll: bpy.types.Collection) -> None:
	angle = SECTORS[element]
	rot = math.radians(angle) + math.pi * 0.5
	tangent = Vector((math.cos(rot), math.sin(rot), 0))
	base = polar(angle, PLATFORM_RADIUS - 0.3)
	bm = bmesh.new()
	for side in (-1, 1):
		p = base + tangent * side * (GATE_HALF_WIDTH - 0.5)
		add_tapered_box(bm, Vector((p.x, p.y, Z_RING)), 1.4, 1.05, 6.4, rot)
	add_box(bm, Vector((base.x, base.y, 6.7)), (GATE_HALF_WIDTH * 2 + 0.8, 1.5, 0.8), rot)
	add_box(bm, Vector((base.x, base.y, 7.35)), (GATE_HALF_WIDTH * 2 - 0.6, 1.1, 0.5), rot)
	out = polar(angle, PLATFORM_RADIUS + 2.5)
	add_box(bm, Vector((out.x, out.y, -0.8)), (GATE_HALF_WIDTH * 2, 5.0, 1.6), rot)
	for side in (-1, 1):
		p = out + tangent * side * (GATE_HALF_WIDTH - 0.2)
		add_box(bm, Vector((p.x, p.y, RAIL_HEIGHT * 0.5)), (0.4, 5.0, RAIL_HEIGHT), rot)
	obj_from_bm(f"Gate_{element}", bm, mats["block"], coll, bevel=0.06)
	bm = bmesh.new()
	add_box(bm, Vector((base.x, base.y, 6.7)), (GATE_HALF_WIDTH * 2 - 1.0, 1.55, 0.2), rot)
	for side in (-1, 1):
		p = base + tangent * side * (GATE_HALF_WIDTH - 0.5)
		add_box(bm, Vector((p.x, p.y, 3.2)), (1.18, 1.18, 0.16), rot)
	obj_from_bm(f"Gate_{element}_Glyph", bm, lit(mats, element), coll)
	if not AWAKE[element]:
		bm = bmesh.new()
		add_box(bm, Vector((base.x, base.y, 3.2)), (GATE_HALF_WIDTH * 2 - 1.9, 0.12, 6.2), rot)
		obj_from_bm(f"Gate_{element}_Veil", bm, mats["veil"], coll)


def build_island(element: str, mats: dict) -> None:
	coll = collection("Islands")
	angle = SECTORS[element]
	center = polar(angle, ISLAND_DISTANCE, -6.0)
	bm = bmesh.new()
	add_cyl(bm, center + Vector((0, 0, -1.2)), 10.0, 10.0, 1.2, 40)
	verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=9.8, radius2=1.0,
		depth=16.0)["verts"]
	bmesh.ops.rotate(bm, verts=verts, cent=Vector(), matrix=Matrix.Rotation(math.pi, 3, "X"))
	bmesh.ops.translate(bm, vec=center + Vector((0, 0, -9.2)), verts=verts)
	for v in verts:
		v.co.x += random.uniform(-0.8, 0.8)
		v.co.y += random.uniform(-0.8, 0.8)
	obj_from_bm(f"Island_{element}_Rock", bm, mats["rock"], coll)
	bm = bmesh.new()
	add_cyl(bm, center, 9.7, 9.3, 0.2, 40)
	obj_from_bm(f"Island_{element}_Grass", bm, mats["moss"], coll)
	bm = bmesh.new()
	for k in range(5):
		p = center + polar(k * 72.0 + 15.0, 5.5)
		add_tapered_box(bm, Vector((p.x, p.y, center.z)), 1.6, 1.0, 5.0 + (k % 3) * 1.5)
	add_tapered_box(bm, center, 3.0, 1.6, 10.0)
	obj_from_bm(f"Island_{element}_Shrine", bm, mats["block"], coll)
	bm = bmesh.new()
	add_cyl(bm, center + Vector((0, 0, 10.0)), 1.2, 0.0, 2.2, 12)
	obj_from_bm(f"Island_{element}_Beacon", bm, lit(mats, element), coll)
	bm = bmesh.new()
	add_cyl(bm, center + Vector((0, 0, 12.2)), 0.6, 0.15, 24.0, 12)
	obj_from_bm(f"Island_{element}_BeaconBeam", bm, soft(mats, element), coll)
	toward = (Vector((0, 0, center.z)) - center).normalized()
	bm = bmesh.new()
	bm_mist = bmesh.new()
	for k in (-1, 1):
		a = math.degrees(math.atan2(toward.y, toward.x)) + k * 35.0
		add_waterfall(bm, bm_mist, center + Vector((0, 0, -0.05)), a, 10.0, 16.0, 3.2)
	obj_from_bm(f"Island_{element}_Waterfall", bm, mats["waterfall"], coll, smooth=True)
	obj_from_bm(f"Island_{element}_Mist", bm_mist, mats["mist"], coll, smooth=True)
	if AWAKE[element]:
		preview_light(f"L_Island_{element}", center + Vector((0, 0, 12.0)), ELEMENT_COLOR[element], 6000, 3.0)


def add_waterfall(bm: bmesh.types.BMesh, bm_mist: bmesh.types.BMesh, center: Vector, angle: float, radius: float,
		drop: float, width: float) -> None:
	"""Thác nước: tấm nước đổ từ mép đảo, văng ra ngoài rồi rơi thẳng, loe dần; cụm hơi nước ở chân."""
	out = polar(angle, 1.0)
	side = Vector((-out.y, out.x, 0))
	rows = 12
	prev = None
	for j in range(rows + 1):
		t = j / rows
		reach = radius + 1.6 * math.sqrt(t)
		z = center.z - drop * t
		w = width * (1.0 + 0.8 * t)
		mid = center + out * reach
		left = bm.verts.new(Vector((mid.x, mid.y, z)) - side * w * 0.5)
		right = bm.verts.new(Vector((mid.x, mid.y, z)) + side * w * 0.5)
		if prev is not None:
			bm.faces.new([prev[0], prev[1], right, left])
		prev = (left, right)
	foot = center + out * (radius + 1.6) + Vector((0, 0, -drop))
	for _k in range(4):
		q = foot + side * random.uniform(-width, width) + Vector((0, 0, random.uniform(-0.5, 0.8)))
		verts = bmesh.ops.create_icosphere(bm_mist, subdivisions=2, radius=random.uniform(1.6, 2.6))["verts"]
		bmesh.ops.scale(bm_mist, vec=Vector((1.0, 1.0, 0.6)), verts=verts)
		bmesh.ops.translate(bm_mist, vec=q, verts=verts)


def sector_paving(element: str, mats: dict, coll: bpy.types.Collection, ground_mat: bpy.types.Material) -> Vector:
	c = polar(SECTORS[element], SECTOR_RADIUS)
	bm = bmesh.new()
	add_cyl(bm, Vector((c.x, c.y, 0)), SECTOR_PAVING_RADIUS, SECTOR_PAVING_RADIUS, Z_PAVING, 56)
	obj_from_bm(f"{element.capitalize()}_Paving", bm, mats["paving"], coll)
	bm = bmesh.new()
	add_annulus(bm, 2.6, 2.8, Z_GROUND_FX, 0.04, 48, c)
	obj_from_bm(f"{element.capitalize()}_GroundRune", bm, ground_mat, coll)
	return c


# ---- Bộ phận kiến trúc cung điện -------------------------------------------------------------------------------
def lathe(bm: bmesh.types.BMesh, base: Vector, profile: list[tuple[float, float]], segments: int = 24) -> None:
	"""Tiện tròn một biên dạng (bán kính, cao) quanh trục đứng: tháp, mái vòm, chóp củ hành, chân cột."""
	rings = []
	for r, z in profile:
		if r <= 1e-4:
			rings.append([bm.verts.new(base + Vector((0, 0, z)))])
			continue
		rings.append([bm.verts.new(base + Vector((math.cos(2 * math.pi * i / segments) * r,
			math.sin(2 * math.pi * i / segments) * r, z))) for i in range(segments)])
	for lower, upper in zip(rings, rings[1:]):
		if len(lower) == 1 and len(upper) == 1:
			continue
		if len(upper) == 1:
			for i in range(segments):
				bm.faces.new([lower[i], lower[(i + 1) % segments], upper[0]])
		elif len(lower) == 1:
			for i in range(segments):
				bm.faces.new([upper[(i + 1) % segments], upper[i], lower[0]])
		else:
			for i in range(segments):
				bm.faces.new([lower[i], lower[(i + 1) % segments], upper[(i + 1) % segments], upper[i]])
	if len(rings[0]) > 1:
		bm.faces.new(list(reversed(rings[0])))


def add_column(bm: bmesh.types.BMesh, base: Vector, radius: float, height: float) -> None:
	"""Cột tròn cổ điển: đế vuông, thân thon nhẹ, đầu cột loe."""
	add_box(bm, base + Vector((0, 0, 0.18)), (radius * 2.8, radius * 2.8, 0.36))
	lathe(bm, base + Vector((0, 0, 0.36)), [(radius * 1.25, 0.0), (radius * 1.05, 0.25), (radius, 0.35),
		(radius * 0.88, height - 1.1), (radius * 1.0, height - 0.95), (radius * 1.35, height - 0.75),
		(radius * 1.35, height - 0.62)], 14)
	add_box(bm, base + Vector((0, 0, height - 0.32)), (radius * 3.0, radius * 3.0, 0.3))


def add_windows(bm: bmesh.types.BMesh, center: Vector, radius: float, z: float, count: int, width: float,
		height: float, start_angle: float = 0.0) -> None:
	"""Ô cửa sáng quanh thân tháp tròn (nhô 4 cm ra ngoài mặt tường để không chồng mặt)."""
	for i in range(count):
		a = start_angle + 360.0 * i / count
		p = center + polar(a, radius + 0.04)
		add_box(bm, Vector((p.x, p.y, z)), (0.1, width, height), math.radians(a))
		add_tapered_box(bm, Vector((p.x, p.y, z + height * 0.5)), width * 0.7, 0.0, width * 0.55, math.radians(a))


def add_banner(bm: bmesh.types.BMesh, top: Vector, facing: float, width: float, length: float,
		phase: float = 0.0) -> None:
	"""Cờ vải rủ xuống, gợn sóng."""
	side = Vector((math.cos(facing + math.pi * 0.5), math.sin(facing + math.pi * 0.5), 0))
	out = Vector((math.cos(facing), math.sin(facing), 0))
	rows = 10
	prev = None
	for j in range(rows + 1):
		t = j / rows
		wave = out * (math.sin(t * 5.0 + phase) * 0.25 * t)
		z = top.z - length * t
		w = width * (1.0 - 0.35 * t)
		left = bm.verts.new(Vector((top.x, top.y, z)) - side * w * 0.5 + wave)
		right = bm.verts.new(Vector((top.x, top.y, z)) + side * w * 0.5 + wave)
		if prev is not None:
			bm.faces.new([prev[0], prev[1], right, left])
		prev = (left, right)


def add_crenellations(bm: bmesh.types.BMesh, a: Vector, b: Vector, z: float, merlon: float = 0.7) -> None:
	"""Răng cưa trên đỉnh tường từ a tới b."""
	d = b - a
	length = d.length
	count = max(2, int(length / (merlon * 2.0)))
	rot = math.atan2(d.y, d.x)
	for i in range(count):
		p = a + d * ((i + 0.5) / count)
		add_box(bm, Vector((p.x, p.y, z + 0.4)), (merlon, 0.9, 0.8), rot)


def palace_axes(element: str, shift: float) -> tuple[Vector, Vector, Vector]:
	"""Tâm cung (lùi ra phía ngoài sân), hướng ra ngoài và hướng ngang của khu."""
	angle = SECTORS[element]
	o = polar(angle, 1.0)
	t = Vector((-o.y, o.x, 0))
	c = polar(angle, SECTOR_RADIUS) + o * shift
	return Vector((c.x, c.y, Z_PAVING - 0.02)), o, t


# ---- Cung Gió: cẩm thạch trắng, mái đồng xanh ngọc, tháp giữa chóp củ hành, hành lang cột tròn, cờ bay -------
def build_wind(mats: dict) -> None:
	coll = collection("Sector_Wind")
	sector_paving("wind", mats, coll, soft(mats, "wind"))
	c, o, t = palace_axes("wind", 1.6)
	bm_marble = bmesh.new()
	bm_roof = bmesh.new()
	bm_gold = bmesh.new()
	bm_glow = bmesh.new()
	lathe(bm_marble, c, [(6.4, 0.0), (6.4, 0.45), (6.0, 0.45), (6.0, 0.9), (5.7, 0.9), (5.7, 1.0)], 40)
	for i in range(12):
		p = c + polar(i * 30.0, 4.9)
		add_column(bm_marble, Vector((p.x, p.y, c.z + 1.0)), 0.28, 5.2)
	lathe(bm_marble, c + Vector((0, 0, 6.2)), [(5.6, 0.0), (5.6, 0.55), (5.85, 0.7), (5.85, 0.95)], 40)
	# Hàng răng chạm dưới gờ mái hành lang + lan can vàng trên mái
	for i in range(72):
		p = c + polar(i * 5.0, 5.66)
		add_box(bm_marble, Vector((p.x, p.y, c.z + 6.62)), (0.16, 0.22, 0.2), math.radians(i * 5.0))
	for i in range(48):
		p = c + polar(i * 7.5, 5.7)
		add_box(bm_gold, Vector((p.x, p.y, c.z + 7.45)), (0.12, 0.12, 0.5), math.radians(i * 7.5))
	add_annulus(bm_gold, 5.55, 5.85, c.z + 7.8, 0.1, 64, Vector((c.x, c.y, 0)))
	lathe(bm_roof, c + Vector((0, 0, 7.15)), [(5.9, 0.0), (5.0, 0.6), (3.3, 1.2), (3.0, 1.25)], 40)
	# Tháp giữa: thân tròn, gờ, tầng trên, chóp củ hành, kim nhọn
	lathe(bm_marble, c + Vector((0, 0, 1.0)), [(2.8, 0.0), (2.8, 8.0), (3.2, 8.2), (3.2, 8.6), (2.3, 8.6),
		(2.3, 12.4), (2.7, 12.6), (2.7, 13.0), (0.0, 13.0)], 32)
	lathe(bm_roof, c + Vector((0, 0, 14.0)), [(2.4, 0.0), (2.9, 0.8), (2.6, 2.0), (1.6, 3.2), (0.6, 4.2),
		(0.25, 5.0), (0.0, 5.2)], 32)
	lathe(bm_gold, c + Vector((0, 0, 19.1)), [(0.22, 0.0), (0.16, 1.0), (0.35, 1.2), (0.12, 1.4), (0.08, 3.2),
		(0.0, 3.6)], 12)
	add_windows(bm_glow, c + Vector((0, 0, 0)), 2.8, c.z + 6.0, 8, 0.7, 1.6, 22.5)
	add_windows(bm_glow, c + Vector((0, 0, 0)), 2.3, c.z + 11.2, 8, 0.55, 1.3)
	add_annulus(bm_gold, 3.15, 3.3, c.z + 9.65, 0.18, 48, Vector((c.x, c.y, 0)))
	# Hai tháp phụ thon, mái nhọn
	for side in (-1, 1):
		p = c + t * side * 5.6 + o * 0.8
		lathe(bm_marble, Vector((p.x, p.y, c.z)), [(1.3, 0.0), (1.3, 0.6), (1.0, 0.6), (1.0, 9.0), (1.25, 9.2),
			(1.25, 9.5), (0.0, 9.5)], 20)
		lathe(bm_roof, Vector((p.x, p.y, c.z + 9.5)), [(1.35, 0.0), (0.9, 1.4), (0.3, 3.0), (0.0, 3.6)], 20)
		add_windows(bm_glow, Vector((p.x, p.y, 0)), 1.0, c.z + 6.5, 4, 0.4, 1.0, 45.0)
	obj_from_bm("Wind_Palace", bm_marble, mats["wind_wall"], coll, bevel=0.05)
	obj_from_bm("Wind_Roofs", bm_roof, mats["patina"], coll, smooth=True)
	obj_from_bm("Wind_Gold", bm_gold, mats["gold"], coll, smooth=True)
	obj_from_bm("Wind_Windows", bm_glow, lit(mats, "wind"), coll)
	if AWAKE["wind"]:
		bm = bmesh.new()
		for i in range(12):
			p = c + polar(i * 30.0 + 15.0, 5.95)
			add_banner(bm, Vector((p.x, p.y, c.z + 7.0)), math.radians(i * 30.0 + 15.0), 1.0, 3.4, i * 0.7)
		obj_from_bm("Wind_Banners", bm, mats["wind_cloth"], coll, smooth=True)
		for k, (radius, turns, phase, z0, z1, width) in enumerate(((7.0, 1.2, 0.0, 1.0, 16.0, 1.6),
				(8.2, 0.9, 2.1, 2.0, 13.0, 1.2), (6.2, 1.6, 4.2, 4.0, 20.0, 1.3))):
			bm = bmesh.new()
			prev = None
			for i in range(161):
				s = i / 160
				theta = phase + s * turns * 2 * math.pi
				z = c.z + z0 + (z1 - z0) * s
				w = width * math.sin(math.pi * s) ** 0.5
				rr = radius * (1.0 + 0.12 * math.sin(s * 9.0))
				vin = bm.verts.new((c.x + math.cos(theta) * (rr - w * 0.5), c.y + math.sin(theta) * (rr - w * 0.5), z))
				vout = bm.verts.new((c.x + math.cos(theta) * (rr + w * 0.5), c.y + math.sin(theta) * (rr + w * 0.5),
					z + w * 0.3))
				if prev is not None:
					bm.faces.new([prev[0], prev[1], vout, vin])
				prev = (vin, vout)
			obj_from_bm(f"Wind_Ribbon_{k}", bm, mats["wind_soft"], coll, smooth=True)
		preview_light("L_Wind_Low", c + Vector((0, 0, 3.0)), ELEMENT_COLOR["wind"], 3000, 2.0)
		preview_light("L_Wind_High", c + Vector((0, 0, 13.0)), ELEMENT_COLOR["wind"], 2500, 2.0)
	build_gate("wind", mats, coll)
	build_island("wind", mats)


# ---- Cung Lửa: thành đá đen viền vàng, tháp góc mái chóp vàng, đền bậc ở giữa đỉnh có lò lửa, hào dung nham ----
def build_fire(mats: dict) -> None:
	coll = collection("Sector_Fire")
	sector_paving("fire", mats, coll, soft(mats, "fire"))
	c, o, t = palace_axes("fire", 1.4)
	rot = math.atan2(o.y, o.x)
	bm_stone = bmesh.new()
	bm_gold = bmesh.new()
	bm_glow = bmesh.new()
	half = 4.6
	corners = [c + o * sx * half + t * sy * half for sx, sy in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
	add_box(bm_stone, c + Vector((0, 0, 0.35)), (half * 2 + 2.0, half * 2 + 2.0, 0.7), rot)
	# Tường bốn phía, mặt hướng vào tâm sân có cổng mở
	for i in range(4):
		a, b = corners[i], corners[(i + 1) % 4]
		mid = (a + b) * 0.5
		d = b - a
		facing_center = (mid - c).normalized().dot(-o) > 0.7
		if facing_center:
			for part in (-1, 1):
				seg_mid = mid + d.normalized() * part * (half * 0.62)
				add_box(bm_stone, Vector((seg_mid.x, seg_mid.y, c.z + 2.6)), (half * 0.76, 0.9, 4.4),
					math.atan2(d.y, d.x))
				add_crenellations(bm_stone, seg_mid - d.normalized() * half * 0.38, seg_mid + d.normalized()
					* half * 0.38, c.z + 4.8)
			add_box(bm_gold, Vector((mid.x, mid.y, c.z + 4.6)), (2.6, 1.0, 0.3), math.atan2(d.y, d.x))
		else:
			add_box(bm_stone, Vector((mid.x, mid.y, c.z + 2.6)), (d.length, 0.9, 4.4), math.atan2(d.y, d.x))
			add_crenellations(bm_stone, a, b, c.z + 4.8)
			for k in range(3):
				p = a + d * ((k + 1) / 4)
				add_box(bm_glow, Vector((p.x, p.y, c.z + 2.8)), (0.25, 0.96, 1.2), math.atan2(d.y, d.x))
	for p in corners:
		add_tapered_box(bm_stone, Vector((p.x, p.y, c.z + 0.7)), 2.4, 2.0, 7.2, rot)
		add_box(bm_gold, Vector((p.x, p.y, c.z + 7.95)), (2.5, 2.5, 0.3), rot)
		add_tapered_box(bm_gold, Vector((p.x, p.y, c.z + 8.1)), 2.4, 0.0, 3.2, rot)
		for k in range(4):
			q = p + polar(math.degrees(rot) + 90.0 * k, 1.05)
			add_box(bm_glow, Vector((q.x, q.y, c.z + 5.6)), (0.22, 0.6, 1.1), rot + math.radians(90.0 * k))
	# Đền bậc ở giữa: 3 tầng đá đen viền vàng, đỉnh là lò lửa lớn
	z = c.z + 0.7
	for size, h in ((6.0, 2.2), (4.4, 2.0), (3.0, 1.8)):
		add_box(bm_stone, Vector((c.x, c.y, z + h * 0.5)), (size, size, h), rot)
		add_box(bm_gold, Vector((c.x, c.y, z + h - 0.12)), (size + 0.12, size + 0.12, 0.24), rot)
		z += h
	add_cyl(bm_gold, Vector((c.x, c.y, z)), 1.0, 1.9, 1.0, 24)
	obj_from_bm("Fire_Palace", bm_stone, mats["fire_wall"], coll, bevel=0.06)
	obj_from_bm("Fire_Gold", bm_gold, mats["gold"], coll, bevel=0.03)
	obj_from_bm("Fire_Windows", bm_glow, lit(mats, "fire"), coll)
	bm = bmesh.new()
	for i in range(4):
		a, b = corners[i], corners[(i + 1) % 4]
		mid = (a + b) * 0.5
		out_dir = mid - c
		out_dir.z = 0
		out_dir.normalize()
		top = mid + out_dir * 0.5
		add_banner(bm, Vector((top.x, top.y, c.z + 4.6)), math.atan2(out_dir.y, out_dir.x), 1.4, 3.2, i * 1.3)
	obj_from_bm("Fire_Banners", bm, mats["fire_cloth"], coll, smooth=True)
	bm = bmesh.new()
	add_annulus(bm, half * 1.55 + 0.4, half * 1.55 + 1.0, Z_GROUND_FX, 0.04, 64, Vector((c.x, c.y, 0)))
	obj_from_bm("Fire_LavaMoat", bm, mats["lava"] if AWAKE["fire"] else mats["off"], coll)
	if AWAKE["fire"]:
		bm_flame = bmesh.new()
		bm_core = bmesh.new()
		for k in range(4):
			q = Vector((c.x + random.uniform(-0.4, 0.4), c.y + random.uniform(-0.4, 0.4), z + 0.9))
			add_cyl(bm_flame, q, 1.3 - k * 0.2, 0.0, 3.2 + k * 0.8, 12)
		add_cyl(bm_core, Vector((c.x, c.y, z + 0.9)), 0.7, 0.0, 2.2, 12)
		for p in corners:
			add_cyl(bm_flame, Vector((p.x, p.y, c.z + 11.2)), 0.5, 0.0, 1.6, 10)
		obj_from_bm("Fire_Flames", bm_flame, mats["flame"], coll, smooth=True)
		obj_from_bm("Fire_FlameCores", bm_core, mats["flame_core"], coll, smooth=True)
		preview_light("L_Fire_Top", Vector((c.x, c.y, z + 3.0)), (1.0, 0.45, 0.1), 6000, 2.0)
		preview_light("L_Fire_Court", Vector((c.x, c.y, c.z + 2.5)), (1.0, 0.35, 0.06), 3500, 3.0)
	build_gate("fire", mats, coll)
	build_island("fire", mats)


# ---- Cung Băng: mái vòm pha lê, tháp nhọn trong mờ, dãy vòm gothic phía trước (giữ thấp vì gần camera) ---------
def add_pointed_arch(bm: bmesh.types.BMesh, center: Vector, facing: float, width: float, spring: float,
		height: float, thickness: float, depth: float) -> None:
	axis = Vector((math.cos(facing), math.sin(facing), 0))
	half = width * 0.5
	for side in (-1, 1):
		foot = center + axis * side * half
		add_segment(bm, Vector((foot.x, foot.y, center.z)), Vector((foot.x, foot.y, center.z + spring)), thickness,
			depth)
		prev = Vector((foot.x, foot.y, center.z + spring))
		for i in range(1, 8):
			s = i / 7
			p = center + axis * side * half * (1 - s) ** 1.4
			cur = Vector((p.x, p.y, center.z + spring + (height - spring) * math.sin(s * math.pi * 0.5)))
			add_segment(bm, prev, cur, thickness, depth)
			prev = cur


def build_ice(mats: dict) -> None:
	coll = collection("Sector_Ice")
	sector_paving("ice", mats, coll, soft(mats, "ice"))
	c, o, t = palace_axes("ice", 1.2)
	facing = math.atan2(t.y, t.x)
	bm_frame = bmesh.new()
	bm_glass = bmesh.new()
	bm_glow = bmesh.new()
	lathe(bm_frame, c, [(6.0, 0.0), (6.0, 0.5), (5.6, 0.5), (5.6, 0.9)], 6)
	# Điện chính: thân tròn trắng bạc + mái vòm pha lê có sườn
	lathe(bm_frame, c + Vector((0, 0, 0.9)), [(3.2, 0.0), (3.2, 3.6), (3.5, 3.8), (3.5, 4.1), (0.0, 4.1)], 32)
	add_windows(bm_glow, c, 3.2, c.z + 2.6, 10, 0.6, 1.8)
	lathe(bm_glass, c + Vector((0, 0, 5.0)), [(3.3, 0.0), (3.2, 1.0), (2.8, 2.0), (2.0, 2.9), (1.0, 3.5),
		(0.0, 3.8)], 32)
	for k in range(8):
		a = k * 45.0
		prev = None
		for prof_r, prof_z in ((3.35, 0.0), (3.25, 1.0), (2.85, 2.0), (2.05, 2.9), (1.05, 3.5), (0.0, 3.85)):
			p = c + polar(a, prof_r) + Vector((0, 0, 5.0 + prof_z))
			if prev is not None:
				add_segment(bm_frame, prev, p, 0.16, 0.16)
			prev = p
	# Tháp nhọn pha lê quanh điện
	for k in range(6):
		a = math.degrees(math.atan2(o.y, o.x)) + 30.0 + k * 60.0
		p = c + polar(a, 4.6)
		h = 6.5 if (k in (0, 5)) else 5.0
		add_prism(bm_glass, Vector((p.x, p.y, c.z + 0.9)), 0.75, h, tip=h * 0.45, sides=6)
		lathe(bm_frame, Vector((p.x, p.y, c.z + 0.9)), [(0.95, 0.0), (0.95, 0.6), (0.8, 0.6), (0.8, 0.75)], 6)
	# Dãy vòm gothic phía trước (hướng vào tâm sân)
	for i in range(3):
		p = c - o * 4.4 + t * (i - 1) * 3.0
		add_pointed_arch(bm_frame, Vector((p.x, p.y, c.z + 0.9)), facing, 2.4, 2.6, 4.8, 0.45, 0.6)
	obj_from_bm("Ice_Palace", bm_frame, mats["silver"], coll, bevel=0.03)
	obj_from_bm("Ice_Glass", bm_glass, mats["ice"], coll, smooth=True)
	obj_from_bm("Ice_Windows", bm_glow, lit(mats, "ice"), coll)
	bm = bmesh.new()
	add_cyl(bm, Vector((c.x, c.y, Z_GROUND_FX - 0.04)), 7.0, 7.0, 0.04, 56)
	obj_from_bm("Ice_Frost", bm, mats["frost"], coll)
	if AWAKE["ice"]:
		bm = bmesh.new()
		for _k in range(10):
			off = polar(random.uniform(0, 360), random.uniform(6.0, 7.4))
			h = random.uniform(1.0, 2.4)
			add_prism(bm, c + off, random.uniform(0.25, 0.45), h, tip=h * 0.5, sides=6,
				tilt=Vector((random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 0)))
		obj_from_bm("Ice_Crystals", bm, mats["crystal"], coll)
		preview_light("L_Ice", c + Vector((0, 0, 5.0)), (0.6, 0.85, 1.0), 5000, 2.5)
	build_gate("ice", mats, coll)
	build_island("ice", mats)


# ---- Cung Sét: đá tím sẫm, tháp kim cao, cột thu lôi đồng, vòng sáng nổi, tia sét giữa các đỉnh ----------------
def build_thunder(mats: dict) -> None:
	coll = collection("Sector_Thunder")
	sector_paving("thunder", mats, coll, soft(mats, "thunder"))
	c, o, t = palace_axes("thunder", 1.2)
	rot = math.atan2(o.y, o.x)
	bm_stone = bmesh.new()
	bm_copper = bmesh.new()
	bm_glow = bmesh.new()
	add_box(bm_stone, c + Vector((0, 0, 0.35)), (11.0, 11.0, 0.7), rot)
	towers = [(c, 10.5, 2.6)] + [(c + o * sx * 3.8 + t * sy * 3.8, 7.0, 1.6) for sx, sy in ((1, 1), (1, -1),
		(-1, -1), (-1, 1))]
	tops = []
	for p, h, w in towers:
		add_tapered_box(bm_stone, Vector((p.x, p.y, c.z + 0.7)), w, w * 0.62, h, rot)
		add_box(bm_copper, Vector((p.x, p.y, c.z + 0.7 + h)), (w * 0.75, w * 0.75, 0.25), rot)
		add_tapered_box(bm_stone, Vector((p.x, p.y, c.z + 0.95 + h)), w * 0.62, 0.0, w * 1.1, rot)
		rod_base = Vector((p.x, p.y, c.z + 0.95 + h + w * 1.1 - 0.2))
		add_segment(bm_copper, rod_base, rod_base + Vector((0, 0, 3.0)), 0.12, 0.12)
		lathe(bm_copper, rod_base + Vector((0, 0, 3.0)), [(0.0, -0.3), (0.32, 0.0), (0.0, 0.3)], 10)
		tops.append(rod_base + Vector((0, 0, 3.0)))
		for k in range(4):
			q = p + polar(math.degrees(rot) + 90.0 * k + 45.0, w * 0.42)
			add_box(bm_glow, Vector((q.x, q.y, c.z + 0.7 + h * 0.6)), (0.18, w * 0.25, h * 0.25),
				rot + math.radians(90.0 * k + 45.0))
	# Tường thấp nối các tháp góc, có răng cưa
	corner_points = [p for p, _h, _w in towers[1:]]
	for i in range(4):
		a, b = corner_points[i], corner_points[(i + 1) % 4]
		mid = (a + b) * 0.5
		d = b - a
		add_box(bm_stone, Vector((mid.x, mid.y, c.z + 1.9)), (d.length, 0.7, 2.4), math.atan2(d.y, d.x))
		add_crenellations(bm_stone, a, b, c.z + 3.1, 0.55)
	obj_from_bm("Thunder_Palace", bm_stone, mats["thunder_wall"], coll, bevel=0.05)
	obj_from_bm("Thunder_Copper", bm_copper, mats["copper"], coll, smooth=True)
	obj_from_bm("Thunder_Windows", bm_glow, lit(mats, "thunder"), coll)
	bm = bmesh.new()
	for p, h, w in towers:
		add_torus(bm, Vector((p.x, p.y, c.z + 0.7 + h * 0.55)), w * 0.78, 0.06, Matrix.Rotation(0.15, 3, "X"), 48, 8)
	obj_from_bm("Thunder_Rings", bm, soft(mats, "thunder"), coll, smooth=True)
	if AWAKE["thunder"]:
		bm = bmesh.new()
		for i in range(1, 5):
			a, b = tops[0], tops[i]
			prev = a
			for k in range(1, 9):
				s = k / 8
				p = b if k == 8 else a.lerp(b, s) + Vector((random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5),
					random.uniform(-0.5, 0.5) + math.sin(s * math.pi) * 1.0))
				add_segment(bm, prev, p, 0.09, 0.09)
				prev = p
		obj_from_bm("Thunder_Bolts", bm, mats["bolt"], coll)
		preview_light("L_Thunder", c + Vector((0, 0, 8.0)), (0.65, 0.4, 1.0), 6000, 2.5)
	build_gate("thunder", mats, coll)
	build_island("thunder", mats)


# ---- Nền: biển mây, vách núi, thác, đảo nổi nhỏ có cột sáng ----------------------------------------------------
def build_backdrop(mats: dict) -> None:
	coll = collection("Backdrop")
	bm = bmesh.new()
	add_cyl(bm, Vector((0, 0, -34.0)), 480.0, 480.0, 0.5, 64)
	obj_from_bm("Cloud_Sea", bm, mats["cloud"], coll)
	bm = bmesh.new()
	# Biển mây liền mảng: ít cụm nhưng to, chồng nhau, mặt trên gợn nhẹ (không thành viên sỏi rời)
	for _k in range(70):
		p = polar(random.uniform(0, 360), random.uniform(36.0, 230.0), random.uniform(-32.0, -26.0))
		for _j in range(5):
			q = p + Vector((random.uniform(-16, 16), random.uniform(-16, 16), random.uniform(-1.5, 1.5)))
			verts = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=random.uniform(11.0, 22.0))["verts"]
			bmesh.ops.scale(bm, vec=Vector((1.0, 1.0, 0.3)), verts=verts)
			bmesh.ops.translate(bm, vec=q, verts=verts)
	obj_from_bm("Cloud_Puffs", bm, mats["cloud"], coll, smooth=True)

	# Vách núi đá cao bao quanh phía sau (bắc, đông, tây), không chắn phía camera
	bm = bmesh.new()
	bm_falls = bmesh.new()
	for _k in range(18):
		a = random.uniform(-10.0, 190.0)
		p = polar(a, random.uniform(170.0, 250.0), -34.0)
		h = random.uniform(28.0, 55.0)
		for _j in range(4):
			off = Vector((random.uniform(-14, 14), random.uniform(-14, 14), 0))
			hj = h * random.uniform(0.45, 1.0)
			verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8,
				radius1=random.uniform(8, 16), radius2=random.uniform(0.8, 3.5), depth=hj)["verts"]
			for v in verts:
				v.co.x += random.uniform(-2.0, 2.0)
				v.co.y += random.uniform(-2.0, 2.0)
			bmesh.ops.translate(bm, vec=p + off + Vector((0, 0, hj * 0.5)), verts=verts)
		if random.random() < 0.5:
			toward = (Vector((0, 0, p.z)) - p).normalized()
			edge = p + toward * 11.0
			add_box(bm_falls, Vector((edge.x, edge.y, p.z + h * 0.35)), (3.0, 0.2, h * 0.7),
				math.atan2(toward.y, toward.x) + math.pi * 0.5)
	obj_from_bm("Cliffs", bm, mats["far_rock"], coll)
	obj_from_bm("Cliff_Waterfalls", bm_falls, mats["waterfall"], coll)

	# Đảo nổi nhỏ có miếu và cột sáng xanh (như các đảo treo trong concept)
	bm = bmesh.new()
	bm_shrine = bmesh.new()
	bm_beam = bmesh.new()
	for a, dist, z in ((92.0, 58.0, 20.0), (165.0, 50.0, 10.0), (15.0, 55.0, 14.0)):
		p = polar(a, dist, z)
		r = random.uniform(3.0, 4.5)
		verts = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10, radius1=0.3, radius2=r,
			depth=7.0)["verts"]
		bmesh.ops.translate(bm, vec=p + Vector((0, 0, -3.5)), verts=verts)
		add_tapered_box(bm_shrine, p, 2.2, 1.6, 2.6)
		add_tapered_box(bm_shrine, p + Vector((0, 0, 2.6)), 2.8, 0.2, 1.6)
		add_cyl(bm_beam, p + Vector((0, 0, -30.0)), 0.2, 0.2, 23.0, 10)
	obj_from_bm("Floaters_Rock", bm, mats["rock"], coll)
	obj_from_bm("Floaters_Shrine", bm_shrine, mats["block"], coll)
	obj_from_bm("Floaters_Beam", bm_beam, mats["beam"], coll)


# ---- Cảnh xem trước ----------------------------------------------------------------------------------------------
def setup_scene() -> None:
	scene = bpy.context.scene
	world = bpy.data.worlds.get("TH_World") or bpy.data.worlds.new("TH_World")
	world.use_nodes = True
	nodes = world.node_tree.nodes
	bg = next(n for n in nodes if n.type == "BACKGROUND")
	bg.inputs["Strength"].default_value = 0.22
	# Trời mây HDRI (Poly Haven, CC0): vừa là ánh sáng trời vừa cho vàng / đồng / bạc có cảnh để phản chiếu
	hdri_path = os.path.join(TEX_DIR, "overcast_soil_puresky_2k.hdr")
	env = next((n for n in nodes if n.type == "TEX_ENVIRONMENT"), None)
	if os.path.exists(hdri_path):
		if env is None:
			env = nodes.new("ShaderNodeTexEnvironment")
		env.image = bpy.data.images.load(hdri_path, check_existing=True)
		world.node_tree.links.new(env.outputs["Color"], bg.inputs["Color"])
	else:
		bg.inputs["Color"].default_value = (0.16, 0.21, 0.30, 1.0)
	scene.world = world
	try:
		scene.view_settings.view_transform = "AgX"
		scene.view_settings.look = "AgX - Medium High Contrast"
	except TypeError:
		scene.view_settings.view_transform = "Standard"
	sun_data = bpy.data.lights.get("TH_Sun") or bpy.data.lights.new("TH_Sun", type="SUN")
	sun_data.energy = 4.2
	sun_data.color = (1.0, 0.9, 0.78)
	sun_data.angle = math.radians(4.0)
	sun = bpy.data.objects.get("TH_Sun") or bpy.data.objects.new("TH_Sun", sun_data)
	if sun.name not in scene.collection.objects:
		scene.collection.objects.link(sun)
	# Nắng thấp xiên từ phía sau bên trái: bóng đổ dài và viền sáng trên mái như concept
	sun.rotation_euler = (math.radians(62), 0, math.radians(150))
	for cam_name, fov in (("TH_HubCam", 30.0), ("TH_OverviewCam", 40.0)):
		data = bpy.data.cameras.get(cam_name) or bpy.data.cameras.new(cam_name)
		data.sensor_fit = "VERTICAL"
		data.angle_y = math.radians(fov)
		data.clip_end = 1000.0
		cam = bpy.data.objects.get(cam_name) or bpy.data.objects.new(cam_name, data)
		if cam.name not in scene.collection.objects:
			scene.collection.objects.link(cam)
	set_camera("TH_HubCam", Vector((0, -6.0, 0)), 46.0, 50.0)
	set_camera("TH_OverviewCam", Vector((0, 6.0, 3.0)), 92.0, 34.0)
	scene.camera = bpy.data.objects["TH_OverviewCam"]
	scene.render.resolution_x = 1600
	scene.render.resolution_y = 900
	setup_bloom(scene)


def setup_bloom(scene: bpy.types.Scene) -> None:
	"""Quầng sáng (bloom) bằng compositor cho ảnh xem trước; trong game dùng Glow của WorldEnvironment."""
	try:
		tree = scene.compositing_node_group
		if tree is None:
			tree = bpy.data.node_groups.new("TH_Compositor", "CompositorNodeTree")
			scene.compositing_node_group = tree
		tree.nodes.clear()
		bpy.context.view_layer.use_pass_mist = True
		scene.world.mist_settings.start = 60.0
		scene.world.mist_settings.depth = 260.0
		scene.world.mist_settings.falloff = "QUADRATIC"
		inp = tree.nodes.new("CompositorNodeRLayers")
		fog = tree.nodes.new("ShaderNodeMix")
		fog.data_type = "RGBA"
		fog.inputs[7].default_value = (0.20, 0.25, 0.34, 1.0)
		glare = tree.nodes.new("CompositorNodeGlare")
		out = tree.nodes.new("NodeGroupOutput")
		tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
		for key, value in (("Type", "Bloom"), ("Quality", "High")):
			if key in glare.inputs:
				glare.inputs[key].default_value = value
		tree.links.new(inp.outputs["Mist"], fog.inputs["Factor"])
		tree.links.new(inp.outputs["Image"], fog.inputs[6])
		tree.links.new(fog.outputs[2], glare.inputs["Image"])
		tree.links.new(glare.outputs["Image"], out.inputs[0])
	except Exception as err:  # API compositor đổi giữa các bản Blender: không có bloom vẫn dựng được
		print("bloom skipped:", err)


def set_camera(name: str, target: Vector, distance: float, pitch_deg: float) -> None:
	cam = bpy.data.objects[name]
	pitch = math.radians(pitch_deg)
	cam.location = target + Vector((0, -math.cos(pitch) * distance, math.sin(pitch) * distance))
	cam.rotation_euler = (math.radians(90.0 - pitch_deg), 0, 0)


def clear_built() -> None:
	names = ("Platform", "Stairs", "Center", "Conduits", "Islands", "Backdrop", "PreviewLights")
	for coll in list(bpy.data.collections):
		if coll.name in names or coll.name.startswith("Sector_"):
			for obj in list(coll.objects):
				data = obj.data
				bpy.data.objects.remove(obj, do_unlink=True)
				if isinstance(data, bpy.types.Light) and data.users == 0:
					bpy.data.lights.remove(data)
			bpy.data.collections.remove(coll)
	for mesh in list(bpy.data.meshes):
		if mesh.users == 0:
			bpy.data.meshes.remove(mesh)


def build() -> None:
	clear_built()
	mats = build_materials()
	build_platform(mats)
	build_south_stairs(mats)
	build_center(mats)
	build_conduits(mats)
	build_wind(mats)
	build_fire(mats)
	build_ice(mats)
	build_thunder(mats)
	build_backdrop(mats)
	setup_scene()


if __name__ == "__main__":
	build()
