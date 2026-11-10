shader_type spatial;
// Nét viền ngoài của hình cáo trên bảng nhận kỹ năng: vỏ lồi ra theo pháp tuyến, chỉ vẽ mặt sau (inverted hull).
// Chạy sau khi xương đã biến dạng nên nét bám đúng dáng đang tạo.
render_mode unshaded, cull_front;

uniform vec4 line_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform float width : hint_range(0.0, 0.1) = 0.014;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
