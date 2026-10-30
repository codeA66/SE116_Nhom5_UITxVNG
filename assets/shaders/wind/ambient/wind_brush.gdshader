// Nét gió của WindZone (MultiMesh, mỗi instance là một nét).
// Gió ngang: nét dài chạy từ mặt vào tới mặt ra, một phần nét cuộn vòng ở đầu.
// Cột gió: nét xoắn ốc đi lên, nhanh dần, loe ra ở đỉnh như phễu.
// INSTANCE_CUSTOM: r, g = vị trí ngẫu nhiên trên mặt cắt; b = pha; a = biến thể (độ dài, cuộn).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

uniform vec3 zone_size = vec3(4.0, 3.0, 8.0);
uniform bool updraft = false;
uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float opacity = 1.0;
uniform float width = 0.06;
// m/s, tốc độ đầu nét chạy dọc vùng
uniform float travel_speed = 10.0;
// Chiều dài nét tính theo tỉ lệ chiều dài vùng
uniform float stroke_length = 0.3;
uniform float length_variation = 0.5;
uniform float wave_amplitude = 0.05;
// Gió ngang: tỉ lệ nét có cuộn, bán kính và số vòng cuộn
uniform float curl_fraction = 0.22;
uniform float curl_radius = 0.35;
uniform float curl_turns = 0.85;
// Cột gió: bán kính đáy/đỉnh theo nửa tiết diện, số vòng xoắn dọc thân, tốc độ xoay
uniform float funnel_bottom = 0.3;
uniform float funnel_top = 1.0;
uniform float twist_turns = 1.1;
uniform float spin_speed = 2.2;
// > 1: đi lên chậm ở đáy và nhanh dần về đỉnh
uniform float rise_acceleration = 1.5;

varying float v_alpha;

const float CURL_START = 0.62;

float stroke_len(vec4 c) {
	return stroke_length * (1.0 - length_variation * 0.5 + length_variation * c.a);
}

// Tiến độ đầu nét dọc vùng: đi hết vùng rồi ra hẳn mới quay lại, không nhảy giữa chừng
float head_progress(vec4 c, float time) {
	float span = 1.0 + stroke_len(c);
	float cycle = zone_size.z * span / max(travel_speed, 0.01);
	return fract(time / cycle + c.b) * span;
}

vec3 gust_point(float p, vec4 c) {
	float x = (c.r - 0.5) * zone_size.x * 0.95;
	float y = (c.g - 0.5) * zone_size.y * 0.85;
	y += sin(p * 5.0 + c.b * 31.0) * wave_amplitude * zone_size.y;
	x += sin(p * 3.0 + c.a * 17.0) * wave_amplitude * zone_size.x * 0.5;
	return vec3(x, y, zone_size.z * (0.5 - p));
}

vec3 updraft_point(float p, vec4 c, float time) {
	float t = pow(clamp(p, 0.0, 1.0), rise_acceleration);
	// Tiết diện elip theo đúng X, Y của vùng: hình khớp khung collider ở mọi kích thước
	vec2 half_section = zone_size.xy * 0.5;
	vec2 radius = mix(funnel_bottom, funnel_top, pow(t, 1.3)) * half_section * (0.75 + 0.25 * c.g);
	float angle = c.r * TAU + t * twist_turns * TAU + time * spin_speed * (0.8 + 0.4 * c.a);
	return vec3(cos(angle) * radius.x, sin(angle) * radius.y, zone_size.z * (0.5 - t));
}

// s: 0 = đuôi nét, 1 = đầu nét
vec3 stroke_point(float s, float head, float len, vec4 c, float time) {
	float p = head - (1.0 - s) * len;
	if (updraft) {
		return updraft_point(p, c, time);
	}
	if (c.a >= curl_fraction || s <= CURL_START) {
		return gust_point(p, c);
	}
	// Phần đầu nét cuộn vòng lên rồi ngược lại, như nét gió vẽ tay
	float k = (s - CURL_START) / (1.0 - CURL_START);
	float angle = k * curl_turns * TAU;
	float radius = curl_radius * (0.7 + 0.6 * c.g);
	vec3 base = gust_point(head - (1.0 - CURL_START) * len, c);
	return base + vec3(0.0, (1.0 - cos(angle)) * radius, -sin(angle) * radius);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float len = stroke_len(c);
	float head = head_progress(c, TIME);
	float s = UV.x;
	float ds = 0.02;
	vec3 point = stroke_point(s, head, len, c, TIME);
	vec3 next;
	if (s + ds <= 1.0) {
		next = stroke_point(s + ds, head, len, c, TIME);
	} else {
		next = point * 2.0 - stroke_point(s - ds, head, len, c, TIME);
	}
	vec3 view_point = (MODELVIEW_MATRIX * vec4(point, 1.0)).xyz;
	vec3 view_next = (MODELVIEW_MATRIX * vec4(next, 1.0)).xyz;
	// Đầu dày, đuôi vuốt nhọn
	float half_width = width * 0.5 * mix(0.15, 1.0, smoothstep(0.0, 0.75, s)) * (0.75 + 0.5 * c.g);
	VERTEX = view_point + wind_ribbon_side(view_point, view_next) * half_width * (UV.y * 2.0 - 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);

	float p = head - (1.0 - s) * len;
	float edges = smoothstep(0.0, 0.06, p) * (1.0 - smoothstep(0.92, 1.0, p));
	v_alpha = wind_coverage(clamp(p, 0.0, 1.0)) * edges;
}

void fragment() {
	float body = wind_stroke_body(UV.y);
	float core = wind_stroke_core(UV.y);
	// Đuôi mờ dần, đầu sáng nhất
	float along = smoothstep(0.0, 0.55, UV.x) * (1.0 - smoothstep(0.985, 1.0, UV.x));
	float head_glow = smoothstep(0.7, 1.0, UV.x);
	ALBEDO = mix(edge_color.rgb, core_color.rgb, clamp(core + head_glow * 0.5, 0.0, 1.0));
	ALPHA = body * along * v_alpha * opacity * mix(edge_color.a, core_color.a, core);
}
