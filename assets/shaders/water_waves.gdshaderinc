// Công thức sóng dùng chung. Water.get_height_at() (GDScript) tính lại ĐÚNG công thức này:
// sửa ở đây thì phải sửa cả bên đó, nếu không vật nổi sẽ lệch mặt nước.
// Mỗi lớp: xy = hướng, z = bước sóng (m), w = biên độ (m); tốc độ (m/s) trong wave_speeds.

uniform vec4 wave_1 = vec4(1.0, 0.3, 6.0, 0.08);
uniform vec4 wave_2 = vec4(-0.4, 1.0, 3.5, 0.05);
uniform vec4 wave_3 = vec4(0.7, -0.7, 1.8, 0.02);
uniform vec3 wave_speeds = vec3(1.2, 0.9, 0.7);
// Thời gian sóng do script đẩy vào (không dùng TIME) để GDScript tính cùng một thời điểm
uniform float wave_time = 0.0;

// xyz: độ cao và đạo hàm theo x, z (để tính pháp tuyến)
vec3 water_wave(vec4 wave, float speed, vec2 world_xz) {
	vec2 dir = normalize(wave.xy);
	float k = TAU / max(wave.z, 0.01);
	float phase = k * (dot(dir, world_xz) - speed * wave_time);
	return vec3(wave.w * sin(phase), wave.w * k * cos(phase) * dir);
}

vec3 water_surface(vec2 world_xz) {
	return water_wave(wave_1, wave_speeds.x, world_xz)
		+ water_wave(wave_2, wave_speeds.y, world_xz)
		+ water_wave(wave_3, wave_speeds.z, world_xz);
}
