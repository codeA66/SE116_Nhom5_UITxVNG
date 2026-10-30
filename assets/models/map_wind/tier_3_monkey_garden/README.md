# tier_3_monkey_garden – V2 có hoa văn

Vườn hoàng gia Wind Palace bị khỉ chiếm; low-poly, shading phẳng, vertex color, không texture. Người dùng không duyệt blockout V1; cả 39 model đã dựng lại thành V2. **V2 chưa được người dùng duyệt mỹ thuật.**

## Nguồn và cách tiếp tục

- File Blender đầy đủ: C:/Code/UITxVNG/Foxy_Art_Source/tier_3_monkey_garden/garden_live_workbench.blend.
- Mỗi model có collection Garden_<tên>; đây là nguồn xuất. Preview CurrentView_* chỉ là linked copy, KHÔNG xuất từ preview.
- BlockoutV1_* và preview cũ giữ để phục hồi; backup garden_blockout_v1_backup.blend ngoài project.
- File riêng <tên>.blend là thư viện Object, dùng File > Append > Object.
- Helper, QA và project thử cô lập: C:/Code/UITxVNG/output/tier_3_monkey_garden/.
- Cảnh Godot: res://tests/kits/monkey_garden_kit/garden_review.tscn. Tham số --group=corner/ground/walls/structures/plants/monkey_props/interactive/composition/scale/motion.
- HANDOFF_AI.md ghi workflow, lỗi crash đã gặp và trạng thái tiếp tục. Không chạy lại helper dựng/hoa văn nguyên khối vì sẽ tạo trùng.

## Model thực tế

Kích thước X × Y cao × Z, mét, đo POSITION GLB sau node transforms; tam giác đếm trực tiếp index buffer GLB. Pivot mesh rời được ghi trong manifest.json, mục separate_meshes.

