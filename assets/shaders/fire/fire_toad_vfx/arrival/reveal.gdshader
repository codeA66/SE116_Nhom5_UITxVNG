shader_type spatial;

uniform sampler2D skin_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 skin_color : source_color = vec4(1.0);
uniform float skin_metallic = 0.0;
uniform float skin_roughness = 0.85;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float feet_y = 0.0;
uniform float reveal_height = 5.4;
uniform vec4 reveal_edge : source_color = vec4(0.80, 0.62, 1.0, 1.0);

varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Quét theo độ cao thật để các mảnh giáp và da mở cùng một đường cắt.
	float stagger = 0.11 * sin(world_point.x * 7.5 + world_point.z * 6.0)
		+ 0.06 * sin(world_point.x * 26.0 - world_point.z * 13.0);
	float threshold = feet_y + mix(reveal_height + 0.40, -0.40, reveal_progress);
	float edge_dist = world_point.y + stagger - threshold;
	if (edge_dist < 0.0 && reveal_progress < 0.999) {
		discard;
	}
	float edge = (1.0 - smoothstep(0.04, 0.28, edge_dist)) * (1.0 - smoothstep(0.89, 1.0, reveal_progress));
	ALBEDO = mix((texture(skin_texture, UV) * skin_color).rgb, reveal_edge.rgb, edge * 0.68);
	ROUGHNESS = skin_roughness;
	METALLIC = skin_metallic;
	EMISSION = reveal_edge.rgb * edge * 0.64;
}
