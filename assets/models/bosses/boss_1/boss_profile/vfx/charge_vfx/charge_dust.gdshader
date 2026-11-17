shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p * vec2(1.0, 1.15));
	float wisps = 0.88 + 0.12 * sin(p.x * 15.0 + sin(p.y * 13.0));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * pow(max(0.0, 1.0 - r), 1.5) * wisps;
}
