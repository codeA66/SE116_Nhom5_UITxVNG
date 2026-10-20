"""Check finished deliverables and build the model catalog without touching gameplay."""
import json
import struct
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'output/wind_production'
DEST = ROOT / 'assets/generated/wind_ruins'
NAMES = {
    'F01': 'Cờ Gió chính', 'F02': 'Cờ rách', 'F03': 'Cột cờ gãy đổ', 'F04': 'Cờ ngang phụ',
    'T01': 'Vách đá thẳng', 'T02': 'Góc vách đá', 'T03': 'Tấm sàn kiến trúc',
    'T04': 'Mép sàn bị sạt', 'T05': 'Cầu thang nghi lễ',
    'A01': 'Cột nghi lễ', 'A02': 'Dầm ngang', 'A03': 'Tường thấp', 'A04': 'Mái điện', 'A05': 'Lan can nghi lễ',
    'I01': 'Nhịp cầu', 'I02': 'Trụ đỡ cầu', 'I03': 'Máy buồm đón gió', 'I04': 'Trụ dẫn gió',
    'I05': 'Bến gỗ', 'I06': 'Thuyền buồm Gió', 'I07': 'Cọc neo', 'I08': 'Cần nâng hàng',
    'L01': 'Cổng phế tích', 'L02': 'Giếng Gió', 'L03': 'Thư điện Gió',
    'L04': 'Đàn Gió và vòng vỡ', 'L05': 'Tháp quan trắc gãy',
    'D01': 'Mảnh vòng nghi lễ', 'D02': 'Cụm đá đổ', 'D03': 'Xe hàng bỏ lại',
    'D04': 'Hòm và giá hàng', 'D05': 'Phù điêu Gió',
    'N01': 'Cây nghiêng theo gió', 'N02': 'Bụi cây và cỏ', 'N03': 'Rễ và dây leo',
    'P01': 'Đèn nghi lễ', 'P02': 'Tường giữ hồ', 'P03': 'Bệ sách Gió', 'P04': 'Điểm lưu Gió',
}

def main():
    state = json.loads((OUT / 'asset_state.json').read_text(encoding='utf-8'))
    issues, results = [], []
    for code, name in NAMES.items():
        item = state.get(code, {})
        if item.get('state') != 'completed':
            issues.append(f'{code}: state is {item.get("state", "missing")}')
            continue
        files = {}
        for key in ('glb', 'source', 'concept', 'preview'):
            path = ROOT / item.get(key, '_missing_')
            if not path.is_file() or path.stat().st_size == 0:
                issues.append(f'{code}: missing or empty {key}')
            files[key] = path
        glb = files['glb']
        if not glb.is_file():
            continue
        if not glb.resolve().is_relative_to(DEST.resolve()):
            issues.append(f'{code}: GLB outside requested folder')
        data = glb.read_bytes()
        if len(data) < 20 or struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
            issues.append(f'{code}: invalid GLB header or length')
            continue
        size, chunk_type = struct.unpack_from('<II', data, 12)
        if chunk_type != 0x4E4F534A:
            issues.append(f'{code}: first chunk is not JSON')
            continue
        doc = json.loads(data[20:20+size])
        accessors = doc.get('accessors', [])
        triangles = 0
        for mesh in doc.get('meshes', []):
            for prim in mesh.get('primitives', []):
                if prim.get('mode', 4) == 4:
                    if 'indices' in prim:
                        accessor = accessors[prim['indices']]
                        triangles += accessor['count'] // 3
                    else:
                        triangles += accessors[prim['attributes']['POSITION']]['count'] // 3
        for resource in doc.get('buffers', []) + doc.get('images', []):
            uri = resource.get('uri', '')
            if uri and not uri.startswith('data:'):
                issues.append(f'{code}: external dependency {uri}')
        if not files['source'].parent.joinpath('.gdignore').is_file():
            issues.append(f'{code}: source .gdignore absent')
        if not glb.parent.joinpath('metrics.json').is_file():
            issues.append(f'{code}: metrics absent')
        results.append({'id': code, 'name': name, 'glb': glb.relative_to(ROOT).as_posix(),
                        'bytes': len(data), 'mesh_count': len(doc.get('meshes', [])),
                        'triangles_including_variants': triangles,
                        'materials': len(doc.get('materials', []))})
    report = {'checked_utc': datetime.now(timezone.utc).isoformat(), 'expected': len(NAMES),
              'completed_checked': len(results), 'issues': issues, 'assets': results,
              'scope': 'Package structure and required deliverables; not a gameplay or performance test.'}
    (OUT / 'final_file_audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    if issues or len(results) != len(NAMES):
        print(json.dumps({'checked': len(results), 'expected': len(NAMES), 'issues': issues}, ensure_ascii=True))
        raise SystemExit(1)
    lines = ['# Bộ model Map Gió', '', 'Đủ 39 hạng mục theo tài liệu concept.', '',
             'Mỗi thư mục có GLB, nguồn Blender trong `source/`, ảnh concept, ảnh xem trước và thông số `metrics.json`. Nguồn Blender có `.gdignore` để Godot không nhập trùng.', '',
             'Một GLB có thể chứa nhiều biến thể nguyên và hư hỏng đặt cạnh nhau. Khi ghép map, chọn nhánh biến thể cần dùng; các nhánh còn lại phục vụ lựa chọn. Model được xuất theo mét và Y hướng lên. Vải, rotor và các bộ phận cần chuyển động được tách riêng trong những model tương ứng.', '',
             'Đây là bộ model và các trạng thái hình học. Bộ này chưa được gắn vào level, collider, animation hay logic tương tác của game. Camera tham chiếu trong ảnh dùng tỷ lệ cáo hiện tại.', '',
             '| Mã | Model | File 3D | Xem trước |', '|---|---|---|---|']
    for code, name in NAMES.items():
        item = state[code]
        gp = (ROOT / item['glb']).relative_to(DEST).as_posix()
        pp = (ROOT / item['preview']).relative_to(DEST).as_posix()
        lines.append(f'| {code} | {name} | [GLB]({gp}) | [Ảnh]({pp}) |')
    lines += ['', '## Kiểm tra file', '',
              'Đã kiểm tra đủ file, header và độ dài GLB 2.0, khả năng đọc JSON, tài nguyên nhúng và thư mục nguồn. Báo cáo chi tiết: `output/wind_production/final_file_audit.json`. Thông số hình học, các lần xem ảnh và góp ý 2D được lưu trong metrics và nhật ký sản xuất; chưa kiểm thử gameplay hoặc đo FPS trong Godot.', '']
    (DEST / 'README.md').write_text('\n'.join(lines), encoding='utf-8')
    print('PASS: 39 complete model packages; catalog written.')

if __name__ == '__main__':
    main()
