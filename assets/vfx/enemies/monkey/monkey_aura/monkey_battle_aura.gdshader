shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age = 0.0;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 p = UV;
	float side = pow(max(1.0-abs(p.x*2.0-1.0),0.0),1.5);
	float streak = pow(0.5+0.5*sin(p.x*26.0+sin(p.y*9.0-age*3.0)*1.6+age*1.8),5.0);
	float body = (1.0-smoothstep(0.25,1.0,p.y)) * smoothstep(0.0,0.25,p.y);
	float flicker = 0.82+0.18*sin(age*6.5+p.x*18.0);
	ALBEDO = vec3(0.85,0.025,0.01);
	EMISSION = vec3(1.8,0.04,0.008) * (0.8+streak);
	ALPHA = side * body * (0.24+streak*0.65) * flicker;
}
