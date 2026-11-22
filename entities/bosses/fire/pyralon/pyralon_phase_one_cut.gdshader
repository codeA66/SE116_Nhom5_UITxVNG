shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// Shader cắt tạm thời gắn lên mesh gốc Phase 1 CHỈ trong lúc biến hình sang Phase 2:
// - Trước mặt sóng ánh sáng (v_chest_dist > light_sweep): hiển thị nguyên gốc Phase 1 để giữ hiệu ứng khung lưới năng lượng bọc 4 bước đầu.
// - Ngay sau mặt sóng đi qua (v_chest_dist <= light_sweep): discard từng pixel đồng bộ tuyệt đối, triệt tiêu hoàn toàn 1-frame flicker lúc kết thúc!
uniform float light_sweep : hint_range(-0.3, 1.6) = -0.3;

varying vec4 v_col;
varying float v_chest_dist;

void vertex() {
	v_col = COLOR;
	v_chest_dist = clamp(length(VERTEX - vec3(0.0, 2.05, 0.0)) / 3.25, 0.0, 1.0);
}

void fragment() {
	if (light_sweep > -0.20 && v_chest_dist <= light_sweep) {
		discard;
	}
	ALBEDO = v_col.rgb;
	ROUGHNESS = 0.88;
}