| File | Model / công dụng | X×Y×Z (m) | Tam giác / trần |
|---|---|---|---|
| [floor_dirt_2m](ground/floors/floor_dirt_2m.glb) | Nền đất nện 2m | 2.0 × 0.0 × 2.0 | 8 / 60 |
| [floor_stone_broken_2m](ground/floors/floor_stone_broken_2m.glb) | Nền lát đá vỡ 2m | 2.0 × 0.016 × 2.0 | 116 / 150 |
| [floor_dirt_4m](ground/floors/floor_dirt_4m.glb) | Nền đất nện 4m | 4.0 × 0.0 × 4.0 | 18 / 120 |
| [floor_stone_broken_4m](ground/floors/floor_stone_broken_4m.glb) | Nền lát đá vỡ 4m | 4.0 × 0.016 × 4.0 | 268 / 300 |
| [path_edge_2m](ground/accents/path_edge_2m.glb) | Viền đá đường đi | 1.97 × 0.16 × 0.3 | 65 / 80 |
| [moss_patch_s](ground/accents/moss_patch_s.glb) | Mảng rêu nhỏ | 0.5727 × 0.001 × 0.4062 | 11 / 30 |
| [moss_patch_m](ground/accents/moss_patch_m.glb) | Mảng rêu vừa | 1.4318 × 0.001 × 1.0154 | 14 / 60 |
| [stair_mossy_2m](ground/transitions/stair_mossy_2m.glb) | Cầu thang đá 4 bậc | 2.0 × 1.001 × 2.0 | 73 / 300 |
| [ramp_dirt_4m](ground/transitions/ramp_dirt_4m.glb) | Dốc đất | 2.0 × 1.0 × 4.0 | 10 / 150 |
| [dry_streambed_4m](ground/transitions/dry_streambed_4m.glb) | Lòng suối khô nông | 2.0 × 0.15 × 4.0 | 158 / 250 |
| [wall_garden_4m](walls/wall_garden_4m.glb) | Tường vườn thẳng | 4.0 × 3.0 × 0.6 | 229 / 300 |
| [wall_garden_corner](walls/wall_garden_corner.glb) | Trụ góc tường | 0.6 × 3.0 × 0.601 | 126 / 150 |
| [wall_garden_arch_4m](walls/wall_garden_arch_4m.glb) | Vòm cửa đá | 4.0 × 3.4824 × 0.604 | 184 / 400 |
| [wall_garden_broken_4m](walls/wall_garden_broken_4m.glb) | Tường sập vẫn chắn người chơi | 4.0 × 3.0 × 0.6 | 120 / 350 |
| [fence_bamboo_2m](walls/fence_bamboo_2m.glb) | Hàng rào tre | 2.0111 × 1.6016 × 0.1938 | 122 / 150 |
| [vine_wall_cover_4m](walls/vine_wall_cover_4m.glb) | Dây leo áp tường | 4.15 × 3.0044 × 0.0556 | 164 / 200 |
| [garden_gate](structures/garden_gate.glb) | Cổng vườn hai cánh có mái | 4.0 × 4.0 × 1.45 | 790 / 800 |
| [pillar_vine_4m](structures/pillar_vine_4m.glb) | Trụ đá quấn dây leo | 0.8 × 4.0 × 0.8 | 182 / 250 |
| [pavilion_small](structures/pavilion_small.glb) | Đình bốn cột, mái có chỗ đứng | 4.0 × 4.0 × 4.0 | 728 / 1500 |
| [bridge_arched_4m](structures/bridge_arched_4m.glb) | Cầu vòm thấp có lan can | 2.57 × 1.615 × 4.0 | 450 / 500 |
| [planter_stone_2m](structures/planter_stone_2m.glb) | Bồn cây viền đá | 2.0 × 0.6 × 2.004 | 88 / 150 |
| [pond_dry_4m](structures/pond_dry_4m.glb) | Ao khô nông | 4.0 × 0.15 × 4.0 | 144 / 300 |
| [tree_ancient](plants/trees/tree_ancient.glb) | Cây cổ thụ, ba cành đứng được | 9.6521 × 8.96 × 6.1863 | 1013 / 4000 |
| [tree_garden](plants/trees/tree_garden.glb) | Cây vườn vừa, tán tách riêng | 3.8173 × 4.998 × 3.012 | 421 / 800 |
| [tree_young](plants/trees/tree_young.glb) | Cây non | 1.5111 × 2.492 × 0.9481 | 140 / 250 |
| [roots_through_floor](plants/accents/roots_through_floor.glb) | Rễ cây nổi phá nền | 3.0098 × 0.293 × 1.7253 | 246 / 300 |
| [bush_broad_s](plants/accents/bush_broad_s.glb) | Bụi lá rộng nhỏ | 0.7804 × 0.4125 × 0.7744 | 63 / 80 |
| [bush_broad_m](plants/accents/bush_broad_m.glb) | Bụi lá rộng vừa | 1.6468 × 1.033 × 1.5489 | 113 / 160 |
| [vine_hanging](plants/accents/vine_hanging.glb) | Dây leo treo có pivot phía trên | 0.64 × 2.7551 × 0.0671 | 39 / 60 |
| [loot_pile](monkey_props/loot/loot_pile.glb) | Đống đồ cướp: chum, thùng, vải, trái cây | 1.8976 × 1.0032 × 1.6737 | 443 / 600 |
| [banana_bunch](monkey_props/loot/banana_bunch.glb) | Nải chuối nhỏ | 0.2898 × 0.1056 × 0.1388 | 46 / 60 |
| [fruit_peels](monkey_props/loot/fruit_peels.glb) | Vỏ trái cây | 0.3388 × 0.0676 × 0.4944 | 36 / 40 |
| [banner_hammock](monkey_props/lair/banner_hammock.glb) | Võng làm từ cờ cung điện | 2.9932 × 1.8051 × 1.103 | 192 / 200 |
| [nest_branch](monkey_props/lair/nest_branch.glb) | Ổ khỉ trên cành | 1.0658 × 0.1758 × 1.0656 | 132 / 200 |
| [chieftain_throne](monkey_props/lair/chieftain_throne.glb) | Ngai thủ lĩnh từ đồ nhặt được | 2.9684 × 3.0 × 2.5 | 556 / 1500 |
| [territory_totem](monkey_props/lair/territory_totem.glb) | Cọc lãnh thổ, mặt nạ không máu me | 0.6 × 2.2058 × 0.2837 | 137 / 300 |
| [garden_door_locked](interactive/garden_door_locked.glb) | Cửa khóa hai cánh, khóa cyan phát sáng | 3.0 × 3.5 × 0.605 | 652 / 800 |
| [key_pedestal_garden](interactive/key_pedestal_garden.glb) | Bệ đặt chìa khóa | 0.8 × 1.102 × 0.8 | 114 / 300 |
| [chest_garden](interactive/chest_garden.glb) | Rương, nắp có bản lề và chốt cyan | 1.2 × 0.812 × 0.89 | 266 / 400 |

## Màu và kiểm tra Godot

Bảng màu cuối hiện tại: dirt #85735F, stone #857E70, wall #6C665D, cap #80796B, moss #4F5E3A, wood #77634C, leaf #566B45, leaf_hi #789259, trunk #65503D, cloth #7FA7A8, fruit #C9A640, ivory #C5BDA1, cyan #3FE0D0, roof #718073, dirt_shade #7E6B56, dirt_soft #897763, stone_light #978F7F, stone_shade #736D62, wall_light #777165, bark_light #786049, bark_dark #544333, leaf_deep #40513A, leaf_soft #657D50, rope #9A8A65, cloth_light #97B5AF, cloth_shade #648B87.

Góc thử 12×12m trong project game, Godot 4.7.2 GL Compatibility, camera nghiêng 50°, FOV 30°, vị trí (0,24.51,20.57), ambient 0.65, sun 0.75: **nền 0.271117, tường 0.197825**. Lấy Color.get_luminance() trên toàn bộ pixel nền nhìn thấy gồm đá/đất/bóng qua ID mask (186214 pixel nền, 70766 pixel tường). Trong điều kiện QA này đạt 0.25–0.30 và chênh tối tường ≥0.05. Ánh sáng level gameplay khác: not measured.

