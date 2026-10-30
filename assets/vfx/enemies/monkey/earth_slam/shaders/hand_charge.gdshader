shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age=0.0;
void fragment(){
	float band=pow(abs(sin(UV.y*26.0+UV.x*9.0-age*8.0)),8.0);
	float fresnel=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	ALBEDO=vec3(.32,.145,.045);
	EMISSION=vec3(.42,.19,.055);
	ALPHA=band*.5+fresnel*.3;
}
