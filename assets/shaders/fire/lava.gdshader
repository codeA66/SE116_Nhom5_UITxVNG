// Dung nham stylized cho map Lửa: mảng vỏ nguội tối trôi trên lõi cam, gân nóng vàng giữa các mảng.
// Màu chia thành vài bậc (không chuyển mượt) để hợp phong cách màu phẳng của game.
// Tính theo tọa độ thế giới nên các tấm 4 m ghép liền nhau không lộ đường nối, mesh không cần UV.
// Mặt nằm ngang trôi theo flow_direction; mặt đứng (thác) chảy xuống theo trục Y.
// Không nhận ánh sáng cảnh: dung nham tự phát sáng, nắng chiếu vào sẽ làm bạc màu.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 crust_color : source_color = vec4(0.23, 0.10, 0.07, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.48, 0.10, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.76, 0.29, 1.0);
// Độ lớn mảng vỏ nguội (m)
uniform float cell_size : hint_range(0.5, 20.0) = 3.0;
// Tỉ lệ diện tích phủ vỏ nguội; 0 = toàn lõi cam
uniform float crust_amount : hint_range(0.0, 1.0) = 0.42;
// Độ rộng gân nóng quanh mép mảng vỏ
uniform float hot_vein_width : hint_range(0.0, 0.5) = 0.08;
uniform vec2 flow_direction = vec2(0.3, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.25;
uniform float fall_speed : hint_range(0.0, 10.0) = 2.5;
// Độ sáng chung; > 1 để glow của Environment bắt được
uniform float brightness : hint_range(0.0, 4.0) = 1.4;
// Nhịp sáng tối chậm toàn mặt, cho cảm giác đang sôi
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.12;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.8;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Khoảng cách tới tâm ô gần nhất và gần nhì (Voronoi): hiệu hai giá trị cho mép mảng vỏ
vec2 voronoi(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 point = offset + hash22(cell + offset);
			float d = length(point - local);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2);
}

void fragment() {
	vec2 coord;
	if (abs(v_world_normal.y) > 0.5) {
		coord = v_world_pos.xz - normalize(flow_direction) * flow_speed * TIME;
	} else {
		// Mặt đứng: lấy trục ngang theo hướng mặt, trục dọc chảy xuống
		vec3 side = normalize(cross(v_world_normal, vec3(0.0, 1.0, 0.0)));
		coord = vec2(dot(v_world_pos, side), v_world_pos.y + fall_speed * TIME);
		coord.y *= 0.5;
	}
	vec2 v = voronoi(coord / cell_size);
	// Mép giữa hai ô: hiệu nhỏ. Vỏ nguội nằm giữa ô, lõi cam lộ ra ở mép
	float edge = v.y - v.x;
	vec3 color = core_color.rgb;
	if (edge > 1.0 - crust_amount) {
		color = crust_color.rgb;
	} else if (edge > 1.0 - crust_amount - hot_vein_width) {
		color = hot_color.rgb;
	}
	float pulse = 1.0 + pulse_strength * sin(TIME * pulse_speed + coord.x * 0.15 + coord.y * 0.1);
	ALBEDO = color * brightness * pulse;
}
