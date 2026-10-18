// Mảnh vụn nhỏ hình thoi (CPUParticles3D, billboard): màu đặc, mép sắc (fwidth). COLOR.a của hạt làm mờ cuối đời.
// Dùng cho mảnh đen bay ra từ vệt chém.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.05, 0.06, 0.09, 1.0);

varying vec4 v_color;

void vertex() {
	v_color = COLOR;
	vec3 center = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[1].xyz);
	vec3 world = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x * s + INV_VIEW_MATRIX[1].xyz * VERTEX.y * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = abs(p.x) + abs(p.y) * 0.7;
	float aa = max(fwidth(d), 0.001);
	float m = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, d);
	ALBEDO = color.rgb;
	ALPHA = m * v_color.a;
}
