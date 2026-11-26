"""Quét chống vệt loang (z-fighting) toàn bộ Đền Tứ Linh trên chính các file glTF Godot nạp.

Chạy bằng Python của Blender (có numpy):  blender -b -P zfight_sweep.py
Báo mọi cặp mặt khác vật liệu:
  - mặt nằm ngang cùng hướng, chồng nhau (lấn hơn 5 cm) mà lệch cao dưới 2 cm;
  - mặt đứng song song cùng hướng, chồng nhau mà lệch dưới 2 cm.
Mặt cùng vật liệu chồng nhau không tính: UV chiếu theo toạ độ thế giới (box_uv) nên hai mặt cho ra cùng điểm ảnh, không loang.
Khối va chạm (-colonly) không vẽ nên bỏ qua. Thoát mã 1 nếu còn cặp lỗi.
"""

import base64
import glob
import json
import math
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GAP = 0.02
OVERLAP = 0.05
CELL = 2.0

COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
DTYPES = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}


def read_accessor(doc: dict, base: str, buffers: dict, index: int) -> np.ndarray:
	acc = doc["accessors"][index]
	view = doc["bufferViews"][acc["bufferView"]]
	buf_index = view["buffer"]
	if buf_index not in buffers:
		uri = doc["buffers"][buf_index]["uri"]
		if uri.startswith("data:"):
			buffers[buf_index] = base64.b64decode(uri.split(",", 1)[1])
		else:
			with open(os.path.join(base, uri), "rb") as f:
				buffers[buf_index] = f.read()
	data = buffers[buf_index]
	dtype = DTYPES[acc["componentType"]]
	comps = COMPONENTS[acc["type"]]
	offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
	count = acc["count"]
	stride = view.get("byteStride", 0)
	item = np.dtype(dtype).itemsize * comps
	if stride and stride != item:
		raw = np.frombuffer(data, dtype=np.uint8, count=stride * (count - 1) + item, offset=offset)
		rows = np.lib.stride_tricks.as_strided(raw, shape=(count, item), strides=(stride, 1))
		return rows.copy().view(dtype).reshape(count, comps)
	return np.frombuffer(data, dtype=dtype, count=count * comps, offset=offset).reshape(count, comps)


def load_triangles() -> list[tuple[str, str, np.ndarray]]:
	"""[(tên node, tên vật liệu, tam giác (n, 3, 3))] trong toạ độ Godot (node không có transform: đã kiểm lúc chạy)."""
	out = []
	for path in sorted(glob.glob(os.path.join(ROOT, "*", "*.gltf"))):
		doc = json.load(open(path, encoding="utf-8"))
		base = os.path.dirname(path)
		buffers: dict = {}
		for node in doc["nodes"]:
			if "mesh" not in node or node["name"].endswith("-colonly"):
				continue
			if any(k in node for k in ("translation", "rotation", "scale", "matrix")):
				sys.exit(f"node {node['name']} có transform, script chưa hỗ trợ")
			for prim in doc["meshes"][node["mesh"]]["primitives"]:
				pos = read_accessor(doc, base, buffers, prim["attributes"]["POSITION"]).astype(np.float64)
				idx = read_accessor(doc, base, buffers, prim["indices"]).reshape(-1, 3).astype(np.int64)
				mat = doc["materials"][prim["material"]]["name"] if "material" in prim else "none"
				out.append((f"{os.path.basename(path)}:{node['name']}", mat, pos[idx]))
	return out


def sat_overlap(a: np.ndarray, b: np.ndarray) -> bool:
	"""Hai tam giác 2D chồng nhau sâu hơn OVERLAP trên mọi trục tách (chạm mép không tính)."""
	for tri in (a, b):
		for i in range(3):
			e = tri[(i + 1) % 3] - tri[i]
			axis = np.array([-e[1], e[0]])
			n = np.linalg.norm(axis)
			if n < 1e-9:
				return False
			axis /= n
			pa, pb = a @ axis, b @ axis
			if min(pa.max(), pb.max()) - max(pa.min(), pb.min()) < OVERLAP:
				return False
	return True


