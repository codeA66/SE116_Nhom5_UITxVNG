shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D icon_mask : filter_linear_mipmap, repeat_disable;
uniform float fill : hint_range(0.0, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float ember(vec2 uv, float phase, float start_x, float start_y) {
	vec2 center = vec2(start_x + 0.026 * sin(phase * 5.0), start_y - 0.22 * phase);
	vec2 offset = abs(uv - center) * vec2(1.0, 0.60);
	return (1.0 - smoothstep(0.011, 0.019, offset.x + offset.y)) * sin(phase * 3.14159);
}

void fragment() {
	vec4 mask = texture(icon_mask, UV);
	float shape = mask.a;
	float interior = mask.g;
	float outline = shape * (1.0 - interior);
	float heat = smoothstep(0.48, 1.0, fill);
	float flicker = 0.94 + 0.06 * sin(TIME * 9.0);
	float level = mix(0.89, 0.11, fill);
	float front = level + 0.012 * sin(UV.x * 22.0 + TIME * 5.0) * sin(fill * 3.14159);
	float filled = smoothstep(front - 0.012, front + 0.012, UV.y) * step(0.001, fill);
	float crest = (1.0 - smoothstep(0.007, 0.023, abs(UV.y - front))) * sin(fill * 3.14159);
	vec3 molten = mix(vec3(0.98, 0.14, 0.025), vec3(1.0, 0.57, 0.055), smoothstep(0.40, 0.90, UV.y));
	molten = mix(molten, vec3(1.0, 0.87, 0.36), mask.b * (0.55 + 0.32 * heat));
	molten = mix(molten, vec3(1.0, 0.80, 0.28), crest * 0.8);
	vec3 center = mix(vec3(0.12, 0.038, 0.035), molten, filled);
	vec3 rim = mix(vec3(0.98, 0.57, 0.24), vec3(1.0, 0.91, 0.61), (1.0 - UV.y) * 0.59 + 0.36 * heat);
	float aura = (1.0 - smoothstep(0.06, 0.48, length((UV - vec2(0.50, 0.62)) * vec2(1.28, 1.0))))
		* (0.20 + 0.28 * heat) * flicker;
	float sparks = ember(UV, fract(TIME * 1.45), 0.79, 0.69)
		+ ember(UV, fract(TIME * 1.21 + 0.4), 0.20, 0.72)
		+ ember(UV, fract(TIME * 1.33 + 0.67), 0.74, 0.42);
	vec3 outside = mix(vec3(0.92, 0.19, 0.025), vec3(1.0, 0.76, 0.30), clamp(sparks, 0.0, 1.0));
	ALBEDO = mix(outside, mix(center, rim, 1.0 - interior), shape);
	ALPHA = max(outline + shape * interior * mix(0.87, 1.0, filled), aura + sparks * (0.33 + 0.58 * heat));
}
