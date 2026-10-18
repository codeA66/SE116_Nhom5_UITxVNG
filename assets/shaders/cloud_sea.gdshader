// Biển mây dưới các đảo: mây trôi theo hướng gió, tô 3 tông màu cắt sắc (không loang) cho hợp phong cách low-poly.
// Toạ độ theo world XZ nên kích thước mây không đổi khi chỉnh cỡ mặt phẳng. Opaque, unshaded: rẻ dù phủ cả màn hình.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color_deep : source_color = vec3(0.56, 0.68, 0.74);
uniform vec3 color_mid : source_color = vec3(0.72, 0.81, 0.85);
uniform vec3 color_top : source_color = vec3(0.88, 0.93, 0.94);
// Hướng gió trên mặt XZ (không cần chuẩn hoá)
uniform vec2 wind_direction = vec2(0.6, -1.0);
uniform float drift_speed : hint_range(0.0, 10.0) = 1.2;
// Cỡ một cụm mây (m)
uniform float cloud_scale : hint_range(1.0, 200.0) = 26.0;
// Ngưỡng tách tông: thấp = nhiều mây sáng
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float top_threshold : hint_range(0.0, 1.0) = 0.6;
// Mây bị kéo dài theo hướng gió (1 = tròn)
uniform float stretch : hint_range(1.0, 6.0) = 2.2;

varying vec2 world_xz;

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 3 tầng đủ để có mép mây vụn; thêm tầng chỉ tốn thêm mà khó thấy ở góc camera cao
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 dir = length(wind_direction) > 0.0001 ? normalize(wind_direction) : vec2(0.0, -1.0);
	vec2 side = vec2(-dir.y, dir.x);
	// Đổi sang hệ trục theo gió để kéo dài mây dọc hướng thổi
	vec2 p = vec2(dot(world_xz, side), dot(world_xz, dir) / stretch) / cloud_scale;
	vec2 flow = vec2(0.0, TIME * drift_speed / (cloud_scale * stretch));
	float n = fbm(p - flow);
	// Tầng nhỏ trôi nhanh hơn: tạo cảm giác gió cuốn trên mặt mây
	n = mix(n, fbm(p * 2.7 - flow * 2.2), 0.3);
	float aa = max(fwidth(n), 0.0005);
	float mid = smoothstep(mid_threshold - aa, mid_threshold + aa, n);
	float top = smoothstep(top_threshold - aa, top_threshold + aa, n);
	ALBEDO = mix(mix(color_deep, color_mid, mid), color_top, top);
}
