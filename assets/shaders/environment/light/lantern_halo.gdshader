// Quầng sáng quanh đèn lồng: quad billboard cộng sáng, sáng ở tâm và tắt dần ra mép.
// Dùng chung một material cho mọi đèn; độ sáng lấy từ INSTANCE_CUSTOM không cần ở đây nên chỉ dùng TIME
// để lập loè nhẹ (lệch pha theo vị trí đèn để các đèn không nháy đồng loạt).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 halo_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float intensity = 0.9;
// Độ đậm phần lõi (0..1 bán kính)
uniform float core_size : hint_range(0.0, 1.0) = 0.18;
uniform float flicker = 0.12;

varying float v_phase;

void vertex() {
	// Billboard: luôn quay mặt về camera, giữ scale của node
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	v_phase = dot(MODEL_MATRIX[3].xyz, vec3(1.7, 0.0, 2.3));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float glow = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	float core = 1.0 - smoothstep(core_size * 0.6, core_size, r);
	float wobble = 1.0 + flicker * (sin(TIME * 7.0 + v_phase) * 0.6 + sin(TIME * 13.0 + v_phase * 1.7) * 0.4);
	ALBEDO = halo_color.rgb * intensity * wobble * (glow + core * 1.5);
	ALPHA = clamp(glow + core, 0.0, 1.0);
}
