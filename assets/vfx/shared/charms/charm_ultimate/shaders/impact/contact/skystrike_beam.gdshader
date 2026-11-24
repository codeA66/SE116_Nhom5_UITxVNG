shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Cột sáng đứng tại điểm chạm, vài khung đầu cú nổ: cho cú đập có chiều đứng khi nhìn từ camera cao.
// Lõi giữa trắng, hai bên vàng cam; đáy sáng nhất, mờ dần lên trên.
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float opacity = 1.0;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float height = 1.0 - UV.y;
	float body = 1.0 - smoothstep(0.15, 1.0, x);
	float core = 1.0 - smoothstep(0.0, 0.28, x);
	float fade = (1.0 - smoothstep(0.35, 1.0, height)) * smoothstep(0.0, 0.03, height);
	ALBEDO = mix(tint.rgb, core_color.rgb, core);
	ALPHA = clamp((body * 0.6 + core) * fade * opacity, 0.0, 1.0);
}
