// Vệt gió không khí của AmbientWind (MultiMesh dải nét, mỗi instance một vệt).
// Vị trí tính theo toạ độ thế giới rồi gói (wrap) quanh tâm node: node đi theo player thì vùng phủ đi theo,
// còn vệt vẫn đứng yên trong thế giới (tương đương local_coords = false), CPU không cập nhật từng vệt.
// Mỗi vệt sống một chu kỳ: vẽ dần từ đuôi lên đầu rồi đuôi đuổi kịp và tan, chu kỳ sau đổi chỗ.
// INSTANCE_CUSTOM: r, g, a = seed vị trí/biến thể (a < curl_fraction là vệt cuộn); b = pha.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

// Hướng gió thế giới, script đã chuẩn hoá
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);
uniform float travel_speed = 9.0;
uniform float coverage_radius = 18.0;
uniform float height_min = 0.6;
uniform float height_max = 3.5;
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform vec4 edge_color : source_color = vec4(0.82, 0.9, 0.97, 0.35);
uniform float opacity = 1.0;
// > 1: đẩy trắng vượt điểm trắng của tonemap AgX, nếu không vệt trông xám hơn sàn được nắng chiếu
uniform float brightness = 1.8;
uniform float width = 0.07;
uniform float stroke_length = 3.5;
uniform float lifetime = 2.2;
uniform float wave_amplitude = 0.25;
uniform float curl_fraction = 0.3;
uniform float curl_radius = 0.45;
uniform float curl_turns = 0.85;

varying float v_alpha;
varying float v_life;

const float CURL_START = 0.62;
// Viền vùng phủ mờ dần từ tỉ lệ này của bán kính, để chỗ wrap không bao giờ thấy được
const float EDGE_FADE_START = 0.7;

vec3 body_point(vec3 head, vec3 dir, vec3 side, float back, vec4 c) {
	vec3 p = head - dir * back;
	p += side * sin(back * 1.3 + c.b * 20.0) * wave_amplitude;
	p.y += sin(back * 0.9 + c.a * 15.0) * wave_amplitude * 0.4;
	return p;
}

// s: 0 = đuôi, 1 = đầu
vec3 streak_point(float s, vec3 head, vec3 dir, vec3 side, float len, vec4 c) {
	if (c.a >= curl_fraction || s <= CURL_START) {
		return body_point(head, dir, side, (1.0 - s) * len, c);
	}
	// Đầu vệt cuộn vòng: mặt phẳng cuộn nghiêng giữa trục đứng và trục ngang để nhìn từ trên vẫn thấy vòng
	vec3 base = body_point(head, dir, side, (1.0 - CURL_START) * len, c);
	float k = (s - CURL_START) / (1.0 - CURL_START);
	float angle = k * curl_turns * TAU;
	float radius = curl_radius * (0.7 + 0.6 * c.g);
	vec3 lift = normalize(vec3(0.0, 0.6, 0.0) + side * 0.8 * sign(c.r - 0.5));
	return base + dir * sin(angle) * radius + lift * (1.0 - cos(angle)) * radius;
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float life_time = max(lifetime * (0.75 + 0.5 * c.g), 0.05);
	float cycle = TIME / life_time + c.b;
	float life = fract(cycle);
	float round_index = floor(cycle);
	vec3 dir = wind_direction;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), dir) + vec3(1e-4, 0.0, 0.0));
	float span = coverage_radius * 2.0;
	vec3 center = MODEL_MATRIX[3].xyz;
	// Chỗ xuất hiện đổi theo mỗi chu kỳ sống, cố định trong thế giới
	vec2 anchor = vec2(wind_hash(c.r * 91.7 + round_index * 1.37), wind_hash(c.g * 57.3 + round_index * 2.11)) * span;
	float speed = travel_speed * (0.8 + 0.4 * c.g);
	vec3 drift = dir * speed * TIME;
	vec2 world_xz = anchor + drift.xz;
	vec2 rel = mod(world_xz - center.xz + coverage_radius, span) - coverage_radius;
	float height = mix(height_min, height_max, wind_hash(c.a * 33.1 + round_index * 3.7));
	vec3 head = vec3(center.x + rel.x, center.y + height, center.z + rel.y);

	float len = stroke_length * (0.7 + 0.6 * c.a);
	float s = UV.x;
	float ds = 0.02;
	vec3 point = streak_point(s, head, dir, side, len, c);
	vec3 next = s + ds <= 1.0 ? streak_point(s + ds, head, dir, side, len, c) : point * 2.0 - streak_point(s - ds, head, dir, side, len, c);
	vec3 view_point = (VIEW_MATRIX * vec4(point, 1.0)).xyz;
	vec3 view_next = (VIEW_MATRIX * vec4(next, 1.0)).xyz;
	float half_width = width * 0.5 * mix(0.2, 1.0, smoothstep(0.0, 0.7, s)) * (0.75 + 0.5 * c.g);
	VERTEX = view_point + wind_ribbon_side(view_point, view_next) * half_width * (UV.y * 2.0 - 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);

	float edge = 1.0 - smoothstep(EDGE_FADE_START, 0.95, length(rel) / max(coverage_radius, 0.01));
	v_alpha = edge;
	v_life = life;
}

void fragment() {
	// Đầu vệt lộ dần trong nửa đầu chu kỳ, đuôi rút theo trong nửa sau
	float reveal = smoothstep(0.0, 0.55, v_life);
	float retract = smoothstep(0.45, 1.0, v_life);
	float shown = smoothstep(retract, retract + 0.12, UV.x) * (1.0 - smoothstep(reveal - 0.12, reveal, UV.x));
	float body = wind_stroke_body(UV.y);
	float core = wind_stroke_core(UV.y);
	ALBEDO = mix(edge_color.rgb, core_color.rgb, core) * brightness;
	ALPHA = body * shown * v_alpha * opacity * mix(edge_color.a, core_color.a, core);
}
