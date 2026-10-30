// Hậu kỳ toàn màn hình cho từng khu: chỉnh màu theo độ sáng (vùng tối ngả lạnh, vùng sáng ngả ấm),
// tăng tương phản nhẹ, và vignette tối 4 góc để dẫn mắt vào giữa. Đặt trong CanvasLayer dưới HUD
// nên chỉ ảnh hưởng cảnh 3D. Compatibility không có color grading sẵn nên làm bằng screen texture.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Màu pha vào vùng tối / vùng sáng
uniform vec4 shadow_tint : source_color = vec4(0.32, 0.30, 0.55, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.12;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.16;
// > 1: tăng tương phản quanh mức xám 0.5
uniform float contrast : hint_range(0.5, 2.0) = 1.12;
uniform float saturation : hint_range(0.0, 2.0) = 1.15;
// Vignette: màu, độ đậm, bán kính bắt đầu tối và độ mềm
uniform vec4 vignette_color : source_color = vec4(0.08, 0.05, 0.12, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.55;
uniform float vignette_softness : hint_range(0.01, 1.5) = 0.6;
// Vùng sáng quanh player (kiểu Death's Door): tâm theo vị trí player trên màn hình (script cập nhật),
// ra ngoài bán kính thì tối dần về focus_color. Bán kính tính theo chiều cao màn hình
uniform vec2 focus_uv = vec2(0.5, 0.5);
uniform vec4 focus_color : source_color = vec4(0.05, 0.03, 0.09, 1.0);
uniform float focus_strength : hint_range(0.0, 1.0) = 0.35;
uniform float focus_radius : hint_range(0.0, 2.0) = 0.5;
uniform float focus_softness : hint_range(0.01, 2.0) = 0.7;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	// Tách vùng theo độ sáng rồi pha màu: không đổi độ sáng tổng, chỉ đổi sắc
	col = mix(col, col * shadow_tint.rgb * 1.6, shadow_strength * (1.0 - smoothstep(0.0, 0.55, luma)));
	col = mix(col, col * highlight_tint.rgb * 1.15, highlight_strength * smoothstep(0.45, 1.0, luma));
	col = (col - 0.5) * contrast + 0.5;
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, saturation);
	// Vignette theo hình elip của khung hình
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(vignette_radius, vignette_radius + vignette_softness, length(d) * 1.6);
	col = mix(col, vignette_color.rgb, v * vignette_strength);
	// Vùng sáng quanh player: tính theo tỉ lệ khung hình để vùng sáng tròn, không bị kéo dẹt
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float fd = length((SCREEN_UV - focus_uv) * aspect);
	float f = smoothstep(focus_radius, focus_radius + focus_softness, fd);
	col = mix(col, focus_color.rgb, f * focus_strength);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
