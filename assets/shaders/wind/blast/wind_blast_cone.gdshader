// Lốc xoáy của cú thổi gió (Wind Blast). Một mesh chứa nhiều dải xoắn ốc quanh trục Y (đáy hẹp, đỉnh loe);
// vertex xoay quanh Y theo TIME nên lốc tự cuộn trên GPU, CPU chỉ đổi vài uniform.
// Lõi trắng HDR (ăn glow) + viền xanh đậm để vẫn đọc rõ trên nền đá trắng; mép sắc bằng fwidth.
// UV.x: dọc dải (0 đầu → 1 cuối), UV.y: ngang dải. COLOR.r: pha ngẫu nhiên, COLOR.g: độ cao chuẩn hoá (0 đáy → 1 đỉnh).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.16, 0.42, 0.62, 1.0);
// > 1 để lõi đủ sáng cho glow (tonemap AgX làm trắng 1.0 trông xám)
uniform float core_intensity = 1.8;
// Bề rộng viền so với nửa bề ngang dải (0..1)
uniform float edge_width : hint_range(0.0, 1.0) = 0.3;
// Vòng/giây ở đáy; đỉnh quay chậm hơn theo spin_falloff để lốc trông xoắn
uniform float spin_speed = 2.6;
uniform float spin_falloff : hint_range(0.0, 1.0) = 0.45;
// 0 = đủ hình, 1 = tan hết: dải teo mỏng lại (không mờ alpha) để giữ mép sắc
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
// Phần dải đang hiện (0..1): dùng lúc lốc hình thành, các dải mọc dần từ đầu tới cuối
uniform float grow : hint_range(0.0, 1.0) = 1.0;

varying float v_height;
varying float v_phase;

void vertex() {
	v_height = COLOR.g;
	v_phase = COLOR.r;
	float spin = TIME * spin_speed * TAU * (1.0 - spin_falloff * v_height);
	float c = cos(spin);
	float s = sin(spin);
	VERTEX.xz = vec2(c * VERTEX.x - s * VERTEX.z, s * VERTEX.x + c * VERTEX.z);
}

void fragment() {
	float u = UV.x;
	// Dải mọc dần theo grow, đầu dải có mũi nhọn
	float visible_end = grow;
	if (u > visible_end) {
		discard;
	}
	float t = u / max(visible_end, 0.001);
	// Thon hai đầu: giữa dày nhất, mũi (đầu đang mọc) nhọn hơn đuôi
	float profile = pow(sin(3.14159 * clamp(t, 0.0, 1.0)), 0.35);
	profile *= 1.0 - dissolve;
	float across = abs(UV.y - 0.5) * 2.0;
	float aa = max(fwidth(across), 0.002);
	float body = 1.0 - smoothstep(profile - aa, profile + aa, across);
	if (body <= 0.001) {
		discard;
	}
	// Lõi: phần giữa dải; viền: dải ngoài edge_width
	float core_limit = profile * (1.0 - edge_width);
	float core = 1.0 - smoothstep(core_limit - aa, core_limit + aa, across);
	vec3 col = mix(edge_color.rgb, core_color.rgb * core_intensity, core);
	ALBEDO = col;
	ALPHA = body;
}
