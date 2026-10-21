shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz * 0.065 + vec2(TIME * 0.004, 0.0);
	float n = sin(p.x + sin(p.y * 1.3)) * 0.22 + cos(p.y * 1.7 - p.x * 0.5) * 0.15 + 0.55;
	ALBEDO = mix(vec3(0.31,0.37,0.44), vec3(0.72,0.76,0.78), smoothstep(0.15,0.95,n));
}
