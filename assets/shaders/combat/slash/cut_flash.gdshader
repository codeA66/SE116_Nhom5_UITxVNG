// Nét cắt thẳng trắng HDR (quad 1x1): rất dài, nhọn hai đầu, hiện tức thì đủ chiều dài rồi co BỀ DÀY về 0 (không mờ alpha).
// axis: hướng nét cắt trong không gian thế giới; length / thickness (m); progress 0..1 do script điều khiển.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity = 3.0;
uniform vec3 axis = vec3(1.0, 0.0, 0.0);
uniform float length_m = 5.0;
uniform float thickness_m = 0.12;
uniform float progress = 0.0;

varying vec2 v_uv;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 ax = normalize(axis);
	vec3 view_dir = normalize(INV_VIEW_MATRIX[3].xyz - center);
	vec3 side = cross(ax, view_dir);
	side = side / max(length(side), 0.00001);
	// Bề dày co về 0 theo progress (ease-in) trong khi chiều dài giữ nguyên
	float thick = thickness_m * (1.0 - pow(progress, 1.6));
	vec3 world = center + ax * VERTEX.x * length_m + side * VERTEX.y * thick / max(0.5, 0.0001) * 0.5;
	v_uv = UV;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = v_uv * 2.0 - 1.0;
	// Nhọn hai đầu: nửa bề rộng giảm theo khoảng cách tới tâm
	float half_w = pow(max(1.0 - abs(p.x), 0.0), 1.5);
	float d = abs(p.y) / max(half_w, 0.0001);
	float aa = max(fwidth(d), 0.001);
	float m = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, d);
	float core = 1.0 - smoothstep(0.0, 0.6, d);
	ALBEDO = mix(tint.rgb, vec3(1.0), core) * intensity;
	ALPHA = clamp(m, 0.0, 1.0);
}
