shader_type canvas_item;
// Hình minh họa trên bảng nhận kỹ năng: quầng sáng quanh nét trắng + hiện dần như mực dâng từ dưới lên.
// Chỉ chạy lúc bảng đang mở (khung nhỏ), nên lấy mẫu vòng quanh mỗi điểm vẫn rẻ.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(0.65, 0.88, 0.94, 1.0);
// Bán kính quầng sáng (px của ảnh nguồn)
uniform float glow_radius : hint_range(0.0, 32.0) = 5.0;
uniform float glow_strength : hint_range(0.0, 4.0) = 0.9;

const int TAPS = 12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float brightness(vec4 c) {
	return c.a * dot(c.rgb, vec3(0.3333));
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float halo = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float angle = float(i) * 6.2831853 / float(TAPS);
		vec2 dir = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * glow_radius;
		halo += brightness(texture(TEXTURE, UV + dir)) + brightness(texture(TEXTURE, UV + dir * 2.0)) * 0.5;
	}
	halo = halo / (float(TAPS) * 1.5);
	// Mép mực dâng từ dưới lên, lởm chởm theo ô nhiễu
	float threshold = (1.0 - UV.y) * 0.85 + hash(floor(UV * 48.0)) * 0.15;
	float shown = smoothstep(threshold - 0.03, threshold + 0.03, reveal * 1.15);
	float edge = (1.0 - smoothstep(0.0, 0.06, abs(threshold - reveal * 1.15))) * (1.0 - step(0.999, reveal));
	vec3 color = base.rgb * base.a + glow_color.rgb * (halo * glow_strength + edge * 0.8);
	float alpha = clamp(base.a + halo * glow_strength + edge, 0.0, 1.0);
	COLOR = vec4(color, alpha * shown);
}
