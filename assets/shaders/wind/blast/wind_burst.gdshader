// Hiệu ứng một lần của kỹ năng gió (cú thổi, bụi khi trúng, lúc gồng). Mọi thứ chạy theo uniform age.
// Hệ tọa độ: gốc ở chân người thổi, hướng thổi là +Z cục bộ.
// kind 0: nét gió (bắn về phía trước trong hình nón + nét tỏa sát đất), một phần cuộn ở đầu.
// kind 1: hạt văng (lá + hạt li ti). kind 2: vòng sóng sát đất. kind 3: nét xoáy hút vào lúc gồng.
// INSTANCE_CUSTOM: r = góc; g = quãng/tốc độ; b = độ cao; a = biến thể.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

uniform int kind = 0;
uniform float age = 0.0;
uniform float duration = 0.45;
uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float opacity = 1.0;

uniform float reach = 5.0;
// Nửa góc hình nón (radian); PI = tỏa đều mọi hướng
uniform float cone_half_angle = 0.5;
uniform float shot_height = 0.9;
uniform float height_spread = 1.2;
uniform float width = 0.07;
uniform float stroke_length = 1.6;
// Tỉ lệ nét tỏa sát đất (vòng quanh chân) và nét có cuộn ở đầu
uniform float ground_fraction = 0.4;
uniform float ground_reach = 1.8;
uniform float curl_fraction = 0.15;
uniform float curl_radius = 0.3;
uniform float curl_turns = 0.85;

uniform float leaf_fraction = 0.3;
uniform vec4 leaf_color : source_color = vec4(0.95, 0.55, 0.2, 1.0);
uniform vec4 leaf_color_alt : source_color = vec4(0.98, 0.72, 0.3, 1.0);
uniform vec4 vein_color : source_color = vec4(0.7, 0.32, 0.1, 1.0);
uniform float leaf_size = 0.22;
uniform float speck_size = 0.06;
uniform float mote_reach = 0.8;
uniform float mote_lift = 0.8;

uniform float ring_radius = 2.2;
uniform float ring_width = 0.06;

uniform float charge_radius = 1.3;

varying float v_alpha;
varying float v_is_leaf;
varying float v_tone;
varying float v_shade;
varying vec2 v_local;

const float CURL_START = 0.62;

float ease_out(float t, float power) {
	return 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), power);
}

bool is_ground(vec4 c) {
	return c.a < ground_fraction;
}

vec3 burst_point(float s, float t, vec4 c) {
	bool ground = is_ground(c);
	float angle = ground ? c.r * TAU : (c.r * 2.0 - 1.0) * cone_half_angle;
	vec3 dir = vec3(sin(angle), 0.0, cos(angle));
	float max_dist = ground ? ground_reach : reach;
	float travel = max_dist * ease_out(t, 3.0) * (0.55 + 0.45 * c.g);
	float len = (ground ? stroke_length * 0.45 : stroke_length) * (0.7 + 0.6 * c.g);
	float start = ground ? 0.35 : 0.3;
	float y = ground ? 0.08 + c.b * 0.1 : shot_height + (c.b - 0.5) * height_spread;
	bool curls = !ground && c.a > 1.0 - curl_fraction;
	float s_line = curls ? min(s, CURL_START) : s;
	float dist = max(travel - (1.0 - s_line) * len, start);
	vec3 point = dir * dist + vec3(0.0, y + sin(dist / max(max_dist, 0.01) * PI) * 0.15 * (c.g - 0.5), 0.0);
	if (curls && s > CURL_START) {
		float k = (s - CURL_START) / (1.0 - CURL_START);
		float a = k * curl_turns * TAU;
		point += dir * sin(a) * curl_radius + vec3(0.0, (1.0 - cos(a)) * curl_radius, 0.0);
	}
	return point;
}

