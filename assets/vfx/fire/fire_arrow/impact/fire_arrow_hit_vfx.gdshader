shader_type spatial;
// Vẽ đè (không thử độ sâu): chỗ trúng nằm trước mặt mục tiêu, lửa phải nổi lên trên thân quái và không bị sàn cắt
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
// Bùng lửa chỗ tên Cung Lửa trúng, kiểu hoạt hình: viền đậm, tô màu theo bậc, tan theo bậc (không mờ trơn).
// Mỗi ô là một quad; UV2.y = loại lớp, UV2.x = chỉ số trong lớp (để rải ngẫu nhiên):
// 0 chớp sao, 1 cục lửa phồng, 2 lưỡi lửa vút lên, 3 tia lửa, 4 khói, 5 vòng xung kích. Node quay +Z theo hướng tên bay.
// Mọi chuyển động tính trên GPU từ `age` (giây); CPU chỉ đổi một số mỗi frame.
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.69, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.54, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.55, 0.15, 0.07, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.42, 0.35, 0.33, 1.0);
uniform vec4 smoke_shadow : source_color = vec4(0.24, 0.19, 0.19, 1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float size = 1.0;
uniform float forward_bias = 0.5;
uniform float edge_width = 0.2;
uniform float dissolve_steps = 4.0;
uniform float flash_time = 0.08;
uniform float flash_scale = 1.3;
uniform float star_points = 5.0;
uniform float blob_count = 5.0;
uniform float blob_time = 0.34;
uniform float blob_scale = 0.55;
uniform float blob_spread = 0.45;
uniform float blob_rise = 0.55;
uniform float lick_count = 3.0;
uniform float lick_time = 0.28;
uniform float lick_height = 0.9;
uniform float lick_width = 0.3;
uniform float spark_time = 0.4;
uniform float spark_speed = 2.2;
uniform float spark_gravity = 6.0;
uniform float spark_length = 0.22;
uniform float spark_width = 0.06;
uniform float smoke_count = 4.0;
uniform float smoke_start = 0.12;
uniform float smoke_time = 0.6;
uniform float smoke_scale = 0.5;
uniform float smoke_rise = 0.9;
uniform float shock_time = 0.16;
uniform float shock_scale = 2.2;
uniform float shock_width = 0.35;
varying float kind;
varying float idx;
varying float life;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	kind = UV2.y;
	idx = UV2.x;
	vec2 q = UV - 0.5;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	vec3 cam_r = normalize(to_local * INV_VIEW_MATRIX[0].xyz);
	vec3 cam_u = normalize(to_local * INV_VIEW_MATRIX[1].xyz);
	float h1 = hash(idx + kind * 17.0);
	float h2 = hash(idx + kind * 17.0 + 5.3);
	float h3 = hash(idx + kind * 17.0 + 9.7);
	vec3 p = vec3(0.0);
	if (kind < 0.5) {
		life = age / flash_time;
		float s = size * flash_scale * (0.55 + 0.6 * sqrt(clamp(life, 0.0, 1.0)));
		p = (cam_r * q.x + cam_u * q.y) * s;
	} else if (kind < 1.5) {
		// Cục lửa: rải đều quanh vòng + lệch về phía trước; bung nhanh, bốc lên, co lại
		float lt = age - h3 * 0.04;
		life = lt / blob_time;
		float a = (idx + h1 * 0.6) / blob_count * 6.283185;
		vec3 dir = vec3(sin(a), 0.0, cos(a) + forward_bias);
		float burst = 1.0 - pow(1.0 - clamp(life, 0.0, 1.0), 3.0);
		vec3 c = dir * size * blob_spread * burst * (0.55 + 0.45 * h2) + vec3(0.0, size * blob_rise * life * life, 0.0);
		float s = size * blob_scale * (0.65 + 0.6 * h2) * smoothstep(-0.05, 0.18, life) * (1.0 - 0.45 * clamp(life, 0.0, 1.0));
		p = c + (cam_r * q.x + cam_u * q.y) * s;
	} else if (kind < 2.5) {
		// Lưỡi lửa: đứng thẳng (trục Y), mặt quay về camera quanh trục đứng; gốc rải quanh tâm
		float lt = age - 0.02 - h3 * 0.05;
		life = lt / lick_time;
		float a = (idx + 0.5 + h1 * 0.5) / lick_count * 6.283185;
		vec3 base = vec3(sin(a), 0.0, cos(a) + forward_bias * 0.5) * size * 0.28;
		vec3 side = normalize(vec3(cam_r.x, 0.0, cam_r.z));
		float hgt = size * lick_height * (0.7 + 0.5 * h2) * smoothstep(0.0, 0.3, life);
		p = base + vec3(0.0, size * 0.35 * life - size * 0.15, 0.0) + side * q.x * size * lick_width + vec3(0.0, UV.y * hgt, 0.0);
	} else if (kind < 3.5) {
		// Tia lửa: quad kéo dài theo vận tốc tức thời, bay ra rồi rơi
		life = age / spark_time;
		float a = h1 * 6.283185;
		vec3 v0 = vec3(sin(a) * (0.5 + h2), 0.7 + h3 * 1.3, cos(a) * (0.5 + h2) + forward_bias) * size * spark_speed;
		vec3 g = vec3(0.0, -spark_gravity * size, 0.0);
		vec3 c = v0 * age + 0.5 * g * age * age;
		vec3 vel = normalize(v0 + g * age);
		vec3 view = normalize(to_local * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
		vec3 side = normalize(cross(vel, view) + vec3(0.0001));
		float len = size * spark_length * (1.0 - 0.6 * clamp(life, 0.0, 1.0));
		p = c + vel * q.y * len + side * q.x * spark_width;
	} else if (kind > 4.5) {
		// Vòng xung kích: nở rất nhanh rồi mỏng đi, tạo cú "bụp" ngay khung trúng
		life = age / shock_time;
		float s = size * shock_scale * (0.25 + 0.75 * (1.0 - pow(1.0 - clamp(life, 0.0, 1.0), 2.5)));
		p = (cam_r * q.x + cam_u * q.y) * s;
	} else {
		// Khói: sau lửa một nhịp, bốc lên, nở to dần
		float lt = age - smoke_start - h3 * 0.08;
		life = lt / smoke_time;
		float a = (idx + h1) / smoke_count * 6.283185;
		vec3 c = vec3(sin(a), 0.0, cos(a) + forward_bias * 0.4) * size * 0.32 + vec3(0.0, size * (0.25 + smoke_rise * life), 0.0);
		float s = size * smoke_scale * (0.7 + 0.5 * h2) * (0.55 + 0.7 * clamp(life, 0.0, 1.0));
		p = c + (cam_r * q.x + cam_u * q.y) * s;
	}
	// Ngoài khoảng sống: thu về một điểm để không tốn pixel
	if (life < 0.0 || life > 1.0) {
		p = vec3(0.0);
	}
	VERTEX = p;
}

// Ba bậc màu lửa theo khoảng cách chuẩn hoá m (0 tâm, 1 mép); heat giảm theo thời gian để lõi nguội dần
vec3 fire_bands(float m, float heat) {
	vec3 col = m > 1.0 - edge_width ? edge_color.rgb : body_color.rgb;
	return m < 0.5 * heat ? core_color.rgb : col;
}

void fragment() {
	if (life < 0.0 || life > 1.0) {
		discard;
	}
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float ang = atan(c.y, c.x);
	// Tan theo bậc: ngưỡng nhảy từng nấc thay vì tăng đều
	float stepped = floor(life * dissolve_steps) / dissolve_steps;
	vec3 col;
	if (kind < 0.5) {
		// Chớp không có viền đậm: viền tối + vòng xung kích làm nó trông như hình sao vẽ bùa
		float star = 0.18 + 0.82 * pow(abs(cos(ang * star_points * 0.5)), 9.0);
		float m = r / star;
		if (m > 1.0) discard;
		col = m < 0.6 ? core_color.rgb : body_color.rgb;
	} else if (kind < 1.5) {
		float wob = vnoise(vec2(ang * 1.6 + idx * 7.0, age * 7.0)) - 0.5;
		float m = r + wob * 0.28;
		if (m > 1.0) discard;
		if (vnoise(UV * 4.0 + idx * 3.1) < stepped * 1.05) discard;
		col = fire_bands(m, 1.0 - life * 0.8);
	} else if (kind < 2.5) {
		// Giọt nước lộn ngược: gốc tròn, ngọn nhọn; ngọn cháy cụt dần theo bậc
		float w = smoothstep(0.0, 0.22, UV.y) * pow(max(1.0 - UV.y, 0.0), 0.75);
		float x = abs(c.x) * 2.0 / max(w, 0.001);
		if (x > 1.0) discard;
		if (UV.y > 1.0 - stepped * 0.85) discard;
		col = fire_bands(max(x, UV.y * 0.9), 1.0 - life * 0.6);
	} else if (kind < 3.5) {
		if (abs(c.x) * 2.0 > 1.0 - abs(c.y) * 2.0) discard;
		col = mix(core_color.rgb, body_color.rgb, step(0.25, abs(c.y)));
	} else if (kind > 4.5) {
		float th = shock_width * (1.0 - stepped);
		if (r > 1.0 || r < 1.0 - th) discard;
		col = r > 1.0 - th * 0.3 ? edge_color.rgb : (r < 1.0 - th * 0.75 ? core_color.rgb : body_color.rgb);
	} else {
		float wob = vnoise(vec2(ang * 1.4 + idx * 5.0, age * 3.0)) - 0.5;
		float m = r + wob * 0.3;
		if (m > 1.0) discard;
		if (vnoise(UV * 3.5 + idx * 2.3) < stepped * 1.05) discard;
		// Nửa trên sáng, nửa dưới tối + viền tối: khói đọc được là khối tròn
		col = (UV.y + wob * 0.2) > 0.52 ? smoke_color.rgb : smoke_shadow.rgb;
		col = m > 1.0 - edge_width * 0.7 ? smoke_shadow.rgb * 0.7 : col;
	}
	ALBEDO = col;
	ALPHA = opacity;
}
