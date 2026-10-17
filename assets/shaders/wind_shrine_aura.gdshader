shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 aura_color : source_color = vec4(0.82, 0.929, 0.949, 1.0);
uniform float active_level : hint_range(0.0, 1.0) = 0.0;
uniform float opacity = 0.085;
uniform float float_amplitude = 0.035;
uniform float float_speed = 1.4;

void vertex() {
	VERTEX.y += sin(TIME * float_speed) * float_amplitude;
	// Quad luôn hướng về camera, kể cả khi checkpoint được scale trong map.
	MODELVIEW_MATRIX = mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), MODELVIEW_MATRIX[3]);
}

void fragment() {
	vec2 centered = (UV - 0.5) * vec2(2.8, 2.0);
	float halo = pow(max(1.0 - length(centered), 0.0), 2.5);
	ALBEDO = aura_color.rgb;
	ALPHA = halo * active_level * opacity;
}
