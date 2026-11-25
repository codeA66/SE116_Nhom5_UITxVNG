shader_type spatial;
// Cầu lửa đang lao xuống chéo (kiểu tên lửa của Rumble): đầu tròn sáng, đuôi lửa thon dần ngược hướng bay.
// Quad nằm dọc trục trail_dir (từ đầu ngược về phía bay tới) và xoay quanh trục đó về phía camera.
// Gốc node là tâm đầu cầu lửa. Một material dùng chung cho mọi quả (trail_dir giống nhau trong một lần gọi).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled, world_vertex_coords;

uniform float head_radius = 0.60;
uniform float tail_length = 4.3;
// Hướng (đơn vị, thế giới) từ đầu cầu lửa ngược về phía nó bay tới
uniform vec3 trail_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.72, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.7, 0.18, 1.0);
uniform vec4 outer_color : source_color = vec4(0.92, 0.3, 0.04, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.17, 0.115, 0.10, 1.0);
uniform float intensity = 1.0;

varying vec2 meters;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(trail_dir);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - origin);
	vec3 right = cross(axis, to_cam);
	right = length(right) > 0.001 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	float width = head_radius * 4.2;
	float height = tail_length + head_radius * 2.0;
	// Lấy góc quad từ UV vì VERTEX đã ở tọa độ thế giới với world_vertex_coords.
	meters = vec2((UV.x - 0.5) * width, (1.0 - UV.y) * height - head_radius * 1.3);
	VERTEX = origin + right * meters.x + axis * meters.y;
}

float puff(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.55, 1.0, length((p - center) / radius));
}

void fragment() {
	vec2 p = meters / vec2(head_radius, tail_length);
	float tip = length(vec2(p.x * 1.15, p.y * tail_length / head_radius));
	float head = 1.0 - smoothstep(0.78, 1.02, tip);
	float core = 1.0 - smoothstep(0.42, 0.81, tip);
	float along = clamp(p.y, 0.0, 1.0);
	float bend = 0.12 * sin(along * 8.0 + floor(TIME * 18.0) * 0.45) * along;
	float w = max(0.02, 0.95 * (1.0 - along));
	float tail = (1.0 - smoothstep(w * 0.70, w, abs(p.x - bend)))
		* step(0.0, p.y) * (1.0 - smoothstep(0.36, 0.82, along));
	float smoke = max(puff(p, vec2(-0.41, 0.39), vec2(0.95, 0.27)),
		max(puff(p, vec2(0.42, 0.61), vec2(1.13, 0.30)),
			puff(p, vec2(-0.20, 0.85), vec2(1.19, 0.19))));
	float fire = max(head, tail);
	vec3 hot = mix(outer_color.rgb, hot_color.rgb, clamp(head + tail * 0.72, 0.0, 1.0));
	hot = mix(hot, core_color.rgb, core);
	ALBEDO = mix(smoke_color.rgb, hot * intensity, fire);
	ALPHA = max(fire, smoke * (0.58 - along * 0.25));
}
