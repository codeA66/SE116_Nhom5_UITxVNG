shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool splash = false;
uniform bool activation = false;
uniform float bend = 0.0;
uniform float fade = 1.0;

void vertex() {
	if (!splash) {
		// Dải đuôi đi theo phần vừa bay qua của quỹ đạo, luôn thấy từ góc camera.
		vec3 across = cross(vec3(0.0, 0.0, 1.0), transpose(mat3(MODEL_MATRIX)) * INV_VIEW_MATRIX[2].xyz);
		vec3 side = dot(across, across) > 0.00001 ? normalize(across) : vec3(1.0, 0.0, 0.0);
		float along = UV.x;
		VERTEX = vec3(0.0, -bend * along * along, -along);
		VERTEX += side * (UV.y - 0.5) * (1.0 - along * 0.83);
	}
}

void fragment() {
	vec3 orange = vec3(1.0, 0.22, 0.015);
	vec3 gold = vec3(1.0, 0.72, 0.09);
	vec3 core = vec3(1.0, 0.97, 0.53);
	if (splash) {
		float angle = UV.x * 6.283185;
		float scallop = 0.5 + 0.5 * sin(angle * 7.0 + sin(angle * 3.0) * 0.87);
		float skin = smoothstep(0.02, 0.23, UV.y) * (1.0 - smoothstep(0.71, 1.0, UV.y));
		float crest = 1.0 - smoothstep(0.07, 0.30, abs(UV.y - 0.51));
		if (activation) {
			ALBEDO = mix(vec3(0.59, 0.012, 0.025), vec3(1.0, 0.073, 0.033), crest);
			ALPHA = fade * skin * (0.28 + 0.34 * crest) * (0.67 + 0.33 * scallop);
		} else {
			float edge = crest * (0.62 + 0.38 * scallop);
			ALBEDO = mix(vec3(0.65, 0.026, 0.014), vec3(1.0, 0.29, 0.04), edge);
			ALPHA = fade * skin * (0.72 + 0.28 * crest);
		}
	} else {
		float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
		float taper = 1.0 - smoothstep(0.05, 1.0, UV.x);
		ALBEDO = mix(orange, mix(gold, core, taper * 0.56), smoothstep(0.24, 0.8, edge) * taper);
		ALPHA = edge * edge * taper;
	}
}
