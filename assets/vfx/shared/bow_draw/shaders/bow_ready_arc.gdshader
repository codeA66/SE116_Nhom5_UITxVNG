shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Vòng cung sáng màu ấm phía trước ngực khi kéo đầy (tượng trưng cây cung đã căng), nằm ngang theo hướng ngắm.
// Hai đầu cung mờ dần, giữa sáng nhất.
uniform vec4 color : source_color = vec4(1.0, 0.66, 0.2, 1.0);
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
uniform float radius = 0.78;
uniform float thickness = 0.07;
// Nửa góc mở của cung (radian), tính từ hướng ngắm (+Z, UV.y = 1)
uniform float half_angle = 1.15;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = abs(atan(p.x, p.y));
	float band = 1.0 - smoothstep(thickness * 0.4, thickness, abs(r - radius));
	float span = 1.0 - smoothstep(half_angle * 0.7, half_angle, angle);
	float core = 1.0 - smoothstep(0.0, thickness * 0.35, abs(r - radius));
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.5);
	ALPHA = clamp(band * span * opacity, 0.0, 1.0);
}
