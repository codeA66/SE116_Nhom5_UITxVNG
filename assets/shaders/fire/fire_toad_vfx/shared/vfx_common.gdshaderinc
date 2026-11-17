uniform sampler2D palette_atlas : source_color, filter_linear, repeat_disable;

uniform float vfx_palette_row = 0.0;
uniform float vfx_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float vfx_progress : hint_range(0.0, 1.0) = 1.0;
uniform float vfx_dissolve : hint_range(0.0, 1.0) = 0.0;

vec4 vfx_sample_palette(float heat) {
	vec2 atlas_size = vec2(textureSize(palette_atlas, 0));
	float row = clamp(round(vfx_palette_row), 0.0, atlas_size.y - 1.0);
	float u = (clamp(heat, 0.0, 1.0) * (atlas_size.x - 1.0) + 0.5) / atlas_size.x;
	// Lấy mẫu giữa hàng để hai màu nguyên tố cạnh nhau không bị trộn.
	return texture(palette_atlas, vec2(u, (row + 0.5) / atlas_size.y));
}

float vfx_erosion(float mask, float dissolve, float softness) {
	float feather = max(softness, 0.001);
	float threshold = mix(-feather, 1.0, clamp(dissolve, 0.0, 1.0));
	return smoothstep(threshold, threshold + feather, mask);
}