def sweep(groups: list, kind: str) -> list[str]:
	"""groups: [(tên, vật liệu, khoá mặt phẳng (n,), toạ độ 2D (n,3,2))]. Tìm cặp cùng mặt phẳng ± GAP, khác vật liệu.
	Chia lưới CELL m theo toạ độ 2D để không so mọi cặp (sàn có hàng chục nghìn tam giác cùng độ cao)."""
	cells: dict[tuple, list] = {}
	for gi, (_name, _mat, keys, pts) in enumerate(groups):
		lo = np.floor(pts.min(1) / CELL).astype(int)
		hi = np.floor(pts.max(1) / CELL).astype(int)
		for ti in range(len(keys)):
			for cx in range(lo[ti, 0], hi[ti, 0] + 1):
				for cy in range(lo[ti, 1], hi[ti, 1] + 1):
					cells.setdefault((cx, cy), []).append((keys[ti], gi, ti))
	bad = []
	seen = set()
	for entries in cells.values():
		mats = {groups[gi][1] for _k, gi, _t in entries}
		if len(mats) < 2:
			continue
		entries.sort(key=lambda e: e[0])
		for i, (k, gi, ti) in enumerate(entries):
			j = i + 1
			while j < len(entries) and entries[j][0] - k < GAP:
				k2, gj, tj = entries[j]
				j += 1
				if groups[gi][1] == groups[gj][1]:
					continue
				pair = tuple(sorted((groups[gi][0], groups[gj][0])))
				if pair in seen:
					continue
				a, b = groups[gi][3][ti], groups[gj][3][tj]
				if a.min(0)[0] > b.max(0)[0] - OVERLAP or b.min(0)[0] > a.max(0)[0] - OVERLAP:
					continue
				if a.min(0)[1] > b.max(0)[1] - OVERLAP or b.min(0)[1] > a.max(0)[1] - OVERLAP:
					continue
				if not sat_overlap(a, b):
					continue
				seen.add(pair)
				first, second = sorted(((groups[gi][0], groups[gi][1]), (groups[gj][0], groups[gj][1])))
				bad.append(f"{kind}: {first[0]} ({first[1]}) <> {second[0]} ({second[1]}) tại {a.mean(0).round(2)},"
					f" lệch {abs(k2 - k):.3f} m")
	return bad


def main() -> None:
	meshes = load_triangles()
	horizontal = []
	vertical: dict[tuple, list] = {}
	for name, mat, tris in meshes:
		n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
		length = np.linalg.norm(n, axis=1)
		ok = length > 1e-8
		tris, n = tris[ok], n[ok] / length[ok][:, None]
		up = n[:, 1] > 0.995
		if up.any():
			t = tris[up]
			horizontal.append((name, mat, t[:, :, 1].mean(1), t[:, :, [0, 2]]))
		side = np.abs(n[:, 1]) < 0.02
		if side.any():
			t, nn = tris[side], n[side]
			yaw = np.round(np.degrees(np.arctan2(nn[:, 0], nn[:, 2]))).astype(int) % 360
			for deg in np.unique(yaw):
				sel = yaw == deg
				r = math.radians(deg)
				normal = np.array([math.sin(r), 0.0, math.cos(r)])
				tangent = np.array([math.cos(r), 0.0, -math.sin(r)])
				tt = t[sel]
				d = tt.reshape(-1, 3) @ normal
				uv = np.stack([tt.reshape(-1, 3) @ tangent, tt.reshape(-1, 3)[:, 1]], 1).reshape(-1, 3, 2)
				vertical.setdefault(deg, []).append((name, mat, d.reshape(-1, 3).mean(1), uv))
	bad = sweep(horizontal, "ngang")
	for deg, groups in vertical.items():
		bad += sweep(groups, f"đứng {deg}°")
	total = sum(len(t) for _n, _m, t in meshes)
	print(f"ZFIGHT {len(meshes)} khối, {total} tam giác: {len(bad)} cặp")
	for line in bad[:80]:
		print("  ", line)
	sys.exit(1 if bad else 0)


main()
