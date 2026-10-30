shader_type canvas_item;
render_mode unshaded;
uniform float age = -1.0;
uniform float duration = 1.1;
uniform vec4 edge_color : source_color = vec4(0.08, 0.93, 1.0, 1.0);

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise21(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = vec2(dot(p, vec2(0.78, -0.625)), dot(p, vec2(0.625, 0.78)));
	float front = clamp(age / 0.16, 0.0, 1.0) * 2.2 - 1.1;
	float fade = (1.0 - smoothstep(0.3, duration, age)) * step(0.0, age);
	float hot = 0.0; float glow = 0.0; float smoke = 0.0;
	float grain = noise21(p * 19.0 + vec2(age * 1.7, -age * 2.0));
	for (int i = 0; i < 3; i++) {
		float curve = (float(i) - 1.0) * 0.39 + 0.28 * (q.x * q.x - 0.35);
		float distance = abs(q.y - curve);
		float taper = sqrt(max(1.0 - q.x * q.x, 0.0));
		float width = 0.009 + taper * 0.025;
		float cut = smoothstep(-0.94, -0.72, q.x) * (1.0 - smoothstep(0.72, 0.97, q.x));
		cut *= 1.0 - smoothstep(front - 0.06, front, q.x);
		hot += exp(-pow(distance / width, 2.0)) * cut;
		glow += exp(-distance * 28.0) * cut;
		smoke += exp(-pow(distance / (width * 4.5 + grain * 0.07), 2.0)) * cut * (0.35 + grain * 0.65);
	}
	float alpha = clamp(smoke * 0.78 + glow * 0.65 + hot, 0.0, 1.0) * fade;
	vec3 color = mix(vec3(0.007, 0.02, 0.028), edge_color.rgb, clamp(glow * 1.5, 0.0, 1.0));
	color = mix(color, vec3(0.91, 1.0, 1.0), clamp(hot, 0.0, 1.0));
	COLOR = vec4(color, alpha);
}
