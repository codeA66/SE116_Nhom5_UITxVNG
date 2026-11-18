shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_image : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform int warp_mode : hint_enum("Shockwave", "Heat haze") = 0;
uniform float strength_px : hint_range(0.0, 20.0, 0.1) = 6.0;
uniform float band_width : hint_range(0.02, 0.6, 0.01) = 0.22;
uniform float haze_frequency : hint_range(1.0, 32.0, 0.1) = 12.0;
uniform float haze_speed : hint_range(0.0, 16.0, 0.1) = 5.0;

instance uniform float vfx_progress : hint_range(0.0, 1.0), instance_index(2) = 0.55;
instance uniform float vfx_opacity : hint_range(0.0, 1.0), instance_index(1) = 1.0;

float view_depth(vec2 uv, float depth, mat4 inverse_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 axis = UV * 2.0 - 1.0;
	float radius = length(axis);
	vec2 direction = vec2(axis.x, -axis.y) / max(radius, 0.001);
	float edge = 1.0 - smoothstep(0.78, 1.0, radius);
	float band = 1.0 - smoothstep(0.0, band_width, abs(radius - clamp(vfx_progress, 0.0, 1.0)));
	if (warp_mode == 1) {
		direction = vec2(sin(UV.y * haze_frequency - TIME * haze_speed),
			cos(UV.x * haze_frequency + TIME * haze_speed) * 0.28);
		band = 1.0;
	}
	vec2 margin = 0.5 / VIEWPORT_SIZE;
	vec2 displaced = clamp(SCREEN_UV + direction * (edge * band * strength_px) / VIEWPORT_SIZE,
		margin, 1.0 - margin);
	// Đọc chiều sâu ở pixel đích để vòng méo không kéo màu vật thể ở tiền cảnh.
	float displaced_depth = view_depth(displaced, texture(scene_depth, displaced).r, INV_PROJECTION_MATRIX);
	ALBEDO = texture(screen_image, displaced).rgb;
	ALPHA = vfx_opacity * edge * band * step(-VERTEX.z, displaced_depth);
}

