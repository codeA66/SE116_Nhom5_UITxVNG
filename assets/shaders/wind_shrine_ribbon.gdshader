shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 wind_color : source_color = vec4(0.82, 0.929, 0.949, 1.0);
uniform float active_level : hint_range(0.0, 1.0) = 0.0;
uniform float opacity = 0.45;
uniform bool is_inlay = false;
uniform float spin_speed = 0.20944;
uniform float float_amplitude = 0.035;
uniform float float_speed = 1.4;

void vertex() {
	if (!is_inlay) {
		float angle = TIME * spin_speed;
		mat3 turn = mat3(vec3(cos(angle), 0.0, -sin(angle)), vec3(0.0, 1.0, 0.0), vec3(sin(angle), 0.0, cos(angle)));
		VERTEX = turn * VERTEX;
		VERTEX.y += sin(TIME * float_speed) * float_amplitude;
	}
}

void fragment() {
	float fade = is_inlay ? 1.0 : sin(UV.x * PI) * (1.0 - pow(abs(UV.y * 2.0 - 1.0), 3.0));
	ALBEDO = wind_color.rgb;
	ALPHA = fade * active_level * opacity;
}
