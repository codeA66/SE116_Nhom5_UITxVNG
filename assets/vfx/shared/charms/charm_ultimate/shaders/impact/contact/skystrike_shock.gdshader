shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Sóng xung kích hai lớp: mép sắc sáng chạy đúng tới bán kính sát thương + dải mềm kéo phía sau.
// Mép sắc đọc rõ phạm vi đòn; dải mềm cho cảm giác áp lực lan ra.
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float front = 0.06;
uniform float band_width = 0.21;
// Độ dày mép sắc (theo tỉ lệ bán kính hiện tại) và độ sáng phần kéo phía sau
uniform float crest_width = 0.035;
uniform float wake_strength = 0.35;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ratio = r / max(front, 0.001);
	vec4 grain = texture(mask, 0.5 + p * (0.43 / max(front, 0.001)));
	float thickness = band_width * mix(0.67, 1.0, grain.a);
	float band = smoothstep(1.0 - thickness, 1.0 - thickness * 0.5, ratio);
	// Chặn ngay mép bán kính để hình khớp vùng sát thương.
	float inside = 1.0 - smoothstep(0.985, 1.0, ratio);
	float crest = smoothstep(1.0 - crest_width * 2.0, 1.0 - crest_width * 0.5, ratio) * inside;
	float wake = smoothstep(0.25, 1.0 - thickness, ratio) * (1.0 - smoothstep(1.0 - thickness, 1.0, ratio)) * wake_strength;
	ALBEDO = mix(tint.rgb, edge_color.rgb, crest);
	ALPHA = clamp((band * inside * mix(0.55, 0.9, grain.a) + crest * 1.2 + wake * grain.a) * opacity, 0.0, 1.0);
}
