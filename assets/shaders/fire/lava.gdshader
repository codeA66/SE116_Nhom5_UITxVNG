// Dung nham stylized cho map Lửa: mảng vỏ nguội tối trôi trên lõi cam, gân nóng vàng giữa các mảng.
// Màu chia thành vài bậc (không chuyển mượt) để hợp phong cách màu phẳng của game.
// Tính theo tọa độ thế giới nên các tấm 4 m ghép liền nhau không lộ đường nối, mesh không cần UV.
// Mặt nằm ngang trôi theo flow_direction; mặt đứng (thác) chảy xuống theo trục Y.
// Thêm: lớp lõi sâu trôi ngược chiều (chiều sâu), viền tối quanh mảng vỏ, bọt dung nham nở rồi vỡ.
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

// Lớp lõi sâu bên dưới: màu tối hơn lõi, ô to hơn và trôi chậm ngược chiều
uniform vec4 deep_color : source_color = vec4(0.82, 0.28, 0.06, 1.0);
uniform float deep_scale : hint_range(0.2, 4.0) = 1.8;
uniform float deep_amount : hint_range(0.0, 1.0) = 0.35;
uniform float deep_speed : hint_range(0.0, 2.0) = 0.12;
// Viền tối quanh mảng vỏ nguội (độ rộng theo cùng thang với hot_vein_width); 0 = tắt
uniform float rim_width : hint_range(0.0, 0.3) = 0.05;
// Bọt dung nham: kích thước ô (m), tỉ lệ ô có bọt, tốc độ nở vỡ; density 0 = tắt
uniform float bubble_cell : hint_range(0.5, 10.0) = 1.6;
uniform float bubble_density : hint_range(0.0, 1.0) = 0.3;
uniform float bubble_speed : hint_range(0.0, 3.0) = 0.35;

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

// Bọt: mỗi ô lưới có pha riêng; đĩa nở từ tâm tới bán kính tối đa rồi vỡ (chỉ còn vành sáng mỏng ở cuối)
// Trả 0 = không bọt, 1 = lõi bọt, 2 = vành sáng
int bubble(vec2 world) {
	vec2 p = world / bubble_cell;
	vec2 cell = floor(p);
	vec2 h = hash22(cell);
	if (h.x > bubble_density) {
		return 0;
	}
	float t = fract(TIME * bubble_speed + h.y * 7.0);
	vec2 centre = vec2(0.5) + (hash22(cell + 11.0) - 0.5) * 0.5;
	float d = length(fract(p) - centre);
	float radius = t * 0.28;
	if (t < 0.8) {
		return d < radius ? 1 : 0;
	}
	// Vỡ: vành mỏng ở bán kính cuối
	return (d < radius && d > radius - 0.04) ? 2 : 0;
}

void fragment() {
	vec2 coord;
	vec2 flat_dir = normalize(flow_direction);
	bool horizontal = abs(v_world_normal.y) > 0.5;
	if (horizontal) {
		coord = v_world_pos.xz - flat_dir * flow_speed * TIME;
	} else {
		// Mặt đứng: lấy trục ngang theo hướng mặt, trục dọc chảy xuống
		vec3 side = normalize(cross(v_world_normal, vec3(0.0, 1.0, 0.0)));
		coord = vec2(dot(v_world_pos, side), v_world_pos.y + fall_speed * TIME);
		coord.y *= 0.5;
	}
	vec2 v = voronoi(coord / cell_size);
	// Mép giữa hai ô: hiệu nhỏ. Vỏ nguội nằm giữa ô, lõi cam lộ ra ở mép
	float edge = v.y - v.x;
	float crust_edge = 1.0 - crust_amount;
	vec3 color = core_color.rgb;
	if (edge > crust_edge) {
		color = crust_color.rgb;
		// Viền tối sát mép vỏ cho vỏ nổi hẳn lên khỏi lõi
		if (edge < crust_edge + rim_width) {
			color = crust_color.rgb * 0.45;
		}
	} else if (edge > crust_edge - hot_vein_width) {
		color = hot_color.rgb;
	} else {
		// Lõi: lớp sâu trôi ngược chiều, một số ô tối hơn tạo chiều sâu
		vec2 deep_coord = horizontal ? v_world_pos.xz + flat_dir * deep_speed * TIME : coord;
		vec2 dv = voronoi(deep_coord / (cell_size * deep_scale));
		if (dv.y - dv.x < deep_amount) {
			color = deep_color.rgb;
		}
		if (horizontal && bubble_density > 0.0) {
			int b = bubble(v_world_pos.xz);
			if (b == 1) {
				color = hot_color.rgb;
			} else if (b == 2) {
				color = hot_color.rgb * 1.3;
			}
		}
	}
	float pulse = 1.0 + pulse_strength * sin(TIME * pulse_speed + coord.x * 0.15 + coord.y * 0.1);
	ALBEDO = color * brightness * pulse;
}
