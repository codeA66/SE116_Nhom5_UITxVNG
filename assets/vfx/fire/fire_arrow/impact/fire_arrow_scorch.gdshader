shader_type spatial;
// Vết cháy trên sàn ngay dưới chỗ tên Cung Lửa trúng: mép gồ ghề, viền than hồng lúc đầu rồi nguội, mờ dần.
// Có thử độ sâu (khác lớp lửa) để vết nằm dưới chân quái, không đè lên thân.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 scorch_color : source_color = vec4(0.13, 0.08, 0.06, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.54, 0.12, 1.0);
uniform vec4 glow_edge : source_color = vec4(0.55, 0.15, 0.07, 1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float size = 1.0;
uniform float floor_y = -0.5;
uniform float scorch_scale = 0.9;
uniform float scorch_time = 1.2;
uniform float glow_time = 0.4;
uniform float scorch_alpha = 0.75;
uniform float glow_width = 0.16;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float s = size * scorch_scale * (0.6 + 0.4 * smoothstep(0.0, 0.08, age));
	VERTEX = vec3((UV.x - 0.5) * s, floor_y, (UV.y - 0.5) * s);
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float ang = atan(c.y, c.x);
	float edge = 0.78 + (vnoise(vec2(ang * 2.2, 3.0)) - 0.5) * 0.4;
	if (r > edge) discard;
	float t = age / scorch_time;
	// Đốm sáng tối loang lổ bên trong để vết không phẳng một màu
	vec3 col = scorch_color.rgb * (0.8 + 0.4 * vnoise(UV * 6.0));
	float a = scorch_alpha * (1.0 - smoothstep(0.45, 1.0, t));
	float glow = 1.0 - clamp(age / glow_time, 0.0, 1.0);
	if (r > edge - glow_width * glow) {
		col = r > edge - glow_width * glow * 0.35 ? glow_edge.rgb : glow_color.rgb;
		a = max(a, glow);
	}
	ALBEDO = col;
	ALPHA = a * opacity;
}
