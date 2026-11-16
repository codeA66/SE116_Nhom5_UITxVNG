shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform sampler2D soft_glow : repeat_disable, filter_linear;
uniform sampler2D star_flare : repeat_disable, filter_linear;
uniform sampler2D spark_streak : repeat_disable, filter_linear;
uniform vec4 glow_color : source_color = vec4(1.0, 0.08, 0.24, 1.0);
uniform vec4 star_color : source_color = vec4(1.0, 0.72, 0.83, 1.0);
uniform float flare_angle : hint_range(-3.14, 3.14) = 0.4;
uniform bool particle_sprite = false;

instance uniform float strength = 0.0;
instance uniform float sprite_size = 0.65;

void vertex() {
	float angle = flare_angle;
	float size = sprite_size;
	if (particle_sprite) {
		angle = INSTANCE_CUSTOM.x;
		size = length(MODELVIEW_MATRIX[0].xyz);
	}
	float c = cos(angle);
	float s = sin(angle);
	vec2 xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy * size;
	VERTEX = MODELVIEW_MATRIX[3].xyz + vec3(xy, 0.0);
}

void fragment() {
	if (particle_sprite) {
		ALBEDO = COLOR.rgb;
		ALPHA = texture(spark_streak, UV).a * COLOR.a;
	} else {
		float halo = texture(soft_glow, UV).r;
		float star = texture(star_flare, UV).a;
		ALBEDO = mix(glow_color.rgb, star_color.rgb, star);
		ALPHA = max(halo * glow_color.a, star * star_color.a) * strength;
	}
}
