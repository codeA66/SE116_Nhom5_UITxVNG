shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age=-1.0;
void fragment(){
	vec2 p=UV*2.0-1.0;
	float r=length(p);
	float a=atan(p.y,p.x);
	float ray=abs(sin(a*5.0+sin(r*28.0+a*4.0)*0.18));
	float cracks=(1.0-smoothstep(0.015,0.045,ray))*(1.0-smoothstep(0.45,0.92,r));
	float flash=exp(-r*10.0)*max(1.0-age*8.0,0.0);
	float ring=exp(-pow((r-clamp(age*3.8,0.0,1.15))*38.0,2.0))*(1.0-smoothstep(0.14,0.33,age));
	float fade=1.0-smoothstep(0.4,0.95,age);
	ALBEDO=vec3(1.0,0.51,0.13);
	EMISSION=vec3(1.8,0.65,0.12);
	ALPHA=(cracks*fade*.75+flash+ring*.7)*(age>=0.0?1.0:0.0);
}
