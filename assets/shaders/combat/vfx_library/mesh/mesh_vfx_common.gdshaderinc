#include "../vfx_common.gdshaderinc"

uniform sampler2D shape_mask : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D erosion_noise : hint_default_white, filter_linear, repeat_enable;
uniform vec2 mask_tiling = vec2(1.0);
uniform vec2 mask_scroll = vec2(0.0);
uniform bool repeat_shape = false;
uniform vec2 noise_tiling = vec2(2.0);
uniform vec2 noise_scroll = vec2(0.32, -0.12);
uniform float noise_influence : hint_range(0.0, 1.0) = 0.44;
uniform float erosion_softness : hint_range(0.01, 0.5) = 0.15;
uniform float erosion_edge_heat : hint_range(0.0, 1.0) = 0.22;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform float vertex_color_weight : hint_range(0.0, 1.0) = 1.0;

instance uniform vec2 vfx_uv_offset : instance_index(4) = vec2(0.0);

void fragment() {
	vec2 shape_uv = UV * mask_tiling + TIME * mask_scroll + vfx_uv_offset;
	float shape;
	if (repeat_shape) {
		shape = texture(shape_mask, shape_uv).r;
	} else {
		// Khóa mẫu trong nửa texel để rìa mask một lần không hút màu từ đầu bên kia.
		vec2 guard = 0.5 / vec2(textureSize(shape_mask, 0));
		shape = texture(shape_mask, clamp(shape_uv, guard, 1.0 - guard)).r;
		vec2 inside = step(vec2(0.0), shape_uv) * step(shape_uv, vec2(1.0));
		shape *= inside.x * inside.y;
	}
	float grain = texture(erosion_noise, UV * noise_tiling + TIME * noise_scroll + vfx_uv_offset).r;
	float erosion = vfx_erosion(mix(shape, grain, noise_influence), vfx_dissolve, erosion_softness);
	float edge_heat = 4.0 * erosion * (1.0 - erosion) * erosion_edge_heat;
	float facing = clamp(abs(dot(normalize(NORMAL), VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power) * rim_amount;
	vec4 palette = vfx_sample_palette(max(shape + edge_heat, rim));
	vec4 vertex_color = mix(vec4(1.0), COLOR, vertex_color_weight);
	ALBEDO = palette.rgb * vertex_color.rgb * intensity;
	ALPHA = clamp(shape * erosion * palette.a * vertex_color.a * vfx_opacity, 0.0, 1.0);
}
