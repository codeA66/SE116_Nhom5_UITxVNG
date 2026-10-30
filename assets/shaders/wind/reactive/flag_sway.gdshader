shader_type spatial;
render_mode cull_disabled;

// Vải cờ bay theo gió hoàn toàn trên GPU: không tốn script mỗi frame.
// Mép trên (anchor_top) đứng yên, càng xuống dưới càng bay mạnh.

// Hướng gió theo toạ độ thế giới; shader tự đổi sang toạ độ của từng lá cờ
uniform vec3 wind_direction = vec3(0.6, 0.0, -1.0);
uniform float sway_amplitude = 0.22;
uniform float sway_speed = 1.6;
uniform float ripple_frequency = 2.4;
uniform float ripple_amplitude = 0.07;
// Độ cao mép treo và chiều dài vải trong toạ độ cục bộ của mesh
uniform float anchor_top = 4.3;
uniform float cloth_length = 2.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.86;

void vertex() {
	float weight = clamp((anchor_top - VERTEX.y) / max(cloth_length, 0.001), 0.0, 1.0);
	weight *= weight;
	// Cờ chỉ xoay quanh trục Y, không scale: nghịch đảo = chuyển vị, rẻ hơn inverse()
	vec3 wind_local = transpose(mat3(MODEL_MATRIX)) * normalize(wind_direction);
	// Lệch pha theo vị trí để các lá cờ không bay đồng loạt
	float phase = dot(NODE_POSITION_WORLD.xz, vec2(0.37, 0.21));
	float t = TIME * sway_speed + phase;
	float gust = 0.65 + 0.35 * sin(t * 0.41);
	float ripple = sin(t * 2.0 + VERTEX.y * ripple_frequency + VERTEX.x * 1.3);
	VERTEX += wind_local * sway_amplitude * gust * weight;
	VERTEX += NORMAL * ripple * ripple_amplitude * weight;
}

void fragment() {
	// Giữ màu gốc của model (vertex color), giống material nhập từ GLB
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
}
