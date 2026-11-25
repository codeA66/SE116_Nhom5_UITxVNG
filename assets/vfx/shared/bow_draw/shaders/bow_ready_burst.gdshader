shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Lớp 2 - vòng sáng bung ra trên sàn đúng lúc kéo đầy: một nhịp, mép sắc, tắt dần khi to ra.
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float front : hint_range(0.0, 1.0) = 0.3;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
uniform float width = 0.08;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring = 1.0 - smoothstep(0.0, width, abs(r - front));
	float inner_glow = (1.0 - smoothstep(0.0, front, r)) * 0.15;
	ALBEDO = color.rgb;
	ALPHA = clamp((ring + inner_glow) * opacity, 0.0, 1.0);
}
