// Giọt máu kéo dài theo vận tốc (CPUParticles3D align_y, billboard): tròn ở đầu, nhọn ở đuôi, mép sắc.
// Giọt chạm mặt đất (dưới floor_y) thì bị loại bỏ; vết máu trên sàn do BloodStains vẽ.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.02, 0.04, 1.0);
uniform float floor_y = -1000.0;

varying vec4 v_color;
varying vec2 v_local;
varying float v_below;

void vertex() {
	v_color = COLOR;
	vec3 center = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[1].xyz);
	vec3 axis = MODEL_MATRIX[1].xyz / max(s, 0.00001);
	vec3 view_dir = normalize(INV_VIEW_MATRIX[3].xyz - center);
	vec3 side = cross(axis, view_dir);
	side = side / max(length(side), 0.00001);
	vec3 world = center + axis * VERTEX.y * s + side * VERTEX.x * s;
	v_local = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	v_below = center.y < floor_y ? 1.0 : 0.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	if (v_below > 0.5) {
		discard;
	}
	float along = clamp(v_local.y, 0.0, 1.0);
	float half_w = sqrt(along) * sqrt(max(1.0 - pow(along, 5.0), 0.0));
	half_w = max(half_w, 0.0001);
	float d = abs(v_local.x) / half_w;
	float aa = max(fwidth(d), 0.001);
	float m = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, d);
	// Vệt sáng ướt nhẹ dọc giọt
	float shine = (1.0 - smoothstep(0.0, 0.35, abs(v_local.x - 0.25 * half_w) / half_w)) * 0.25;
	ALBEDO = color.rgb + vec3(shine);
	ALPHA = m * v_color.a;
}
