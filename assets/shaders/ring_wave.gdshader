// Vòng sóng mở rộng + lóe lõi (QuadMesh). progress 0..1 do script tween (ease-out), không tính trong shader mỗi lần.
// billboard = true: quay mặt camera (vòng trúng đòn); false: nằm ngang trên mặt đất (vòng chết).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float intensity = 3.0;
uniform float progress = 0.0;
uniform bool billboard = true;
// Bán kính vòng lúc đầu / cuối (0..1 nửa quad)
uniform float start_radius = 0.08;
uniform float end_radius = 0.95;
uniform float start_width = 0.2;
uniform float end_width = 0.035;
// Độ sáng của lõi lóe giữa vòng (0 = không lóe)
uniform float flash_strength = 1.2;
// Làm vòng đứt đoạn như tia (0 = vòng liền)
uniform float break_up = 0.35;
uniform float seed = 0.0;

void vertex() {
	if (billboard) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float radius = mix(start_radius, end_radius, progress);
	float width = mix(start_width, end_width, progress);
	float x = (r - radius) / max(width, 0.0001);
	float ring = exp(-x * x);
	float ang = atan(p.y, p.x);
	float broken = 0.5 + 0.5 * sin(ang * 3.0 + seed) * sin(ang * 5.0 - seed * 1.7 + 1.3);
	ring *= 1.0 - break_up * broken;
	float fade = pow(1.0 - progress, 1.5);
	float flash = exp(-r * r * 16.0) * pow(1.0 - progress, 3.0) * flash_strength;
	float edge_cut = 1.0 - smoothstep(0.85, 1.0, r);
	vec3 col = mix(tint.rgb, vec3(1.0), clamp(flash + ring * 0.25, 0.0, 1.0)) * intensity;
	ALBEDO = col;
	ALPHA = clamp((ring * fade + flash) * edge_cut, 0.0, 1.0);
}
