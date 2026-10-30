shader_type spatial;
render_mode cull_disabled;

uniform vec3 gate_size = vec3(4.0, 4.2, 0.55);
uniform vec4 stone_color : source_color = vec4(0.18, 0.20, 0.27, 1.0);
uniform vec4 rune_color : source_color = vec4(0.68, 0.39, 0.58, 1.0);
uniform vec4 edge_color : source_color = vec4(0.79, 0.83, 1.0, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_position;

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 pos = local_position.xy / gate_size.xy + vec2(0.5);
	float grain = cell_hash(floor(local_position.xy * 14.0));
	float field = pos.y + grain * 0.13;
	float cut = mix(-0.02, 1.16, dissolve);
	if (field < cut) {
		discard;
	}
	float edge = (1.0 - smoothstep(0.0, 0.045, field - cut)) * step(0.005, dissolve);
	vec2 p = vec2((pos.x - 0.5) * gate_size.x / gate_size.y, pos.y - 0.54);
	float ring = 1.0 - smoothstep(0.006, 0.014, abs(length(p) - 0.22));
	float stroke = 1.0 - smoothstep(0.007, 0.016, abs(p.y - sin(p.x * 17.0) * 0.045));
	stroke *= 1.0 - smoothstep(0.14, 0.19, abs(p.x));
	float seal = max(ring, stroke);
	float row = floor(pos.y * 6.0);
	vec2 masonry = fract(vec2(pos.x * 4.0 + mod(row, 2.0) * 0.5, pos.y * 6.0));
	float joints = (1.0 - smoothstep(0.015, 0.035, masonry.y)) * 0.12;
	joints += (1.0 - smoothstep(0.008, 0.02, masonry.x)) * 0.06;
	ALBEDO = mix(stone_color.rgb * (0.91 + grain * 0.12 - joints), rune_color.rgb, seal * 0.68);
	ROUGHNESS = 0.93;
	EMISSION = edge_color.rgb * edge * 2.2 + rune_color.rgb * seal * 0.1;
}
