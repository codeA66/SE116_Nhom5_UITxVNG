// Vòng bụi sát đất dưới chân lốc xoáy (PlaneMesh 1x1): vòng tròn sắc mép mở rộng theo spread,
// kèm vài vệt cong chạy quanh theo chiều xoáy. Viền xanh đậm + lõi trắng giống dải lốc.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.16, 0.42, 0.62, 1.0);
uniform float core_intensity = 1.5;
// 0..1: bán kính vòng so với nửa quad
uniform float spread : hint_range(0.0, 1.0) = 0.5;
// Bề dày vòng (0..1 nửa quad), teo về 0 khi tan
uniform float thickness : hint_range(0.0, 0.5) = 0.09;
uniform float spin_speed = 2.6;
// Số vệt cong quanh vòng
uniform float streaks = 5.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x) / TAU + 0.5;
	// Vệt cong: vòng bị cắt thành các đoạn quay theo chiều xoáy
	float seg = fract(angle * streaks + TIME * spin_speed);
	float gap = smoothstep(0.62, 0.7, seg);
	float half_width = thickness * (1.0 - gap);
	float d = abs(r - spread);
	float aa = max(fwidth(r), 0.002);
	float body = 1.0 - smoothstep(half_width - aa, half_width + aa, d);
	if (body <= 0.001) {
		discard;
	}
	float core = 1.0 - smoothstep(half_width * 0.55 - aa, half_width * 0.55 + aa, d);
	ALBEDO = mix(edge_color.rgb, core_color.rgb * core_intensity, core);
	ALPHA = body;
}
