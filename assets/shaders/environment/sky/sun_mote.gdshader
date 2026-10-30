// Hạt bụi bắt nắng: chấm tròn mềm cộng sáng, luôn quay mặt về camera. Màu và độ mờ lấy từ COLOR
// (color_ramp của CPUParticles3D: hiện dần, lấp lánh, tắt dần). Lõi HDR nhẹ để ăn glow.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float intensity = 2.6;
// Lấp lánh: mỗi hạt nhấp nháy lệch pha theo vị trí
uniform float twinkle_speed = 5.0;
uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.5;

varying vec4 v_color;
varying float v_phase;

void vertex() {
	v_color = COLOR;
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	v_phase = dot(MODEL_MATRIX[3].xyz, vec3(3.1, 1.7, 2.3));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float dot_shape = pow(clamp(1.0 - r, 0.0, 1.0), 1.8);
	float twinkle = 1.0 - twinkle_amount * (0.5 + 0.5 * sin(TIME * twinkle_speed + v_phase));
	ALBEDO = v_color.rgb * intensity * twinkle;
	ALPHA = clamp(dot_shape * v_color.a, 0.0, 1.0);
}
