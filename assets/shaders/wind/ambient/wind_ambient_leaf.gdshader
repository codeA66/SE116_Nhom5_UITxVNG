// Lá / cánh hoa bay theo gió không khí của AmbientWind (MultiMesh quad, quay mặt về camera).
// Cùng cách gói vị trí theo thế giới như wind_ambient_streak: node đi theo player, lá vẫn đứng yên trong thế giới.
// INSTANCE_CUSTOM: r, g = seed vị trí; b = pha; a < petal_fraction là cánh hoa, còn lại là lá.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);
uniform float travel_speed = 5.0;
uniform float coverage_radius = 18.0;
uniform float height_min = 0.3;
uniform float height_max = 3.0;
uniform vec4 leaf_color : source_color = vec4(0.72, 0.6, 0.38, 1.0);
uniform vec4 leaf_color_alt : source_color = vec4(0.6, 0.62, 0.4, 1.0);
uniform vec4 petal_color : source_color = vec4(0.9, 0.8, 0.74, 1.0);
uniform vec4 vein_color : source_color = vec4(0.42, 0.36, 0.24, 1.0);
uniform float petal_fraction = 0.35;
uniform float leaf_size = 0.18;
uniform float opacity = 1.0;
uniform float lifetime = 6.0;
uniform float flutter = 0.5;
uniform float tumble_speed = 5.0;

varying float v_alpha;
varying float v_is_petal;
varying float v_shade;
varying float v_tone;

const float EDGE_FADE_START = 0.7;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float life_time = max(lifetime * (0.75 + 0.5 * c.r), 0.1);
	float cycle = TIME / life_time + c.b;
	float life = fract(cycle);
	float round_index = floor(cycle);
	vec3 dir = wind_direction;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), dir) + vec3(1e-4, 0.0, 0.0));
	float span = coverage_radius * 2.0;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec2 anchor = vec2(wind_hash(c.r * 71.3 + round_index * 1.91), wind_hash(c.g * 43.9 + round_index * 2.57)) * span;
	float speed = travel_speed * (0.7 + 0.6 * c.g);
	vec2 world_xz = anchor + dir.xz * speed * TIME;
	vec2 rel = mod(world_xz - center.xz + coverage_radius, span) - coverage_radius;
	float height = mix(height_min, height_max, wind_hash(c.a * 29.3 + round_index * 4.1));
	// Lá chao lượn: lệch ngang và nhấp nhô chậm hơn vệt gió
	float t = TIME + c.b * 40.0;
	vec3 wobble = side * sin(t * 1.3) * flutter + vec3(0.0, sin(t * 2.1) * flutter * 0.5, 0.0);
	vec3 world_center = vec3(center.x + rel.x, center.y + height, center.z + rel.y) + wobble;
	vec3 view_center = (VIEW_MATRIX * vec4(world_center, 1.0)).xyz;

	v_is_petal = c.a < petal_fraction ? 1.0 : 0.0;
	v_tone = c.g;
	float size = leaf_size * (0.75 + 0.5 * c.r) * mix(1.0, 0.8, v_is_petal);
	vec2 corner = VERTEX.xy * size;
	// Lật: co bề ngang theo cos, đồng thời xoay quanh trục nhìn
	float flip = cos(TIME * tumble_speed * (0.6 + 0.8 * c.r) + c.b * 20.0);
	corner.x *= max(abs(flip), 0.15);
	v_shade = 0.78 + 0.22 * flip;
	float a = TIME * tumble_speed * 0.5 * (c.g - 0.5) + c.r * TAU;
	corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
	VERTEX = view_center + vec3(corner, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);

	float edge = 1.0 - smoothstep(EDGE_FADE_START, 0.95, length(rel) / max(coverage_radius, 0.01));
	v_alpha = edge * smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.85, 1.0, life));
}

void fragment() {
	vec2 leaf = wind_leaf(UV);
	vec3 base = mix(leaf_color.rgb, leaf_color_alt.rgb, v_tone);
	vec3 color;
	if (v_is_petal > 0.5) {
		// Cánh hoa: tròn hơn lá, không gân
		color = petal_color.rgb * v_shade;
		leaf.x = wind_dot(vec2(UV.x * 0.8 + 0.1, UV.y));
	} else {
		color = mix(base * v_shade, vein_color.rgb, leaf.y * 0.5);
	}
	ALBEDO = color;
	ALPHA = leaf.x * v_alpha * opacity * mix(leaf_color.a, petal_color.a, v_is_petal);
}
