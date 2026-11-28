shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 ember : source_color = vec4(0.92, 0.14, 0.026, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.58, 0.21, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.92, 0.63, 1.0);
uniform bool heated_iron = false;
uniform float power : hint_range(0.0, 2.0) = 1.0;

float tongue(vec2 p, float x, float height, float width, float curve, float phase) {
	float y = p.y / height;
	float bend = (curve + 0.1 * sin(phase + y * 6.5)) * y * y;
	float r = width * pow(max(1.0 - y, 0.0), 0.68) * (0.91 + 0.13 * sin(y * 14.0 + phase));
	return (r - abs(p.x - x - bend)) * (1.0 - smoothstep(0.86, 1.0, y));
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	vec3 rgb;
	float coverage;
	if (heated_iron) {
		float edge = (1.0 - abs(p.x)) * sin(p.y * 3.14159);
		float vein = 0.76 + 0.19 * sin(p.y * 13.0 - TIME * 3.6);
		coverage = smoothstep(0.0, 0.6, edge) * min(power, 1.0);
		rgb = mix(ember.rgb, gold.rgb, edge * vein) * (0.56 + power * 0.68);
	} else {
		float t = TIME * 5.5;
		float shape = max(tongue(p, -0.23, 0.73, 0.54, -0.16, t), tongue(p, 0.04, 0.96, 0.48, 0.24, t * 0.77 + 1.0));
		shape = max(shape, tongue(p, 0.32, 0.57, 0.35, -0.24, t * 1.11 + 3.2));
		float base = smoothstep(0.01, 0.085, p.y);
		coverage = smoothstep(0.0, 0.079, shape) * base;
		float heat = smoothstep(0.005, 0.39, shape - p.y * 0.22 + 0.08);
		rgb = mix(ember.rgb, gold.rgb, heat);
		rgb = mix(rgb, core.rgb, smoothstep(0.51, 0.91, heat) * (1.0 - p.y));
		rgb *= 1.08 + 0.25 * heat;
	}
	ALBEDO = rgb;
	ALPHA = coverage;
}
