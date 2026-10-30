// Vòng sóng trắng mảnh nằm ngang (PlaneMesh 1x1): mở rộng nhanh rồi mỏng dần biến mất, mép sắc (fwidth).
// progress 0..1 do script điều khiển (ease-out). Màu trắng, lõi HDR.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity = 2.5;
uniform float progress = 0.0;
uniform float start_radius = 0.1;
uniform float end_radius = 0.97;
// Bề dày vòng lúc đầu (0..1 nửa quad), co về 0 theo progress
uniform float start_width = 0.12;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float radius = mix(start_radius, end_radius, progress);
	float width = start_width * (1.0 - progress);
	float d = abs(r - radius) - width * 0.5;
	float aa = max(fwidth(r), 0.002);
	float m = 1.0 - smoothstep(-aa, aa, d);
	ALBEDO = tint.rgb * intensity;
	ALPHA = clamp(m * step(0.001, width), 0.0, 1.0);
}
