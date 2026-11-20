shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform int kind = 0;
uniform float strength = 1.0;
uniform float progress = 0.0;
uniform float fold = 0.0;
uniform float tail_growth = 0.0;
uniform float tail_slot = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec3 mouth_local = vec3(0.0, 0.25, 5.1);
varying vec3 point;

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = dot(i, vec3(1.0, 57.0, 113.0));
	vec4 a = fract(sin(n + vec4(0.0, 1.0, 57.0, 58.0)) * 43758.5453);
	vec4 b = fract(sin(n + 113.0 + vec4(0.0, 1.0, 57.0, 58.0)) * 43758.5453);
	vec4 c = mix(a, b, f.z);
	return mix(mix(c.x, c.y, f.x), mix(c.z, c.w, f.x), f.y);
}

void vertex() {
	if (kind == 2) {
		float t = UV.x;
		float angle = UV.y * 6.283185;
		float side = tail_slot;
		vec3 a = vec3(side * 0.16, 0.0, 0.0);
		vec3 goal = mouth_local + vec3(side * 0.64, 0.16 + 0.17 * (1.0 - abs(side)), -0.12);
		float aim_angle = atan(goal.z, goal.y);
		float angle_yz = mix(-1.04 - abs(side) * 0.13, aim_angle, fold);
		float reach = mix(5.1 - abs(side) * 0.28, length(goal.yz), fold);
		vec3 d = vec3(mix(side * 1.55, goal.x, fold), cos(angle_yz) * reach, sin(angle_yz) * reach);
		vec3 b = vec3(side * mix(0.80, 1.05, fold), mix(0.78, 3.25, fold), mix(-1.65, -0.8, fold));
		vec3 c = d * 0.72 + vec3(side * mix(0.78, 1.10, fold), mix(0.58, 2.90, fold), mix(-0.75, -0.50, fold));
		float u = 1.0 - t;
		vec3 center = u*u*u*a + 3.0*u*u*t*b + 3.0*u*t*t*c + t*t*t*d;
		vec3 tangent = normalize(3.0*u*u*(b-a) + 6.0*u*t*(c-b) + 3.0*t*t*(d-c));
		vec3 right = normalize(cross(tangent, vec3(0.0, 1.0, 0.001)));
		vec3 up = cross(right, tangent);
		float width = mix(0.28, 0.43, smoothstep(0.0, 0.30, t)) * (1.0 - smoothstep(0.36, 1.0, t)) + 0.012;
		float sway = sin(TIME * 3.5 - t * 9.0 + side) * sin(t * 3.14159);
		center.x += sway * mix(0.16, 0.045, fold);
		VERTEX = mix(a, center + (right*cos(angle) + up*sin(angle)) * width, tail_growth);
		NORMAL = right*cos(angle) + up*sin(angle);
	} else if (kind == 3) {
		VERTEX += NORMAL * noise(VERTEX * 5.0 + vec3(0.0, -TIME * 3.0, 0.0)) * 0.16;
	} else if (kind == 5) {
		float ridge = noise(vec3(VERTEX.xz * 7.0, progress * 5.0));
		VERTEX.y *= mix(0.30, 1.50, ridge);
		VERTEX.xz *= 0.88 + 0.17 * ridge;
	} else if (kind < 3) {
		VERTEX += NORMAL * sin(TIME * 11.0 + VERTEX.y * 18.0 + VERTEX.x * 9.0) * 0.015;
	}
	point = VERTEX;
}

void fragment() {
	vec3 flow = point * (kind == 1 ? vec3(4.0, 11.0, 4.0) : vec3(3.2));
	flow.y -= TIME * (kind == 1 ? 15.0 : 2.5);
	float n = noise(flow + noise(flow * 0.6) * 1.9);
	float ribbon = smoothstep(0.45, 0.75, n);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float boundary = 0.0;
	if (kind == 2 && dissolve > 0.0) {
		float rank = clamp(UV.x * 0.77 + n * 0.24, 0.02, 0.98);
		if (rank < dissolve) { discard; }
		boundary = 1.0 - smoothstep(0.0, 0.19, rank - dissolve);
	}
	vec3 fire = mix(vec3(0.60, 0.025, 0.006), vec3(1.0, 0.32, 0.025), ribbon);
	fire = mix(fire, vec3(1.0, 0.79, 0.26), smoothstep(0.63, 0.88, n) + rim * 0.28);
	if (kind == 1) {
		fire = mix(fire, vec3(1.0, 0.90, 0.53), 0.60 * (1.0 - rim));
	} else if (kind == 3) {
		if (n < progress * 0.85) { discard; }
		float hot_core = (0.75 + n * 0.22) * (1.0 - progress * 0.65);
		fire = mix(fire, vec3(1.0, 0.80, 0.35), hot_core);
	} else if (kind == 5) {
		float radius = length(point.xz);
		if (radius < mix(0.38, 0.76, progress) || point.y < -0.01 || n < mix(0.24, 0.87, progress)) { discard; }
		float heat = smoothstep(0.45, 0.88, n) * (1.0 - progress * 0.8);
		fire = mix(vec3(0.53, 0.026, 0.006), vec3(1.0, 0.61, 0.10), heat);
	}
	ALBEDO = fire * strength;
	EMISSION = fire * strength * (1.1 + ribbon * 0.7) + vec3(1.2, 0.34, 0.047) * boundary;
}
