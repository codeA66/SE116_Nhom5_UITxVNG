"""Xuất Đền Tứ Linh sang glTF cho Godot: dựng lại từ build_temple_hub.py rồi xuất từng cụm ra thư mục riêng.

Chạy: blender -b temple_hub.blend -P export_temple_hub.py
Ra:   assets/models/map_temple/
        platform/temple_platform.gltf   sân, lan can, cầu thang, mạch năng lượng
        center/temple_center.gltf       bệ + quả cầu thiên văn (các vòng là node riêng để Godot quay)
        palaces/palace_<nguyên tố>.gltf cung điện + cổng của từng khu
        backdrop/temple_backdrop.gltf   biển mây, vách núi, đảo nổi, đảo nguyên tố
        textures/                       texture dùng chung của cả 7 model
Không xuất đèn xem trước (PreviewLights), camera, mặt trời: ánh sáng trong game làm bằng vật liệu phát sáng + glow.
"""

import os
import runpy

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_ROOT = os.path.dirname(HERE)

GROUPS: dict[str, list[str]] = {
	"platform/temple_platform.gltf": ["Platform", "Stairs", "Conduits", "Collision"],
	"center/temple_center.gltf": ["Center"],
	"palaces/palace_wind.gltf": ["Sector_Wind"],
	"palaces/palace_fire.gltf": ["Sector_Fire"],
	"palaces/palace_ice.gltf": ["Sector_Ice"],
	"palaces/palace_thunder.gltf": ["Sector_Thunder"],
	"backdrop/temple_backdrop.gltf": ["Backdrop", "Islands"],
}


## Độ sáng phát quang chỉnh cho render Cycles (AgX); Godot (filmic + glow) cháy trắng nên nén lại khi xuất
EMISSION_KNEE: float = 1.0
EMISSION_SCALE: float = 0.25


def _soften_emission() -> None:
	"""Nén phần phát sáng trên 1: s -> 1 + (s - 1) * EMISSION_SCALE. Chỉ đổi bản xuất, không lưu vào .blend."""
	for mat in bpy.data.materials:
		if not mat.use_nodes:
			continue
		for node in mat.node_tree.nodes:
			if node.type == "BSDF_PRINCIPLED" and "Emission Strength" in node.inputs:
				socket = node.inputs["Emission Strength"]
				if socket.default_value > EMISSION_KNEE:
					socket.default_value = EMISSION_KNEE + (socket.default_value - EMISSION_KNEE) * EMISSION_SCALE


def export() -> None:
	ns = runpy.run_path(os.path.join(HERE, "build_temple_hub.py"), run_name="not_main")
	ns["build"]()
	bpy.ops.wm.save_mainfile()
	_soften_emission()
	for rel_path, collections in GROUPS.items():
		bpy.ops.object.select_all(action="DESELECT")
		count = 0
		for name in collections:
			coll = bpy.data.collections.get(name)
			if coll is None:
				print("thiếu collection", name)
				continue
			for obj in coll.all_objects:
				if obj.type == "MESH":
					obj.select_set(True)
					count += 1
		path = os.path.join(OUT_ROOT, rel_path)
		os.makedirs(os.path.dirname(path), exist_ok=True)
		# glTF tách file: 7 model dùng chung một thư mục textures/ thay vì mỗi .glb đóng gói một bản (145 MB -> nhẹ)
		bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="../textures",
			use_selection=True, export_apply=True, export_yup=True, export_lights=False, export_cameras=False,
			export_image_format="JPEG")
		print("EXPORTED", rel_path, count, "mesh")


if __name__ == "__main__":
	export()
