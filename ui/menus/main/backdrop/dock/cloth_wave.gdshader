shader_type canvas_item;
// Vải bay (khăn, cờ) trên một lớp ảnh tách riêng, nền trong suốt. Lấy mẫu ngược: điểm ảnh lấy từ chỗ vải "đã ở" trước
// khi bị đẩy, nên chỉ lớp vải dịch, nền phía sau (lớp khác) không bị méo.
// Gốc ghim đứng yên, càng ra đuôi càng bay mạnh; sóng chạy từ gốc ra đuôi; cơn gió giật theo chu kỳ.
// Đơn vị là điểm ảnh của ảnh gốc, nên ảnh co giãn theo màn thì chuyển động vẫn đúng tỉ lệ.

// Điểm ghim (px ảnh gốc) và hướng từ gốc ra đuôi vải
uniform vec2 pin = vec2(0.0);
uniform vec2 direction = vec2(0.0, 1.0);
// Chiều dài vải tính từ gốc (px)
uniform float cloth_length : hint_range(1.0, 1000.0) = 150.0;
// Biên độ lắc ngang ở đuôi (px): lúc lặng và lúc gió giật
uniform float calm_amplitude : hint_range(0.0, 60.0) = 3.0;
uniform float gust_amplitude : hint_range(0.0, 80.0) = 14.0;
// Gió giật thì vải bị thổi lệch hẳn sang một bên (px ở đuôi, theo hướng vuông góc; âm = phía ngược lại)
uniform float gust_lift = 8.0;
// Số bước sóng trên chiều dài vải và tốc độ sóng
uniform float waves : hint_range(0.0, 4.0) = 1.3;
uniform float wave_speed : hint_range(0.0, 20.0) = 5.0;
// Gốc cứng cỡ nào: lớn = gần gốc gần như đứng yên
uniform float stiffness : hint_range(0.5, 4.0) = 1.6;
// Chu kỳ cơn gió (s), độ trễ so với lớp khác (s), lệch pha sóng
uniform float gust_interval : hint_range(1.0, 12.0) = 5.2;
uniform float gust_delay : hint_range(0.0, 3.0) = 0.0;
uniform float phase = 0.0;

float gust(float time) {
	float p = fract(time / gust_interval);
	return smoothstep(0.02, 0.26, p) * (1.0 - smoothstep(0.30, 0.74, p));
}

void fragment() {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 dir = normalize(direction);
	vec2 side = vec2(-dir.y, dir.x);
	float along = clamp(dot(px - pin, dir) / cloth_length, 0.0, 1.0);
	float weight = pow(along, stiffness);
	float t = TIME - gust_delay;
	float g = gust(t);
	float wave = sin(t * wave_speed - along * waves * TAU + phase);
	// Sóng phụ ngắn hơn ở đuôi: mép rách lật phần phật
	float flutter = sin(t * wave_speed * 2.3 - along * waves * 2.0 * TAU + phase * 1.7) * along;
	float offset = weight * (mix(calm_amplitude, gust_amplitude, g) * (wave + 0.35 * flutter) + gust_lift * g);
	// Đuôi bị thổi thì co lại một chút theo chiều dài (vải cong chứ không giãn)
	float shrink = weight * abs(offset) * 0.15;
	vec2 source = px - side * offset + dir * shrink;
	COLOR = texture(TEXTURE, source * TEXTURE_PIXEL_SIZE);
}