Đã xem ảnh màu+xám từ Godot: corner, contact sheet 6 nhóm, composition, scale và motion. Hoa văn cổng và nắp rương gắn đúng mesh bản lề, đã xem trạng thái mở. COLOR_0 và shared material được kiểm tra bằng script; tất cả GLB có màu vertex, không texture/camera/light, tam giác dưới trần.

Ảnh QA ở C:/Code/UITxVNG/output/tier_3_monkey_garden:

- [corner màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/corner_color.png), [corner xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/corner_grayscale.png).
- [ground màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/ground_color.png), [ground xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/ground_grayscale.png).
- [walls màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/walls_color.png), [walls xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/walls_grayscale.png).
- [structures màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/structures_color.png), [structures xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/structures_grayscale.png).
- [plants màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/plants_color.png), [plants xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/plants_grayscale.png).
- [monkey_props màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/monkey_props_color.png), [monkey_props xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/monkey_props_grayscale.png).
- [interactive màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/interactive_color.png), [interactive xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/interactive_grayscale.png).
- [composition màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/composition_color.png), [composition xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/composition_grayscale.png).
- [scale màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/scale_color.png), [scale xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/scale_grayscale.png).
- [motion màu](C:/Code/UITxVNG/output/tier_3_monkey_garden/motion_color.png), [motion xám](C:/Code/UITxVNG/output/tier_3_monkey_garden/motion_grayscale.png).

Scale shot dùng GLB cáo/khỉ có sẵn, chỉ đọc nguồn. Chuẩn hóa posed mesh AABB thành cáo/khỉ 1.8m và thủ lĩnh 2.35m; không đo bằng bind-pose AABB vì bị phóng sai. Slash ivory là hình mẫu QA, không thay VFX gameplay. Composition lùi camera 1.2 lần và nâng mục tiêu để thấy hết tán cây; scale/motion dùng camera gameplay.

## Hoa văn và tham chiếu

Biểu tượng ba lá/gió nguyên bản nối các món cung điện: cửa, mái đình, cột, bệ, rương, cầu, ổ làm từ cờ. Dấu tay khỉ phủ lên đồ cướp/ngai/cờ. Hoa văn là geometry tô vertex color, không texture hay asset sao chép.

- Ground/walls: [Death’s Door, Estate of the Urn Witch](https://www.trueachievements.com/game/Deaths-Door/walkthrough/4), ảnh 120744.jpg và 120741.jpg: sân vườn đá, mảng nền rõ.
- Structures/interactive: cùng bộ ảnh Death’s Door cho khối đá, bệ, cổng và độ tiết chế; [Deku Palace](https://www.bjarke.it/sundaymorninggame/majoras-mask-part-7) cho tính cung điện gắn với thực vật. Ảnh Deku Garden đúng khu chưa kiểm chứng.
- Plants: [Death’s Door screenshots](https://steamdb.info/app/894020/screenshots/), vườn Estate ở trên, và [Black Myth Wukong Huaguo](https://sikemokux.com/entry/2024/09/04/001709); dùng thân cong và tán cụm, không sao chép model.
- Monkey props: thiết kế theo spec về đồ cướp, cờ thành võng và ngai chắp vá; tham chiếu bối cảnh Huaguo ở trên. Ảnh Water Curtain Cave cụ thể chưa kiểm chứng.

## Việc còn mở / chưa làm

- Chưa được người dùng duyệt chất lượng mỹ thuật; chưa thể gọi đây là bản art hoàn tất.
- Vẫn có leaf sheet hai mặt đồng phẳng trên dây leo, cần kiểm tra kỹ mọi góc/độ rung; kiểm toán toàn bộ mặt giao nhau bên trong chưa hoàn tất.
- Chum chưa có lòng sâu hoàn chỉnh; cần tinh chỉnh một số decal nhỏ và vùng vải/hoa văn từ góc khác.
- Kích thước thực khác kích thước danh nghĩa ở một số props/module; luôn đọc bảng/manifest. Lan can nằm ngoài bề rộng đi bộ 2m của cầu.
- Chưa có collider, navigation, gameplay, logic cửa/rương hay canopy-fade. Đường đi/độ dốc được dựng theo hình học; capsule traversal chưa chạy kiểm thử.
- Chạy trong game chính tạo ảnh thành công nhưng khi thoát có cảnh báo texture RID leak 4156 bytes và RenderingServer null; không sửa autoload/gameplay để xử lý. Log *_game_render.log ngoài project.
- Một số contact sheet không thay đổi sau lượt hoa văn; đọc timestamp/log nếu cần truy vết.

Không sửa kit khác, level, builder, gameplay hoặc project.godot; không cài addon, không commit. Dựng trực tiếp trong Blender đang mở theo yêu cầu người dùng.
