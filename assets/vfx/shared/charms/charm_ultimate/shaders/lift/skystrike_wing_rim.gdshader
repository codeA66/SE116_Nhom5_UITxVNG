shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform float scroll = 0.0;
uniform float offset = 0.012;
uniform float scroll_depth = 0.33;

void vertex() {
	// Dịch về phía camera để lớp viền không tranh độ sâu với mặt lông.
	vec3 toward_camera = vec3(MODELVIEW_MATRIX[0].z, MODELVIEW_MATRIX[1].z, MODELVIEW_MATRIX[2].z);
	VERTEX += normalize(toward_camera) * offset;
}

void fragment() {
	float side = abs(UV.y * 2.0 - 1.0);
	float rim = smoothstep(0.60, 1.0, side);
	float taper = smoothstep(0.05, 0.22, UV.x) * (1.0 - smoothstep(0.93, 1.0, UV.x));
	float wave = 0.5 + 0.5 * sin((UV.x - scroll) * TAU);
	ALBEDO = tint.rgb;
	ALPHA = clamp(rim * taper * mix(1.0 - scroll_depth, 1.0, wave) * opacity, 0.0, 1.0);
}
