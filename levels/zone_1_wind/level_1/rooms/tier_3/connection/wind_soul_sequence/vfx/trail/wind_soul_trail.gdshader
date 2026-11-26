shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;

uniform vec4 tint : source_color = vec4(0.36, 0.85, 0.67, 1.0);
uniform vec3 head;
uniform vec3 bend_near;
uniform vec3 bend_far;
uniform vec3 tail;
uniform float width : hint_range(0.01, 2.0) = 0.52;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float t = UV.x;
	float s = 1.0 - t;
	vec3 center = s * s * s * head + 3.0 * s * s * t * bend_near +
		3.0 * s * t * t * bend_far + t * t * t * tail;
	vec3 tangent = s * s * (bend_near - head) + 2.0 * s * t * (bend_far - bend_near) +
		t * t * (tail - bend_far);
	vec3 side = cross(tangent, CAMERA_POSITION_WORLD - center);
	side = dot(side, side) > 0.000001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float taper = pow(max(s, 0.0), 0.64) * mix(0.70, 1.0, smoothstep(0.0, 0.18, t));
	VERTEX = center + side * ((UV.y - 0.5) * width * taper);
}

void fragment() {
	float u = UV.x;
	float y = UV.y * 2.0 - 1.0;
	float wave = sin(u * 19.0 - TIME * 7.0) * u;
	float silk = 1.0 - smoothstep(0.075, 0.42, abs(y + wave * 0.11));
	float filament = 1.0 - smoothstep(0.04, 0.16, abs(y - 0.49 - wave * 0.16));
	float veil = 1.0 - smoothstep(0.22, 1.0, abs(y));
	float head_fade = smoothstep(0.0, 0.09, u);
	float tail_fade = 1.0 - smoothstep(0.23, 1.0, u);
	float glint = silk * (1.0 - smoothstep(0.16, 0.73, u)) * 0.74;
	ALBEDO = mix(tint.rgb * 0.68, vec3(0.91, 1.0, 0.97), glint);
	ALPHA = (veil * 0.20 + silk * 0.70 + filament * 0.48) * head_fade * tail_fade * strength;
}
