shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_add, shadows_disabled, fog_disabled;

// Chớp sáng lúc lốc nổ: quầng tròn quay mặt về camera, cộng sáng nên không che nhân vật
uniform vec4 color : source_color = vec4(0.85, 0.97, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float glow = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = color.rgb * glow * strength * 1.6;
}
