shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age = -1.0;
uniform vec4 tint : source_color = vec4(0.25, 0.75, 1.0, 1.0);
varying float opacity;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float p = max(age, 0.0);
	float angle = c.r * 6.28318;
	vec2 direction = vec2(cos(angle), sin(angle));
	vec2 side = vec2(-direction.y, direction.x);
	VERTEX.xy = direction * (VERTEX.x * (0.25 + c.g * 0.45)) + side * VERTEX.y * 0.025;
	VERTEX.xy += direction * p * (1.0 + c.b * 3.0);
	VERTEX.y -= p * p * 1.1;
	opacity = step(0.0, age) * (1.0 - smoothstep(0.10, 0.45 + c.a * 0.2, age));
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	ALBEDO = mix(tint.rgb, vec3(3.0), 0.55);
	ALPHA = (1.0 - smoothstep(0.5, 1.0, p.x + p.y)) * opacity;
}
