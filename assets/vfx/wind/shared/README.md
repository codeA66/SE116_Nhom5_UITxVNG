# Wind VFX — Godot 4.7.2 / GL Compatibility

## Chế độ của game

- Cột nâng dùng `resources/wind/wind_updraft.tres`: gió **liên tục**, không pulse. Các nét luôn đi từ dưới chân cáo lên đỉnh; không xoay toàn bộ hình lò xo tại chỗ.
- Chỉ vùng có `WindData.pulse_enabled = true` mới có báo trước, đầu gió và đuôi gió. Resource `wind_pulse.tres` là cấu hình ngắt quãng riêng.
- `WindZone` quản lý lực và nhịp nguồn. `WindZoneVfx` nghe active_changed/warning_changed/configuration_changed và là nơi duy nhất quản lý BaseRing.

## Diện mạo

Cột có 3–5 mảng chính (mặc định 5) và 12 mảng phụ: độ rộng, dài, độ cong, bán kính và độ đậm thay đổi theo seed, trắng ở lõi và xanh rất nhạt ở mép. Mảng trải dọc hướng nâng, không còn xếp thành các cung tròn đều. Nét thực sự chuyển vị trí lên trong vertex shader, tăng tốc về đỉnh rồi tan. Các nét gộp trong một mesh đã cache, một material, một draw call cho phần nét cột. HeightRing đánh dấu chiều cao cuối vùng, OutletFan bung nét ra ngoài rồi tan; không có lớp mist phủ mờ toàn cột. Vòng đáy có viền rõ, CPUParticles3D bụi phát từ vòng và có gia tốc hướng ra ngoài.

Màu lấy từ WindData.updraft_color/particle_color và WindVfxStyle. Không đóng màu vào texture. Ảnh kiểm tra lấy từ renderer game: FOV 30, nhìn xuống khoảng 50 độ, khoảng cách khoảng 32 m. Preview cột đặt cáo trong vùng, bật vật lý để gió thật nâng cáo.

## Texture

`wind_vfx_textures.gd` vẽ 5 mặt nạ RGBA trong Godot:

- stroke: nét cọ đầu/đuôi nhọn, lõi sáng, mép mềm;
- gust: mảng gió bất đối xứng, đầu lớn và đuôi chia nhánh;
- ring: vòng có viền rõ;
- dust: cụm bụi có lỗ thoáng;
- feather: lông có gân và nhánh.

Tạo một lần theo mask_resolution rồi cache dùng chung. Không có tải asset/plugin hoặc API tạo ảnh trong pipeline chạy game. Các mask cũng gắn vào vệt gồng E, vệt thổi E, vòng bụi E và bụi trúng. Texture có alpha thật, không có nền đen. Mặc định stroke 256×64, các mask còn lại 256×256.

## Thông số ưu tiên

Mở `assets/vfx/wind/wind_vfx_default.tres`. Muốn chỉnh riêng vùng, gán Resource riêng vào WindData.vfx_style. Để trống dùng mặc định, resource gió cũ không cần sửa.

| Thông số | Tác dụng |
|---|---|
| WindData.updraft_color / particle_color | Màu lõi cột / gió ngang |
| zone_edge_color, leaf_color, front_color | Màu mép, lông/đốm, đầu gió |
| zone_ribbon_count | Số nét cột, giới hạn 3–5 |
| zone_turns | Số vòng của **mỗi nét ngắn**, mặc định 0.18 |
| zone_stroke_span | Chiều cao của một nét so với cột, mặc định 0.38 |
| zone_ribbon_width, zone_opacity | Độ dày và đậm của nét |
| zone_rise_speed | Tần suất nét bay lên, không phải lực vật lý |
| height_ring_opacity, outlet_opacity | Vòng đánh dấu đỉnh và nét tỏa ra ngoài |
| WindData.ring_opacity, ring_pulse_speed | Độ đậm và nhịp nhẹ của vòng chân |
| zone_ring_width | Độ rộng viền vòng |
| base_dust_count/speed/lifetime/color/size_min/size_max | Bụi bung ra ngoài đáy |
| leaf_size, leaf_orbit_radius/speed, leaf_rise_speed | Kích thước và đường bay lá; rise_speed áp dụng cho gió liên tục |
| WindData.particle_density, leaf_density_ratio, max_leaf_count | ceil(thể tích × mật độ × hệ số), chặn theo max; mật độ 0 không có lá |
| mask_resolution | Độ phân giải mask (256 mặc định), chỉ tạo khi cấu hình |
| preview_enabled trên WindZoneVfx | Tắt preview editor: ẩn VFX và set_process(false) |

zone_rotation_speed/zone_mist_opacity/zone_mist_speed giữ tương thích Resource cũ; bản nét cọ mới không dùng lớp xoay/mist cũ.

## Pulse: lực và hình dùng chung thời gian truyền

`WindData.sweep_time` mặc định 0.25 s; `sweep_exponent` mặc định 1.6 làm đầu gió nhanh dần về cuối. p=0 tại +Z cục bộ, p=1 tại -Z. Độ trễ tới p = pow(p, 1/exponent) × sweep_time.

Một vị trí nhận lực nếu đầu nguồn phát gió tại thời điểm hiện tại trừ độ trễ. active=false tắt **nguồn**, không xóa lực đang truyền. Gió rút cùng hướng từ +Z tới -Z. Nhịp, tên và payload active_changed/warning_changed không đổi. Pulse ngắn hơn sweep_time vẫn giữ được các gói gió trong vùng, không ghi đè bằng một front/tail đơn lẻ.

VFX dùng cùng phase và tuổi nguồn; sweep_softness chỉ làm mềm biên hình. head_brightness chỉnh độ rõ đầu gió. Gió ngang có vệt báo trước ở đầu +Z, chỉnh bằng warning_width và zone_warning_opacity. Warning không sinh lực.

