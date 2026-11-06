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
uniform float exposure_gain = 1.0;
uniform float local_radiance = 0.42;
void fragment() {
	vec3 source = texture(screen_texture,SCREEN_UV).rgb;
	float luma = dot(source,vec3(0.2126,0.7152,0.0722));
	float outside = smoothstep(focus_radius*0.3,focus_radius,distance(SCREEN_UV,focus));
	if (!local_focus) outside = 1.0;
	vec3 grade = mix(source,vec3(luma),desaturate*outside);
	grade *= 1.0-dim*mix(0.5,1.0,outside);
	float glow = 1.0-smoothstep(0.0,focus_radius*1.8,distance(SCREEN_UV,focus));
	grade *= 1.0+charge*exposure_gain;
	grade += accent.rgb*charge*glow*glow*local_radiance;
	COLOR = vec4(mix(grade,vec3(1),clamp(pulse,0.0,1.0)),1.0);
}
