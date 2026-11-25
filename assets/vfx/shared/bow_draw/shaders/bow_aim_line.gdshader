shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Vạch ngắm rất mảnh, mờ, kéo dài phía trước mũi tên chỉ hướng; nhạt dần về cuối. Cùng màu với mũi tên.
uniform vec4 draw_color : source_color = vec4(0.3, 0.68, 1.0, 1.0);
uniform vec4 ready_color : source_color = vec4(1.0, 0.66, 0.2, 1.0);
uniform float ready : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float line = 1.0 - smoothstep(0.3, 1.0, x);
	float fade = (1.0 - smoothstep(0.0, 1.0, UV.y)) * smoothstep(0.0, 0.05, UV.y);
	ALBEDO = mix(draw_color.rgb, ready_color.rgb, ready);
	ALPHA = clamp(line * fade * opacity, 0.0, 1.0);
}
