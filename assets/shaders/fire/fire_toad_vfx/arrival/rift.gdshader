shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform float fracture : hint_range(0.0, 1.0) = 0.0;
uniform float opening : hint_range(0.0, 1.0) = 0.0;
uniform float closure : hint_range(0.0, 1.0) = 0.0;
uniform vec4 void_color : source_color = vec4(0.035, 0.016, 0.072, 1.0);
uniform vec4 violet_color : source_color = vec4(0.59, 0.35, 0.95, 1.0);
uniform vec4 edge_color : source_color = vec4(0.96, 0.88, 1.0, 1.0);

float fissure(float y) {
	float x = mix(-0.20, 0.03, smoothstep(-0.92, -0.54, y));
	x -= 0.23 * smoothstep(-0.54, -0.20, y);
	x += 0.30 * smoothstep(-0.20, 0.17, y);
	x -= 0.25 * smoothstep(0.17, 0.47, y);
	x += 0.27 * smoothstep(0.47, 0.91, y);
	return x + 0.012 * sin(y * 51.0) + 0.008 * sin(y * 97.0);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

float branch(vec2 p, vec2 a, vec2 b, vec2 tip, float spread) {
	vec2 joint = mix(a, b, clamp(spread * 2.0, 0.0, 1.0));
	vec2 end = mix(b, tip, clamp(spread * 2.0 - 1.0, 0.0, 1.0));
	float d = segment_distance(p, a, joint + vec2(0.0001, 0.0));
	if (spread > 0.5) {
		d = min(d, segment_distance(p, b, end + vec2(0.0001, 0.0)));
	}
	return (1.0 - smoothstep(0.004, 0.014, d)) * smoothstep(0.0, 0.15, spread);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float reach = 1.0 - smoothstep(fracture * 0.96, fracture * 0.96 + 0.07, abs(p.y));
	float taper = pow(max(1.0 - pow(abs(p.y) / 0.94, 2.0), 0.0), 0.86);
	float side = p.x - fissure(p.y);
	float rough = 0.80 + 0.12 * sin(p.y * 15.0) + 0.08 * sin(p.y * 43.0);
	float width = opening * 0.65 * taper * (rough + (side < 0.0 ? 0.03 : 0.15));
	float edge_dist = abs(side) - width;
	float aura = (1.0 - smoothstep(0.012, 0.135, abs(edge_dist))) * reach;
	float edge = (1.0 - smoothstep(0.007, 0.026, abs(edge_dist))) * reach;
	float interior = (1.0 - smoothstep(-0.020, 0.012, edge_dist)) * reach
		* smoothstep(0.015, 0.15, opening);
	float forks = branch(p, vec2(fissure(-0.16) - opening * 0.32, -0.16),
		vec2(-0.43, -0.32), vec2(-0.73, -0.25), smoothstep(0.12, 0.75, fracture));
	forks = max(forks, branch(p, vec2(fissure(0.22) + opening * 0.35, 0.22),
		vec2(0.48, 0.27), vec2(0.78, 0.54), smoothstep(0.22, 0.85, fracture)));
	forks = max(forks, branch(p, vec2(fissure(0.57) - opening * 0.18, 0.57),
		vec2(-0.34, 0.62), vec2(-0.51, 0.85), smoothstep(0.49, 0.94, fracture)));
	forks *= 1.0 - 0.80 * opening;

	// Một mặt phẳng là đủ để các mảnh vỡ văng theo mép khe cùng một nhịp.
	float shards = 0.0;
	for (int i = 0; i < 8; i++) {
		float k = float(i);
		float seed = fract(sin(k * 18.31 + 3.27) * 1531.34);
		float dir = mod(k, 2.0) < 1.0 ? -1.0 : 1.0;
		float y = mix(-0.70, 0.72, (k + 0.5) / 8.0);
		vec2 center = vec2(fissure(y) + dir * (0.10 + opening * (0.40 + seed * 0.34)), y);
		center += vec2(0.022 * cos(TIME * 4.0 + k), 0.046 * sin(TIME * 3.0 + k));
		vec2 v = p - center;
		float angle = seed * 6.2832;
		vec2 q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * v;
		float chip = 1.0 - smoothstep(0.78, 1.0, abs(q.x) / (0.012 + seed * 0.020) + abs(q.y) / (0.034 + seed * 0.027));
		shards = max(shards, chip * smoothstep(0.20, 0.70, fracture));
	}
	float drift = p.x + p.y * 0.26 + 0.10 * sin(p.y * 3.2 - TIME * 2.0);
	float streak = pow(max(0.0, sin(drift * 23.0 + TIME * 1.9)), 15.0) * 0.12;
	streak *= 0.2 + 0.8 * smoothstep(-0.8, 0.65, sin(p.y * 9.0 + p.x * 11.0 - TIME));
	float visible_factor = smoothstep(0.0, 0.12, fracture) * (1.0 - smoothstep(0.78, 1.0, closure));
	float highlight = max(edge, max(forks * 0.85, shards * 0.88));
	vec3 color = mix(violet_color.rgb, void_color.rgb + violet_color.rgb * streak, interior);
	color = mix(color, edge_color.rgb, highlight);
	ALBEDO = color;
	ALPHA = max(interior * 0.98, max(aura * 0.39, highlight)) * visible_factor;
}
