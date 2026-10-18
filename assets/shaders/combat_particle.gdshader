// Hạt chiến đấu (CPUParticles3D). Hai kiểu trong một shader:
//  streak = true : tia sáng kéo dài theo vận tốc (align_y), thon nhọn, lõi trắng viền màu, luôn quay mặt về camera.
//  streak = false: đốm tròn mềm (bụi, hồn bay lên), billboard.
// Màu HDR (intensity > 1) để glow của môi trường ăn vào. Độ trong theo COLOR.a của hạt (color_ramp).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.65, 0.25, 1.0);
uniform float intensity = 3.0;
uniform bool streak = true;
// Độ rộng lõi trắng (0..1 so với nửa bề ngang tia)
uniform float core_width = 0.4;
uniform float dot_softness = 1.6;

varying vec4 v_color;
varying vec2 v_local;

void vertex() {
	v_color = COLOR;
	vec3 center = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[1].xyz);
	vec3 world;
	if (streak) {
		vec3 axis = MODEL_MATRIX[1].xyz / max(s, 0.00001);
		vec3 view_dir = normalize(INV_VIEW_MATRIX[3].xyz - center);
		vec3 side = cross(axis, view_dir);
		side = side / max(length(side), 0.00001);
		world = center + axis * VERTEX.y * s + side * VERTEX.x * s;
		// x: -1..1 ngang tia, y: 0 đuôi .. 1 đầu
		v_local = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	} else {
		world = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x * s + INV_VIEW_MATRIX[1].xyz * VERTEX.y * s;
		v_local = UV * 2.0 - 1.0;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	if (streak) {
		float along = clamp(v_local.y, 0.0, 1.0);
		// Thon nhọn ở đuôi, đầu tròn rồi nhọn lại ngay mút
		float half_w = pow(along, 0.75) * (1.0 - 0.9 * pow(along, 8.0));
		half_w = max(half_w, 0.0001);
		float d = abs(v_local.x) / half_w;
		float mask = 1.0 - smoothstep(0.55, 1.0, d);
		float core = 1.0 - smoothstep(0.0, core_width, d);
		vec3 col = mix(tint.rgb, vec3(1.0), core * core) * intensity * (0.35 + 0.65 * along);
		ALBEDO = col;
		ALPHA = clamp(mask * v_color.a, 0.0, 1.0);
	} else {
		float r = length(v_local);
		float a = pow(1.0 - smoothstep(0.0, 1.0, r), dot_softness);
		vec3 col = mix(tint.rgb, vec3(1.0), a * a * 0.6) * intensity;
		ALBEDO = col * v_color.rgb;
		ALPHA = clamp(a * v_color.a, 0.0, 1.0);
	}
}
