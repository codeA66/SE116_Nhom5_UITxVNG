shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D aura_texture : filter_linear, repeat_disable;
uniform vec4 rarity_color : source_color = vec4(0.63, 0.73, 0.86, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.96, 0.95, 1.0, 1.0);
uniform float glow_strength = 0.88;
uniform float pulse_speed = 0.38;
uniform float selected = 0.0;
uniform float opening = 0.0;

vec2 arrow_stroke(vec2 trail, float tip, float rail, float reach, float width, float aa) {
	float along = tip - trail.x;
	float offset = abs(trail.y - rail - along * rail * 0.14);
	float head = max(0.0, min(along / 0.12, (0.23 - along) / 0.11));
	float spine = 0.36 * (1.0 - smoothstep(reach * 0.48, reach, along));
	float profile = max(head, spine) * width;
	float taper = smoothstep(0.0, 0.075, along) * (1.0 - smoothstep(reach * 0.70, reach, along));
	float stroke = (1.0 - smoothstep(profile - aa, profile + aa, offset)) * taper;
	float spill = (1.0 - smoothstep(profile, profile + 0.12, offset)) * taper;
	return vec2(stroke, spill);
}

float segment_distance(vec2 point, vec2 start, vec2 end) {
	vec2 delta = end - start;
	float along = clamp(dot(point - start, delta) / dot(delta, delta), 0.0, 1.0);
	return length(point - start - delta * along);
}

void fragment() {
	vec4 modulation = COLOR;
	vec2 p = UV * 2.0 - 1.0;
	vec2 direction = vec2(0.80, -0.60);
	vec2 trail = vec2(dot(p, direction), dot(p, vec2(-direction.y, direction.x)));
	float aa = max(fwidth(trail.y) * 0.6, 0.009);
	float elapsed = 1.0 - opening;
	float head = mix(-1.23, 1.44, smoothstep(0.07, 0.85, elapsed));
	float entry = smoothstep(0.08, 0.26, elapsed) * (1.0 - smoothstep(0.59, 0.92, elapsed));
	vec2 arrows = arrow_stroke(trail, head, -0.22, 0.92, 0.089, aa);
	arrows = max(arrows, arrow_stroke(trail, head - 0.20, -0.02, 1.05, 0.099, aa));
	arrows = max(arrows, arrow_stroke(trail, head - 0.35, 0.18, 0.82, 0.077, aa));
	float impact = smoothstep(0.31, 0.50, elapsed) * (1.0 - smoothstep(0.50, 0.73, elapsed));
	// Mũi và đuôi nằm ngoài ô để dấu bậc đặc biệt vẫn hiện khi ô không được chọn.
	vec2 bevel = vec2(trail.x, abs(trail.y));
	float head_edge = segment_distance(bevel, vec2(1.10, 0.0), vec2(0.64, 0.38));
	head_edge = min(head_edge, segment_distance(bevel, vec2(0.64, 0.38), vec2(0.27, 0.68)));
	float tail_edge = segment_distance(bevel, vec2(-0.92, 0.28), vec2(-0.60, 0.44));
	tail_edge = min(tail_edge, segment_distance(bevel, vec2(-1.03, 0.06), vec2(-0.76, 0.19)));
	tail_edge = min(tail_edge, segment_distance(bevel, vec2(-0.54, 0.49), vec2(-0.31, 0.67)));
	float nick = segment_distance(bevel, vec2(0.25, 0.73), vec2(0.04, 0.80));
	float rim_distance = min(min(head_edge, tail_edge), nick);
	float form = 1.0 - smoothstep(0.023 - aa, 0.023 + aa, rim_distance);
	float crest = 1.0 - smoothstep(0.019 - aa, 0.019 + aa, tail_edge);
	float glint = pow(0.5 + 0.5 * cos(trail.x * 5.0 - TIME * pulse_speed * 4.0), 5.0);
	float halo = (1.0 - smoothstep(0.025, 0.17, rim_distance)) * (0.20 + selected * 0.07 + impact * 0.16);
	float bank = 1.0 - smoothstep(0.18, 0.54, abs(trail.y));
	float background = texture(aura_texture, UV).r * bank * 0.12;
	float streak = entry * (arrows.x * 0.82 + arrows.y * 0.33);
	float feather = 1.0 - smoothstep(0.93, 1.0, max(abs(p.x), abs(p.y)));
	float frame = form * (0.78 + glint * 0.10 + selected * 0.10 + impact * 0.21);
	float opacity = min((frame + halo + background + streak) * feather * glow_strength, 1.0);
	vec3 steel = mix(rarity_color.rgb, highlight_color.rgb, clamp(form * 0.76 + glint * form * 0.21, 0.0, 1.0));
	vec3 lilac = vec3(0.77, 0.59, 0.95);
	vec3 shade = mix(mix(steel, lilac, crest * 0.84), highlight_color.rgb, min(streak * 0.76 + form * impact * 0.14, 0.94));
	COLOR = vec4(shade * modulation.rgb, opacity * modulation.a);
}
