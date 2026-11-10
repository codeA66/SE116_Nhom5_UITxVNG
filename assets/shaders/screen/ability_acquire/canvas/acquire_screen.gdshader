shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float dim = 0.0;
uniform float desaturate = 0.0;
uniform float pulse = 0.0;
uniform vec2 focus = vec2(0.5);
uniform float focus_radius = 0.22;
uniform bool local_focus = true;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform float charge = 0.0;
uniform float exposure_gain = 0.85;
uniform float local_radiance = 0.16;
uniform float shock = -1.0;
uniform float shock_gain = 0.004;
uniform float shock_width = 0.04;
// Vùng quanh tâm giữ lại bao nhiêu phần độ tối: thấp = đèn sân khấu rõ, 1 = tối đều cả màn
uniform float focus_dim_keep = 0.5;
void fragment() {
	vec2 delta = SCREEN_UV-focus;
	float distance_from_focus = length(delta);
	vec2 sample_uv = SCREEN_UV;
	if (shock >= 0.0) {
		float radius = shock*focus_radius*2.0;
		float band = 1.0-smoothstep(0.0,max(shock_width,0.001),abs(distance_from_focus-radius));
		sample_uv += delta/max(distance_from_focus,0.001)*band*shock_gain*(1.0-shock);
	}
	vec3 source = texture(screen_texture,clamp(sample_uv,vec2(0),vec2(1))).rgb;
	float luma = dot(source,vec3(0.2126,0.7152,0.0722));
	float outside = smoothstep(focus_radius*0.3,focus_radius,distance(SCREEN_UV,focus));
	if (!local_focus) outside = 1.0;
	vec3 grade = mix(source,vec3(luma),desaturate*outside);
	grade *= 1.0-dim*mix(focus_dim_keep,1.0,outside);
	float glow = 1.0-smoothstep(0.0,focus_radius*1.8,distance(SCREEN_UV,focus));
	grade += grade*(1.0-grade)*charge*exposure_gain*glow;
	grade += mix(accent.rgb,vec3(1),0.65)*charge*glow*glow*glow*local_radiance;
	COLOR = vec4(mix(grade,vec3(1),clamp(pulse,0.0,1.0)),1.0);
}
