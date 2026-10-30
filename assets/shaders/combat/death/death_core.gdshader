// Lõi sáng lóe lúc quái chết (SphereMesh): giữa trắng nóng, viền fresnel đậm màu. progress 0..1 do script tween.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float intensity = 3.5;
uniform float progress = 0.0;
uniform float fresnel_power = 2.2;
// Phần trắng nóng ở giữa lõi (0 = toàn màu, 1 = trắng)
uniform float core_white = 0.3;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	float fade = pow(1.0 - progress, 2.0);
	ALBEDO = mix(mix(tint.rgb, vec3(1.0), core_white), tint.rgb, f) * intensity;
	ALPHA = clamp((0.35 + 0.65 * f) * fade, 0.0, 1.0);
}
