// Nước stylized: sát bờ xanh ngọc sáng và trong (thấy chân vật chìm), ra xa xanh đậm;
// bọt trắng quanh bờ / vật có mép tơi, thêm một vệt bọt mảnh cách bờ; mặt nước phẳng màu với mảng sáng nhẹ.
// Mặt nước nhấp nhô bằng đỉnh mesh theo water_waves.gdshaderinc (cùng công thức với Water.get_height_at()).
// Mesh là PlaneMesh chia lưới, node Water không được xoay hay scale (sóng tính theo tọa độ thế giới).
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, shadows_disabled;

#include "res://assets/shaders/water_waves.gdshaderinc"

uniform vec4 shallow_color : source_color = vec4(0.3, 0.88, 0.85, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.38, 0.72, 1.0);
uniform vec4 crest_color : source_color = vec4(0.55, 0.92, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 1.0, 1.0, 1.0);
// Độ trong: sát bờ nhìn xuyên được, nước sâu gần như đặc
uniform float shallow_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float deep_opacity : hint_range(0.0, 1.0) = 0.97;

uniform bool use_depth = true;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform float depth_fade_distance = 2.5;
// Dải bọt sát bờ (m) và vệt bọt mảnh thứ hai cách bờ (m)
uniform float foam_width = 0.45;
uniform float foam_line_distance = 0.9;
uniform float foam_line_width = 0.12;
// Kích thước hạt làm mép bọt tơi ra (m)
uniform float foam_noise_scale = 0.35;
uniform float foam_speed = 0.4;
// Kích thước tấm nước (m) để tính bọt ở mép tấm (giáp vách)
uniform vec2 plane_size = vec2(8.0, 30.0);
uniform float edge_foam_width = 0.3;

// Mảng sáng nhẹ trôi trên mặt nước
uniform float patch_scale = 5.0;
uniform float patch_opacity = 0.12;
uniform float sparkle_density = 0.015;
// Tổng biên độ sóng, để chuẩn hóa độ cao khi làm sáng đỉnh sóng
uniform float wave_amplitude_sum = 0.15;

varying vec2 v_world_xz;
varying float v_height;

void vertex() {
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 wave = water_surface(world_xz);
	VERTEX.y += wave.x;
	NORMAL = normalize(vec3(-wave.y, 1.0, -wave.z));
	v_world_xz = world_xz;
	v_height = wave.x;
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return value_noise(p) * 0.6 + value_noise(p * 2.3 + 7.1) * 0.3 + value_noise(p * 5.1 + 3.3) * 0.1;
}

float crisp_step(float edge, float x) {
	float aa = max(fwidth(x), 0.0001);
	return smoothstep(edge - aa, edge + aa, x);
}

void fragment() {
	// Độ sâu nước tại điểm này: khoảng cách từ mặt nước tới vật phía sau (đáy, bờ, chân vật)
	float water_depth = depth_fade_distance;
	if (use_depth) {
		float raw = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float scene_distance = -view.z / view.w;
		water_depth = max(scene_distance - (-VERTEX.z), 0.0);
	}
	// Khoảng cách tới mép tấm nước (vách thẳng đứng không luôn đọc được độ sâu): coi như bờ
	vec2 to_edge = min(UV, 1.0 - UV) * plane_size;
	float shore_distance = min(water_depth, min(to_edge.x, to_edge.y) / max(edge_foam_width, 0.01) * foam_width);

	float deep = smoothstep(0.0, max(depth_fade_distance, 0.01), shore_distance);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, deep);
	float alpha = mix(shallow_opacity, deep_opacity, deep);

	// Mảng sáng trôi rất nhẹ và đỉnh sóng sáng hơn chút
	float patch = fbm(v_world_xz / max(patch_scale, 0.01) + vec2(wave_time * 0.05, wave_time * 0.03));
	color = mix(color, crest_color.rgb, smoothstep(0.55, 0.8, patch) * patch_opacity);
	float crest = clamp(v_height / max(wave_amplitude_sum, 0.001) * 0.5 + 0.5, 0.0, 1.0);
	color = mix(color, crest_color.rgb, smoothstep(0.7, 1.0, crest) * 0.25);

	// Bọt: dải sát bờ có mép tơi + vệt mảnh thứ hai cách bờ, cả hai lay nhẹ theo thời gian
	vec2 foam_uv = v_world_xz / max(foam_noise_scale, 0.01);
	float wobble = fbm(foam_uv + vec2(wave_time * foam_speed, -wave_time * foam_speed * 0.7));
	float band = 1.0 - crisp_step(foam_width * (0.55 + 0.6 * wobble), shore_distance);
	float pulse = 0.5 + 0.5 * sin(wave_time * 1.3);
	float line_center = foam_line_distance + pulse * 0.15;
	float line = 1.0 - crisp_step(foam_line_width * (0.4 + 0.8 * wobble), abs(shore_distance - line_center));
	line *= crisp_step(0.45, fbm(foam_uv * 0.6 + 11.0));
	// Đốm lấp lánh nhỏ trên nước sâu
	float sparkle = crisp_step(1.0 - sparkle_density, value_noise(v_world_xz * 3.0 + wave_time * 0.6)) * deep;
	float foam = max(max(band, line * 0.9), sparkle * 0.7);
	color = mix(color, foam_color.rgb, foam);

	ALBEDO = color;
	ALPHA = mix(alpha, 1.0, foam);
}
