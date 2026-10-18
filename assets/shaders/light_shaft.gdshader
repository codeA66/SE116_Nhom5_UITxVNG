// Cột nắng giả (god ray) cho LightShaft: mỗi dải là một quad dọc trục nắng, tự quay mặt về camera quanh trục.
// Cộng sáng (blend_add), không ghi depth, không đổ bóng: rẻ, không che vật phía sau.
// Mesh chỉ chứa điểm trên trục: VERTEX = điểm trục, UV.x = ngang dải (0..1), UV.y = 0 đỉnh .. 1 chân,
// UV2.x = nửa bề rộng tại đỉnh/chân (m), UV2.y = chiều dài dải (m), COLOR.r = độ sáng riêng, COLOR.a = seed.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind_flow.gdshaderinc"

// Hướng trục nắng (đỉnh -> chân) trong không gian của node, script tính từ góc nghiêng
uniform vec3 axis_direction = vec3(0.0, -1.0, 0.0);
uniform vec4 shaft_color : source_color = vec4(1.0, 0.9, 0.68, 1.0);
uniform float intensity = 0.14;
// 0 = mép cứng, 1 = mờ từ tim ra mép
uniform float edge_softness = 0.6;
uniform float top_fade = 0.35;
uniform float bottom_fade = 0.12;
uniform float ripple_speed = 0.25;
uniform float ripple_strength = 0.35;
// Kích thước một gợn theo chiều dài dải (m)
uniform float ripple_scale = 2.5;
uniform float dust_density = 0.25;
uniform float dust_size = 0.06;
uniform float dust_speed = 0.15;
uniform float dust_brightness = 1.6;
// Camera lại gần hơn near_fade_end thì mờ dần, tới near_fade_start thì tắt hẳn
uniform float near_fade_start = 3.0;
uniform float near_fade_end = 8.0;

varying float v_fade;
varying float v_length;
varying float v_width;
varying float v_brightness;
varying float v_seed;

void vertex() {
	vec3 view_point = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_axis = (MODELVIEW_MATRIX * vec4(axis_direction, 0.0)).xyz;
	vec3 side = cross(normalize(view_axis), normalize(-view_point));
	// Nhìn dọc trục thì cross suy biến: chọn tạm trục X của view
	side = dot(side, side) < 1e-8 ? vec3(1.0, 0.0, 0.0) : normalize(side);
	VERTEX = view_point + side * UV2.x * (UV.x * 2.0 - 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	float denominator = max(near_fade_end - near_fade_start, 0.001);
	v_fade = clamp((-view_point.z - near_fade_start) / denominator, 0.0, 1.0);
	v_length = UV2.y;
	v_width = UV2.x * 2.0;
	v_brightness = COLOR.r;
	v_seed = COLOR.a;
}

float dust_sparkle(vec2 meters, float time) {
	// Lưới ô 0.5 m: mỗi ô tối đa một hạt, ô bị loại theo mật độ
	vec2 q = meters * 2.0 + vec2(0.0, -time * dust_speed * 2.0);
	vec2 cell = floor(q);
	vec2 local = fract(q);
	float h = wind_hash(dot(cell, vec2(1.0, 113.0)) + v_seed * 71.0);
	if (h > dust_density) {
		return 0.0;
	}
	vec2 spot = vec2(wind_hash(h * 37.0), wind_hash(h * 91.0)) * 0.6 + 0.2;
	float d = length(local - spot) * 0.5;
	float aa = max(fwidth(d), 0.0001);
	float dot_mask = 1.0 - smoothstep(dust_size - aa, dust_size + aa, d);
	float twinkle = 0.5 + 0.5 * sin(time * 2.7 + h * 60.0);
	return dot_mask * twinkle * twinkle;
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(1.0 - clamp(edge_softness, 0.02, 1.0), 1.0, across);
	float along = smoothstep(0.0, max(top_fade, 0.001), UV.y) * (1.0 - smoothstep(1.0 - max(bottom_fade, 0.001), 1.0, UV.y));
	// Gợn trôi xuống chậm theo trục nắng
	vec2 ripple_uv = vec2(UV.x * 1.5 + v_seed * 13.0, UV.y * v_length / max(ripple_scale, 0.01) - TIME * ripple_speed);
	float ripple = wind_value_noise(ripple_uv) * 0.65 + wind_value_noise(ripple_uv * 2.3 + 5.1) * 0.35;
	float bands = mix(1.0, ripple * 1.4, clamp(ripple_strength, 0.0, 1.0));
	float body = edge * along * bands;
	float dust = dust_sparkle(vec2(UV.x * v_width, UV.y * v_length), TIME) * edge * along;
	float total = (body + dust * dust_brightness) * v_brightness * v_fade;
	ALBEDO = shaft_color.rgb * intensity * total;
	ALPHA = clamp(shaft_color.a, 0.0, 1.0);
}
