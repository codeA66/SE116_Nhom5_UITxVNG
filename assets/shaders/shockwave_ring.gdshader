// Vành sóng kích trên mặt đất (PlaneMesh nằm ngang). Vẽ theo khoảng cách ngang tới tâm (mét) nên
// vành trên hình khớp đúng vành va chạm của GroundShockwave.
// Chế độ preview: vòng báo phạm vi (nét đứt + nền mờ) hiện lúc quái tụ lực.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Bán kính tâm vành (m)
uniform float radius = 1.0;
uniform float band_width = 0.6;
uniform float max_radius = 6.0;
// Cạnh của plane (m): đổi UV 0..1 thành mét
uniform float plane_size = 13.0;
uniform vec4 wave_color : source_color = vec4(0.85, 0.5, 0.2, 1.0);
uniform vec4 front_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float wave_alpha = 0.85;

uniform bool preview = false;
// 0..1: vòng báo đậm dần tới lúc đập
uniform float preview_progress = 0.0;
uniform float preview_alpha = 0.25;
uniform float preview_edge = 0.08;
uniform float dash_count = 48.0;

const float TAU_F = 6.2831853;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * plane_size;
	float d = length(p);
	ALBEDO = wave_color.rgb;
	if (preview) {
		float edge = 1.0 - smoothstep(0.0, preview_edge, abs(d - radius));
		float dashes = step(0.5, fract(atan(p.y, p.x) * dash_count / TAU_F));
		float fill = step(d, radius) * 0.35;
		float strength = mix(preview_alpha, 1.0, preview_progress);
		ALPHA = clamp(edge * mix(0.3, 1.0, dashes) + fill * preview_alpha, 0.0, 1.0) * strength;
	} else {
		float half_band = max(band_width * 0.5, 0.0001);
		float x = (d - radius) / half_band;
		float body = 1.0 - smoothstep(0.55, 1.0, abs(x));
		float front = smoothstep(0.0, 1.0, x);
		ALBEDO = mix(wave_color.rgb, front_color.rgb, front);
		float fade = 1.0 - 0.8 * clamp(radius / max(max_radius, 0.0001), 0.0, 1.0);
		ALPHA = body * wave_alpha * fade;
	}
}
