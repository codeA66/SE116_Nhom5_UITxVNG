shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// Sương giả chỉ dành cho kết cấu tầng dưới trong renderer Compatibility.
uniform vec4 haze_color : source_color = vec4(0.145098, 0.172549, 0.211765, 1.0);
uniform float clear_height = -0.8;
uniform float obscured_height = -5.0;
uniform float maximum_haze : hint_range(0.0, 1.0) = 0.75;

varying float world_height;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float haze = (1.0 - smoothstep(obscured_height, clear_height, world_height)) * maximum_haze;
	ALBEDO = haze_color.rgb;
	ALPHA = haze;
}
