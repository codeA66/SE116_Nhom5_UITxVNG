// Hạt bay theo gió của WindZone (MultiMesh quad, quay mặt về camera): lá xoay lật và hạt li ti.
// INSTANCE_CUSTOM: r, g = vị trí trên mặt cắt; b = pha; a < leaf_fraction là lá, còn lại là hạt.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

uniform vec3 zone_size = vec3(4.0, 3.0, 8.0);
uniform bool updraft = false;
uniform float leaf_fraction = 0.35;
uniform vec4 leaf_color : source_color = vec4(0.95, 0.55, 0.2, 1.0);
uniform vec4 leaf_color_alt : source_color = vec4(0.98, 0.72, 0.3, 1.0);
uniform vec4 vein_color : source_color = vec4(0.7, 0.32, 0.1, 1.0);
uniform vec4 speck_color : source_color = vec4(1.0);
uniform float leaf_size = 0.22;
uniform float speck_size = 0.06;
uniform float opacity = 1.0;
// m/s; hạt chậm hơn nét gió để có chiều sâu
uniform float travel_speed = 6.0;
uniform float flutter = 0.35;
uniform float tumble_speed = 6.0;
// Cột gió: hạt bay vòng quanh trục theo phễu
uniform float funnel_bottom = 0.3;
uniform float funnel_top = 1.0;
uniform float spin_speed = 2.2;

varying float v_alpha;
varying float v_is_leaf;
varying float v_shade;
varying float v_tone;

vec3 mote_center(float p, vec4 c, float time) {
	if (updraft) {
		vec2 half_section = zone_size.xy * 0.5;
		vec2 radius = mix(funnel_bottom, funnel_top, p) * half_section * (0.3 + 0.7 * c.g);
		float angle = c.r * TAU + p * TAU * 1.5 + time * spin_speed;
		return vec3(cos(angle) * radius.x, sin(angle) * radius.y, zone_size.z * (0.5 - p));
	}
	float x = (c.r - 0.5) * zone_size.x * 0.95 + sin(time * 1.7 + c.b * 40.0) * flutter;
	float y = (c.g - 0.5) * zone_size.y * 0.85 + sin(time * 2.3 + c.a * 50.0) * flutter;
	return vec3(x, y, zone_size.z * (0.5 - p));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float speed = travel_speed * (0.75 + 0.5 * c.g);
	float cycle = zone_size.z / max(speed, 0.01);
	float p = fract(TIME / cycle + c.b);
	vec3 view_center = (MODELVIEW_MATRIX * vec4(mote_center(p, c, TIME), 1.0)).xyz;

	v_is_leaf = c.a < leaf_fraction ? 1.0 : 0.0;
	v_tone = c.g;
	float size = mix(speck_size * (0.6 + 0.8 * c.r), leaf_size * (0.75 + 0.5 * c.g), v_is_leaf);
	vec2 corner = VERTEX.xy * size;
	if (v_is_leaf > 0.5) {
		// Lá lật: co bề ngang theo cos, đồng thời xoay quanh trục nhìn
		float flip = cos(TIME * tumble_speed * (0.6 + 0.8 * c.r) + c.b * 20.0);
		corner.x *= max(abs(flip), 0.15);
		v_shade = 0.75 + 0.25 * flip;
		float a = TIME * tumble_speed * 0.5 * (c.g - 0.5) + c.r * TAU;
		corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
	} else {
		v_shade = 1.0;
	}
	VERTEX = view_center + vec3(corner, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_alpha = wind_coverage(p) * smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.88, 1.0, p));
}

void fragment() {
	vec3 color;
	float alpha;
	if (v_is_leaf > 0.5) {
		vec2 leaf = wind_leaf(UV);
		vec3 base = mix(leaf_color.rgb, leaf_color_alt.rgb, v_tone);
		color = mix(base * v_shade, vein_color.rgb, leaf.y * 0.6);
		alpha = leaf.x * leaf_color.a;
	} else {
		color = speck_color.rgb;
		alpha = wind_dot(UV) * speck_color.a;
	}
	ALBEDO = color;
	ALPHA = alpha * v_alpha * opacity;
}
