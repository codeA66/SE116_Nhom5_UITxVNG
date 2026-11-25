shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Vòng cung sáng màu ấm phía trước ngực khi kéo đầy (tượng trưng cây cung đã căng), nằm ngang theo hướng ngắm.
// Cùng kiểu nét sáng với mũi tên chỉ hướng: lõi gần trắng + quầng mờ; hai đầu cung nhạt dần.
uniform vec4 color : source_color = vec4(1.0, 0.66, 0.2, 1.0);
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
// Theo tỉ lệ nửa cạnh mesh
uniform float radius = 0.75;
uniform float core_width = 0.05;
uniform float glow_width = 0.1;
// Nửa góc mở của cung (radian), tính từ hướng ngắm (+Z, UV.y = 1)
uniform float half_angle = 1.05;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = abs(length(p) - radius);
	float angle = abs(atan(p.x, p.y));
	float span = 1.0 - smoothstep(half_angle * 0.6, half_angle, angle);
	float core = 1.0 - smoothstep(core_width * 0.5, core_width, d);
	float glow = exp(-d / glow_width) * 0.5;
	ALBEDO = mix(color.rgb, mix(color.rgb, vec3(1.0), 0.6), core);
	ALPHA = clamp(max(core, glow) * span * opacity, 0.0, 1.0);
}
