shader_type spatial;
// Cầu lửa đang lao xuống chéo (kiểu tên lửa của Rumble): đầu tròn sáng, đuôi lửa thon dần ngược hướng bay.
// Quad nằm dọc trục trail_dir (từ đầu ngược về phía bay tới) và xoay quanh trục đó về phía camera.
// Gốc node là tâm đầu cầu lửa. Một material dùng chung cho mọi quả (trail_dir giống nhau trong một lần gọi).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, world_vertex_coords;

uniform float head_radius = 0.42;
uniform float tail_length = 3.2;
// Hướng (đơn vị, thế giới) từ đầu cầu lửa ngược về phía nó bay tới
uniform vec3 trail_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.72, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.7, 0.18, 1.0);
uniform vec4 outer_color : source_color = vec4(0.92, 0.3, 0.04, 1.0);
uniform float intensity = 1.0;

varying vec2 meters;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(trail_dir);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - origin);
	vec3 right = cross(axis, to_cam);
	right = length(right) > 0.001 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	float width = head_radius * 2.6;
	float height = tail_length + head_radius * 2.0;
	// QuadMesh -0.5..0.5: cạnh dưới ngay trước đầu cầu lửa, cạnh trên là chót đuôi
	float y = (VERTEX.y + 0.5) * height - head_radius * 1.3;
	VERTEX = origin + right * VERTEX.x * width + axis * y;
	meters = vec2((UV.x - 0.5) * width, (1.0 - UV.y) * height - head_radius * 1.3);
}

void fragment() {
	float x = meters.x;
	float y = meters.y;
	float head = length(vec2(x, y));
	float head_core = smoothstep(head_radius, head_radius * 0.25, head);
	float head_glow = exp(-max(head - head_radius, 0.0) / (head_radius * 0.6)) * 0.6;
	// Đuôi: bề ngang thon dần từ đầu lên chót đuôi, gợn nhẹ theo thời gian
	float along = clamp(y / tail_length, 0.0, 1.0);
	float tail_w = head_radius * (1.0 - along) * (0.85 + 0.15 * sin(y * 9.0 - TIME * 30.0));
	float tail = smoothstep(tail_w, tail_w * 0.3, abs(x)) * step(0.0, y) * (1.0 - along);
	float shape = clamp(head_core + head_glow + tail * 0.9, 0.0, 1.0);
	vec3 color = mix(outer_color.rgb, hot_color.rgb, clamp(shape * 1.4, 0.0, 1.0));
	color = mix(color, core_color.rgb, head_core);
	ALBEDO = color * intensity;
	ALPHA = shape * intensity;
}
