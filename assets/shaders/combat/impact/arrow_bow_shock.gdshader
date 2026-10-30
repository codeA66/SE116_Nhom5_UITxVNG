// Vòm sóng xung kích: sáng ở viền (fresnel) kèm các vạch toả ra từ đỉnh, nét chạy về phía đáy theo thời gian.
// Dùng trên SphereMesh: nửa cầu (is_hemisphere) ở đầu tên, hoặc cả cầu cho vụ nổ lúc trúng.
// Trục vòm là +Y cục bộ của mesh (đỉnh ở +Y); node tự xoay để +Y trỏ theo hướng cần.
// Độ sáng do script/scene điều khiển qua intensity (cộng sáng: giảm intensity = mờ dần).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform float intensity = 1.6;
// Viền: lớn = viền mảnh
uniform float rim_power = 2.5;
uniform float rim_strength = 1.0;
// Lớp phủ đều toàn vòm (0 = chỉ có viền và vạch)
uniform float fill = 0.08;
uniform float line_count = 14.0;
// Lớn = vạch mảnh
uniform float line_sharpness = 6.0;
uniform float line_strength = 0.8;
uniform float line_speed = 3.0;
// Mờ dần về phía đáy vòm (0..1 theo chiều cao); 0 = không mờ (dùng cho cả cầu)
uniform float base_fade : hint_range(0.0, 1.0) = 0.35;
uniform float back_face_dim : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_local;

void vertex() {
	v_local = normalize(VERTEX);
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_power) * rim_strength;
	float angle = atan(v_local.z, v_local.x);
	// Mỗi vạch có độ dài lệch nhau theo góc để không đều tăm tắp
	float lines = pow(abs(sin(angle * line_count * 0.5)), line_sharpness);
	float run = fract(v_local.y * 1.5 - TIME * line_speed + sin(angle * 3.0) * 0.3);
	lines *= smoothstep(0.0, 0.4, run) * line_strength;
	float height = clamp(v_local.y, 0.0, 1.0);
	float base = base_fade > 0.0 ? smoothstep(0.0, base_fade, height) : 1.0;
	float face = FRONT_FACING ? 1.0 : back_face_dim;
	ALBEDO = mix(tint.rgb, vec3(1.0), clamp(rim, 0.0, 1.0) * 0.6) * intensity * face;
	ALPHA = clamp((rim + lines + fill) * base, 0.0, 1.0) * tint.a;
}
