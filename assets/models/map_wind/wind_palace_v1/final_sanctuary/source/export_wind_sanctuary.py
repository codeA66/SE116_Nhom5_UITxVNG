"""Xuất từng cụm và dùng ảnh PBR chung để tránh nhân bản bộ texture."""
from pathlib import Path
import json
import runpy
import sys
import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
GROUPS = {"stage": ("SanctuaryStage", "SanctuaryCollision"), "shrine": ("SanctuaryShrine",), "weather": ("SanctuaryWeather",)}


def export() -> None:
    ns = runpy.run_path(str(HERE / "build_wind_sanctuary.py"), run_name="sanctuary_build")
    ns["build"]()
    if "--" in sys.argv:
        folder = Path(sys.argv[sys.argv.index("--") + 1])
        ns["setup_preview"](folder / "blender_review.png")
        # Đường dẫn tương đối qua thư mục xem thử dễ vượt giới hạn Windows và làm mất texture khi xuất.
        bpy.ops.wm.save_as_mainfile(filepath=str(folder / "wind_sanctuary.blend"), relative_remap=False)
    fields = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_keep_originals" not in fields:
        raise RuntimeError("Bản xuất cần hỗ trợ đường dẫn texture gốc")
    for name, collections in GROUPS.items():
        bpy.ops.object.select_all(action="DESELECT")
        for group in collections:
            for obj in bpy.data.collections[group].objects:
                obj.hide_set(False)
                obj.select_set(True)
        path = ROOT / "geometry" / name / (name + ".gltf")
        path.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLTF_SEPARATE", use_selection=True,
            export_apply=True, export_yup=True, export_lights=False, export_cameras=False,
            export_keep_originals=True, export_animations=False)
        # Bắt ngay vật liệu mất ảnh thay vì để Godot hiện sàn trắng mà không báo lỗi import.
        document = json.loads(path.read_text(encoding="utf-8"))
        for material in document.get("materials", []):
            material_name = material.get("name", "")
            if material_name.startswith("Sanctuary_tile_variants/") or material_name == "Sanctuary_woven_silk":
                if "baseColorTexture" not in material.get("pbrMetallicRoughness", {}):
                    raise RuntimeError("Mất texture: " + material_name)
            if material_name == "Sanctuary_PaintedStorm" and "emissiveTexture" not in material:
                raise RuntimeError("Mất texture biển mây")
        print("SANCTUARY EXPORTED", name, flush=True)


if __name__ == "__main__":
    export()
