shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform float fracture : hint_range(0.0, 1.0) = 0.0;
uniform float opening : hint_range(0.0, 1.0) = 0.0;
uniform float closure : hint_range(0.0, 1.0) = 0.0;
uniform vec4 void_color : source_color = vec4(0.055, 0.022, 0.10, 1.0);
uniform vec4 violet_color : source_color = vec4(0.43, 0.22, 0.80, 1.0);
uniform vec4 edge_color : source_color = vec4(0.92, 0.86, 1.0, 1.0);
uniform vec4 fringe_color : source_color = vec4(0.42, 0.38, 0.86, 1.0);
uniform float flow_speed : hint_range(0.0, 4.0) = 0.65;
uniform float edge_width : hint_range(0.002, 0.04) = 0.009;
uniform float aura_width : hint_range(0.02, 0.2) = 0.085;
uniform int shard_count : hint_range(0, 12) = 12;

float fissure(float y) {
	// Các đoạn gãy tạo vết xé, tránh đường sin đều như cổng phép tròn.
	float step_y = floor((y + 1.0) * 15.0);
	float corner = fract(sin(step_y * 18.37) * 431.97) - 0.5;
	return 0.042 * corner + 0.048 * sin(y * 8.0) + 0.025 * sin(y * 23.0);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0));
}

float branch(vec2 p, vec2 a, vec2 b, vec2 tip, float spread) {
	vec2 joint = mix(a, b, clamp(spread * 2.0, 0.0, 1.0));
	vec2 end = mix(b, tip, clamp(spread * 2.0 - 1.0, 0.0, 1.0));
	float d = segment_distance(p, a, joint + vec2(0.0001, 0.0));
	if (spread > 0.5) {
		d = min(d, segment_distance(p, b, end + vec2(0.0001, 0.0)));
	}
	return (1.0 - smoothstep(0.003, 0.010, d)) * smoothstep(0.0, 0.15, spread);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float clock = TIME * flow_speed;
	float reach = 1.0 - smoothstep(fracture * 0.92, fracture * 0.92 + 0.055, abs(p.y));
	float taper = pow(max(1.0 - abs(p.y) / 0.94, 0.0), 0.68);
	float side = p.x - fissure(p.y);
	float serration = 0.88 + 0.06 * sin(p.y * 29.0) + 0.06 * sin(p.y * 67.0);
	float width = opening * 0.72 * taper * serration;
	float edge_dist = abs(side) - width;
	float edge = (1.0 - smoothstep(edge_width, edge_width * 2.0, abs(edge_dist))) * reach;
	float aura = exp(-abs(edge_dist) / aura_width) * reach;
	float fringe = (1.0 - smoothstep(0.003, 0.011, abs(edge_dist - 0.035))) * reach;
	float interior = (1.0 - smoothstep(-0.007, 0.007, edge_dist)) * reach * smoothstep(0.015, 0.12, opening);

	float forks = branch(p, vec2(-width * 0.65, -0.27), vec2(-0.62, -0.40), vec2(-0.84, -0.34), smoothstep(0.12, 0.8, fracture));
	forks = max(forks, branch(p, vec2(width * 0.65, 0.17), vec2(0.55, 0.34), vec2(0.77, 0.59), smoothstep(0.26, 0.9, fracture)));
	forks = max(forks, branch(p, vec2(-width * 0.35, 0.61), vec2(-0.33, 0.74), vec2(-0.46, 0.90), smoothstep(0.42, 0.96, fracture)));
	forks *= 1.0 - 0.68 * opening;

	// Mảnh vỡ nằm trong shader để không tạo thêm hạt lúc mở khe.
	float shard_fill = 0.0;
	float shard_edge = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= shard_count) { break; }
		float k = float(i);
		float seed = fract(sin(k * 18.31 + 3.27) * 1531.34);
		float dir = mod(k, 2.0) < 1.0 ? -1.0 : 1.0;
		float y = mix(-0.78, 0.78, (k + 0.5) / 12.0);
		float local_taper = pow(max(1.0 - abs(y) / 0.94, 0.0), 0.68);
		vec2 center = vec2(fissure(y) + dir * (0.13 + opening * (0.72 * local_taper + 0.04 + seed * 0.08)), y);
		center += vec2(0.013 * cos(clock * 1.7 + k), 0.020 * sin(clock * 1.3 + k));
		vec2 v = p - center;
		float angle = seed * 6.2832 + sin(clock + k) * 0.15;
		vec2 q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * v;
		float diamond = abs(q.x) / (0.018 + seed * 0.018) + abs(q.y) / (0.038 + seed * 0.022);
		float alive = smoothstep(0.18, 0.65, fracture) * (1.0 - smoothstep(0.3, 1.0, closure));
		shard_fill = max(shard_fill, (1.0 - smoothstep(0.86, 1.0, diamond)) * alive);
		shard_edge = max(shard_edge, (1.0 - smoothstep(0.09, 0.27, abs(diamond - 0.84))) * alive);
	}

	float flow = sin(p.y * 11.0 - clock * 2.1 + sin(p.x * 8.0 + clock));
	float filament = pow(max(flow, 0.0), 22.0) * smoothstep(0.12, 0.85, abs(side) / max(width, 0.01));
	float contour = pow(max(sin(edge_dist * 46.0 + clock * 1.6 + p.y * 5.0), 0.0), 20.0);
	float pulse = 0.75 + 0.25 * sin(p.y * 15.0 - clock * 5.0);
	float highlight = max(edge * pulse, max(forks * 0.70, shard_edge * 0.68));
	vec3 interior_color = void_color.rgb + violet_color.rgb * (filament * 0.22 + contour * 0.16);
	vec3 color = mix(violet_color.rgb * 0.45, interior_color, interior);
	color = mix(color, fringe_color.rgb, fringe * 0.65);
	color = mix(color, void_color.rgb * 0.6, shard_fill);
	color = mix(color, edge_color.rgb, highlight);
	float visible_factor = smoothstep(0.0, 0.12, fracture) * (1.0 - smoothstep(0.85, 1.0, closure));
	ALBEDO = color;
	ALPHA = max(interior * 0.99, max(aura * 0.48, max(fringe * 0.65, max(highlight, shard_fill)))) * visible_factor;
}
