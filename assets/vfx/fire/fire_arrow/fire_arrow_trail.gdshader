shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Vệt lửa sau mũi tên Cung Lửa. Node đặt trùng transform của tên (+Z = hướng bay).
// UV2.y: 0 = dải lửa kéo dài phía sau (luôn xoay mặt về camera quanh trục bay), 1 = quả lửa ở đầu tên.
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.69, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.54, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.55, 0.15, 0.07, 1.0);
uniform float trail_length = 0.0;
uniform float trail_width = 0.32;
uniform float head_size = 0.42;
uniform float head_back = 0.12;
uniform float flicker_speed = 22.0;
uniform float wobble = 0.05;
uniform float intensity = 1.0;
varying float kind;

void vertex() {
	kind = UV2.y;
	float u = UV.x;
	float v = UV.y;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	vec3 cam_right = normalize(to_local * INV_VIEW_MATRIX[0].xyz);
	vec3 cam_up = normalize(to_local * INV_VIEW_MATRIX[1].xyz);
	vec3 p;
	if (kind < 0.5) {
		// Mặt dải vuông góc với hướng nhìn quanh trục bay: nhìn chéo từ trên vẫn thấy bề rộng
		vec3 to_cam = normalize(to_local * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
		vec3 side = cross(vec3(0.0, 0.0, 1.0), to_cam);
		side = length(side) < 0.001 ? vec3(1.0, 0.0, 0.0) : normalize(side);
		float w = trail_width * pow(1.0 - u, 0.45) * (0.85 + 0.15 * sin(TIME * flicker_speed + u * 9.0));
		float bend = sin(u * 9.0 - TIME * flicker_speed) * wobble * u;
		p = vec3(0.0, 0.0, -head_back - u * trail_length) + side * ((v - 0.5) * w + bend);
	} else {
		float s = head_size * (1.0 + 0.12 * sin(TIME * flicker_speed * 1.7));
		p = vec3(0.0, 0.0, -head_back) + cam_right * (u - 0.5) * s + cam_up * (v - 0.5) * s;
	}
	VERTEX = p;
}

void fragment() {
	vec3 col;
	float a;
	if (kind < 0.5) {
		float edge = min(UV.y, 1.0 - UV.y) * 2.0;
		// Lưỡi lửa: thu hẹp dần về đuôi, mép răng cưa chạy ngược hướng bay
		float n = sin(UV.x * max(trail_length, 0.1) * 7.0 + TIME * flicker_speed + UV.y * 3.0) * 0.5 + 0.5;
		float shape = edge - UV.x * 0.5 - n * 0.3 * UV.x;
		a = smoothstep(0.0, 0.08, shape) * smoothstep(0.0, 0.04, UV.x + 0.02);
		// Thân cam chiếm chủ đạo, sẫm dần về đuôi; lõi sáng chỉ là sợi mảnh gần đầu (lõi to nhìn trắng như tên gió)
		vec3 body = mix(body_color.rgb, edge_color.rgb, UV.x * 0.55);
		col = mix(edge_color.rgb, body, step(0.12, shape));
		col = mix(col, core_color.rgb, step(0.62, shape));
	} else {
		float d = length(UV - 0.5) * 2.0;
		col = mix(core_color.rgb, body_color.rgb, smoothstep(0.3, 0.55, d));
		col = mix(col, edge_color.rgb, smoothstep(0.7, 0.85, d));
		a = 1.0 - smoothstep(0.85, 1.0, d);
	}
	ALBEDO = col;
	ALPHA = a * intensity;
}