## Hiệu năng và vòng đời

- Lá/đốm: một MultiMeshInstance3D, một mesh, một material cho mỗi vùng. INSTANCE_CUSTOM chứa seed/phase/size chuẩn hóa; Compatibility lưu custom data 16-bit. Buffer instance chỉ ghi lúc cấu hình. Shader tính chuyển động, sinh từ đầu vào, không bật lá giữa đường. Pulse vận chuyển trong sweep_time; gió liên tục dùng leaf_rise_speed.
- Không set_shader_parameter hay đặt transform từng lá mỗi frame. CPU chỉ cập nhật bộ uniforms chung cho vùng; custom_aabb bao phủ đường bay.
- Mesh nét cọ và các mask cache dùng chung. Cast shadow tắt trên mọi VFX. CPUParticles3D dùng cho bụi, không dùng GPU trails.
- VFX ngủ sau khi đuôi và bụi dư ra hết; lần bật/warning tiếp theo đánh thức bằng signal. Editor dùng @tool; đổi size, hướng và Resource đều cập nhật.

## Skill E

WindBlastArea.begin_charge(data) phát charge_started; activate/deactivate phát blast_started/blast_stopped; pushed(receiver) và logic đẩy giữ nguyên. State WindBlast gọi begin_charge sau khi chốt hướng. Bị ngắt trước khi bung: gồng dừng ngay. Stop lặp được bỏ qua; phần đã bung tan theo dissolve_time.

Nón và hạt theo reach/width/height. Gồng theo active_start. Nón dùng noise UV trượt, vệt dùng mask nét cọ. Vòng bụi raycast một lần lúc bung, mask=1 world, không exclude player. Không có đất gần thì bỏ vòng bụi. Pool bụi trúng tạo sẵn, top_level=true; đầy thì bỏ hiệu ứng mới. Phần bung và bụi giữ vị trí thế giới khi cáo chạy/xoay đi.

wind_blast_vfx khôi phục material sau ready của cha vì script cáo hiện gán palette cho mọi MeshInstance3D dưới Model. Không sửa script nhân vật trong lượt VFX.

Các nút chỉnh E: wind_color/highlight_color/dust_color; cone_opacity, flow_speed, noise_scale, band_count, swirl, edge_softness; expansion_time/dissolve_time; streak_count/width/length_ratio/scale_min/max; charge_count/radius/ribbon_width/orbit_speed; ground_ring_size_ratio/width/duration; ground_probe_up/down; impact_pool_size/particle_count/lifetime/size/speed/spread/gravity.

## Kiểm tra

`tests/test_wind_vfx.tscn`:

- Mặc định: preview skill E.
- `--updraft`: cáo được gió thật nâng trong cột **liên tục**. Không dùng pulse cho preview cột.
- `--lane --pulse`: preview đầu/đuôi và warning của gió ngang.
- `--verify`: kiểm tra logic tự động, không ghi save; tạm replace_progress trong bộ nhớ rồi khôi phục, không phát progress_changed.
- Thêm `--capture`: frame runtime trong user://wind_updraft_frames, user://wind_lane_pulse_frames hoặc user://wind_vfx_frames.

Đã kiểm tra: ngắt gồng qua FSM thật; stop lặp; receiver thật bị đẩy một lần; pool và vị trí thế giới; kích thước theo data; bỏ vòng bụi trên không; A/giữa/B khi bật/tắt; receiver đứng yên trước đầu gió và bị đẩy sau khi đầu đến; shader/lực cùng sweep_time/phase; warning không sinh lực; pulse ngắn; buffer MultiMesh đứng yên khi lá chuyển động; mật độ 0 và giới hạn số lá; marker chiều cao và cache texture. Kiểm tra editor thật: preview, resize và tắt process. Hồi quy player: chạy/nhảy/dash/chém. Render trực tiếp OpenGL Compatibility trên MX230 ở camera game.

Chưa kiểm chứng: nhiều vùng chồng nhau, GPU/driver khác, export release và mọi nền của map cuối. Sound chưa có file. Không thêm animation thổi riêng cho cáo trong lượt này.


## Lớp particle và mảng gió bổ sung

- zone_detail_count (mặc định 12): số mảng phụ. Tất cả mảng lớn/nhỏ vẫn gộp trong một mesh và một material, một draw call; không cập nhật transform từng mảng từ CPU.
- AirParticles là CPUParticles3D riêng: 36 vệt khí/đốm nhỏ mặc định, sinh ở đáy, đi -Z cục bộ và tăng tốc; lifetime tính theo chiều cao, vận tốc và gia tốc lớn nhất để đầu hạt không vượt đỉnh. Các hạt dùng chung mesh/material, cast_shadow tắt.
- air_particle_count/color/speed/acceleration/width/length chỉnh được trong style. BaseDust tiếp tục là hệ CPUParticles3D thứ hai, đẩy bụi ra ngoài đáy. Lá/lông vẫn là MultiMesh + shader.
- Vòng đáy/đỉnh được ngắt thành các đoạn có độ đậm khác nhau, giảm cảm giác hai vòng UI. ground_ring_gain chỉnh độ đậm vòng đáy.
- Cột nâng vẫn liên tục; các mảng tan và nối tiếp riêng lẻ, không bật/tắt nguồn gió.


Bản lực gió mạnh: mảng chính dài hơn, rộng ở chân và thu ở đỉnh; 12 mảng phụ, 36 vệt khí với vận tốc 7 m/s và gia tốc 7 m/s²; 22 hạt bụi đáy bung ra nhanh. Đây là thông số hình ảnh trong style; strength của WindData và lực gameplay không bị tăng theo.
