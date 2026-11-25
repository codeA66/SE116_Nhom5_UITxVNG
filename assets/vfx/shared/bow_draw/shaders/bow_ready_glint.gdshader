shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Lớp 3 - tia lóe hình ngôi sao 4 cánh ở đầu mũi tên lúc kéo đầy; luôn quay mặt về camera.
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.75, 0.35, 1.0);
uniform float opacity : hint_range(0.0, 2.0) = 1.0;

void vertex() {
	// Billboard: bỏ xoay của model, giữ cỡ
	vec3 scale_by = vec3(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz), length(MODELVIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX[0] = vec4(scale_by.x, 0.0, 0.0, 0.0);
	MODELVIEW_MATRIX[1] = vec4(0.0, scale_by.y, 0.0, 0.0);
	MODELVIEW_MATRIX[2] = vec4(0.0, 0.0, scale_by.z, 0.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ax = abs(p.x);
	float ay = abs(p.y);
	// Hai tia chéo nhau + lõi tròn
	float spike = max((1.0 - smoothstep(0.0, 0.07, ay)) * (1.0 - ax), (1.0 - smoothstep(0.0, 0.07, ax)) * (1.0 - ay));
	float core = 1.0 - smoothstep(0.0, 0.32, length(p));
	float shape = max(spike, core);
	ALBEDO = mix(edge_color.rgb, core_color.rgb, core);
	ALPHA = clamp(shape * opacity, 0.0, 1.0);
}
