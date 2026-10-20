# Bộ model Map Gió

Đủ 39 hạng mục theo tài liệu concept.

Mỗi thư mục có GLB, nguồn Blender trong `source/`, ảnh concept, ảnh xem trước và thông số `metrics.json`. Nguồn Blender có `.gdignore` để Godot không nhập trùng.

Một GLB có thể chứa nhiều biến thể nguyên và hư hỏng đặt cạnh nhau. Khi ghép map, chọn nhánh biến thể cần dùng; các nhánh còn lại phục vụ lựa chọn. Model được xuất theo mét và Y hướng lên. Vải, rotor và các bộ phận cần chuyển động được tách riêng trong những model tương ứng.

Đây là bộ model và các trạng thái hình học. Bộ này chưa được gắn vào level, collider, animation hay logic tương tác của game. Camera tham chiếu trong ảnh dùng tỷ lệ cáo hiện tại.

| Mã | Model | File 3D | Xem trước |
|---|---|---|---|
| F01 | Cờ Gió chính | [GLB](f01/f01_wind_main_banner.glb) | [Ảnh](f01/preview.png) |
| F02 | Cờ rách | [GLB](f02/f02_torn_wind_banner.glb) | [Ảnh](f02/preview.png) |
| F03 | Cột cờ gãy đổ | [GLB](f03/f03_collapsed_wind_banner.glb) | [Ảnh](f03/preview.png) |
| F04 | Cờ ngang phụ | [GLB](f04/f04_secondary_horizontal_banner.glb) | [Ảnh](f04/preview.png) |
| T01 | Vách đá thẳng | [GLB](t01/t01_straight_cliff_wall.glb) | [Ảnh](t01/preview.png) |
| T02 | Góc vách đá | [GLB](t02/t02_cliff_corner_wall.glb) | [Ảnh](t02/preview.png) |
| T03 | Tấm sàn kiến trúc | [GLB](t03/t03_architectural_floor_slab.glb) | [Ảnh](t03/preview.png) |
| T04 | Mép sàn bị sạt | [GLB](t04/t04_cliff_edge_collapse.glb) | [Ảnh](t04/preview.png) |
| T05 | Cầu thang nghi lễ | [GLB](t05/t05_ceremonial_staircase.glb) | [Ảnh](t05/preview.png) |
| A01 | Cột nghi lễ | [GLB](a01/a01_ceremonial_column.glb) | [Ảnh](a01/preview.png) |
| A02 | Dầm ngang | [GLB](a02/a02_ceremonial_lintel_beam.glb) | [Ảnh](a02/preview.png) |
| A03 | Tường thấp | [GLB](a03/a03_low_retaining_wall.glb) | [Ảnh](a03/preview.png) |
| A04 | Mái điện | [GLB](a04/a04_ceremonial_wind_shrine_roof.glb) | [Ảnh](a04/preview.png) |
| A05 | Lan can nghi lễ | [GLB](a05/a05_ceremonial_barrier_module.glb) | [Ảnh](a05/preview.png) |
| I01 | Nhịp cầu | [GLB](i01/i01_modular_bridge_span.glb) | [Ảnh](i01/preview.png) |
| I02 | Trụ đỡ cầu | [GLB](i02/i02_modular_bridge_pier.glb) | [Ảnh](i02/preview.png) |
| I03 | Máy buồm đón gió | [GLB](i03/i03_wind_sail_machine.glb) | [Ảnh](i03/preview.png) |
| I04 | Trụ dẫn gió | [GLB](i04/i04_wind_guide_pillar.glb) | [Ảnh](i04/preview.png) |
| I05 | Bến gỗ | [GLB](i05/i05_wooden_dock.glb) | [Ảnh](i05/preview.png) |
| I06 | Thuyền buồm Gió | [GLB](i06/i06_wind_sailboat.glb) | [Ảnh](i06/preview.png) |
| I07 | Cọc neo | [GLB](i07/i07_mooring_post.glb) | [Ảnh](i07/preview.png) |
| I08 | Cần nâng hàng | [GLB](i08/i08_abandoned_cargo_crane.glb) | [Ảnh](i08/preview.png) |
| L01 | Cổng phế tích | [GLB](l01/l01_wind_ritual_gate.glb) | [Ảnh](l01/preview.png) |
| L02 | Giếng Gió | [GLB](l02/l02_ceremonial_wind_well.glb) | [Ảnh](l02/preview.png) |
| L03 | Thư điện Gió | [GLB](l03/l03_wind_archive_pavilion.glb) | [Ảnh](l03/preview.png) |
| L04 | Đàn Gió và vòng vỡ | [GLB](l04/l04_wind_orchestra_broken_ring.glb) | [Ảnh](l04/preview.png) |
| L05 | Tháp quan trắc gãy | [GLB](l05/l05_broken_observatory_tower.glb) | [Ảnh](l05/preview.png) |
| D01 | Mảnh vòng nghi lễ | [GLB](d01/d01_ceremonial_ring_fragment.glb) | [Ảnh](d01/preview.png) |
| D02 | Cụm đá đổ | [GLB](d02/d02_stone_rubble_clusters.glb) | [Ảnh](d02/preview.png) |
| D03 | Xe hàng bỏ lại | [GLB](d03/d03_abandoned_cargo_cart.glb) | [Ảnh](d03/preview.png) |
| D04 | Hòm và giá hàng | [GLB](d04/d04_abandoned_storage_kit.glb) | [Ảnh](d04/preview.png) |
| D05 | Phù điêu Gió | [GLB](d05/d05_wind_relief_slab.glb) | [Ảnh](d05/preview.png) |
| N01 | Cây nghiêng theo gió | [GLB](n01/n01_wind_bent_trees.glb) | [Ảnh](n01/preview.png) |
| N02 | Bụi cây và cỏ | [GLB](n02/n02_shrub_and_grass_set.glb) | [Ảnh](n02/preview.png) |
| N03 | Rễ và dây leo | [GLB](n03/n03_roots_and_vines.glb) | [Ảnh](n03/preview.png) |
| P01 | Đèn nghi lễ | [GLB](p01/p01_ceremonial_lantern.glb) | [Ảnh](p01/preview.png) |
| P02 | Tường giữ hồ | [GLB](p02/p02_pond_retaining_wall.glb) | [Ảnh](p02/preview.png) |
| P03 | Bệ sách Gió | [GLB](p03/p03_wind_reading_pedestal.glb) | [Ảnh](p03/preview.png) |
| P04 | Điểm lưu Gió | [GLB](p04/p04_wind_checkpoint_beacon.glb) | [Ảnh](p04/preview.png) |

## Kiểm tra file

Đã kiểm tra đủ file, header và độ dài GLB 2.0, khả năng đọc JSON, tài nguyên nhúng và thư mục nguồn. Báo cáo chi tiết: `output/wind_production/final_file_audit.json`. Thông số hình học, các lần xem ảnh và góp ý 2D được lưu trong metrics và nhật ký sản xuất; chưa kiểm thử gameplay hoặc đo FPS trong Godot.