vec3 charge_point(float s, float t, vec4 c) {
	float radius = mix(charge_radius, 0.25, pow(t, 0.8)) * (0.8 + 0.4 * c.g);
	// Nét là một cung tròn quanh người, xoay nhanh dần khi hút vào
	float angle = c.r * TAU + t * TAU * 1.4 + s * 1.6;
	float y = 0.35 + c.b * 1.3;
	return vec3(cos(angle) * radius, y, sin(angle) * radius);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float t = clamp(age / max(duration, 0.001), 0.0, 1.0);
	v_is_leaf = 0.0;
	v_tone = c.g;
	v_shade = 1.0;
	v_local = VERTEX.xz;
	if (kind == 0 || kind == 3) {
		float s = UV.x;
		float ds = 0.02;
		vec3 point;
		vec3 next;
		if (kind == 0) {
			point = burst_point(s, t, c);
			next = s + ds <= 1.0 ? burst_point(s + ds, t, c) : point * 2.0 - burst_point(s - ds, t, c);
		} else {
			point = charge_point(s, t, c);
			next = s + ds <= 1.0 ? charge_point(s + ds, t, c) : point * 2.0 - charge_point(s - ds, t, c);
		}
		float half_width = width * 0.5 * mix(0.15, 1.0, smoothstep(0.0, 0.75, s)) * (0.75 + 0.5 * c.g);
		vec3 view_point = (MODELVIEW_MATRIX * vec4(point, 1.0)).xyz;
		vec3 view_next = (MODELVIEW_MATRIX * vec4(next, 1.0)).xyz;
		VERTEX = view_point + wind_ribbon_side(view_point, view_next) * half_width * (UV.y * 2.0 - 1.0);
		if (kind == 0) {
			v_alpha = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.5, 1.0, t));
		} else {
			v_alpha = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.85, 1.0, t));
		}
	} else if (kind == 1) {
		float angle = (c.r * 2.0 - 1.0) * cone_half_angle;
		vec3 dir = vec3(sin(angle), 0.0, cos(angle));
		float dist = reach * mote_reach * ease_out(t, 2.0) * (0.35 + 0.65 * c.g);
		float y = shot_height * (0.3 + c.b) + mote_lift * sin(t * PI) * c.a;
		vec3 center = dir * (0.3 + dist) + vec3(0.0, y, 0.0);
		vec3 view_center = (MODELVIEW_MATRIX * vec4(center, 1.0)).xyz;
		v_is_leaf = c.a < leaf_fraction ? 1.0 : 0.0;
		float size = mix(speck_size * (0.6 + 0.8 * c.r), leaf_size * (0.75 + 0.5 * c.g), v_is_leaf);
		vec2 corner = VERTEX.xy * size;
		if (v_is_leaf > 0.5) {
			float flip = cos(age * 14.0 * (0.6 + 0.8 * c.r) + c.b * 20.0);
			corner.x *= max(abs(flip), 0.15);
			v_shade = 0.75 + 0.25 * flip;
			float a = age * 8.0 * (c.g - 0.5) + c.r * TAU;
			corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
		}
		VERTEX = view_center + vec3(corner, 0.0);
		v_alpha = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.6, 1.0, t));
	} else {
		float radius = ring_radius * ease_out(t, 3.0);
		vec3 local = vec3(VERTEX.x * radius * 2.0, 0.04, VERTEX.z * radius * 2.0);
		VERTEX = (MODELVIEW_MATRIX * vec4(local, 1.0)).xyz;
		v_alpha = 1.0 - smoothstep(0.35, 1.0, t);
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec3 color;
	float alpha;
	if (kind == 0 || kind == 3) {
		float core = wind_stroke_core(UV.y);
		float along = smoothstep(0.0, 0.55, UV.x) * (1.0 - smoothstep(0.985, 1.0, UV.x));
		color = mix(edge_color.rgb, core_color.rgb, clamp(core + smoothstep(0.7, 1.0, UV.x) * 0.5, 0.0, 1.0));
		alpha = wind_stroke_body(UV.y) * along * mix(edge_color.a, core_color.a, core);
	} else if (kind == 1) {
		if (v_is_leaf > 0.5) {
			vec2 leaf = wind_leaf(UV);
			vec3 base = mix(leaf_color.rgb, leaf_color_alt.rgb, v_tone);
			color = mix(base * v_shade, vein_color.rgb, leaf.y * 0.6);
			alpha = leaf.x * leaf_color.a;
		} else {
			color = core_color.rgb;
			alpha = wind_dot(UV);
		}
	} else {
		// Vòng sóng: viền sắc, đứt quãng theo góc để không giống vòng nhựa
		float r = length(v_local) * 2.0;
		float aa = max(fwidth(r), 0.0001);
		float band = 1.0 - smoothstep(ring_width - aa, ring_width + aa, abs(r - 0.94));
		float angle = atan(v_local.y, v_local.x);
		float breakup = step(0.25, wind_value_noise(vec2(angle * 3.0, 0.0) + 5.0));
		float inner = (1.0 - smoothstep(0.5, 0.94, r)) * smoothstep(0.6, 0.94, r) * 0.25;
		color = core_color.rgb;
		alpha = (band * breakup + inner) * step(r, 1.0);
	}
	ALBEDO = color;
	ALPHA = alpha * v_alpha * opacity;
}
